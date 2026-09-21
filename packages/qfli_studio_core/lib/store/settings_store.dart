import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../services/app_paths.dart';
import '../editor/highlight_import.dart';
import '../editor/textmate_grammar.dart';

ImportedHighlightTheme _parseHighlightTheme(
  ({String source, String name}) input,
) => ImportedHighlightTheme.parse(input.source, name: input.name);

TextMateGrammar _parseTextMateGrammar(
  ({String source, String? fileTypes}) input,
) => TextMateGrammar.parse(input.source, fileTypes: input.fileTypes);

({ImportedHighlightTheme? theme, List<TextMateGrammar> grammars})
_restoreHighlightImports(Map<String, dynamic> data) {
  ImportedHighlightTheme? theme;
  final savedTheme = data['importedHighlightTheme'];
  if (savedTheme is Map && savedTheme['source'] is String) {
    try {
      theme = ImportedHighlightTheme.parse(
        savedTheme['source'] as String,
        name: savedTheme['name'] as String? ?? '自定义配色',
      );
    } catch (_) {
      // 损坏的导入配置退回内置配色。
    }
  }
  final grammars = <TextMateGrammar>[];
  final savedGrammars = data['textMateGrammars'];
  if (savedGrammars is List) {
    for (final saved in savedGrammars.take(12)) {
      if (saved is! Map || saved['source'] is! String) continue;
      try {
        grammars.add(
          TextMateGrammar.parse(
            saved['source'] as String,
            fileTypes: saved['fileTypes'] as String?,
          ),
        );
      } catch (_) {
        // 一份语法失败不影响其他语法。
      }
    }
  }
  return (theme: theme, grammars: grammars);
}

/// 应用设置（settings.json），设置页修改后立即持久化。
class SettingsStore extends ChangeNotifier {
  SettingsStore({File? storageFile}) : _storageOverride = storageFile;

  final File? _storageOverride;
  File? _storage;
  bool _loaded = false;
  Future<void>? _writes;

  /// 编辑器代码鸟瞰图可见。
  bool minimap = true;

  /// 编辑器顶部的打开文件标签栏可见。
  bool showEditorTabs = true;

  /// 自动保存：编辑停止 2.5 秒后写盘，写盘前把上一版本备份到 files_backup。
  bool autoSave = false;

  /// 外观主题：system / light / dark。
  String themeMode = 'system';

  bool syntaxHighlighting = true;
  bool textMateEnabled = true;
  String highlightTheme = 'system';
  Map<String, String> highlightColors = {};
  ImportedHighlightTheme? importedHighlightTheme;
  List<TextMateGrammar> customGrammars = [];
  int highlightRevision = 0;

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
          showEditorTabs = data['showEditorTabs'] as bool? ?? showEditorTabs;
          autoSave = data['autoSave'] as bool? ?? autoSave;
          themeMode = data['themeMode'] as String? ?? themeMode;
          syntaxHighlighting = data['syntaxHighlighting'] as bool? ?? true;
          textMateEnabled = data['textMateEnabled'] as bool? ?? true;
          final selectedTheme = data['highlightTheme'];
          if (['system', 'light', 'dark', 'custom'].contains(selectedTheme)) {
            highlightTheme = selectedTheme as String;
          }
          final colors = data['highlightColors'];
          if (colors is Map) {
            for (final entry in colors.entries) {
              if (entry.key is! String || entry.value is! String) continue;
              try {
                parseHighlightColor(entry.value as String);
                highlightColors[entry.key as String] = entry.value as String;
              } on FormatException {
                // 单个无效颜色不影响其他设置。
              }
            }
          }
          if (data['importedHighlightTheme'] is Map ||
              (data['textMateGrammars'] is List &&
                  (data['textMateGrammars'] as List).isNotEmpty)) {
            final imported = await compute(
              _restoreHighlightImports,
              Map<String, dynamic>.from(data),
            );
            importedHighlightTheme = imported.theme;
            customGrammars = imported.grammars;
          }
          if (highlightTheme == 'custom' && importedHighlightTheme == null) {
            highlightTheme = 'system';
          }
          highlightRevision++;
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

  Future<void> _persist() {
    final file = _storage;
    if (file == null) return Future.value();
    final encoded = const JsonEncoder.withIndent('  ').convert({
      'version': 1,
      'minimap': minimap,
      'showEditorTabs': showEditorTabs,
      'autoSave': autoSave,
      'themeMode': themeMode,
      'syntaxHighlighting': syntaxHighlighting,
      'textMateEnabled': textMateEnabled,
      'highlightTheme': highlightTheme,
      'highlightColors': highlightColors,
      if (importedHighlightTheme case final imported?)
        'importedHighlightTheme': {
          'name': imported.name,
          'source': imported.source,
        },
      'textMateGrammars': [
        for (final grammar in customGrammars)
          {'source': grammar.source, 'fileTypes': grammar.fileTypes.join(',')},
      ],
      'aiBaseUrl': aiBaseUrl,
      'aiApiKey': aiApiKey,
      'aiModel': aiModel,
      'customFileExts': customFileExts,
      'backupEnabled': backupEnabled,
      'symbolBars': symbolBars,
    });
    Future<void> write() async {
      await file.parent.create(recursive: true);
      await file.writeAsString(encoded);
    }

    final previous = _writes;
    return _writes = previous == null
        ? write()
        : previous.catchError((Object _) {}).then((_) => write());
  }

  Future<void> _highlightChanged() {
    highlightRevision++;
    notifyListeners();
    return _persist();
  }

  Future<void> setSyntaxHighlighting(bool value) {
    syntaxHighlighting = value;
    return _highlightChanged();
  }

  Future<void> setTextMateEnabled(bool value) {
    textMateEnabled = value;
    return _highlightChanged();
  }

  Future<void> setHighlightTheme(String value) {
    if (!['system', 'light', 'dark', 'custom'].contains(value) ||
        (value == 'custom' && importedHighlightTheme == null)) {
      throw ArgumentError.value(value, 'value', '无效的高亮主题');
    }
    highlightTheme = value;
    return _highlightChanged();
  }

  Future<void> setHighlightColor(String token, String? color) {
    if (color == null || color.trim().isEmpty) {
      highlightColors = {...highlightColors}..remove(token);
    } else {
      parseHighlightColor(color);
      highlightColors = {...highlightColors, token: color.trim()};
    }
    return _highlightChanged();
  }

  Future<void> resetHighlightColors() {
    highlightColors = {};
    return _highlightChanged();
  }

  Future<String> importHighlightTheme(
    String source, {
    String name = '自定义配色',
  }) async {
    final imported = await compute(_parseHighlightTheme, (
      source: source,
      name: name,
    ));
    importedHighlightTheme = imported;
    highlightTheme = 'custom';
    await _highlightChanged();
    return imported.name;
  }

  Future<void> removeHighlightTheme() {
    importedHighlightTheme = null;
    if (highlightTheme == 'custom') highlightTheme = 'system';
    return _highlightChanged();
  }

  Future<String> importTextMateGrammar(
    String source, {
    String? fileTypes,
  }) async {
    final grammar = await compute(_parseTextMateGrammar, (
      source: source,
      fileTypes: fileTypes,
    ));
    if (customGrammars.length >= 12 &&
        !customGrammars.any((item) => item.scopeName == grammar.scopeName)) {
      throw const FormatException('最多导入 12 份语法，请先移除不再使用的语法');
    }
    customGrammars = [
      grammar,
      ...customGrammars.where((item) => item.scopeName != grammar.scopeName),
    ];
    textMateEnabled = true;
    await _highlightChanged();
    return grammar.name;
  }

  Future<void> removeTextMateGrammar(String scopeName) {
    customGrammars = customGrammars
        .where((item) => item.scopeName != scopeName)
        .toList();
    return _highlightChanged();
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

  Future<void> setShowEditorTabs(bool value) async {
    if (showEditorTabs == value) return;
    showEditorTabs = value;
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
