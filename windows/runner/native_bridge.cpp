#include "native_bridge.h"

#include <flutter/standard_method_codec.h>
#include <ole2.h>
#include <shellapi.h>

#include <cmath>
#include <string>

namespace {

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

}  // namespace

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
    if (call.method_name() == "setRegion") {
      const auto* rects = std::get_if<flutter::EncodableList>(call.arguments());
      SetRegion(rects ? *rects : flutter::EncodableList{});
      result->Success();
    } else {
      result->NotImplemented();
    }
  });

  OleInitialize(nullptr);
  drop_target_ = new DropTarget(this);
  RegisterDragDrop(view_, drop_target_);
}

NativeBridge::~NativeBridge() {
  RevokeDragDrop(view_);
  if (drop_target_) drop_target_->Release();
  channel_->SetMethodCallHandler(nullptr);
  OleUninitialize();
}

// Each rect is [left, top, right, bottom, radius] in logical pixels from the
// window's top-left corner. An empty list removes the region.
void NativeBridge::SetRegion(const flutter::EncodableList& rects) {
  if (rects.empty()) {
    SetWindowRgn(window_, nullptr, TRUE);
    return;
  }
  double scale = Scale(window_);
  HRGN region = CreateRectRgn(0, 0, 0, 0);
  for (const auto& value : rects) {
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
