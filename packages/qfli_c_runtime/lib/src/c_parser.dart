/// C 语法分析：记号流 → 抽象语法树。
///
/// 解析阶段只做「语法 + 类型名」两件事，表达式类型留到解释执行时按运行时
/// 信息推导。这样 `sizeof arr` 这类依赖具体对象类型的写法才准确。
library;

import 'c_ast.dart';
import 'c_lexer.dart';
import 'c_preprocessor.dart';
import 'c_types.dart';

/// 语法错误。
class CParseException implements Exception {
  CParseException(this.message, this.line, this.column);

  final String message;
  final int line;
  final int column;

  @override
  String toString() => '语法错误：$message';
}

/// 解析一个翻译单元。
CTranslationUnit parseTranslationUnit(
  List<CToken> tokens, {
  CPreprocessedSource? source,
}) {
  return _Parser(tokens, source).parse();
}

class _Parser {
  _Parser(this.tokens, this.source);

  final List<CToken> tokens;
  final CPreprocessedSource? source;
  int _pos = 0;

  /// 类型名（typedef）集合。C 里 typedef 名和普通标识符共用一个命名空间，
  /// 这里按「只要在某处被 typedef 过就当类型名」处理，够用且简单。
  final Map<String, CType> _typedefs = {};

  /// struct / union / enum 标签。
  final Map<String, CRecordType> _records = {};
  final Map<String, CEnumType> _enums = {};

  /// 枚举常量。
  final Map<String, int> _enumConstants = {};

  /// 当前作用域里的名字 → 类型，用于判断标识符是否为已知对象（供错误提示）。
  final List<Map<String, CType>> _scopes = [<String, CType>{}];

  static const Set<String> _storageKeywords = {
    'typedef',
    'static',
    'extern',
    'auto',
    'register',
    'inline',
    '_Noreturn',
  };

  static const Set<String> _qualifiers = {
    'const',
    'volatile',
    'restrict',
    '_Atomic',
  };

  static const Set<String> _typeKeywords = {
    'void',
    'char',
    'short',
    'int',
    'long',
    'float',
    'double',
    'signed',
    'unsigned',
    '_Bool',
    'struct',
    'union',
    'enum',
  };

  // ---- 记号工具 ----

  CToken get _current => tokens[_pos];

  CToken _peekAt(int offset) {
    final i = _pos + offset;
    return i < tokens.length ? tokens[i] : tokens.last;
  }

  bool _checkPunct(String text) =>
      _current.kind == CTokenKind.punctuator && _current.text == text;

  bool _checkIdent(String text) =>
      _current.kind == CTokenKind.identifier && _current.text == text;

  bool _matchPunct(String text) {
    if (_checkPunct(text)) {
      _pos++;
      return true;
    }
    return false;
  }

  bool _matchIdent(String text) {
    if (_checkIdent(text)) {
      _pos++;
      return true;
    }
    return false;
  }

  CToken _advance() => tokens[_pos++];

  CToken _expectPunct(String text) {
    if (!_checkPunct(text)) {
      _fail('期望 "$text"，实际是 "${_current.text}"');
    }
    return _advance();
  }

  Never _fail(String message) {
    final token = _current;
    final origin = source?.originOf(token.line);
    final where = origin == null
        ? '第 ${token.line + 1} 行'
        : '$origin';
    throw CParseException('$message（$where）', token.line, token.column);
  }

  bool _isDeclarationStart() {
    final token = _current;
    if (token.kind != CTokenKind.identifier) return false;
    if (_typeKeywords.contains(token.text)) return true;
    if (_typedefs.containsKey(token.text)) return true;
    // 存储类/限定符只有在后面跟着类型时才当作声明。
    if (_storageKeywords.contains(token.text) ||
        _qualifiers.contains(token.text)) {
      final next = _peekAt(1);
      if (next.kind != CTokenKind.identifier) return false;
      return _typeKeywords.contains(next.text) ||
          _qualifiers.contains(next.text) ||
          _storageKeywords.contains(next.text) ||
          _typedefs.containsKey(next.text);
    }
    return false;
  }

  // ---- 作用域 ----

  void _pushScope() => _scopes.add(<String, CType>{});

  void _popScope() => _scopes.removeLast();

  void _declare(String name, CType type) => _scopes.last[name] = type;

  CType? _lookup(String name) {
    for (var i = _scopes.length - 1; i >= 0; i--) {
      final found = _scopes[i][name];
      if (found != null) return found;
    }
    return null;
  }

  // ---- 顶层 ----

  CTranslationUnit parse() {
    final items = <CTopLevelItem>[];
    while (!_current.isEof) {
      if (_matchPunct(';')) continue;
      items.add(_parseTopLevelItem());
    }
    return CTranslationUnit(items);
  }

  CTopLevelItem _parseTopLevelItem() {
    final line = _current.line;
    final spec = _parseDeclarationSpecifiers();

    if (_matchPunct(';')) {
      // 只有类型没有声明符：struct/enum 定义或空声明。
      return CTopLevelDeclaration(
        CDeclaration(
          baseType: spec.type,
          declarators: const [],
          isTypedef: spec.isTypedef,
          isStatic: spec.isStatic,
          isExtern: spec.isExtern,
          line: line,
        ),
      );
    }

    // 函数定义与变量声明的分叉点：第一个声明符。
    final declarators = <CInitDeclarator>[];
    var isFirst = true;

    while (true) {
      final decl = _parseDeclarator(spec.type);
      if (decl.name == null) {
        _fail('声明缺少名字');
      }

      // 函数定义：`类型 名字(参数) { ... }`
      if (isFirst && decl.type is CFunctionType && _checkPunct('{')) {
        final functionType = decl.type as CFunctionType;
        final names = decl.parameterNames;
        _pushScope();
        for (var i = 0; i < names.length; i++) {
          final paramName = names[i];
          if (paramName.isEmpty) continue;
          final paramType = i < functionType.parameters.length
              ? functionType.parameters[i]
              : CTypes.intType;
          _declare(paramName, paramType);
        }
        final body = _parseCompound(alreadyPushed: true);
        _popScope();
        return CFunctionDefinition(
          name: decl.name!,
          type: functionType,
          parameterNames: names,
          body: body,
          line: line,
          isStatic: spec.isStatic,
        );
      }

      final initializer = _matchPunct('=')
          ? _parseInitializer(decl.type)
          : null;
      declarators.add(
        CInitDeclarator(
          name: decl.name!,
          type: decl.type,
          initializer: initializer,
          line: line,
        ),
      );

      isFirst = false;
      if (_matchPunct(',')) continue;
      _expectPunct(';');
      break;
    }

    if (spec.isTypedef) {
      for (final d in declarators) {
        _typedefs[d.name] = d.type;
      }
    } else {
      for (final d in declarators) {
        _declare(d.name, d.type);
      }
    }

    return CTopLevelDeclaration(
      CDeclaration(
        baseType: spec.type,
        declarators: declarators,
        isTypedef: spec.isTypedef,
        isStatic: spec.isStatic,
        isExtern: spec.isExtern,
        line: line,
      ),
    );
  }

  // ---- 声明说明符 ----

  ({CType type, bool isTypedef, bool isStatic, bool isExtern})
  _parseDeclarationSpecifiers() {
    var isTypedef = false;
    var isStatic = false;
    var isExtern = false;

    var sawVoid = false;
    var sawChar = false;
    var sawShort = false;
    var longCount = 0;
    var sawFloat = false;
    var sawDouble = false;
    var sawSigned = false;
    var sawUnsigned = false;
    var sawBool = false;
    CType? explicitType;
    var sawAny = false;

    while (true) {
      final token = _current;
      if (token.kind != CTokenKind.identifier) break;
      final text = token.text;

      if (text == 'typedef') {
        isTypedef = true;
        sawAny = true;
        _advance();
        continue;
      }
      if (text == 'static') {
        isStatic = true;
        sawAny = true;
        _advance();
        continue;
      }
      if (text == 'extern') {
        isExtern = true;
        sawAny = true;
        _advance();
        continue;
      }
      if (_storageKeywords.contains(text)) {
        sawAny = true;
        _advance();
        continue;
      }
      if (_qualifiers.contains(text)) {
        sawAny = true;
        _advance();
        continue;
      }
      switch (text) {
        case 'void':
          sawVoid = true;
          sawAny = true;
          _advance();
          continue;
        case 'char':
          sawChar = true;
          sawAny = true;
          _advance();
          continue;
        case 'short':
          sawShort = true;
          sawAny = true;
          _advance();
          continue;
        case 'long':
          longCount++;
          sawAny = true;
          _advance();
          continue;
        case 'int':
          // `int` 本身不改变判定结果（省略 int 时默认就是 int）。
          sawAny = true;
          _advance();
          continue;
        case 'float':
          sawFloat = true;
          sawAny = true;
          _advance();
          continue;
        case 'double':
          sawDouble = true;
          sawAny = true;
          _advance();
          continue;
        case 'signed':
          sawSigned = true;
          sawAny = true;
          _advance();
          continue;
        case 'unsigned':
          sawUnsigned = true;
          sawAny = true;
          _advance();
          continue;
        case '_Bool':
          sawBool = true;
          sawAny = true;
          _advance();
          continue;
        case 'struct':
          explicitType = _parseStructOrUnion(false);
          sawAny = true;
          continue;
        case 'union':
          explicitType = _parseStructOrUnion(true);
          sawAny = true;
          continue;
        case 'enum':
          explicitType = _parseEnum();
          sawAny = true;
          continue;
        default:
          break;
      }

      final typedefType = _typedefs[text];
      if (typedefType != null) {
        explicitType = typedefType;
        sawAny = true;
        _advance();
        continue;
      }
      break;
    }

    if (!sawAny) {
      // C89 隐式 int：`main() { }` 这类老式写法。
      return (
        type: CTypes.intType,
        isTypedef: false,
        isStatic: false,
        isExtern: false,
      );
    }

    if (explicitType != null) {
      return (
        type: explicitType,
        isTypedef: isTypedef,
        isStatic: isStatic,
        isExtern: isExtern,
      );
    }

    CType type;
    if (sawVoid) {
      type = CTypes.voidType;
    } else if (sawBool) {
      type = CTypes.boolType;
    } else if (sawFloat) {
      type = CTypes.floatType;
    } else if (sawDouble) {
      type = CTypes.doubleType;
    } else if (sawChar) {
      type = sawUnsigned
          ? CTypes.unsignedChar
          : (sawSigned ? CTypes.signedChar : CTypes.charType);
    } else if (longCount >= 2) {
      type = sawUnsigned ? CTypes.unsignedLongLong : CTypes.longLong;
    } else if (longCount == 1) {
      type = sawUnsigned ? CTypes.unsignedLong : CTypes.longType;
    } else if (sawShort) {
      type = sawUnsigned ? CTypes.unsignedShort : CTypes.shortType;
    } else {
      type = sawUnsigned ? CTypes.unsignedInt : CTypes.intType;
    }
    return (
      type: type,
      isTypedef: isTypedef,
      isStatic: isStatic,
      isExtern: isExtern,
    );
  }

  CRecordType _parseStructOrUnion(bool isUnion) {
    _advance(); // struct / union
    var tag = '';
    if (_current.kind == CTokenKind.identifier && !_checkPunct('{')) {
      tag = _advance().text;
    }

    final key = '${isUnion ? 'union' : 'struct'} $tag';
    var record = _records[key];

    if (_checkPunct('{')) {
      if (record == null) {
        record = CRecordType(tag: tag, isUnion: isUnion);
        _records[key] = record;
      }
      _advance(); // {
      while (!_checkPunct('}') && !_current.isEof) {
        if (_matchPunct(';')) continue;
        final spec = _parseDeclarationSpecifiers();
        if (_matchPunct(';')) {
          // 匿名 struct/union 成员：按展开处理。
          if (spec.type is CRecordType) {
            final nested = spec.type as CRecordType;
            for (final f in nested.fields) {
              record.fields.add(CField(f.name, f.type, f.offset));
            }
            record.layout();
          }
          continue;
        }
        while (true) {
          final decl = _parseDeclarator(spec.type);
          if (decl.name != null) {
            record.fields.add(CField(decl.name!, decl.type, 0));
          }
          if (_matchPunct(',')) continue;
          _expectPunct(';');
          break;
        }
      }
      _expectPunct('}');
      record.layout();
      return record;
    }

    if (record == null) {
      // 只出现 `struct X *p;` 这类不完整引用，先占位。
      record = CRecordType(tag: tag, isUnion: isUnion);
      _records[key] = record;
    }
    return record;
  }

  CEnumType _parseEnum() {
    _advance(); // enum
    var tag = '';
    if (_current.kind == CTokenKind.identifier && !_checkPunct('{')) {
      tag = _advance().text;
    }

    final key = 'enum $tag';
    var type = _enums[key];
    if (_checkPunct('{')) {
      type ??= CEnumType(tag);
      _enums[key] = type;
      _advance();
      var next = 0;
      while (!_checkPunct('}') && !_current.isEof) {
        final name = _advance().text;
        if (_matchPunct('=')) {
          final value = _parseConditional();
          next = _evalConstExpr(value);
        }
        type.constants[name] = next;
        _enumConstants[name] = next;
        next++;
        if (!_matchPunct(',')) break;
      }
      _expectPunct('}');
      return type;
    }
    type ??= CEnumType(tag);
    _enums[key] = type;
    return type;
  }

  // ---- 声明符 ----

  _DeclaratorResult _parseDeclarator(CType base) {
    final parsed = _parseDeclaratorOps();
    final type = _buildType(base, parsed.ops);
    return _DeclaratorResult(
      name: parsed.name,
      type: type,
      parameterNames: parsed.parameterNames,
    );
  }

  _DeclOps _parseDeclaratorOps() {
    // 前缀指针
    var pointerCount = 0;
    while (_checkPunct('*')) {
      _advance();
      pointerCount++;
      while (_current.kind == CTokenKind.identifier &&
          _qualifiers.contains(_current.text)) {
        _advance();
      }
    }

    String? name;
    var innerOps = <_DeclOp>[];
    var parameterNames = <String>[];

    if (_checkPunct('(') &&
        (_peekAt(1).text == '*' || _peekAt(1).text == '(')) {
      _advance(); // (
      final inner = _parseDeclaratorOps();
      _expectPunct(')');
      name = inner.name;
      innerOps = inner.ops;
      parameterNames = inner.parameterNames;
    } else if (_current.kind == CTokenKind.identifier) {
      name = _advance().text;
    }

    final suffixOps = <_DeclOp>[];
    while (true) {
      if (_checkPunct('[')) {
        _advance();
        CExpr? size;
        if (!_checkPunct(']')) {
          size = _parseAssignment();
        }
        _expectPunct(']');
        suffixOps.add(_ArrayOp(size));
        continue;
      }
      if (_checkPunct('(')) {
        final params = _parseParameterList();
        suffixOps.add(_FunctionOp(params));
        if (parameterNames.isEmpty) {
          parameterNames = params.names;
        }
        continue;
      }
      break;
    }

    // 从「紧贴标识符」到「最外层」排列：内层 → 本层后缀 → 本层指针。
    final ops = <_DeclOp>[
      ...innerOps,
      ...suffixOps,
      for (var i = 0; i < pointerCount; i++) _PointerOp(),
    ];
    return _DeclOps(name, ops, parameterNames);
  }

  CType _buildType(CType base, List<_DeclOp> ops) {
    var type = base;
    for (final op in ops.reversed) {
      switch (op) {
        case _PointerOp():
          type = CPointerType(type);
        case _ArrayOp(:final size):
          final length = size == null ? -1 : _evalConstExpr(size);
          type = CArrayType(type, length);
        case _FunctionOp(:final params):
          type = CFunctionType(
            returnType: type,
            parameters: params.parameters.map((p) => p.type).toList(),
            variadic: params.variadic,
            prototype: params.prototype,
          );
      }
    }
    return type;
  }

  _ParamList _parseParameterList() {
    _expectPunct('(');
    final types = <({String name, CType type})>[];
    var variadic = false;
    var prototype = false;

    if (_checkPunct(')')) {
      _advance();
      return _ParamList(const [], false, false);
    }

    // `f()` 老式写法：没有参数列表。
    if (_checkIdent('void') && _peekAt(1).text == ')') {
      _advance();
      _advance();
      return _ParamList(const [], false, true);
    }

    prototype = true;
    while (true) {
      if (_checkPunct('...')) {
        _advance();
        variadic = true;
        break;
      }
      final spec = _parseDeclarationSpecifiers();
      final decl = _parseDeclarator(spec.type);
      types.add((name: decl.name ?? '', type: decl.type.decayed == decl.type ? decl.type : decl.type));
      if (!_matchPunct(',')) break;
    }
    _expectPunct(')');
    return _ParamList(types, variadic, prototype);
  }

  // ---- 初始化器 ----

  CInitializer _parseInitializer(CType type) {
    if (_checkPunct('{')) {
      _advance();
      final items = <CInitializer>[];
      var index = 0;
      while (!_checkPunct('}') && !_current.isEof) {
        if (_matchPunct('.')) {
          // 指定初始化器：.field = value
          _advance();
          _expectPunct('=');
          items.add(_parseInitializer(_elementTypeAt(type, index)));
          index++;
        } else if (_matchPunct('[')) {
          _advance();
          _expectPunct(']');
          _expectPunct('=');
          items.add(_parseInitializer(_elementTypeAt(type, index)));
          index++;
        } else {
          items.add(_parseInitializer(_elementTypeAt(type, index)));
          index++;
        }
        if (!_matchPunct(',')) break;
      }
      _expectPunct('}');
      return CListInitializer(items);
    }
    return CExprInitializer(_parseAssignment());
  }

  static CType _elementTypeAt(CType type, int index) {
    if (type is CArrayType) return type.element;
    if (type is CRecordType && index < type.fields.length) {
      return type.fields[index].type;
    }
    return type;
  }

  // ---- 语句 ----

  CCompound _parseCompound({bool alreadyPushed = false}) {
    final line = _current.line;
    _expectPunct('{');
    if (!alreadyPushed) _pushScope();
    final items = <CStmt>[];
    while (!_checkPunct('}') && !_current.isEof) {
      items.add(_parseStatement());
    }
    _expectPunct('}');
    if (!alreadyPushed) _popScope();
    return CCompound(items, line: line);
  }

  CStmt _parseStatement() {
    final line = _current.line;

    if (_checkPunct('{')) return _parseCompound();
    if (_matchPunct(';')) return CEmpty(line: line);

    if (_checkIdent('if')) {
      _advance();
      _expectPunct('(');
      final condition = _parseExpression();
      _expectPunct(')');
      final thenBranch = _parseStatement();
      final elseBranch = _matchIdent('else') ? _parseStatement() : null;
      return CIf(condition, thenBranch, elseBranch, line: line);
    }

    if (_checkIdent('while')) {
      _advance();
      _expectPunct('(');
      final condition = _parseExpression();
      _expectPunct(')');
      final body = _parseStatement();
      return CWhile(condition, body, line: line);
    }

    if (_checkIdent('do')) {
      _advance();
      final body = _parseStatement();
      if (!_matchIdent('while')) _fail('do 语句缺少 while');
      _expectPunct('(');
      final condition = _parseExpression();
      _expectPunct(')');
      _expectPunct(';');
      return CWhile(condition, body, doWhile: true, line: line);
    }

    if (_checkIdent('for')) {
      _advance();
      _expectPunct('(');
      _pushScope();
      CStmt? init;
      if (_matchPunct(';')) {
        init = null;
      } else if (_isDeclarationStart()) {
        init = CDeclarationStatement(_parseLocalDeclaration(), line: line);
      } else {
        init = CExprStatement(_parseExpression(), line: line);
        _expectPunct(';');
      }
      CExpr? condition;
      if (!_checkPunct(';')) condition = _parseExpression();
      _expectPunct(';');
      CExpr? step;
      if (!_checkPunct(')')) step = _parseExpression();
      _expectPunct(')');
      final body = _parseStatement();
      _popScope();
      return CFor(init, condition, step, body, line: line);
    }

    if (_checkIdent('switch')) {
      _advance();
      _expectPunct('(');
      final condition = _parseExpression();
      _expectPunct(')');
      final body = _parseStatement();
      return CSwitch(condition, body, line: line);
    }

    if (_checkIdent('case')) {
      _advance();
      final value = _parseConditional();
      _expectPunct(':');
      return CCaseLabel(_evalConstExpr(value), line: line);
    }

    if (_checkIdent('default') && _peekAt(1).text == ':') {
      _advance();
      _advance();
      return CCaseLabel(null, line: line);
    }

    if (_checkIdent('break')) {
      _advance();
      _expectPunct(';');
      return CBreak(line: line);
    }

    if (_checkIdent('continue')) {
      _advance();
      _expectPunct(';');
      return CContinue(line: line);
    }

    if (_checkIdent('return')) {
      _advance();
      if (_matchPunct(';')) return CReturn(null, line: line);
      final value = _parseExpression();
      _expectPunct(';');
      return CReturn(value, line: line);
    }

    if (_checkIdent('goto')) {
      _advance();
      final label = _advance().text;
      _expectPunct(';');
      return CGoto(label, line: line);
    }

    // 标签：`name:`
    if (_current.kind == CTokenKind.identifier &&
        _peekAt(1).kind == CTokenKind.punctuator &&
        _peekAt(1).text == ':' &&
        !_isDeclarationStart()) {
      final label = _advance().text;
      _advance(); // :
      final statement = _parseStatement();
      return CLabeled(label, statement, line: line);
    }

    if (_isDeclarationStart()) {
      return CDeclarationStatement(_parseLocalDeclaration(), line: line);
    }

    final expr = _parseExpression();
    _expectPunct(';');
    return CExprStatement(expr, line: line);
  }

  CDeclaration _parseLocalDeclaration() {
    final line = _current.line;
    final spec = _parseDeclarationSpecifiers();
    final declarators = <CInitDeclarator>[];

    if (_matchPunct(';')) {
      return CDeclaration(baseType: spec.type, declarators: declarators, line: line);
    }

    while (true) {
      final decl = _parseDeclarator(spec.type);
      if (decl.name == null) _fail('声明缺少名字');
      final initializer = _matchPunct('=') ? _parseInitializer(decl.type) : null;
      declarators.add(
        CInitDeclarator(
          name: decl.name!,
          type: decl.type,
          initializer: initializer,
          line: line,
        ),
      );
      if (_matchPunct(',')) continue;
      _expectPunct(';');
      break;
    }

    if (spec.isTypedef) {
      for (final d in declarators) {
        _typedefs[d.name] = d.type;
      }
    } else {
      for (final d in declarators) {
        _declare(d.name, d.type);
      }
    }

    return CDeclaration(
      baseType: spec.type,
      declarators: declarators,
      isTypedef: spec.isTypedef,
      isStatic: spec.isStatic,
      isExtern: spec.isExtern,
      line: line,
    );
  }

  // ---- 表达式 ----

  CExpr _parseExpression() {
    final line = _current.line;
    final first = _parseAssignment();
    if (!_checkPunct(',')) return first;
    final items = <CExpr>[first];
    while (_matchPunct(',')) {
      items.add(_parseAssignment());
    }
    return CComma(items, line: line);
  }

  CExpr _parseAssignment() {
    final line = _current.line;
    final left = _parseConditional();

    const assignmentOps = {
      '=',
      '+=' ,
      '-=',
      '*=',
      '/=',
      '%=',
      '&=',
      '|=',
      '^=',
      '<<=',
      '>>=',
    };

    if (_current.kind == CTokenKind.punctuator &&
        assignmentOps.contains(_current.text)) {
      final op = _advance().text;
      final value = _parseAssignment();
      return CAssign(op, left, value, line: line);
    }
    return left;
  }

  CExpr _parseConditional() {
    final line = _current.line;
    final condition = _parseBinary(0);
    if (!_matchPunct('?')) return condition;
    final thenExpr = _parseExpression();
    _expectPunct(':');
    final elseExpr = _parseConditional();
    return CConditional(condition, thenExpr, elseExpr, line: line);
  }

  /// 二元运算符优先级（数值越大结合越紧）。
  static const List<List<String>> _binaryLevels = [
    ['||'],
    ['&&'],
    ['|'],
    ['^'],
    ['&'],
    ['==', '!='],
    ['<', '>', '<=', '>='],
    ['<<', '>>'],
    ['+', '-'],
    ['*', '/', '%'],
  ];

  CExpr _parseBinary(int level) {
    if (level >= _binaryLevels.length) return _parseUnary();
    var left = _parseBinary(level + 1);
    while (true) {
      final op = _current.text;
      if (_current.kind != CTokenKind.punctuator ||
          !_binaryLevels[level].contains(op)) {
        return left;
      }
      // `a & b` 与取地址无关，这里已经是二元位置，直接消费。
      final line = _current.line;
      _advance();
      final right = _parseBinary(level + 1);
      left = CBinary(op, left, right, line: line);
    }
  }

  CExpr _parseUnary() {
    final line = _current.line;
    final token = _current;

    if (token.kind == CTokenKind.punctuator) {
      switch (token.text) {
        case '++':
        case '--':
          _advance();
          return CUnary(token.text, _parseUnary(), line: line);
        case '&':
        case '*':
        case '+':
        case '-':
        case '~':
        case '!':
          _advance();
          return CUnary(token.text, _parseUnary(), line: line);
        case '(':
          // 可能是强制转换或括号表达式。
          if (_looksLikeTypeName(_pos + 1)) {
            _advance();
            final type = _parseTypeName();
            _expectPunct(')');
            final operand = _parseUnary();
            return CCast(type, operand, line: line);
          }
          break;
        default:
          break;
      }
    }

    if (_checkIdent('sizeof')) {
      _advance();
      if (_checkPunct('(') && _looksLikeTypeName(_pos + 1)) {
        _advance();
        final type = _parseTypeName();
        _expectPunct(')');
        return CSizeof(operandType: type, line: line);
      }
      final operand = _parseUnary();
      return CSizeof(operand: operand, line: line);
    }

    if (_checkIdent('_Alignof') || _checkIdent('alignof')) {
      _advance();
      _expectPunct('(');
      final type = _parseTypeName();
      _expectPunct(')');
      return CSizeof(operandType: type, line: line);
    }

    return _parsePostfix();
  }

  bool _looksLikeTypeName(int index) {
    if (index >= tokens.length) return false;
    final token = tokens[index];
    if (token.kind != CTokenKind.identifier) return false;
    return _typeKeywords.contains(token.text) ||
        _qualifiers.contains(token.text) ||
        _typedefs.containsKey(token.text);
  }

  CType _parseTypeName() {
    final spec = _parseDeclarationSpecifiers();
    if (_checkPunct(')') || _checkPunct(',') || _checkPunct(']')) {
      return spec.type;
    }
    final parsed = _parseDeclaratorOps();
    return _buildType(spec.type, parsed.ops);
  }

  CExpr _parsePostfix() {
    var expr = _parsePrimary();
    while (true) {
      final line = _current.line;
      if (_matchPunct('[')) {
        final index = _parseExpression();
        _expectPunct(']');
        expr = CIndex(expr, index, line: line);
        continue;
      }
      if (_checkPunct('(')) {
        _advance();
        final args = <CExpr>[];
        if (!_checkPunct(')')) {
          while (true) {
            args.add(_parseAssignment());
            if (!_matchPunct(',')) break;
          }
        }
        _expectPunct(')');
        expr = CCall(expr, args, line: line);
        continue;
      }
      if (_matchPunct('.')) {
        final name = _advance().text;
        expr = CMember(expr, name, arrow: false, line: line);
        continue;
      }
      if (_matchPunct('->')) {
        final name = _advance().text;
        expr = CMember(expr, name, arrow: true, line: line);
        continue;
      }
      if (_checkPunct('++') || _checkPunct('--')) {
        final op = _advance().text;
        expr = CUnary(op, expr, postfix: true, line: line);
        continue;
      }
      return expr;
    }
  }

  CExpr _parsePrimary() {
    final line = _current.line;
    final token = _current;

    switch (token.kind) {
      case CTokenKind.intLiteral:
        _advance();
        return CIntLiteral(
          token.intValue ?? 0,
          _integerLiteralType(token.text, token.intValue ?? 0),
          line: line,
        );
      case CTokenKind.charLiteral:
        _advance();
        return CIntLiteral(token.intValue ?? 0, CTypes.intType, line: line);
      case CTokenKind.floatLiteral:
        _advance();
        return CFloatLiteral(
          token.doubleValue ?? 0,
          CTypes.doubleType,
          line: line,
        );
      case CTokenKind.stringLiteral:
        _advance();
        final buffer = StringBuffer(token.stringValue ?? '');
        // 相邻字符串字面量自动拼接。
        while (_current.kind == CTokenKind.stringLiteral) {
          buffer.write(_advance().stringValue ?? '');
        }
        final value = buffer.toString();
        final bytes = _utf8Length(value) + 1;
        return CStringLiteral(
          value,
          CArrayType(CTypes.charType, bytes),
          line: line,
        );
      case CTokenKind.identifier:
        _advance();
        final name = token.text;
        final enumValue = _enumConstants[name];
        if (enumValue != null) {
          return CIntLiteral(cTruncate(enumValue, CTypes.intType), CTypes.intType, line: line);
        }
        if (name == 'NULL' || name == 'true' || name == 'false') {
          // 宏已被预处理展开，这里只是兜底。
          final v = name == 'true' ? 1 : 0;
          return CIntLiteral(v, CTypes.intType, line: line);
        }
        return CIdentifier(name, line: line);
      case CTokenKind.punctuator:
        if (token.text == '(') {
          _advance();
          final expr = _parseExpression();
          _expectPunct(')');
          return expr;
        }
        break;
      default:
        break;
    }

    _fail('无法解析的表达式片段 "${token.text}"');
  }

  // ---- 常量求值（数组长度、case 标签、枚举值） ----

  int _evalConstExpr(CExpr expr) {
    switch (expr) {
      case CIntLiteral(:final value):
        return value;
      case CFloatLiteral(:final value):
        return value.toInt();
      case CIdentifier(:final name):
        final constant = _enumConstants[name];
        if (constant != null) return constant;
        _fail('数组长度/case 标签必须是常量，但出现了标识符 "$name"');
      case CUnary(:final op, :final operand):
        final v = _evalConstExpr(operand);
        return switch (op) {
          '-' => -v,
          '+' => v,
          '~' => ~v,
          '!' => v == 0 ? 1 : 0,
          _ => _fail('常量表达式里不支持运算符 "$op"'),
        };
      case CBinary(:final op, :final left, :final right):
        final a = _evalConstExpr(left);
        final b = _evalConstExpr(right);
        return switch (op) {
          '+' => a + b,
          '-' => a - b,
          '*' => a * b,
          '/' => b == 0 ? _fail('常量表达式除零') : a ~/ b,
          '%' => b == 0 ? _fail('常量表达式取模零') : a % b,
          '<<' => a << b,
          '>>' => a >> b,
          '&' => a & b,
          '|' => a | b,
          '^' => a ^ b,
          '==' => a == b ? 1 : 0,
          '!=' => a != b ? 1 : 0,
          '<' => a < b ? 1 : 0,
          '>' => a > b ? 1 : 0,
          '<=' => a <= b ? 1 : 0,
          '>=' => a >= b ? 1 : 0,
          '&&' => (a != 0 && b != 0) ? 1 : 0,
          '||' => (a != 0 || b != 0) ? 1 : 0,
          _ => _fail('常量表达式里不支持运算符 "$op"'),
        };
      case CConditional(:final condition, :final thenExpr, :final elseExpr):
        return _evalConstExpr(condition) != 0
            ? _evalConstExpr(thenExpr)
            : _evalConstExpr(elseExpr);
      case CCast(:final targetType, :final operand):
        final v = _evalConstExpr(operand);
        return targetType is CIntegerType ? cTruncate(v, targetType) : v;
      case CSizeof(:final operandType, :final operand):
        if (operandType != null) return operandType.size;
        if (operand != null) return _sizeOfExpr(operand);
        return 0;
      case CComma(:final items):
        return _evalConstExpr(items.last);
      default:
        _fail('这里需要常量表达式');
    }
  }

  /// 整数字面量的类型：按后缀与量级决定，`4294967295U` 不该被截成 int。
  static CType _integerLiteralType(String raw, int value) {
    final suffix = RegExp(r'[uUlL]+$').stringMatch(raw) ?? '';
    final isUnsigned = suffix.contains('U') || suffix.contains('u');
    final isLong = suffix.contains('L') || suffix.contains('l');
    if (isLong) {
      return isUnsigned ? CTypes.unsignedLong : CTypes.longType;
    }
    if (isUnsigned) return CTypes.unsignedInt;
    if (value > 2147483647 || value < -2147483648) return CTypes.longType;
    return CTypes.intType;
  }

  /// 常量上下文里能算出的 `sizeof expr`：只覆盖「有静态类型的简单式子」。
  int _sizeOfExpr(CExpr expr) {
    switch (expr) {
      case CStringLiteral(:final arrayType):
        return arrayType.size;
      case CIntLiteral(:final literalType):
        return literalType.size;
      case CFloatLiteral(:final literalType):
        return literalType.size;
      case CIndex(:final array):
        final element = _staticType(array);
        return element is CArrayType ? element.element.size : 0;
      case CMember(:final object, :final name):
        final record = _staticType(object);
        if (record is CRecordType) {
          final field = record.field(name);
          if (field != null) return field.type.size;
        }
        return 0;
      case CIdentifier(:final name):
        final type = _lookup(name);
        return type?.size ?? 0;
      default:
        return 0;
    }
  }

  CType? _staticType(CExpr expr) {
    switch (expr) {
      case CIdentifier(:final name):
        return _lookup(name);
      case CUnary(op: '*', :final operand):
        final t = _staticType(operand);
        return t is CPointerType ? t.to : null;
      case CIndex(:final array):
        final t = _staticType(array);
        if (t is CArrayType) return t.element;
        if (t is CPointerType) return t.to;
        return null;
      case CMember(:final object, :final name):
        var t = _staticType(object);
        if (t is CPointerType) t = t.to;
        if (t is CRecordType) return t.field(name)?.type;
        return null;
      case CCast(:final targetType):
        return targetType;
      default:
        return null;
    }
  }

  static int _utf8Length(String value) {
    var count = 0;
    for (final unit in value.codeUnits) {
      if (unit < 0x80) {
        count += 1;
      } else if (unit < 0x800) {
        count += 2;
      } else if (unit >= 0xD800 && unit <= 0xDBFF) {
        count += 4;
      } else if (unit >= 0xDC00 && unit <= 0xDFFF) {
        // 低位代理项已在上一个高位项里计过。
      } else {
        count += 3;
      }
    }
    return count;
  }
}

// ---- 内部数据结构 ----

class _DeclaratorResult {
  const _DeclaratorResult({
    required this.name,
    required this.type,
    required this.parameterNames,
  });

  final String? name;
  final CType type;
  final List<String> parameterNames;
}

class _DeclOps {
  const _DeclOps(this.name, this.ops, this.parameterNames);

  final String? name;
  final List<_DeclOp> ops;
  final List<String> parameterNames;
}

sealed class _DeclOp {
  const _DeclOp();
}

class _PointerOp extends _DeclOp {
  const _PointerOp();
}

class _ArrayOp extends _DeclOp {
  const _ArrayOp(this.size);

  final CExpr? size;
}

class _FunctionOp extends _DeclOp {
  const _FunctionOp(this.params);

  final _ParamList params;
}

class _ParamList {
  const _ParamList(this.parameters, this.variadic, this.prototype);

  final List<({String name, CType type})> parameters;
  final bool variadic;
  final bool prototype;

  List<String> get names =>
      parameters.map((p) => p.name).toList(growable: false);
}
