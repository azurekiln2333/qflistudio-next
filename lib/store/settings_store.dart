import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../services/app_paths.dart';

/// 应用设置（settings.json），设置页修改后立即持久化。
class SettingsStore extends ChangeNotifier {
  SettingsStore({File? storageFile}) : _storageOverride = storageFile;

  final File? _storageOverride;
  File? _storage;
  bool _loaded = false;

  /// 编辑器代码鸟瞰图可见。
  bool minimap = true;

  /// 自动保存：编辑停止 2.5 秒后写盘，写盘前把上一版本备份到 files_backup。
  bool autoSave = false;

  /// 外观主题：system / light / dark。
  String themeMode = 'system';

  ThemeMode get themeModeValue => switch (themeMode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  /// 新建文件对话框的自定义后缀（含点，如 ".md"）。
  List<String> customFileExts = [];

  /// 备份总开关：关闭后自动保存/同步不再生成历史版本备份。
  bool backupEnabled = true;

  /// 快捷符号栏：语言 → 空格分隔的符号串（用户自定义后覆盖默认）。
  Map<String, String> symbolBars = {};

  /// AI 接口（OpenAI 兼容）：地址 / 密钥 / 模型。
  String aiBaseUrl = '';
  String aiApiKey = '';
  String aiModel = '';

  bool get loaded => _loaded;

  Future<void> load() async {
    try {
      _storage = _storageOverride ?? await _resolveStorage();
      if (await _storage!.exists()) {
        final data = jsonDecode(await _storage!.readAsString());
        if (data is Map) {
          minimap = data['minimap'] as bool? ?? minimap;
          autoSave = data['autoSave'] as bool? ?? autoSave;
          themeMode = data['themeMode'] as String? ?? themeMode;
          aiBaseUrl = data['aiBaseUrl'] as String? ?? aiBaseUrl;
          aiApiKey = data['aiApiKey'] as String? ?? aiApiKey;
          aiModel = data['aiModel'] as String? ?? aiModel;
          customFileExts = [
            for (final e in (data['customFileExts'] as List? ?? []))
              e as String,
          ];
          backupEnabled = data['backupEnabled'] as bool? ?? backupEnabled;
          if (data['symbolBars'] is Map) {
            symbolBars = Map<String, String>.from(
              (data['symbolBars'] as Map).map(
                (k, v) => MapEntry(k as String, v as String),
              ),
            );
          }
        }
      }
    } catch (_) {
      // 配置损坏时用默认值。
    }
    _loaded = true;
    notifyListeners();
  }

  Future<File> _resolveStorage() async {
    final base = await AppPaths.storageDirectory();
    if (base == null) throw const FileSystemException('未找到可写的存储目录');
    return File(p.join(base, 'settings.json'));
  }

  Future<void> _persist() async {
    final file = _storage;
    if (file == null) return;
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent(
        '  ',
      ).convert({
        'version': 1,
        'minimap': minimap,
        'autoSave': autoSave,
        'themeMode': themeMode,
        'aiBaseUrl': aiBaseUrl,
        'aiApiKey': aiApiKey,
        'aiModel': aiModel,
        'customFileExts': customFileExts,
        'backupEnabled': backupEnabled,
        'symbolBars': symbolBars,
      }),
    );
  }

  Future<void> setThemeMode(String value) async {
    if (themeMode == value) return;
    themeMode = value;
    await _persist();
    notifyListeners();
  }

  Future<void> addCustomFileExt(String ext) async {
    var normalized = ext.trim();
    if (!normalized.startsWith('.')) normalized = '.$normalized';
    if (normalized.length < 2) return;
    if (customFileExts.contains(normalized)) return;
    customFileExts = [normalized, ...customFileExts];
    await _persist();
    notifyListeners();
  }

  Future<void> setBackupEnabled(bool value) async {
    if (backupEnabled == value) return;
    backupEnabled = value;
    await _persist();
    notifyListeners();
  }

  Future<void> setSymbolBar(String language, String tokens) async {
    symbolBars = {...symbolBars, language: tokens};
    await _persist();
    notifyListeners();
  }

  Future<void> saveAi({
    required String baseUrl,
    required String apiKey,
    required String model,
  }) async {
    aiBaseUrl = baseUrl;
    aiApiKey = apiKey;
    aiModel = model;
    await _persist();
    notifyListeners();
  }

  Future<void> setMinimap(bool value) async {
    if (minimap == value) return;
    minimap = value;
    notifyListeners();
    await _persist();
  }

  Future<void> setAutoSave(bool value) async {
    if (autoSave == value) return;
    autoSave = value;
    notifyListeners();
    await _persist();
  }
}
