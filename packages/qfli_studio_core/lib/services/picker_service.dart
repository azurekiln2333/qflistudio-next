import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';

import 'app_paths.dart';

class PickedDocument {
  const PickedDocument({this.path, this.uri, this.name});

  final String? path;
  final String? uri;
  final String? name;

  bool get isLocalFile => path != null && path!.isNotEmpty;
}

/// File, folder and photo selection boundary shared by desktop and HarmonyOS.
abstract final class PickerService {
  static const MethodChannel _channel = MethodChannel('qflistudio/platform');

  /// Test hook for exercising the native contract on a desktop host.
  static bool forcePlatformChannel = false;

  static Future<PickedDocument?> pickDocument({
    bool folder = false,
    List<String> extensions = const ['json'],
  }) async {
    if (AppPaths.isDesktop && !forcePlatformChannel) {
      if (folder) {
        final path = await getDirectoryPath();
        return path == null ? null : PickedDocument(path: path);
      }
      final file = await openFile(
        acceptedTypeGroups: [
          XTypeGroup(label: 'QFLI document', extensions: extensions),
        ],
      );
      return file == null ? null : PickedDocument(path: file.path, name: file.name);
    }
    final raw = await _channel.invokeMethod<Object?>('pickDocument', {
      'folder': folder,
      'extensions': extensions,
    });
    return _document(raw);
  }

  static Future<PickedDocument?> saveDocument({
    String suggestedName = 'qfli-project.json',
  }) async {
    if (AppPaths.isDesktop && !forcePlatformChannel) {
      final location = await getSaveLocation(suggestedName: suggestedName);
      return location == null ? null : PickedDocument(path: location.path);
    }
    final raw = await _channel.invokeMethod<Object?>('saveDocument', {
      'suggestedName': suggestedName,
    });
    return _document(raw);
  }

  static Future<List<PickedDocument>> pickPhotos() async {
    if (AppPaths.isDesktop && !forcePlatformChannel) {
      final files = await openFiles(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'Images',
            extensions: ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'],
          ),
        ],
      );
      return [for (final file in files) PickedDocument(path: file.path, name: file.name)];
    }
    final raw = await _channel.invokeMethod<Object?>('pickPhotos');
    if (raw is! List) return const [];
    final documents = <PickedDocument>[];
    for (final item in raw) {
      final document = _document(item);
      if (document != null) documents.add(document);
    }
    return documents;
  }

  static Future<Uint8List> readUri(String uri) async {
    final raw = await _channel.invokeMethod<Object?>('readUri', {'uri': uri});
    if (raw is Uint8List) return raw;
    if (raw is List) return Uint8List.fromList(raw.cast<int>());
    throw const FormatException('Picker 未返回文件内容');
  }

  static Future<void> writeUri(String uri, Uint8List bytes) async {
    await _channel.invokeMethod<void>('writeUri', {'uri': uri, 'bytes': bytes});
  }

  static PickedDocument? _document(Object? raw) {
    if (raw is String && raw.isNotEmpty) return PickedDocument(uri: raw);
    if (raw is! Map) return null;
    return PickedDocument(
      path: raw['path'] as String?,
      uri: raw['uri'] as String?,
      name: raw['name'] as String?,
    );
  }
}
