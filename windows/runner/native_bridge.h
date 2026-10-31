#ifndef RUNNER_NATIVE_BRIDGE_H_
#define RUNNER_NATIVE_BRIDGE_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <windows.h>
// windows.h first: shellapi.h needs its declarations.
#include <shellapi.h>

#include <memory>
#include <optional>
#include <string>
#include <utility>
#include <vector>

// Window services the Dart side needs beyond window_manager, on the
// "onehit/native" channel:
//  - setRegion: clip the window to the visible pills so its transparent
//    parts pass clicks through to whatever is underneath.
//  - dragOver / dragLeave / drop (to Dart): a drop target that accepts
//    files, URLs and text, so an image file or link can become an icon.
//  - setTray, trayClick / trayMenu (to Dart): the notification-area icon.
//  - setPrefix, endPrefix, prefix / prefixKey / prefixEnd (to Dart): the
//    global prefix key. After it, the next key press anywhere is taken
//    from the foreground app and reported instead.
//  - displays, placeOn: monitors, and covering one's work area.
//  - fonts, autostart, setAutostart.
class NativeBridge {
 public:
  NativeBridge(flutter::BinaryMessenger* messenger, HWND window, HWND view);
  ~NativeBridge();

  NativeBridge(const NativeBridge&) = delete;
  NativeBridge& operator=(const NativeBridge&) = delete;

  // Top-level window messages: the tray icon's callbacks, the prefix
  // hotkey and its timeout.
  std::optional<LRESULT> HandleMessage(UINT message, WPARAM wparam,
                                       LPARAM lparam);

 private:
  class DropTarget;

  void SetRegion(const flutter::EncodableList* rects);
  void SetTray(const flutter::EncodableMap& args);
  void AddTray();
  void ShowTrayMenu(int x, int y);
  bool SetPrefix(const flutter::EncodableMap* args);
  void StartPrefix();
  void EndPrefix();
  flutter::EncodableValue PlaceOn(const std::string& device);

  static LRESULT CALLBACK KeyboardProc(int code, WPARAM wparam,
                                       LPARAM lparam);
  static NativeBridge* hooked_;

  HWND window_;
  HWND view_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  DropTarget* drop_target_ = nullptr;

  NOTIFYICONDATAW tray_ = {};
  bool tray_added_ = false;
  UINT taskbar_created_ = 0;
  // Menu entries as (id, label); an empty label is a separator.
  std::vector<std::pair<std::string, std::wstring>> tray_items_;

  UINT prefix_vk_ = 0;
  HHOOK hook_ = nullptr;
  // The prefix's own key, still held when the hook starts.
  bool prefix_held_ = false;
  // The key taken after the prefix, until it is released.
  DWORD taken_ = 0;

  // Device name of the monitor whose work area the window covers.
  std::string placed_;
};

#endif  // RUNNER_NATIVE_BRIDGE_H_
