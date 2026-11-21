#ifndef RUNNER_ARCHIVE_SHARE_H_
#define RUNNER_ARCHIVE_SHARE_H_

#include <windows.h>
#include <flutter/encodable_value.h>
#include <flutter/method_result.h>
#include <memory>
#include <string>

// One per top-level HWND, created/used/disposed on the Flutter platform thread.
// WinRT callbacks retain only independent request state, never FlutterWindow.
class WindowsArchiveShare {
 public:
  explicit WindowsArchiveShare(HWND owner);
  ~WindowsArchiveShare();
  WindowsArchiveShare(const WindowsArchiveShare&) = delete;
  WindowsArchiveShare& operator=(const WindowsArchiveShare&) = delete;

  void Share(const std::string& path, const std::string& title,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void Dispose();

 private:
  struct Impl;
  std::unique_ptr<Impl> impl_;
};

#endif  // RUNNER_ARCHIVE_SHARE_H_
