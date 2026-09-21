/// QFLIStudio+ C 运行时。
///
/// 在应用进程内解释执行 C 源码：预处理、词法、语法、执行四步全部用 Dart
/// 实现，不依赖设备上的编译器、不生成可执行文件、不 fork 子进程。
///
/// 这样做的直接原因是鸿蒙的应用沙箱：普通应用被 SELinux 禁止 exec 任意
/// ELF，但从来不限制应用解释自己的数据。
library;

export 'src/c_program.dart'
    show
        CRunResult,
        CProgramError,
        CRunSession,
        runCSource,
        startCSource,
        kStdinMissingHint;

// 运行上限的默认值由调用方（各语言 App）决定要不要覆盖，所以对外暴露。
export 'src/c_interpreter.dart'
    show kDefaultMaxSteps, kDefaultTimeLimit, CTimeoutException;

export 'src/c_types.dart';
