part of re_editor;

typedef IsolateRunnable<Req, Res> = Res Function(Req req);
typedef IsolateCallback<Res> = void Function(Res res);

/// One persistent worker per analyzer, with a single replaceable pending task.
/// Closing kills a stuck worker immediately instead of awaiting its event loop.
class _IsolateTasker<Req, Res> {
  final String name;
  final IsolateRunnable<Req, Res> _runnable;
  bool _closed = false;
  bool _running = false;
  int _revision = 0;
  Future<void> Function()? _pendingTask;

  Isolate? _isolate;
  ReceivePort? _responses;
  SendPort? _requests;
  Completer<void>? _ready;
  Completer<Res>? _result;
  Future<void>? _starting;

  _IsolateTasker(this.name, this._runnable);

  void run(
    Req req,
    IsolateCallback<Res> callback, {
    void Function(Object, StackTrace)? onError,
  }) {
    if (_closed) return;
    final revision = ++_revision;
    _pendingTask = () async {
      try {
        final result = await _compute(req);
        if (!_closed && revision == _revision) callback(result);
      } catch (error, stack) {
        if (_closed || revision != _revision) return;
        if (onError != null) {
          onError(error, stack);
        } else {
          debugPrint('$name failed: $error');
        }
      }
    };
    _drain();
  }

  Future<void> _drain() async {
    if (_running) return;
    _running = true;
    try {
      while (!_closed && _pendingTask != null) {
        final task = _pendingTask!;
        _pendingTask = null;
        await task();
      }
    } finally {
      _running = false;
    }
  }

  Future<Res> _compute(Req req) async {
    if (kIsWeb) return compute(_runnable, req, debugLabel: name);
    await (_starting ??= _startWorker());
    if (_closed) throw StateError('$name is closed');
    final result = Completer<Res>();
    _result = result;
    _requests!.send(req);
    return result.future;
  }

  Future<void> _startWorker() async {
    final responses = ReceivePort();
    _responses = responses;
    final ready = Completer<void>();
    _ready = ready;
    responses.listen((message) {
      if (_closed) return;
      if (message is SendPort) {
        _requests = message;
        if (!ready.isCompleted) ready.complete();
      } else if (message is List &&
          message.length == 2 &&
          message.first is bool) {
        final result = _result;
        _result = null;
        if (result == null || result.isCompleted) return;
        if (message.first == true) {
          result.complete(message[1] as Res);
        } else {
          final error = message[1] as List;
          result.completeError(
              RemoteError(error[0] as String, error[1] as String));
        }
      } else {
        _failWorker(message is List
            ? RemoteError(message.first.toString(), message.last.toString())
            : StateError('$name worker exited'));
      }
    });
    try {
      await Future.wait<void>([
        Isolate.spawn<_IsolateStart<Req, Res>>(
          _taskerMain<Req, Res>,
          _IsolateStart<Req, Res>(responses.sendPort, _runnable),
          debugName: name,
          onError: responses.sendPort,
          onExit: responses.sendPort,
        ).then((isolate) {
          if (_closed) {
            isolate.kill(priority: Isolate.immediate);
          } else {
            _isolate = isolate;
          }
        }),
        ready.future,
      ], eagerError: true);
    } catch (_) {
      responses.close();
      rethrow;
    }
  }

  void _failWorker(Object error) {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _responses?.close();
    _requests = null;
    final ready = _ready;
    if (ready != null && !ready.isCompleted) ready.completeError(error);
    final result = _result;
    _result = null;
    if (result != null && !result.isCompleted) result.completeError(error);
    _starting = null;
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _pendingTask = null;
    _failWorker(StateError('$name is closed'));
  }
}

class _IsolateStart<Req, Res> {
  final SendPort responses;
  final IsolateRunnable<Req, Res> runnable;
  const _IsolateStart(this.responses, this.runnable);
}

@pragma('vm:entry-point')
void _taskerMain<Req, Res>(_IsolateStart<Req, Res> initial) {
  final requests = ReceivePort();
  initial.responses.send(requests.sendPort);
  requests.listen((request) {
    try {
      initial.responses.send([true, initial.runnable(request as Req)]);
    } catch (error, stack) {
      initial.responses.send([
        false,
        [error.toString(), stack.toString()]
      ]);
    }
  });
}
