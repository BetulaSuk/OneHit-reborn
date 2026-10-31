#include "native_bridge.h"

#include <dwmapi.h>
#include <dwrite.h>
#include <flutter/standard_method_codec.h>
#include <ole2.h>
#include <shellscalingapi.h>
#include <windowsx.h>

#include <cmath>
#include <string>

#include "resource.h"

namespace {

constexpr UINT kTrayMessage = WM_APP + 1;
constexpr UINT kEndPrefixMessage = WM_APP + 2;
constexpr int kPrefixHotkey = 0x4F48;
constexpr UINT_PTR kPrefixTimer = 0x4F48;
// How long the key after the prefix is waited for.
constexpr UINT kPrefixWait = 3000;

constexpr wchar_t kRunKey[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
constexpr wchar_t kRunValue[] = L"OneHit";

std::string Utf8(const std::wstring& wide) {
  if (wide.empty()) return {};
  int size = WideCharToMultiByte(CP_UTF8, 0, wide.data(),
                                 static_cast<int>(wide.size()), nullptr, 0,
                                 nullptr, nullptr);
  std::string out(size, '\0');
  WideCharToMultiByte(CP_UTF8, 0, wide.data(), static_cast<int>(wide.size()),
                      out.data(), size, nullptr, nullptr);
  return out;
}

std::wstring Wide(const std::string& utf8) {
  if (utf8.empty()) return {};
  int size = MultiByteToWideChar(CP_UTF8, 0, utf8.data(),
                                 static_cast<int>(utf8.size()), nullptr, 0);
  std::wstring out(size, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()),
                      out.data(), size);
  return out;
}

flutter::EncodableValue V(const std::string& s) {
  return flutter::EncodableValue(s);
}

const flutter::EncodableValue* Field(const flutter::EncodableMap& map,
                                     const char* key) {
  auto it = map.find(flutter::EncodableValue(key));
  return it == map.end() ? nullptr : &it->second;
}

double Scale(HWND hwnd) { return GetDpiForWindow(hwnd) / 96.0; }

double Number(const flutter::EncodableValue& value) {
  if (auto d = std::get_if<double>(&value)) return *d;
  if (auto i = std::get_if<int32_t>(&value)) return *i;
  if (auto l = std::get_if<int64_t>(&value)) return static_cast<double>(*l);
  return 0;
}

CLIPFORMAT UrlFormat() {
  static CLIPFORMAT format = static_cast<CLIPFORMAT>(
      RegisterClipboardFormat(L"UniformResourceLocatorW"));
  return format;
}

bool Has(IDataObject* data, CLIPFORMAT format) {
  FORMATETC fmt = {format, nullptr, DVASPECT_CONTENT, -1, TYMED_HGLOBAL};
  return data->QueryGetData(&fmt) == S_OK;
}

std::wstring ReadText(IDataObject* data, CLIPFORMAT format) {
  FORMATETC fmt = {format, nullptr, DVASPECT_CONTENT, -1, TYMED_HGLOBAL};
  STGMEDIUM medium;
  if (data->GetData(&fmt, &medium) != S_OK) return {};
  std::wstring text;
  if (auto chars = static_cast<const wchar_t*>(GlobalLock(medium.hGlobal))) {
    text = chars;
    GlobalUnlock(medium.hGlobal);
  }
  ReleaseStgMedium(&medium);
  return text;
}

flutter::EncodableList ReadFiles(IDataObject* data) {
  flutter::EncodableList files;
  FORMATETC fmt = {CF_HDROP, nullptr, DVASPECT_CONTENT, -1, TYMED_HGLOBAL};
  STGMEDIUM medium;
  if (data->GetData(&fmt, &medium) != S_OK) return files;
  if (auto drop = static_cast<HDROP>(GlobalLock(medium.hGlobal))) {
    UINT count = DragQueryFileW(drop, 0xFFFFFFFF, nullptr, 0);
    for (UINT i = 0; i < count; ++i) {
      UINT length = DragQueryFileW(drop, i, nullptr, 0);
      std::wstring path(length, L'\0');
      DragQueryFileW(drop, i, path.data(), length + 1);
      files.push_back(flutter::EncodableValue(Utf8(path)));
    }
    GlobalUnlock(medium.hGlobal);
  }
  ReleaseStgMedium(&medium);
  return files;
}

struct Monitor {
  HMONITOR handle;
  MONITORINFOEXW info;
};

BOOL CALLBACK AddMonitor(HMONITOR handle, HDC, LPRECT, LPARAM out) {
  Monitor m{handle, {}};
  m.info.cbSize = sizeof(m.info);
  if (GetMonitorInfoW(handle, &m.info)) {
    reinterpret_cast<std::vector<Monitor>*>(out)->push_back(m);
  }
  return TRUE;
}

std::vector<Monitor> Monitors() {
  std::vector<Monitor> list;
  EnumDisplayMonitors(nullptr, nullptr, AddMonitor,
                      reinterpret_cast<LPARAM>(&list));
  return list;
}

// The monitor named [device] (like \\.\DISPLAY1), else the primary one.
const Monitor* FindMonitor(const std::vector<Monitor>& list,
                           const std::string& device) {
  for (const auto& m : list) {
    if (Utf8(m.info.szDevice) == device) return &m;
  }
  for (const auto& m : list) {
    if (m.info.dwFlags & MONITORINFOF_PRIMARY) return &m;
  }
  return list.empty() ? nullptr : &list.front();
}

double MonitorScale(HMONITOR monitor) {
  UINT x = 96, y = 96;
  GetDpiForMonitor(monitor, MDT_EFFECTIVE_DPI, &x, &y);
  return x / 96.0;
}

flutter::EncodableValue Displays() {
  flutter::EncodableList list;
  for (const auto& m : Monitors()) {
    DISPLAY_DEVICEW device = {};
    device.cb = sizeof(device);
    std::wstring name;
    if (EnumDisplayDevicesW(m.info.szDevice, 0, &device, 0)) {
      name = device.DeviceString;
    }
    const RECT& r = m.info.rcMonitor;
    bool primary = (m.info.dwFlags & MONITORINFOF_PRIMARY) != 0;
    list.push_back(flutter::EncodableValue(flutter::EncodableMap{
        {V("id"), V(Utf8(m.info.szDevice))},
        {V("name"), V(Utf8(name))},
        {V("primary"), flutter::EncodableValue(primary)},
        {V("left"), flutter::EncodableValue(static_cast<int>(r.left))},
        {V("width"), flutter::EncodableValue(static_cast<int>(r.right - r.left))},
        {V("height"),
         flutter::EncodableValue(static_cast<int>(r.bottom - r.top))},
        {V("scale"), flutter::EncodableValue(MonitorScale(m.handle))},
    }));
  }
  return flutter::EncodableValue(list);
}

std::string FontName(IDWriteLocalizedStrings* names, const wchar_t* locale) {
  UINT32 index = 0;
  BOOL exists = FALSE;
  names->FindLocaleName(locale, &index, &exists);
  if (!exists) index = 0;
  UINT32 length = 0;
  names->GetStringLength(index, &length);
  std::wstring name(length, L'\0');
  names->GetString(index, name.data(), length + 1);
  return Utf8(name);
}

// Font families as [family, name in the user's language]. DirectWrite's
// list is what Flutter's text engine can find by family name.
flutter::EncodableValue Fonts() {
  flutter::EncodableList list;
  IDWriteFactory* factory = nullptr;
  if (FAILED(DWriteCreateFactory(DWRITE_FACTORY_TYPE_SHARED,
                                 __uuidof(IDWriteFactory),
                                 reinterpret_cast<IUnknown**>(&factory)))) {
    return flutter::EncodableValue(list);
  }
  wchar_t locale[LOCALE_NAME_MAX_LENGTH] = L"en-us";
  GetUserDefaultLocaleName(locale, LOCALE_NAME_MAX_LENGTH);
  IDWriteFontCollection* fonts = nullptr;
  if (SUCCEEDED(factory->GetSystemFontCollection(&fonts, FALSE))) {
    for (UINT32 i = 0; i < fonts->GetFontFamilyCount(); ++i) {
      IDWriteFontFamily* family = nullptr;
      if (FAILED(fonts->GetFontFamily(i, &family))) continue;
      IDWriteLocalizedStrings* names = nullptr;
      if (SUCCEEDED(family->GetFamilyNames(&names))) {
        list.push_back(flutter::EncodableValue(flutter::EncodableList{
            V(FontName(names, L"en-us")), V(FontName(names, locale))}));
        names->Release();
      }
      family->Release();
    }
    fonts->Release();
  }
  factory->Release();
  return flutter::EncodableValue(list);
}

std::wstring LaunchCommand() {
  wchar_t path[MAX_PATH];
  GetModuleFileNameW(nullptr, path, MAX_PATH);
  return L"\"" + std::wstring(path) + L"\"";
}

// True when Windows starts this very executable at sign-in.
bool Autostart() {
  wchar_t value[MAX_PATH + 8];
  DWORD size = sizeof(value);
  if (RegGetValueW(HKEY_CURRENT_USER, kRunKey, kRunValue, RRF_RT_REG_SZ,
                   nullptr, value, &size) != ERROR_SUCCESS) {
    return false;
  }
  return _wcsicmp(value, LaunchCommand().c_str()) == 0;
}

void SetAutostart(bool on) {
  if (!on) {
    RegDeleteKeyValueW(HKEY_CURRENT_USER, kRunKey, kRunValue);
    return;
  }
  std::wstring command = LaunchCommand();
  RegSetKeyValueW(HKEY_CURRENT_USER, kRunKey, kRunValue, REG_SZ,
                  command.c_str(),
                  static_cast<DWORD>((command.size() + 1) * sizeof(wchar_t)));
}

bool IsModifier(DWORD vk) {
  switch (vk) {
    case VK_SHIFT:
    case VK_LSHIFT:
    case VK_RSHIFT:
    case VK_CONTROL:
    case VK_LCONTROL:
    case VK_RCONTROL:
    case VK_MENU:
    case VK_LMENU:
    case VK_RMENU:
    case VK_LWIN:
    case VK_RWIN:
      return true;
  }
  return false;
}

}  // namespace

NativeBridge* NativeBridge::hooked_ = nullptr;

class NativeBridge::DropTarget : public IDropTarget {
 public:
  explicit DropTarget(NativeBridge* bridge) : bridge_(bridge) {}

  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, void** out) override {
    if (iid == IID_IDropTarget || iid == IID_IUnknown) {
      AddRef();
      *out = this;
      return S_OK;
    }
    *out = nullptr;
    return E_NOINTERFACE;
  }

  ULONG STDMETHODCALLTYPE AddRef() override {
    return InterlockedIncrement(&refs_);
  }

  ULONG STDMETHODCALLTYPE Release() override {
    LONG count = InterlockedDecrement(&refs_);
    if (count == 0) delete this;
    return count;
  }

  HRESULT STDMETHODCALLTYPE DragEnter(IDataObject* data, DWORD, POINTL pt,
                                      DWORD* effect) override {
    accept_ = Has(data, CF_HDROP) || Has(data, UrlFormat()) ||
              Has(data, CF_UNICODETEXT);
    return DragOver(0, pt, effect);
  }

  HRESULT STDMETHODCALLTYPE DragOver(DWORD, POINTL pt,
                                     DWORD* effect) override {
    *effect = accept_ ? DROPEFFECT_COPY : DROPEFFECT_NONE;
    if (accept_) {
      bridge_->channel_->InvokeMethod(
          "dragOver", std::make_unique<flutter::EncodableValue>(Point(pt)));
    }
    return S_OK;
  }

  HRESULT STDMETHODCALLTYPE DragLeave() override {
    if (accept_) bridge_->channel_->InvokeMethod("dragLeave", nullptr);
    return S_OK;
  }

  HRESULT STDMETHODCALLTYPE Drop(IDataObject* data, DWORD, POINTL pt,
                                 DWORD* effect) override {
    *effect = accept_ ? DROPEFFECT_COPY : DROPEFFECT_NONE;
    if (!accept_) return S_OK;
    flutter::EncodableMap args = Point(pt);
    args[flutter::EncodableValue("files")] =
        flutter::EncodableValue(ReadFiles(data));
    args[flutter::EncodableValue("url")] =
        flutter::EncodableValue(Utf8(ReadText(data, UrlFormat())));
    args[flutter::EncodableValue("text")] =
        flutter::EncodableValue(Utf8(ReadText(data, CF_UNICODETEXT)));
    bridge_->channel_->InvokeMethod(
        "drop", std::make_unique<flutter::EncodableValue>(args));
    return S_OK;
  }

 private:
  // Drop position in logical pixels from the window's top-left corner.
  flutter::EncodableMap Point(POINTL pt) const {
    POINT p{pt.x, pt.y};
    ScreenToClient(bridge_->window_, &p);
    double scale = Scale(bridge_->window_);
    return {
        {flutter::EncodableValue("x"), flutter::EncodableValue(p.x / scale)},
        {flutter::EncodableValue("y"), flutter::EncodableValue(p.y / scale)},
    };
  }

  NativeBridge* bridge_;
  LONG refs_ = 1;
  bool accept_ = false;
};

NativeBridge::NativeBridge(flutter::BinaryMessenger* messenger, HWND window,
                           HWND view)
    : window_(window), view_(view) {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "onehit/native",
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    const std::string& method = call.method_name();
    const auto* args = call.arguments();
    const auto* map = std::get_if<flutter::EncodableMap>(args);
    if (method == "setRegion") {
      SetRegion(std::get_if<flutter::EncodableList>(args));
      result->Success();
    } else if (method == "setTray" && map) {
      SetTray(*map);
      result->Success();
    } else if (method == "setPrefix") {
      result->Success(flutter::EncodableValue(SetPrefix(map)));
    } else if (method == "endPrefix") {
      EndPrefix();
      result->Success();
    } else if (method == "displays") {
      result->Success(Displays());
    } else if (method == "placeOn") {
      const auto* device = std::get_if<std::string>(args);
      result->Success(PlaceOn(device ? *device : ""));
    } else if (method == "fonts") {
      result->Success(Fonts());
    } else if (method == "autostart") {
      result->Success(flutter::EncodableValue(Autostart()));
    } else if (method == "setAutostart") {
      const auto* on = std::get_if<bool>(args);
      SetAutostart(on && *on);
      result->Success();
    } else {
      result->NotImplemented();
    }
  });
  taskbar_created_ = RegisterWindowMessageW(L"TaskbarCreated");

  // Windows 11 draws a border around framed windows; on a window the size
  // of the screen it shows as a line around the screen edge.
  COLORREF no_border = 0xFFFFFFFE;  // DWMWA_COLOR_NONE
  DwmSetWindowAttribute(window_, 34 /* DWMWA_BORDER_COLOR */, &no_border,
                        sizeof(no_border));

  OleInitialize(nullptr);
  drop_target_ = new DropTarget(this);
  RegisterDragDrop(view_, drop_target_);
}

NativeBridge::~NativeBridge() {
  EndPrefix();
  UnregisterHotKey(window_, kPrefixHotkey);
  if (tray_added_) Shell_NotifyIconW(NIM_DELETE, &tray_);
  if (tray_.hIcon) DestroyIcon(tray_.hIcon);
  RevokeDragDrop(view_);
  if (drop_target_) drop_target_->Release();
  channel_->SetMethodCallHandler(nullptr);
  OleUninitialize();
}

std::optional<LRESULT> NativeBridge::HandleMessage(UINT message, WPARAM wparam,
                                                   LPARAM lparam) {
  switch (message) {
    case kTrayMessage:
      switch (LOWORD(lparam)) {
        case NIN_SELECT:
        case NIN_KEYSELECT:
          channel_->InvokeMethod("trayClick", nullptr);
          break;
        case WM_CONTEXTMENU:
          ShowTrayMenu(GET_X_LPARAM(wparam), GET_Y_LPARAM(wparam));
          break;
      }
      return 0;
    case WM_HOTKEY:
      if (wparam != kPrefixHotkey) break;
      StartPrefix();
      return 0;
    case WM_TIMER:
      if (wparam != kPrefixTimer) break;
      if (!taken_) channel_->InvokeMethod("prefixEnd", nullptr);
      EndPrefix();
      return 0;
    case kEndPrefixMessage:
      EndPrefix();
      return 0;
    case WM_DPICHANGED:
      // Windows suggests a rect scaled for the new DPI; the window keeps
      // covering the work area instead.
      if (placed_.empty()) break;
      PlaceOn(placed_);
      return 0;
    case WM_DISPLAYCHANGE:
      if (!placed_.empty()) PlaceOn(placed_);
      break;
    case WM_SETTINGCHANGE:
      if (wparam == SPI_SETWORKAREA && !placed_.empty()) PlaceOn(placed_);
      break;
  }
  // Explorer restarted: the icon has to be added again.
  if (message == taskbar_created_ && tray_added_) {
    tray_added_ = false;
    AddTray();
  }
  return std::nullopt;
}

// Each rect is [left, top, right, bottom, radius] in logical pixels from the
// window's top-left corner; null covers the whole window. The window always
// keeps a region: without one, Windows draws its frame border around the
// screen-sized window.
void NativeBridge::SetRegion(const flutter::EncodableList* rects) {
  if (!rects) {
    RECT client;
    GetClientRect(window_, &client);
    SetWindowRgn(window_, CreateRectRgnIndirect(&client), TRUE);
    return;
  }
  double scale = Scale(window_);
  HRGN region = CreateRectRgn(0, 0, 0, 0);
  for (const auto& value : *rects) {
    const auto* r = std::get_if<flutter::EncodableList>(&value);
    if (!r || r->size() < 5) continue;
    int left = static_cast<int>(std::floor(Number((*r)[0]) * scale));
    int top = static_cast<int>(std::floor(Number((*r)[1]) * scale));
    int right = static_cast<int>(std::ceil(Number((*r)[2]) * scale));
    int bottom = static_cast<int>(std::ceil(Number((*r)[3]) * scale));
    int diameter = static_cast<int>(std::round(Number((*r)[4]) * 2 * scale));
    HRGN part = CreateRoundRectRgn(left, top, right + 1, bottom + 1,
                                   diameter, diameter);
    CombineRgn(region, region, part, RGN_OR);
    DeleteObject(part);
  }
  // The system owns the region after this call.
  SetWindowRgn(window_, region, TRUE);
}

// args: tip (string), items ([id, label] pairs; an empty label is a
// separator). The first call adds the icon.
void NativeBridge::SetTray(const flutter::EncodableMap& args) {
  tray_items_.clear();
  if (const auto* items = Field(args, "items")) {
    for (const auto& value : std::get<flutter::EncodableList>(*items)) {
      const auto& pair = std::get<flutter::EncodableList>(value);
      tray_items_.emplace_back(std::get<std::string>(pair[0]),
                               Wide(std::get<std::string>(pair[1])));
    }
  }
  std::wstring tip;
  if (const auto* t = Field(args, "tip")) tip = Wide(std::get<std::string>(*t));
  wcsncpy_s(tray_.szTip, tip.c_str(), _TRUNCATE);
  if (tray_added_) {
    Shell_NotifyIconW(NIM_MODIFY, &tray_);
  } else {
    AddTray();
  }
}

void NativeBridge::AddTray() {
  tray_.cbSize = sizeof(tray_);
  tray_.hWnd = window_;
  tray_.uID = 1;
  tray_.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP | NIF_SHOWTIP;
  tray_.uCallbackMessage = kTrayMessage;
  if (!tray_.hIcon) {
    UINT dpi = GetDpiForWindow(window_);
    tray_.hIcon = static_cast<HICON>(LoadImageW(
        GetModuleHandleW(nullptr), MAKEINTRESOURCEW(IDI_APP_ICON), IMAGE_ICON,
        GetSystemMetricsForDpi(SM_CXSMICON, dpi),
        GetSystemMetricsForDpi(SM_CYSMICON, dpi), 0));
  }
  tray_added_ = Shell_NotifyIconW(NIM_ADD, &tray_);
  tray_.uVersion = NOTIFYICON_VERSION_4;
  Shell_NotifyIconW(NIM_SETVERSION, &tray_);
}

void NativeBridge::ShowTrayMenu(int x, int y) {
  HMENU menu = CreatePopupMenu();
  for (size_t i = 0; i < tray_items_.size(); ++i) {
    const auto& label = tray_items_[i].second;
    if (label.empty()) {
      AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
    } else {
      AppendMenuW(menu, MF_STRING, i + 1, label.c_str());
    }
  }
  // Without this the menu stays open when the user clicks elsewhere.
  SetForegroundWindow(window_);
  UINT align =
      GetSystemMetrics(SM_MENUDROPALIGNMENT) ? TPM_RIGHTALIGN : TPM_LEFTALIGN;
  UINT chosen = TrackPopupMenuEx(menu,
                                 TPM_RETURNCMD | TPM_NONOTIFY |
                                     TPM_RIGHTBUTTON | TPM_BOTTOMALIGN | align,
                                 x, y, window_, nullptr);
  PostMessageW(window_, WM_NULL, 0, 0);
  DestroyMenu(menu);
  if (chosen > 0 && chosen <= tray_items_.size()) {
    channel_->InvokeMethod("trayMenu",
                           std::make_unique<flutter::EncodableValue>(
                               tray_items_[chosen - 1].first));
  }
}

// args: mods (MOD_* flags) and vk; null only clears the current prefix.
// False when another app already owns the combination.
bool NativeBridge::SetPrefix(const flutter::EncodableMap* args) {
  EndPrefix();
  UnregisterHotKey(window_, kPrefixHotkey);
  prefix_vk_ = 0;
  if (!args) return true;
  const auto* mods = Field(*args, "mods");
  const auto* vk = Field(*args, "vk");
  if (!mods || !vk) return false;
  prefix_vk_ = static_cast<UINT>(Number(*vk));
  return RegisterHotKey(window_, kPrefixHotkey,
                        static_cast<UINT>(Number(*mods)) | MOD_NOREPEAT,
                        prefix_vk_) != 0;
}

void NativeBridge::StartPrefix() {
  EndPrefix();
  hooked_ = this;
  hook_ = SetWindowsHookExW(WH_KEYBOARD_LL, KeyboardProc,
                            GetModuleHandleW(nullptr), 0);
  prefix_held_ = (GetAsyncKeyState(prefix_vk_) & 0x8000) != 0;
  SetTimer(window_, kPrefixTimer, kPrefixWait, nullptr);
  channel_->InvokeMethod("prefix", nullptr);
}

void NativeBridge::EndPrefix() {
  KillTimer(window_, kPrefixTimer);
  if (hook_) UnhookWindowsHookEx(hook_);
  hook_ = nullptr;
  hooked_ = nullptr;
  taken_ = 0;
  prefix_held_ = false;
}

// While the prefix waits: modifiers pass (so the prefix's own can be
// released), and the first other key press is reported to Dart and
// swallowed along with its release.
LRESULT CALLBACK NativeBridge::KeyboardProc(int code, WPARAM wparam,
                                            LPARAM lparam) {
  NativeBridge* self = hooked_;
  if (code != HC_ACTION || !self) {
    return CallNextHookEx(nullptr, code, wparam, lparam);
  }
  DWORD vk = reinterpret_cast<KBDLLHOOKSTRUCT*>(lparam)->vkCode;
  bool down = wparam == WM_KEYDOWN || wparam == WM_SYSKEYDOWN;
  if (self->taken_) {
    if (vk != self->taken_) {
      return CallNextHookEx(nullptr, code, wparam, lparam);
    }
    // Unhooking is left to the window's message loop, outside the hook.
    if (!down) PostMessageW(self->window_, kEndPrefixMessage, 0, 0);
    return 1;
  }
  if (vk == self->prefix_vk_ && self->prefix_held_) {
    if (!down) self->prefix_held_ = false;
    return CallNextHookEx(nullptr, code, wparam, lparam);
  }
  if (!down || IsModifier(vk)) {
    return CallNextHookEx(nullptr, code, wparam, lparam);
  }
  self->taken_ = vk;
  // Now only its release is awaited; give up on that after a while.
  SetTimer(self->window_, kPrefixTimer, 1000, nullptr);
  self->channel_->InvokeMethod(
      "prefixKey",
      std::make_unique<flutter::EncodableValue>(static_cast<int>(vk)));
  return 1;
}

// Covers the work area of the monitor named [device] (the primary one when
// it is gone) and returns {id, width, height} in that monitor's logical px.
flutter::EncodableValue NativeBridge::PlaceOn(const std::string& device) {
  auto monitors = Monitors();
  const Monitor* m = FindMonitor(monitors, device);
  if (!m) return flutter::EncodableValue();
  placed_ = Utf8(m->info.szDevice);
  const RECT& w = m->info.rcWork;
  SetWindowPos(window_, nullptr, w.left, w.top, w.right - w.left,
               w.bottom - w.top, SWP_NOZORDER | SWP_NOACTIVATE);
  double scale = MonitorScale(m->handle);
  return flutter::EncodableValue(flutter::EncodableMap{
      {V("id"), V(placed_)},
      {V("width"), flutter::EncodableValue((w.right - w.left) / scale)},
      {V("height"), flutter::EncodableValue((w.bottom - w.top) / scale)},
  });
}
