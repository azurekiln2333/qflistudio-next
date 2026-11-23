#include "flutter_window.h"

#include <optional>
#include <string>
#include <utility>
#include <vector>

#include "flutter/generated_plugin_registrant.h"
#include "folder_drop.h"
#include <flutter/standard_method_codec.h>

namespace {

// Batch shape shared with Core: {id: String, paths: List<String>}.
flutter::EncodableValue BatchToValue(const FolderDrop::PendingBatch& batch) {
  flutter::EncodableList paths;
  paths.reserve(batch.paths.size());
  for (const auto& path : batch.paths) {
    paths.push_back(flutter::EncodableValue(path));
  }
  flutter::EncodableMap map;
  map[flutter::EncodableValue("id")] = flutter::EncodableValue(batch.id);
  map[flutter::EncodableValue("paths")] = flutter::EncodableValue(paths);
  return flutter::EncodableValue(map);
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  archive_share_ = std::make_unique<WindowsArchiveShare>(GetHandle());
  platform_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "qflistudio/platform",
      &flutter::StandardMethodCodec::GetInstance());
  platform_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() != "shareFile") {
          result->NotImplemented();
          return;
        }
        const auto* arguments = call.arguments()
            ? std::get_if<flutter::EncodableMap>(call.arguments()) : nullptr;
        const auto text = [arguments](const char* key) -> const std::string* {
          if (!arguments) return nullptr;
          const auto found = arguments->find(flutter::EncodableValue(key));
          return found == arguments->end()
              ? nullptr : std::get_if<std::string>(&found->second);
        };
        const auto* path = text("path");
        const auto* title = text("title");
        const auto* mime = text("mimeType");
        if (!path || !mime || *mime != "application/zip") {
          result->Error("INVALID_ARGUMENT", "A prepared ZIP is required.");
          return;
        }
        archive_share_->Share(*path, title ? *title : "ZIP archive", std::move(result));
      });

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // Directory drops. The target is registered on the Flutter child window,
  // because it covers the client area and receives the drag messages.
  drop_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "qflistudio/folder_drop",
      &flutter::StandardMethodCodec::GetInstance());
  // Attach adopts the initial COM reference. OLE owns its own reference.
  drop_target_.Attach(new FolderDrop());
  if (!drop_target_->Register(
          flutter_controller_->view()->GetNativeWindow())) {
    // Drops unavailable. Keep the target so takePending can report why rather
    // than silently returning an empty list.
    drop_registered_ = false;
  } else {
    drop_registered_ = true;
  }
  drop_target_->SetCallbacks(
      [this](const FolderDrop::PendingBatch& batch) {
        if (!drop_channel_) return;
        drop_channel_->InvokeMethod(
            "incoming", std::make_unique<flutter::EncodableValue>(BatchToValue(batch)));
      },
      [this](const std::string& message) {
        if (!drop_channel_) return;
        flutter::EncodableMap args;
        args[flutter::EncodableValue("message")] = flutter::EncodableValue(message);
        drop_channel_->InvokeMethod(
            "rejected", std::make_unique<flutter::EncodableValue>(args));
      });
  drop_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() != "takePending") {
          result->NotImplemented();
          return;
        }
        if (!drop_target_ || !drop_registered_) {
          result->Error("UNAVAILABLE",
                        "Directory drop is not available on this window.");
          return;
        }
        // Dart is listening: flush the backlog and stop queueing.
        const auto pending = drop_target_->TakePending();
        drop_target_->MarkReady();
        flutter::EncodableList list;
        list.reserve(pending.size());
        for (const auto& batch : pending) {
          list.push_back(BatchToValue(batch));
        }
        result->Success(flutter::EncodableValue(list));
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  // Revoke the OLE drop target before the child window goes away.
  if (drop_target_) {
    drop_target_->Unregister();
    drop_target_.Reset();
  }
  drop_registered_ = false;
  drop_channel_ = nullptr;
  // Complete/cancel native replies before destroying the Flutter messenger.
  if (archive_share_) archive_share_->Dispose();
  archive_share_ = nullptr;
  platform_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      if (flutter_controller_) {
        flutter_controller_->engine()->ReloadSystemFonts();
      }
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
