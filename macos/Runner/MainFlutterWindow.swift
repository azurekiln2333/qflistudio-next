import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var platformChannel: FlutterMethodChannel?
  private var sharePicker: NSSharingServicePicker?
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let channel = FlutterMethodChannel(
      name: "qflistudio/platform", binaryMessenger: flutterViewController.engine.binaryMessenger)
    platformChannel = channel
    channel.setMethodCallHandler { [weak self] call, reply in
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
      guard call.method == "shareFile" else { reply(FlutterMethodNotImplemented); return }
      guard let path = args["path"] as? String,
        args["mimeType"] as? String == "application/zip",
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
        let view = self?.contentView else {
        reply(FlutterError(code: "INVALID_ARGUMENT", message: "A prepared ZIP is required.", details: nil))
        return
      }
      // path_provider appends the bundle identifier on macOS.
      let root = support.appendingPathComponent(Bundle.main.bundleIdentifier ?? "")
        .appendingPathComponent("archive_shares").resolvingSymlinksInPath().path + "/"
      let file = URL(fileURLWithPath: path).resolvingSymlinksInPath()
      guard file.path.hasPrefix(root), file.pathExtension == "zip",
        FileManager.default.fileExists(atPath: file.path) else {
        reply(FlutterError(code: "SHARE_FAILED", message: "Share ZIP is unavailable.", details: nil))
        return
      }
      let picker = NSSharingServicePicker(items: [file])
      self?.sharePicker = picker
      picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
      reply(true) // Never unlink: a receiving app may read later.
    }

    super.awakeFromNib()
  }
}
