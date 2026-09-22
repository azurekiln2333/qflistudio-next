// Conditional export: on platforms with `dart:io` this resolves to the real
// process-backed shell, otherwise to a stub that explains the limitation.
export 'local_shell_stub.dart' if (dart.library.io) 'local_shell_io.dart';
