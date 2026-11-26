import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qfli_studio_core/harness/harness_host.dart';
import 'package:qfli_studio_core/harness/remote/remote_harness.dart';
import 'package:qfli_studio_core/remote_control/models/herdr.dart' as herdr;
import 'package:qfli_studio_core/remote_control/models/protocol.dart'
    as protocol;
import 'package:qfli_studio_core/remote_control/state/remote_controller.dart'
    show ConnectionPhase;
import 'package:qfli_studio_core/remote_control/state/session_view.dart';

protocol.SessionInfo _session({
  required String id,
  protocol.SessionStatus status = protocol.SessionStatus.running,
  String kind = 'claude',
  String title = '修复登录',
  String cwd = r'D:\work',
  int pending = 0,
}) => protocol.SessionInfo(
  id: id,
  title: title,
  cwd: cwd,
  status: status,
  mode: 'default',
  createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
  updatedAt: DateTime.fromMillisecondsSinceEpoch(2000),
  kind: kind,
  pending: pending,
);

class FakeRemoteSessionPort extends ChangeNotifier
    implements RemoteSessionPort {
  FakeRemoteSessionPort({
    this.isOnline = true,
    this.phase = ConnectionPhase.online,
    this.hostLabel = '办公室电脑',
    this.hostId = 'agent-42',
  });

  @override
  Listenable get changes => this;

  @override
  bool isOnline;

  @override
  ConnectionPhase phase;

  @override
  final String hostLabel;

  /// Mutable on purpose: a test can simulate pairing arriving after the host was
  /// constructed.
  @override
  String hostId;

  final Map<String, protocol.SessionInfo> sessionsById =
      <String, protocol.SessionInfo>{};
  final Map<String, SessionView> views = <String, SessionView>{};
  final List<String> calls = <String>[];

  @override
  List<protocol.SessionInfo> get sessions => sessionsById.values.toList();

  @override
  SessionView view(protocol.SessionInfo info) =>
      views.putIfAbsent(info.id, () => SessionView(info));

  void put(protocol.SessionInfo info) {
    sessionsById[info.id] = info;
    views.putIfAbsent(info.id, () => SessionView(info)).updateInfo(info);
    notifyListeners();
  }

  void pushEvent(String sessionId, protocol.SessionEvent event) {
    view(sessionsById[sessionId]!).applyEvent(event);
  }

  @override
  Future<void> refreshSessions() async => calls.add('refreshSessions');

  @override
  Future<void> subscribe(String id, {required Object owner}) async =>
      calls.add('subscribe:$id');

  @override
  void unsubscribe(String id, {required Object owner}) =>
      calls.add('unsubscribe:$id');

  @override
  Future<void> send(String id, String text) async =>
      calls.add('send:$id:$text');

  @override
  Future<void> respondPermission(
    String id,
    String requestId,
    String decision, {
    String? message,
    Map<String, String>? answers,
  }) async => calls.add(
    'respond:$id:$requestId:$decision:${answers ?? const <String, String>{}}',
  );

  @override
  Future<void> terminalInput(String id, String data) async =>
      calls.add('input:$id:${data.replaceAll('\r', '<CR>')}');

  @override
  Future<void> terminalResize(String id, int cols, int rows) async =>
      calls.add('resize:$id:$cols:$rows');

  @override
  Future<void> closeSession(String id) async {
    calls.add('closeSession:$id');
    sessionsById.remove(id);
    notifyListeners();
  }

  @override
  Future<protocol.SessionInfo> createSession({
    required String cwd,
    String? prompt,
  }) async {
    calls.add('createSession:$cwd');
    final created = _session(
      id: 'new-claude',
      status: protocol.SessionStatus.starting,
      title: '新会话',
      cwd: cwd,
    );
    put(created);
    return created;
  }

  @override
  Future<protocol.SessionInfo> createTerminal({required String cwd}) async {
    calls.add('createTerminal:$cwd');
    final created = _session(
      id: 'new-terminal',
      status: protocol.SessionStatus.starting,
      kind: 'terminal',
      title: '终端',
      cwd: cwd,
    );
    put(created);
    return created;
  }
}

herdr.HerdrAgent _agent({
  String paneId = 'w37:p14',
  String kind = 'pi',
  herdr.HerdrAgentStatus status = herdr.HerdrAgentStatus.idle,
  String title = 'π - qflistudio',
}) => herdr.HerdrAgent(
  target: paneId,
  paneId: paneId,
  workspaceId: 'w37',
  tabId: 'w37:t1',
  cwd: r'D:\MyNewProjects\qflistudio',
  agentKind: kind,
  status: status,
  focused: false,
  terminalTitle: title,
);

class FakeRemoteHerdrPort extends ChangeNotifier implements RemoteHerdrPort {
  FakeRemoteHerdrPort({this.canControl = true});

  @override
  Listenable get changes => this;

  @override
  bool canControl;

  final List<herdr.HerdrAgent> agentList = <herdr.HerdrAgent>[];
  final Map<String, String> paneTexts = <String, String>{};
  final List<String> calls = <String>[];

  @override
  List<herdr.HerdrAgent> get agents =>
      List<herdr.HerdrAgent>.unmodifiable(agentList);

  @override
  String paneText(String paneId) => paneTexts[paneId] ?? '';

  @override
  Future<void> refresh() async => calls.add('refresh');

  @override
  Future<herdr.HerdrOutput> read(
    String paneId, {
    herdr.HerdrReadSource source = herdr.HerdrReadSource.recent,
    int lines = 200,
  }) async =>
      herdr.HerdrOutput(paneId: paneId, source: source, text: paneText(paneId));

  @override
  Future<herdr.HerdrActionReport> sendText(String paneId, String text) async {
    calls.add('sendText:$paneId:$text');
    return const herdr.HerdrActionReport(action: 'ok', summary: '');
  }

  @override
  Future<herdr.HerdrActionReport> sendKeys(
    String paneId,
    List<String> keys,
  ) async {
    calls.add('sendKeys:$paneId:${keys.join(',')}');
    return const herdr.HerdrActionReport(action: 'ok', summary: '');
  }

  @override
  Future<herdr.HerdrActionReport> prompt(String paneId, String text) async {
    calls.add('prompt:$paneId:$text');
    return const herdr.HerdrActionReport(action: 'ok', summary: '');
  }

  @override
  Future<void> closePane(String paneId) async => calls.add('closePane:$paneId');
}

class FakeCodexThreadView extends ChangeNotifier
    implements RemoteCodexThreadView {
  FakeCodexThreadView(this._thread);

  protocol.CodexThread _thread;

  /// Pushes a new thread status the way the desktop does: through [changes].
  void setStatus(String status) {
    _thread = protocol.CodexThread(
      id: _thread.id,
      title: _thread.title,
      cwd: _thread.cwd,
      updatedAt: _thread.updatedAt,
      status: status,
      canAcceptDirectInput: _thread.canAcceptDirectInput,
      canResume: _thread.canResume,
    );
    notifyListeners();
  }

  final List<protocol.CodexTurn> turnList = <protocol.CodexTurn>[];
  final List<protocol.CodexPendingRequest> pendingList =
      <protocol.CodexPendingRequest>[];
  String? errorText;
  bool loadedValue = false;
  bool disposed = false;

  @override
  Listenable get changes => this;

  @override
  protocol.CodexThread get thread => _thread;
  @override
  List<protocol.CodexTurn> get turns => turnList;

  @override
  List<protocol.CodexPendingRequest> get pendingRequests => pendingList;

  @override
  String? get error => errorText;

  @override
  bool get loaded => loadedValue;

  @override
  bool get canControl => true;

  @override
  bool get canSend => true;

  @override
  Future<void> load({bool refresh = false}) async {
    loadedValue = true;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    super.dispose();
  }
}

class FakeRemoteCodexPort implements RemoteCodexPort {
  FakeRemoteCodexPort({
    this.available = true,
    List<protocol.CodexThread>? threads,
  }) : threadList = threads ?? <protocol.CodexThread>[];

  @override
  bool available;

  @override
  bool canControl = true;

  final List<protocol.CodexThread> threadList;
  final Map<String, FakeCodexThreadView> views =
      <String, FakeCodexThreadView>{};
  final List<String> calls = <String>[];

  @override
  Future<List<protocol.CodexThread>> recentThreads() async => threadList;

  @override
  Future<protocol.CodexTranscript> read(
    String threadId, {
    String? cursor,
  }) async => protocol.CodexTranscript(
    thread: threadList.firstWhere((thread) => thread.id == threadId),
    turns: const <protocol.CodexTurn>[],
  );

  @override
  Future<void> send(String threadId, String text, {String? turnId}) async =>
      calls.add('send:$threadId:$text');

  @override
  Future<void> respond(
    String threadId,
    String requestId,
    String decision, {
    Map<String, List<String>>? answers,
  }) async => calls.add('respond:$threadId:$requestId:$decision:$answers');

  @override
  Future<void> interrupt(String threadId, String turnId) async =>
      calls.add('interrupt:$threadId:$turnId');

  @override
  Future<protocol.CodexPage<protocol.CodexProject>> projects({
    String? cursor,
  }) async => const protocol.CodexPage<protocol.CodexProject>(
    <protocol.CodexProject>[],
    null,
  );

  @override
  RemoteCodexThreadView openThread(protocol.CodexThread thread) =>
      views.putIfAbsent(thread.id, () => FakeCodexThreadView(thread));
}

protocol.CodexThread _thread({
  String id = 'thread-1',
  String status = 'idle',
  String title = '重构 登录',
}) => protocol.CodexThread(
  id: id,
  title: title,
  cwd: r'D:\work',
  updatedAt: DateTime.fromMillisecondsSinceEpoch(3000),
  status: status,
  canAcceptDirectInput: true,
  canResume: true,
);

/// Sessions arrive from pushes, so wait for the snapshot instead of depending on
/// which broadcast event a test happens to observe.
Future<List<HarnessSessionInfo>> _waitFor(
  RemoteHarnessHost host,
  bool Function(List<HarnessSessionInfo>) predicate,
) async {
  for (var attempt = 0; attempt < 200; attempt++) {
    final list = host.currentSessions;
    if (predicate(list)) return list;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  return host.currentSessions;
}

Future<List<HarnessSessionInfo>> _waitForCount(
  RemoteHarnessHost host,
  int count,
) => _waitFor(host, (list) => list.length >= count);

/// 每个用例都带超时：一旦哪个 await 永远不回来，要失败得又快又准。
void testT(String description, Future<void> Function() body) =>
    test(description, () => body().timeout(const Duration(seconds: 15)));

/// 登记主机，用例失败也释放：定时器与推送订阅不会因为断言失败就停下。
RemoteHarnessHost tracked(RemoteHarnessHost host) {
  addTearDown(host.dispose);
  return host;
}

void main() {
  testT('merges Claude, Herdr and Codex sessions into one list', () async {
    final remote = FakeRemoteSessionPort();
    remote.put(_session(id: 's1', pending: 1));
    remote.put(
      _session(
        id: 's2',
        kind: 'terminal',
        title: 'PowerShell',
        status: protocol.SessionStatus.idle,
      ),
    );
    final herdrPort = FakeRemoteHerdrPort()..agentList.add(_agent());
    final codex = FakeRemoteCodexPort(
      threads: <protocol.CodexThread>[_thread()],
    );
    final host = RemoteHarnessHost(
      remote: remote,
      herdr: herdrPort,
      codex: codex,
    );

    final list = await _waitForCount(host, 4);
    final ids = list.map((session) => session.id).toList();
    expect(
      ids,
      containsAll(<String>[
        'session:s1',
        'session:s2',
        'herdr:w37:p14',
        'codex:thread-1',
      ]),
    );
    expect(host.state.value, HarnessHostState.online);
    expect(host.label, '办公室电脑');
    await host.dispose();
  });

  testT('maps statuses and capabilities per surface', () async {
    final remote = FakeRemoteSessionPort();
    remote.put(_session(id: 's1', status: protocol.SessionStatus.waiting));
    remote.put(
      _session(
        id: 's2',
        kind: 'terminal',
        status: protocol.SessionStatus.closed,
      ),
    );
    final host = RemoteHarnessHost(
      remote: remote,
      herdr: FakeRemoteHerdrPort()
        ..agentList.add(_agent(status: herdr.HerdrAgentStatus.blocked)),
    );
    final list = await _waitForCount(host, 3);
    final byId = <String, HarnessSessionInfo>{
      for (final info in list) info.id: info,
    };
    expect(byId['session:s1']!.status, HarnessSessionStatus.blocked);
    expect(
      byId['session:s1']!.capabilities,
      contains(HarnessCapability.approve),
    );
    expect(byId['session:s2']!.status, HarnessSessionStatus.exited);
    expect(byId['session:s2']!.providerId, 'shell');
    expect(
      byId['session:s2']!.capabilities,
      isNot(contains(HarnessCapability.transcript)),
    );
    expect(byId['herdr:w37:p14']!.status, HarnessSessionStatus.blocked);
    await host.dispose();
  });

  testT(
    'a Claude transcript streams history and keeps approvals explicit',
    () async {
      final remote = FakeRemoteSessionPort();
      remote.put(_session(id: 's1'));
      final host = tracked(RemoteHarnessHost(remote: remote));
      final handle = await host.open('session:s1');
      expect(handle.transcript, isNotNull);

      final events = <TranscriptEvent>[];
      final subscription = handle.transcript!.listen(events.add);

      remote.pushEvent(
        's1',
        protocol.UserEvent(1, DateTime.fromMillisecondsSinceEpoch(10), '你好'),
      );
      remote.pushEvent(
        's1',
        protocol.AssistantEvent(
          2,
          DateTime.fromMillisecondsSinceEpoch(11),
          '在',
        ),
      );
      remote.pushEvent(
        's1',
        protocol.PermissionRequestEvent(
          3,
          DateTime.fromMillisecondsSinceEpoch(12),
          requestId: 'r7',
          toolName: 'Bash',
          title: '允许执行 rm -rf build?',
          input: null,
          canAlwaysAllow: true,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(
        events.map((event) => event.text),
        containsAll(<String>['你好', '在']),
      );
      final request = events.firstWhere((event) => event.requestId == 'r7');
      expect(request.role, TranscriptRole.tool);
      expect(request.options, containsAll(<String>['allow', 'deny']));

      // Nothing was approved just by reading.
      expect(
        remote.calls.where((call) => call.startsWith('respond:')),
        isEmpty,
      );

      await handle.reply(const HarnessReply(requestId: 'r7', choice: 'allow'));
      expect(remote.calls, contains('respond:s1:r7:allow:{}'));

      await subscription.cancel();
      await handle.detach();
      expect(remote.calls, contains('unsubscribe:s1'));
      expect(
        remote.calls.any((call) => call.startsWith('closeSession:')),
        isFalse,
        reason: 'detach releases the view; the desktop session keeps running',
      );
      await host.dispose();
    },
  );

  testT('an unknown approval decision is a refusal, never consent', () async {
    final remote = FakeRemoteSessionPort();
    remote.put(_session(id: 's1'));
    final host = tracked(RemoteHarnessHost(remote: remote));
    final handle = await host.open('session:s1');
    remote.pushEvent(
      's1',
      protocol.PermissionRequestEvent(
        1,
        DateTime.fromMillisecondsSinceEpoch(1),
        requestId: 'r9',
        toolName: 'Bash',
        title: '执行命令',
        input: null,
        canAlwaysAllow: false,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await handle.reply(const HarnessReply(requestId: 'r9', choice: 'whatever'));
    expect(remote.calls, contains('respond:s1:r9:deny:{}'));
    await handle.detach();
    await host.dispose();
  });

  testT('a terminal session streams bytes and types exact input', () async {
    final remote = FakeRemoteSessionPort();
    remote.put(
      _session(
        id: 't1',
        kind: 'terminal',
        status: protocol.SessionStatus.running,
      ),
    );
    final host = tracked(RemoteHarnessHost(remote: remote));
    final handle = await host.open('session:t1');
    expect(handle.terminal, isNotNull);
    expect(handle.transcript, isNull);

    final chunks = <List<int>>[];
    final subscription = handle.terminal!.output.listen(
      (data) => chunks.add(data),
    );
    remote.pushEvent(
      't1',
      protocol.TerminalOutputEvent(
        1,
        DateTime.fromMillisecondsSinceEpoch(1),
        'PS> ',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(chunks.single, 'PS> '.codeUnits);

    handle.terminal!.write(Uint8List.fromList('dir\r'.codeUnits));
    expect(remote.calls, contains('input:t1:dir<CR>'));

    handle.terminal!.resize(100, 30);
    expect(remote.calls, contains('resize:t1:100:30'));

    await subscription.cancel();
    await handle.detach();
    await host.dispose();
  });

  testT('a terminal replays the screen it missed and clears on reset', () async {
    final remote = FakeRemoteSessionPort();
    remote.put(_session(id: 't1', kind: 'terminal'));
    final host = tracked(RemoteHarnessHost(remote: remote));

    final first = await host.open('session:t1');
    final live = <String>[];
    final firstSub = first.terminal!.output.listen(
      (data) => live.add(String.fromCharCodes(data)),
    );
    remote.pushEvent(
      't1',
      protocol.TerminalOutputEvent(
        1,
        DateTime.fromMillisecondsSinceEpoch(1),
        'PS> ',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(live.join(), 'PS> ');
    await firstSub.cancel();
    await first.detach();

    // Reopening builds a fresh channel; the screen so far must come back, or an
    // idle shell would look like an empty terminal.
    final second = await host.open('session:t1');
    final replay = <String>[];
    final secondSub = second.terminal!.output.listen(
      (data) => replay.add(String.fromCharCodes(data)),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(replay.join(), 'PS> ');

    // A resubscribe replays from scratch: the view must say so, or the same
    // screen would be appended to the old one.
    remote
        .view(remote.sessionsById['t1']!)
        .applyBacklog(<protocol.SessionEvent>[
          protocol.TerminalOutputEvent(
            1,
            DateTime.fromMillisecondsSinceEpoch(1),
            'PS> ',
          ),
        ], reset: true);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(replay.join(), 'PS> \u001b[2J\u001b[HPS> ');

    await secondSub.cancel();
    await second.detach();
    await host.dispose();
  });

  testT('a stopped session does not hand out a dead handle', () async {
    final remote = FakeRemoteSessionPort();
    remote.put(_session(id: 's1'));
    final host = tracked(RemoteHarnessHost(remote: remote));
    final handle = await host.open('session:s1');
    await handle.stop();

    // The desktop dropped the session, so reopening reports that instead of
    // returning a handle whose terminal is already closed.
    await expectLater(host.open('session:s1'), throwsA(isA<StateError>()));
    await host.dispose();
  });

  testT('a stopped Herdr pane reopens with a live handle', () async {
    final remote = FakeRemoteSessionPort();
    final herdrPort = FakeRemoteHerdrPort()..agentList.add(_agent());
    final host = tracked(RemoteHarnessHost(remote: remote, herdr: herdrPort));
    await _waitForCount(host, 1);

    final handle = await host.open('herdr:w37:p14');
    await handle.stop();
    expect(herdrPort.calls, contains('closePane:w37:p14'));

    // The pane row can still be listed while the desktop catches up; a second
    // open must build a new terminal rather than return the closed one.
    final again = await host.open('herdr:w37:p14');
    expect(identical(again, handle), isFalse);
    expect(again.terminal, isNotNull);
    await again.detach();
    await host.dispose();
  });

  testT('the host id is resolved once and namespaced once', () async {
    final remote = FakeRemoteSessionPort(hostId: '');
    final host = tracked(RemoteHarnessHost(remote: remote));
    expect(host.id, 'remote');
    // Pairing arrives after construction: the id must not change under the hub.
    remote.hostId = 'agent-42';
    expect(host.id, 'remote');

    final named = tracked(RemoteHarnessHost(remote: remote));
    expect(named.id, 'remote:agent-42');

    final explicit = tracked(RemoteHarnessHost(remote: remote, hostId: 'remote:pc-9'));
    expect(explicit.id, 'remote:pc-9');

    await host.dispose();
    await named.dispose();
    await explicit.dispose();
  });

  testT('a Codex row follows the thread status', () async {
    final remote = FakeRemoteSessionPort();
    final codex = FakeRemoteCodexPort(
      threads: <protocol.CodexThread>[_thread(status: 'active')],
    );
    final host = tracked(RemoteHarnessHost(remote: remote, codex: codex));
    await _waitForCount(host, 1);
    final handle = await host.open('codex:thread-1');
    expect(handle.status.value, HarnessSessionStatus.working);

    codex.views['thread-1']!.setStatus('blocked');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(handle.status.value, HarnessSessionStatus.blocked);

    codex.views['thread-1']!.setStatus('done');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(handle.status.value, HarnessSessionStatus.done);

    await handle.detach();
    await host.dispose();
  });

  testT('stop closes the session; detach does not', () async {
    final remote = FakeRemoteSessionPort();
    remote.put(_session(id: 's1'));
    final host = tracked(RemoteHarnessHost(remote: remote));
    final handle = await host.open('session:s1');
    await handle.stop();
    expect(remote.calls, contains('closeSession:s1'));
    expect(handle.status.value, HarnessSessionStatus.exited);
    await host.dispose();
  });

  testT(
    'Herdr panes on the paired computer replay snapshots and send keys',
    () async {
      final remote = FakeRemoteSessionPort();
      final herdrPort = FakeRemoteHerdrPort()..agentList.add(_agent());
      final host = tracked(RemoteHarnessHost(remote: remote, herdr: herdrPort));
      await _waitForCount(host, 1);
      final handle = await host.open('herdr:w37:p14');
      expect(handle.terminal, isNotNull);
      expect(handle.transcript, isNull);

      final chunks = <String>[];
      final subscription = handle.terminal!.output
          .cast<List<int>>()
          .transform(utf8.decoder)
          .listen(chunks.add);
      // Push after subscribing: the terminal is a view, not a buffer.
      herdrPort.paneTexts['w37:p14'] = 'π > ready\n';
      herdrPort.notifyListeners();
      for (var attempt = 0; attempt < 100; attempt++) {
        if (chunks.join().contains('π > ready')) break;
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(chunks.join(), contains('π > ready'));

      handle.terminal!.write(Uint8List.fromList(<int>[0x1b, 0x5b, 0x41]));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(herdrPort.calls, contains('sendKeys:w37:p14:up'));

      await expectLater(
        handle.reply(const HarnessReply(requestId: 'x', choice: 'allow')),
        throwsA(isA<UnsupportedError>()),
      );

      await handle.stop();
      expect(herdrPort.calls, contains('closePane:w37:p14'));
      await subscription.cancel();
      await host.dispose();
    },
  );

  testT(
    'Codex threads expose a transcript and answer pending approvals',
    () async {
      final remote = FakeRemoteSessionPort();
      final codex = FakeRemoteCodexPort(
        threads: <protocol.CodexThread>[_thread()],
      );
      final host = tracked(RemoteHarnessHost(remote: remote, codex: codex));
      await _waitForCount(host, 1);

      final handle = await host.open('codex:thread-1');
      expect(handle.transcript, isNotNull);
      expect(handle.terminal, isNull);

      final view = codex.views['thread-1']!;
      view.turnList.add(
        const protocol.CodexTurn(
          id: 'turn-1',
          status: 'complete',
          items: <protocol.CodexItem>[
            protocol.CodexItem(id: 'i1', kind: 'user', text: '改一下标题'),
            protocol.CodexItem(id: 'i2', kind: 'assistant', text: '已经改好'),
          ],
        ),
      );
      view.pendingList.add(
        const protocol.CodexPendingRequest(
          requestId: 'req-1',
          kind: 'command',
          title: '运行 flutter analyze?',
          canAccept: true,
        ),
      );
      view.notifyListeners();

      final events = <TranscriptEvent>[];
      final subscription = handle.transcript!.listen(events.add);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(
        events.map((event) => event.text),
        containsAll(<String>['改一下标题', '已经改好']),
      );
      final approval = events.firstWhere((event) => event.requestId == 'req-1');
      expect(approval.options, containsAll(<String>['accept', 'deny']));

      await handle.reply(
        const HarnessReply(requestId: 'req-1', choice: 'accept'),
      );
      expect(
        codex.calls.any(
          (call) => call.startsWith('respond:thread-1:req-1:accept'),
        ),
        isTrue,
      );
      await subscription.cancel();
      await handle.detach();
      expect(view.disposed, isTrue);
      await host.dispose();
    },
  );

  testT(
    'launch creates a Claude session or a terminal on the desktop',
    () async {
      final remote = FakeRemoteSessionPort();
      final host = tracked(RemoteHarnessHost(remote: remote));
      final claude = await host.launch(
        const HarnessLaunchRequest(providerId: 'claude', cwd: r'D:\work'),
      );
      expect(claude.info.providerId, 'claude');
      expect(remote.calls, contains(r'createSession:D:\work'));

      final terminal = await host.launch(
        const HarnessLaunchRequest(providerId: 'shell', cwd: r'D:\work'),
      );
      expect(terminal.info.providerId, 'shell');
      expect(remote.calls, contains(r'createTerminal:D:\work'));
      await expectLater(
        host.launch(
          const HarnessLaunchRequest(providerId: 'codex', cwd: r'D:\work'),
        ),
        throwsA(isA<StateError>()),
      );
      await host.dispose();
    },
  );

  testT(
    'an offline computer reports offline and offers no remote launch',
    () async {
      final remote = FakeRemoteSessionPort(
        isOnline: false,
        phase: ConnectionPhase.agentOffline,
      );
      final host = tracked(RemoteHarnessHost(remote: remote));
      expect(host.state.value, HarnessHostState.offline);
      await expectLater(
        host.launch(
          const HarnessLaunchRequest(providerId: 'claude', cwd: r'D:\w'),
        ),
        throwsA(isA<StateError>()),
      );
      await host.dispose();
    },
  );
}
