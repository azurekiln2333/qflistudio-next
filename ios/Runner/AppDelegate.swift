import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var platformChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // 接收分享文件：文档类型打开后由 SceneDelegate 转给这个桥。
    ShareInboxBridge.shared.configure(
      messenger: engineBridge.applicationRegistrar.messenger())
    let channel = FlutterMethodChannel(
      name: "qflistudio/platform", binaryMessenger: engineBridge.applicationRegistrar.messenger())
    platformChannel = channel
    channel.setMethodCallHandler { [weak self] call, reply in
      let arguments = call.arguments as? [String: Any] ?? [:]
      if call.method == "openUrl" {
        guard let value = arguments["url"] as? String, let url = URL(string: value),
          ["http", "https"].contains(url.scheme ?? ""), url.host != nil,
          url.user == nil, url.password == nil else {
          reply(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid browser URL.", details: nil))
          return
        }
        UIApplication.shared.open(url, options: [:]) { opened in
          reply(opened ? nil : FlutterError(code: "UNSUPPORTED", message: "Browser unavailable.", details: nil))
        }
        return
      }
      guard call.method == "shareFile" else { reply(FlutterMethodNotImplemented); return }
      guard let path = arguments["path"] as? String,
        arguments["mimeType"] as? String == "application/zip",
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      else {
        reply(FlutterError(code: "INVALID_ARGUMENT", message: "A prepared ZIP is required.", details: nil))
        return
      }
      let root = support.appendingPathComponent("archive_shares").resolvingSymlinksInPath().path + "/"
      let file = URL(fileURLWithPath: path).resolvingSymlinksInPath()
      let sceneWindow = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap { $0.windows }
        .first { $0.isKeyWindow }
      guard file.path.hasPrefix(root), file.pathExtension == "zip",
        FileManager.default.fileExists(atPath: file.path),
        var presenter = sceneWindow?.rootViewController ?? self?.window?.rootViewController else {
        reply(FlutterError(code: "SHARE_FAILED", message: "Share ZIP is unavailable.", details: nil))
        return
      }
      while let presented = presenter.presentedViewController { presenter = presented }
      let sheet = UIActivityViewController(activityItems: [file], applicationActivities: nil)
      if let popover = sheet.popoverPresentationController {
        popover.sourceView = presenter.view
        popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 1, height: 1)
      }
      // Handoff only; no deletion on dismissal or completion.
      presenter.present(sheet, animated: true) { reply(true) }
    }
  }
}
