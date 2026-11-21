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
    let channel = FlutterMethodChannel(
      name: "qflistudio/platform", binaryMessenger: engineBridge.applicationRegistrar.messenger())
    platformChannel = channel
    channel.setMethodCallHandler { call, reply in
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
      reply(FlutterMethodNotImplemented)
    }
  }
}
