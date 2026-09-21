/// C 抽象语法树。
library;

import 'c_types.dart';

/// 所有表达式的基类。[type] 在解析阶段由类型环境推导出来。
sealed class CExpr {
  CExpr({required this.line});

  final int line;

  /// 静态类型；解析阶段无法确定时为 null（例如隐式声明的函数调用）。
  CType? type;
}

class CIntLiteral extends CExpr {
  CIntLiteral(this.value, this.literalType, {required super.line});

  final int value;
  final CType literalType;

  @override
  String toString() => '$value';
}

class CFloatLiteral extends CExpr {
  CFloatLiteral(this.value, this.literalType, {required super.line});

  final double value;
  final CType literalType;

  @override
  String toString() => '$value';
}

class CStringLiteral extends CExpr {
  CStringLiteral(this.value, this.arrayType, {required super.line});

  final String value;
  final CType arrayType;

  @override
  String toString() => '"$value"';
}

class CIdentifier extends CExpr {
  CIdentifier(this.name, {required super.line});

  final String name;

  @override
  String toString() => name;
}

/// 一元运算：`+ - ! ~ * & ++ -- sizeof`。
class CUnary extends CExpr {
  CUnary(this.op, this.operand, {this.postfix = false, required super.line});

  final String op;
  final CExpr operand;
  final bool postfix;

  @override
  String toString() => postfix ? '($operand$op)' : '($op$operand)';
}

/// `sizeof(T)` / `sizeof expr`。
class CSizeof extends CExpr {
  CSizeof({this.operandType, this.operand, required super.line});

  final CType? operandType;
  final CExpr? operand;

  @override
  String toString() => 'sizeof(...)';
}

class CBinary extends CExpr {
  CBinary(this.op, this.left, this.right, {required super.line});

  final String op;
  final CExpr left;
  final CExpr right;

  @override
  String toString() => '($left $op $right)';
}

class CAssign extends CExpr {
  CAssign(this.op, this.target, this.value, {required super.line});

  /// `=` `+=` `-=` 等。
  final String op;
  final CExpr target;
  final CExpr value;

  @override
  String toString() => '($target $op $value)';
}

class CConditional extends CExpr {
  CConditional(this.condition, this.thenExpr, this.elseExpr, {required super.line});

  final CExpr condition;
  final CExpr thenExpr;
  final CExpr elseExpr;

  @override
  String toString() => '($condition ? $thenExpr : $elseExpr)';
}

class CCall extends CExpr {
  CCall(this.callee, this.arguments, {required super.line});

  final CExpr callee;
  final List<CExpr> arguments;

  @override
  String toString() => '$callee(...)';
}

class CIndex extends CExpr {
  CIndex(this.array, this.index, {required super.line});

  final CExpr array;
  final CExpr index;

  @override
  String toString() => '$array[$index]';
}

class CMember extends CExpr {
  CMember(this.object, this.name, {required this.arrow, required super.line});

  final CExpr object;
  final String name;

  /// true 表示 `->`。
  final bool arrow;

  @override
  String toString() => arrow ? '$object->$name' : '$object.$name';
}

class CCast extends CExpr {
  CCast(this.targetType, this.operand, {required super.line});

  final CType targetType;
  final CExpr operand;

  @override
  String toString() => '($targetType)$operand';
}

class CComma extends CExpr {
  CComma(this.items, {required super.line});

  final List<CExpr> items;

  @override
  String toString() => items.join(', ');
}

// ---- 初始化器 ----

sealed class CInitializer {
  const CInitializer();
}

class CExprInitializer extends CInitializer {
  const CExprInitializer(this.expr);

  final CExpr expr;
}

class CListInitializer extends CInitializer {
  const CListInitializer(this.items);

  final List<CInitializer> items;
}

// ---- 语句 ----

sealed class CStmt {
  const CStmt({required this.line});

  final int line;
}

class CCompound extends CStmt {
  const CCompound(this.items, {required super.line});

  final List<CStmt> items;
}

class CExprStatement extends CStmt {
  const CExprStatement(this.expr, {required super.line});

  final CExpr expr;
}

class CDeclarationStatement extends CStmt {
  const CDeclarationStatement(this.declaration, {required super.line});

  final CDeclaration declaration;
}

class CIf extends CStmt {
  const CIf(this.condition, this.thenBranch, this.elseBranch, {required super.line});

  final CExpr condition;
  final CStmt thenBranch;
  final CStmt? elseBranch;
}

class CWhile extends CStmt {
  const CWhile(this.condition, this.body, {this.doWhile = false, required super.line});

  final CExpr condition;
  final CStmt body;
  final bool doWhile;
}

class CFor extends CStmt {
  const CFor(this.init, this.condition, this.step, this.body, {required super.line});

  final CStmt? init;
  final CExpr? condition;
  final CExpr? step;
  final CStmt body;
}

class CSwitch extends CStmt {
  const CSwitch(this.condition, this.body, {required super.line});

  final CExpr condition;

  /// 通常是 [CCompound]，里面含 [CCaseLabel] / [CDefaultLabel]。
  final CStmt body;
}

class CCaseLabel extends CStmt {
  const CCaseLabel(this.value, {required super.line});

  /// null 表示 `default:`。
  final int? value;
}

class CBreak extends CStmt {
  const CBreak({required super.line});
}

class CContinue extends CStmt {
  const CContinue({required super.line});
}

class CReturn extends CStmt {
  const CReturn(this.value, {required super.line});

  final CExpr? value;
}

class CGoto extends CStmt {
  const CGoto(this.label, {required super.line});

  final String label;
}

class CLabeled extends CStmt {
  const CLabeled(this.label, this.statement, {required super.line});

  final String label;
  final CStmt statement;
}

class CEmpty extends CStmt {
  const CEmpty({required super.line});
}

// ---- 声明 ----

/// 一个声明符：名字、完整类型、可选初始化器。
class CInitDeclarator {
  const CInitDeclarator({
    required this.name,
    required this.type,
    this.initializer,
    this.line = 0,
  });

  final String name;
  final CType type;
  final CInitializer? initializer;
  final int line;
}

/// 一组声明（`int a, b = 2;` 或 `typedef ...;`）。
class CDeclaration {
  const CDeclaration({
    required this.baseType,
    required this.declarators,
    this.isTypedef = false,
    this.isStatic = false,
    this.isExtern = false,
    this.line = 0,
  });

  final CType baseType;
  final List<CInitDeclarator> declarators;
  final bool isTypedef;
  final bool isStatic;
  final bool isExtern;
  final int line;
}

// ---- 顶层 ----

sealed class CTopLevelItem {
  const CTopLevelItem();
}

class CTopLevelDeclaration extends CTopLevelItem {
  const CTopLevelDeclaration(this.declaration);

  final CDeclaration declaration;
}

class CFunctionDefinition extends CTopLevelItem {
  const CFunctionDefinition({
    required this.name,
    required this.type,
    required this.parameterNames,
    required this.body,
    required this.line,
    this.isStatic = false,
  });

  final String name;
  final CFunctionType type;
  final List<String> parameterNames;
  final CCompound body;
  final int line;
  final bool isStatic;
}

/// 一个翻译单元（一个 .c 文件预处理后的全部内容）。
class CTranslationUnit {
  const CTranslationUnit(this.items);

  final List<CTopLevelItem> items;
}
