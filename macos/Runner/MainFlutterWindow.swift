import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var platformChannel: FlutterMethodChannel?
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let channel = FlutterMethodChannel(
      name: "qflistudio/platform", binaryMessenger: flutterViewController.engine.binaryMessenger)
    platformChannel = channel
    channel.setMethodCallHandler { call, reply in
      let args = call.arguments as? [String: Any] ?? [:]
      if call.method == "openUrl" {
        guard let text = args["url"] as? String, let url = URL(string: text),
          ["https", "http"].contains(url.scheme ?? ""), url.host != nil,
          url.user == nil, url.password == nil else {
          reply(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid browser URL.", details: nil))
          return
        }
        reply(NSWorkspace.shared.open(url) ? nil : FlutterError(code: "UNSUPPORTED", message: "Browser unavailable.", details: nil))
        return
      }
      reply(FlutterMethodNotImplemented)
    }

    super.awakeFromNib()
  }
}
