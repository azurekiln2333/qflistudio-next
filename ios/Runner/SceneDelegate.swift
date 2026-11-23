import Flutter
import UIKit

/// 接收别的应用打开的文件。
///
/// iOS 用文档类型加打开 URL：系统把文件交给我们一个 security-scoped URL，
/// 这里按块复制进 `shared_inbox/<批次>/`，再把批次交给 Dart。Share Extension
/// 要 App Group，CI 的未签名包重签后可能失效，所以第一版不做扩展。
///
/// 通道由 [AppDelegate] 在引擎初始化时装配，本文件只负责收 URL 与复制。
final class ShareInboxBridge {
  static let shared = ShareInboxBridge()

  private static let channelName = "qflistudio/share_inbox"
  private static let inboxDirectory = "shared_inbox"
  private static let maxFiles = 16
  private static let maxFileBytes: Int64 = 2 * 1024 * 1024 * 1024
  private static let maxBatchBytes: Int64 = 512 * 1024 * 1024
  private static let copyChunk = 1024 * 1024

  private var channel: FlutterMethodChannel?
  private var pending: [String: Any]?
  private var dartListening = false
  private let queue = DispatchQueue(label: "qflistudio.share-inbox", qos: .userInitiated)

  private init() {}

  /// 由 AppDelegate 在 `didInitializeImplicitFlutterEngine` 里调用。
  func configure(messenger: FlutterBinaryMessenger) {
    guard channel == nil else { return }
    let channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterMethodNotImplemented)
        return
      }
      switch call.method {
      case "takePending":
        self.dartListening = true
        let batch = self.pending
        self.pending = nil
        result(batch)
      case "discard":
        let arguments = call.arguments as? [String: Any] ?? [:]
        guard let id = arguments["id"] as? String, Self.validBatchId(id) else {
          result(FlutterError(code: "INVALID_ARGUMENT", message: "批次 id 无效", details: nil))
          return
        }
        if let directory = self.batchDirectory(id) {
          try? FileManager.default.removeItem(at: directory)
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.channel = channel
  }

  /// 冷启动与热启动都从这里进来。
  func offer(urls: [URL]) {
    let fileURLs = urls.filter { $0.isFileURL }
    guard !fileURLs.isEmpty else { return }
    let batchId = Self.makeBatchId()
    queue.async { [weak self] in
      guard let self else { return }
      let files = self.copyAll(fileURLs, batchId: batchId)
      if files.isEmpty {
        if let directory = self.batchDirectory(batchId) {
          try? FileManager.default.removeItem(at: directory)
        }
        return
      }
      let batch: [String: Any] = [
        "id": batchId,
        "coldStart": !self.dartListening,
        "source": "document",
        "files": files,
      ]
      DispatchQueue.main.async {
        if self.dartListening, let channel = self.channel {
          channel.invokeMethod("incoming", arguments: batch)
        } else {
          self.pending = batch
        }
      }
    }
  }

  private func copyAll(_ urls: [URL], batchId: String) -> [[String: Any]] {
    guard let directory = batchDirectory(batchId) else { return [] }
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    var files: [[String: Any]] = []
    var total: Int64 = 0
    for (index, url) in urls.enumerated() {
      if files.count >= Self.maxFiles || total >= Self.maxBatchBytes { break }
      let scoped = url.startAccessingSecurityScopedResource()
      defer { if scoped { url.stopAccessingSecurityScopedResource() } }
      let name = url.lastPathComponent.isEmpty ? "shared_\(index + 1)" : url.lastPathComponent
      let target = directory.appendingPathComponent(
        String(format: "%04d-%@", index + 1, Self.safeName(name) as NSString)
      )
      guard let copied = copyFile(from: url, to: target), copied > 0 else { continue }
      total += copied
      files.append([
        "path": target.path,
        "name": name,
        "bytes": Int(copied),
        "mimeType": Self.mimeType(of: url) as Any,
      ])
    }
    return files
  }

  private func copyFile(from url: URL, to target: URL) -> Int64? {
    guard let input = try? FileHandle(forReadingFrom: url) else { return nil }
    defer { try? input.close() }
    FileManager.default.createFile(atPath: target.path, contents: nil)
    guard let output = try? FileHandle(forWritingTo: target) else { return nil }
    defer { try? output.close() }
    var total: Int64 = 0
    while true {
      guard let chunk = try? input.read(upToCount: Self.copyChunk), !chunk.isEmpty else { break }
      total += Int64(chunk.count)
      if total > Self.maxFileBytes {
        try? FileManager.default.removeItem(at: target)
        return nil
      }
      try? output.write(contentsOf: chunk)
    }
    return total
  }

  private func batchDirectory(_ id: String) -> URL? {
    guard
      let support = FileManager.default.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
      ).first
    else { return nil }
    return support
      .appendingPathComponent(Self.inboxDirectory, isDirectory: true)
      .appendingPathComponent(id, isDirectory: true)
  }

  private static func validBatchId(_ id: String) -> Bool {
    let allowed = CharacterSet(
      charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-")
    return !id.isEmpty && id.count <= 64
      && id.unicodeScalars.allSatisfy { allowed.contains($0) }
  }

  private static func makeBatchId() -> String {
    let suffix = UUID().uuidString.prefix(4)
    return "\(Int(Date().timeIntervalSince1970 * 1000))-\(suffix)"
  }

  private static func safeName(_ name: String) -> String {
    let flattened = name.isEmpty ? "shared-file" : name
    let cleaned = flattened.map { character -> Character in
      if "\\/:*?\"<>|".contains(character) { return "_" }
      if let scalar = character.unicodeScalars.first, scalar.value < 0x20 { return "_" }
      return character
    }
    return String(cleaned.prefix(120))
  }

  private static func mimeType(of url: URL) -> String? {
    // 部署目标是 iOS 13，用扩展名查表，不引 UniformTypeIdentifiers。
    switch url.pathExtension.lowercased() {
    case "txt", "md", "log": return "text/plain"
    case "json": return "application/json"
    case "pdf": return "application/pdf"
    case "png": return "image/png"
    case "jpg", "jpeg": return "image/jpeg"
    case "gif": return "image/gif"
    case "zip": return "application/zip"
    case "mp4": return "video/mp4"
    case "mp3": return "audio/mpeg"
    default: return nil
    }
  }
}

class SceneDelegate: FlutterSceneDelegate {

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    // 冷启动：进程由打开文件拉起。
    ShareInboxBridge.shared.offer(urls: connectionOptions.urlContexts.map { $0.url })
  }

  override func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    super.scene(scene, openURLContexts: URLContexts)
    // 热启动：应用已在运行。
    ShareInboxBridge.shared.offer(urls: URLContexts.map { $0.url })
  }
}