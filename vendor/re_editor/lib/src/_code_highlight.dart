part of re_editor;

class _CodeHighlighter extends ValueNotifier<List<_HighlightResult>> {
  final BuildContext _context;
  final _CodeParagraphProvider _provider;
  final _CodeHighlightEngine _engine;

  CodeLineEditingController _controller;
  CodeHighlightTheme? _theme;
  Timer? _debounce;

  _CodeHighlighter({
    required BuildContext context,
    required CodeLineEditingController controller,
    CodeHighlightTheme? theme,
  })  : _context = context,
        _provider = _CodeParagraphProvider(),
        _controller = controller,
        _theme = theme,
        _engine = _CodeHighlightEngine(theme),
        super(const []) {
    _controller.addListener(_onCodesChanged);
    _processHighlight();
  }

  set controller(CodeLineEditingController value) {
    if (_controller == value) {
      return;
    }
    _controller.removeListener(_onCodesChanged);
    _debounce?.cancel();
    _engine.invalidate();
    _controller = value;
    _controller.addListener(_onCodesChanged);
    _processHighlight();
  }

  set theme(CodeHighlightTheme? value) {
    if (_theme == value) {
      return;
    }
    _theme = value;
    _debounce?.cancel();
    _engine.theme = value;
    _processHighlight();
  }

  IParagraph build({
    required int index,
    required TextStyle style,
    required double maxWidth,
    int? maxLengthSingleLineRendering,
  }) {
    _provider.updateBaseStyle(style);
    _provider.updateMaxLengthSingleLineRendering(maxLengthSingleLineRendering);
    return _provider.build(
        _controller.buildTextSpan(
            context: _context,
            index: index,
            textSpan: _buildSpan(index, style),
            style: style),
        maxWidth);
  }

  void clearCache() {
    _provider.clearCache();
  }

  @override
  void dispose() {
    _controller.removeListener(_onCodesChanged);
    _debounce?.cancel();
    _engine.dispose();
    super.dispose();
  }

  TextSpan _buildSpan(int index, TextStyle style) {
    final String text = _controller.codeLines[index].text;
    if (index >= value.length) {
      return TextSpan(text: text, style: style);
    }
    final _HighlightResult result = value[index];
    if (result.nodes.isEmpty) {
      return TextSpan(text: text, style: style);
    }
    if (result.source == text) {
      return _buildSpanFromNodes(result.nodes, style);
    }
    // Diff the changes and reuse node to avoid style blink.
    final List<_HighlightNode> startNodes = [];
    int start = 0;
    int end = text.length;
    for (int i = 0; i < result.nodes.length && start < end; i++) {
      final String value = result.nodes[i].value;
      if (text.startsWith(value, start)) {
        startNodes.add(result.nodes[i]);
        start += value.length;
      } else {
        break;
      }
    }
    final List<_HighlightNode> endNodes = [];
    for (int i = result.nodes.length - 1; i >= 0 && start < end; i--) {
      final String value = result.nodes[i].value;
      if (value.length <= end - start &&
          text.startsWith(value, end - value.length)) {
        endNodes.insert(0, result.nodes[i]);
        end -= value.length;
      } else {
        break;
      }
    }
    final _HighlightNode? midNode;
    if (startNodes.isEmpty) {
      midNode =
          _HighlightNode(text.substring(start, end), result.nodes[0].className);
    } else if (startNodes.length < result.nodes.length) {
      midNode = _HighlightNode(text.substring(start, end),
          result.nodes[startNodes.length].className);
    } else if (end > start) {
      midNode = _HighlightNode(
          text.substring(start, end), result.nodes.last.className);
    } else {
      midNode = null;
    }
    return _buildSpanFromNodes(
        [...startNodes, if (midNode != null) midNode, ...endNodes], style);
  }

  TextSpan _buildSpanFromNodes(
      List<_HighlightNode> nodes, TextStyle baseStyle) {
    return TextSpan(
        children: nodes
            .map((e) => TextSpan(text: e.value, style: _findStyle(e.className)))
            .toList(),
        style: baseStyle);
  }

  TextStyle? _findStyle(String? className) {
    if (className == null) {
      return null;
    }
    while (true) {
      final TextStyle? style = _theme?.theme[className];
      if (style != null) {
        return style;
      }
      final int pieceIndex = className!.indexOf('-');
      if (pieceIndex < 0) {
        break;
      }
      className = className.substring(pieceIndex + 1);
      if (className.isEmpty) {
        break;
      }
    }
    return null;
  }

  void _onCodesChanged() {
    if (_controller.preValue?.codeLines == _controller.codeLines) {
      return;
    }
    _engine.invalidate();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 100), _processHighlight);
  }

  void _processHighlight() {
    _engine.run(_controller.codeLines, (result) => value = result);
  }
}

class _CodeHighlightEngine {
  late _IsolateTasker<_HighlightPayload, List<_HighlightResult>> _tasker;
  Highlight? _highlight;
  CodeHighlightTheme? _theme;
  CodeLines? _pendingCodes;
  IsolateCallback<List<_HighlightResult>>? _pendingCallback;
  Timer? _watchdog;
  bool _running = false;
  bool _disposed = false;
  bool _disabled = false;
  int _revision = 0;
  int _themeId = 0;

  static int? _cachedThemeId;
  static Highlight? _cachedHighlight;

  _CodeHighlightEngine(CodeHighlightTheme? theme) {
    _createTasker();
    this.theme = theme;
  }

  void _createTasker() {
    _tasker = _IsolateTasker<_HighlightPayload, List<_HighlightResult>>(
        'CodeHighlightEngine', _run);
  }

  set theme(CodeHighlightTheme? value) {
    if (_theme == value) return;
    invalidate();
    _watchdog?.cancel();
    _tasker.close();
    _createTasker();
    _running = false;
    _disabled = false;
    _theme = value;
    _themeId++;
    final modes = value?.languages;
    if (modes == null || modes.isEmpty) {
      _highlight = null;
    } else {
      final highlight = Highlight();
      highlight.registerLanguages(
          modes.map((key, value) => MapEntry(key, value.mode)));
      for (final plugin in value!.plugins) {
        highlight.addPlugin(plugin);
      }
      _highlight = highlight;
    }
  }

  /// Mark results obsolete immediately, including during the input debounce.
  void invalidate() {
    _revision++;
    _pendingCodes = null;
    _pendingCallback = null;
  }

  void dispose() {
    _disposed = true;
    invalidate();
    _watchdog?.cancel();
    _tasker.close();
  }

  void run(CodeLines codes, IsolateCallback<List<_HighlightResult>> callback) {
    if (_disposed) return;
    _revision++;
    if (_highlight == null || _disabled) {
      _pendingCodes = null;
      _pendingCallback = null;
      callback(const []);
      return;
    }
    // At most one running request and one latest request; never queue every key.
    _pendingCodes = codes;
    _pendingCallback = callback;
    _dispatch();
  }

  void _dispatch() {
    if (_disposed || _running || _pendingCodes == null) return;
    final codes = _pendingCodes!;
    final callback = _pendingCallback!;
    final revision = _revision;
    final modes = _theme!.languages;
    _pendingCodes = null;
    _pendingCallback = null;
    _running = true;

    void fail() {
      if (_disposed) return;
      _watchdog?.cancel();
      _tasker.close();
      _createTasker();
      _disabled = true;
      _running = false;
      // Bound pathological regular expressions to an isolate; keep editing usable.
      if (revision == _revision) callback(const []);
      _pendingCallback?.call(const []);
      _pendingCallback = null;
      _pendingCodes = null;
    }

    _watchdog = Timer(const Duration(seconds: 2), fail);
    _tasker.run(
        _HighlightPayload(
          highlight: _highlight!,
          themeId: _themeId,
          codes: codes,
          languages: modes.keys.toList(),
          language: _theme!.language,
          maxSizes: modes.values.map((e) => e.maxSize).toList(),
          maxLineLengths: modes.values.map((e) => e.maxLineLength).toList(),
        ), (result) {
      if (_disposed) return;
      _watchdog?.cancel();
      _running = false;
      if (revision == _revision) callback(result);
      _dispatch();
    }, onError: (_, __) => fail());
  }

  @pragma('vm:entry-point')
  static List<_HighlightResult> _run(_HighlightPayload payload) {
    final maxSize = payload.maxSizes.reduce(min);
    final maxLineLength = payload.maxLineLengths.reduce(min);
    var total = 0;
    var firstLine = true;
    // Walk segments once. Do not build a full string when plain text is enough.
    for (final segment in payload.codes.segments) {
      for (final line in segment.codeLines) {
        total += line.length + (firstLine ? 0 : 1);
        firstLine = false;
        if (line.length > maxLineLength || total > maxSize) return const [];
      }
    }
    if (_cachedThemeId != payload.themeId) {
      _cachedThemeId = payload.themeId;
      _cachedHighlight = payload.highlight;
    }
    final highlight = _cachedHighlight!;
    final code = payload.codes.asString(TextLineBreak.lf, false);
    final language = payload.language;
    final HighlightResult result;
    if (language != null || payload.languages.length == 1) {
      result = highlight.highlight(
          code: code, language: language ?? payload.languages.first);
    } else {
      result = highlight.highlightAuto(code, payload.languages);
    }
    final renderer = _HighlightLineRenderer();
    result.render(renderer);
    return renderer.lineResults;
  }
}

class _HighlightPayload {
  final Highlight highlight;
  final int themeId;
  final CodeLines codes;
  final List<String> languages;
  final String? language;
  final List<int> maxSizes;
  final List<int> maxLineLengths;

  const _HighlightPayload({
    required this.highlight,
    required this.themeId,
    required this.codes,
    required this.languages,
    required this.language,
    required this.maxSizes,
    required this.maxLineLengths,
  });
}

class _HighlightResult {
  final List<_HighlightNode> nodes;

  _HighlightResult(this.nodes);

  late final String source = nodes.map((e) => e.value).join();
}

class _HighlightNode {
  final String? className;
  final String value;

  const _HighlightNode(this.value, [this.className]);
}

class _HighlightLineRenderer implements HighlightRenderer {
  final List<_HighlightResult> lineResults;
  final List<String?> classNames;
  _HighlightLineRenderer()
      : lineResults = [_HighlightResult([])],
        classNames = [];

  @override
  void addText(String text) {
    final String? className = classNames.isEmpty ? null : classNames.last;
    final List<String> lines = text.split(TextLineBreak.lf.value);
    lineResults.last.nodes.add(_HighlightNode(lines.first, className));
    if (lines.length > 1) {
      for (int i = 1; i < lines.length; i++) {
        lineResults
            .add(_HighlightResult([_HighlightNode(lines[i], className)]));
      }
    }
  }

  @override
  void openNode(DataNode node) {
    final String? className = classNames.isEmpty ? null : classNames.last;
    String? newClassName;
    if (className == null || node.scope == null) {
      newClassName = node.scope;
    } else {
      newClassName = '$className-${node.scope!}';
    }
    newClassName = newClassName?.split('.')[0];
    classNames.add(newClassName);
  }

  @override
  void closeNode(DataNode node) {
    if (classNames.isNotEmpty) {
      classNames.removeLast();
    }
  }
}
