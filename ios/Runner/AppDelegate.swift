import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var platformChannel: FlutterMethodChannel?
  private let externalFolders = ExternalFolderStore()

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
    channel.setMethodCallHandler { [weak self] call, reply in
      let arguments = call.arguments as? [String: Any] ?? [:]
      if let store = self?.externalFolders, store.handle(call, reply: reply) { return }
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


/// 外部文件夹：安全作用域书签与范围登记。
///
/// 原生持有书签与已打开的安全作用域。Dart 只拿不透明 id 与解析后的路径。
final class ExternalFolderStore: NSObject, UIDocumentPickerDelegate {
  private struct Entry: Codable {
    var id: String
    var name: String
    var bookmark: String
  }

  private let queue = DispatchQueue(label: "qfli.external.fs")
  private var entries: [Entry] = []
  private var scopes: [String: URL] = [:]
  private var loaded = false
  private var pickReply: FlutterResult?

  // MARK: - 通道

  func handle(_ call: FlutterMethodCall, reply: @escaping FlutterResult) -> Bool {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "pickFolder":
      presentPicker(reply)
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

  private func presentPicker(_ reply: @escaping FlutterResult) {
    DispatchQueue.main.async {
      guard self.pickReply == nil else {
        reply(
          FlutterError(
            code: "PICKER_BUSY", message: "Another folder picker is already open.", details: nil))
        return
      }
      guard let host = self.presenter() else {
        reply(
          FlutterError(
            code: "INVALID_ARGUMENT", message: "No presenter for the folder picker.", details: nil))
        return
      }
      self.pickReply = reply
      let picker = UIDocumentPickerViewController(documentTypes: ["public.folder"], in: .open)
      picker.delegate = self
      picker.allowsMultipleSelection = false
      host.present(picker, animated: true)
    }
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let reply = pickReply else { return }
    pickReply = nil
    guard let url = urls.first else {
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
      let bookmark = try makeBookmark(url)
      let id = UUID().uuidString
      let name = url.lastPathComponent
      loadEntries()
      entries.append(Entry(id: id, name: name, bookmark: bookmark.base64EncodedString()))
      saveEntries()
      scopes[id] = url
      reply(["id": id, "name": name, "path": url.path])
    } catch {
      url.stopAccessingSecurityScopedResource()
      reply(
        FlutterError(
          code: "INVALID_ARGUMENT", message: error.localizedDescription, details: nil))
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    guard let reply = pickReply else { return }
    pickReply = nil
    reply(nil)
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
    return support.appendingPathComponent("qfli_external_folders.json")
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

  // MARK: - 呈现

  private func presenter() -> UIViewController? {
    let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    var controller =
      scene?.windows.first { $0.isKeyWindow }?.rootViewController
      ?? (UIApplication.shared.delegate as? AppDelegate)?.window?.rootViewController
    while let presented = controller?.presentedViewController {
      controller = presented
    }
    return controller
  }
}