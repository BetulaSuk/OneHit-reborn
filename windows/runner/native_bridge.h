#ifndef RUNNER_NATIVE_BRIDGE_H_
#define RUNNER_NATIVE_BRIDGE_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <memory>

// Window services the Dart side needs beyond window_manager, on the
// "onehit/native" channel:
//  - setRegion: clip the window to the visible pills so its transparent
//    parts pass clicks through to whatever is underneath.
//  - dragOver / dragLeave / drop (to Dart): a drop target that accepts
//    files, URLs and text, so an image file or link can become an icon.
class NativeBridge {
 public:
  NativeBridge(flutter::BinaryMessenger* messenger, HWND window, HWND view);
  ~NativeBridge();

  NativeBridge(const NativeBridge&) = delete;
  NativeBridge& operator=(const NativeBridge&) = delete;

 private:
  class DropTarget;

  void SetRegion(const flutter::EncodableList& rects);

  HWND window_;
  HWND view_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  DropTarget* drop_target_ = nullptr;
};

#endif  // RUNNER_NATIVE_BRIDGE_H_
