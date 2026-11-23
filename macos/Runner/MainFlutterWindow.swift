import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var platformChannel: FlutterMethodChannel?
  private var sharePicker: NSSharingServicePicker?
  private let externalFolders = ExternalFolderStore()
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
      if let store = self?.externalFolders, store.handle(call, reply: reply) { return }
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


/// 外部文件夹：app-scope 书签与范围登记。
///
/// 沙盒里只有 NSOpenPanel 的选择能生成书签。原生持有书签与已打开的范围。
final class ExternalFolderStore: NSObject {
  private struct Entry: Codable {
    var id: String
    var name: String
    var bookmark: String
  }

  private let queue = DispatchQueue(label: "qfli.external.fs")
  private var entries: [Entry] = []
  private var scopes: [String: URL] = [:]
  private var loaded = false
  private weak var window: NSWindow?

  // MARK: - 通道

  func handle(_ call: FlutterMethodCall, reply: @escaping FlutterResult) -> Bool {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "pickFolder":
      presentPanel(reply)
      return true
    case "resolveFolders":
      resolveAll(reply)
      return true
    case "releaseFolder":
      releaseFolder(args["id"] as? String, reply)
      return true
    default:
      return false
    }
  }

  // MARK: - 选择

  private func presentPanel(_ reply: @escaping FlutterResult) {
    DispatchQueue.main.async {
      let panel = NSOpenPanel()
      panel.canChooseDirectories = true
      panel.canChooseFiles = false
      panel.allowsMultipleSelection = false
      panel.canCreateDirectories = false
      let finish: (NSApplication.ModalResponse) -> Void = { response in
        guard response == .OK, let url = panel.url else {
          reply(nil)
          return
        }
        guard url.startAccessingSecurityScopedResource() else {
          reply(
            FlutterError(
              code: "NO_SCOPE", message: "The folder could not be opened.", details: nil))
          return
        }
        do {
          let bookmark = try self.makeBookmark(url)
          let id = UUID().uuidString
          let name = url.lastPathComponent
          self.loadEntries()
          self.entries.append(Entry(id: id, name: name, bookmark: bookmark.base64EncodedString()))
          self.saveEntries()
          self.scopes[id] = url
          reply(["id": id, "name": name, "path": url.path])
        } catch {
          url.stopAccessingSecurityScopedResource()
          reply(
            FlutterError(
              code: "INVALID_ARGUMENT", message: error.localizedDescription, details: nil))
        }
      }
      if let window = self.presenterWindow() {
        panel.beginSheetModal(for: window, completionHandler: finish)
      } else {
        panel.begin(completionHandler: finish)
      }
    }
  }

  private func presenterWindow() -> NSWindow? {
    if let key = NSApplication.shared.keyWindow { return key }
    return NSApplication.shared.windows.first { $0.isVisible }
  }

  // MARK: - 解析与释放

  private func resolveAll(_ reply: @escaping FlutterResult) {
    loadEntries()
    var payload: [[String: Any]] = []
    var renewed = false
    for index in entries.indices {
      let entry = entries[index]
      guard let data = Data(base64Encoded: entry.bookmark) else { continue }
      var stale = false
      guard
        let url = try? URL(
          resolvingBookmarkData: data,
          options: .withSecurityScope,
          relativeTo: nil,
          bookmarkDataIsStale: &stale)
      else { continue }
      if scopes[entry.id] == nil {
        _ = url.startAccessingSecurityScopedResource()
        scopes[entry.id] = url
      }
      if stale, let fresh = try? makeBookmark(url) {
        entries[index].bookmark = fresh.base64EncodedString()
        renewed = true
      }
      payload.append(["id": entry.id, "name": entry.name, "path": url.path, "stale": stale])
    }
    if renewed { saveEntries() }
    reply(payload)
  }

  private func releaseFolder(_ id: String?, _ reply: @escaping FlutterResult) {
    guard let id = id, !id.isEmpty else {
      reply(
        FlutterError(code: "INVALID_ARGUMENT", message: "A folder id is required.", details: nil))
      return
    }
    loadEntries()
    if let url = scopes.removeValue(forKey: id) {
      url.stopAccessingSecurityScopedResource()
    }
    entries.removeAll { $0.id == id }
    saveEntries()
    reply(nil)
  }

  // MARK: - 书签存储

  private var storeURL: URL? {
    guard
      let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        .first
    else { return nil }
    // path_provider 在 macOS 上会再拼一层 bundle id，这里跟随同一布局。
    let folder = support.appendingPathComponent(Bundle.main.bundleIdentifier ?? "")
    return folder.appendingPathComponent("qfli_external_folders.json")
  }

  private func loadEntries() {
    if loaded { return }
    loaded = true
    guard let url = storeURL, let data = try? Data(contentsOf: url),
      let decoded = try? JSONDecoder().decode([Entry].self, from: data)
    else { return }
    entries = decoded
  }

  private func saveEntries() {
    guard let url = storeURL else { return }
    let folder = url.deletingLastPathComponent()
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    guard let data = try? JSONEncoder().encode(entries) else { return }
    try? data.write(to: url, options: .atomic)
  }

  private func makeBookmark(_ url: URL) throws -> Data {
    return try url.bookmarkData(
      options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
  }
}