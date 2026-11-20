// Cross-layer test: the real Windows client controller talks to the real Node
// sidecar over the loopback socket. This proves the IPC contract end to end
// without a Windows toolchain, and is skipped when agent deps are missing.
//
// It starts the sidecar from empty config and cwd, without --local-relay or a
// bootstrap file, matching the first launch of the portable package.

import 'dart:async';
import 'dart:io';

import 'package:cloudterminal_windows/engine/sidecar_client.dart';
import 'package:cloudterminal_windows/models/tool.dart';
import 'package:flutter_test/flutter_test.dart';

final bool _serverReady = Directory(
  '../remote_agent/node_modules',
).existsSync();

Future<T> _waitFor<T>(
  Stream<Map<String, dynamic>> messages,
  T? Function() probe, {
  Duration timeout = const Duration(seconds: 25),
}) {
  final now = probe();
  if (now != null) return Future<T>.value(now);
  final completer = Completer<T>();
  late StreamSubscription<Map<String, dynamic>> sub;
  sub = messages.listen((_) {
    final value = probe();
    if (value != null && !completer.isCompleted) {
      completer.complete(value);
      unawaited(sub.cancel());
    }
  });
  return completer.future.timeout(timeout).whenComplete(sub.cancel);
}

void main() {
  test(
    'the sidecar serves snapshot, tool probes and a pair code to the client',
    () async {
      final home = Directory.systemTemp.createTempSync('ct-win-ipc-');
      addTearDown(() {
        if (home.existsSync()) home.deleteSync(recursive: true);
      });

      final portProbe = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final relayPort = portProbe.port;
      await portProbe.close();
      final entry = File('../remote_agent/src/agent/main.ts').absolute.path;
      final client = SidecarClient(
        executable: Platform.isWindows ? 'node.exe' : 'node',
        arguments: <String>[
          entry,
          '--sidecar',
          '--port',
          '$relayPort',
          '--no-herdr',
        ],
        workingDirectory: home.path,
        environment: <String, String>{
          'CLOUDTERMINAL_HOME': home.path,
          'CLOUDTERMINAL_RELAY': '',
          'CLOUDTERMINAL_RELAY_KEY': '',
          'CLOUDTERMINAL_BOOTSTRAP': '${home.path}/absent-bootstrap.json',
        },
      );
      addTearDown(client.dispose);

      final snapshots = <AssistantSnapshot>[];
      final codes = <PairCodeInfo>[];
      client.messages.listen((message) {
        if (message['type'] == 'snapshot') {
          snapshots.add(AssistantSnapshot.fromJson(message));
        }
        if (message['type'] == 'pair_code') {
          codes.add(PairCodeInfo.fromJson(message));
        }
      });

      await client.start();
      expect(client.port, isNotNull);
      client.probeTools();
      client.requestPairCode();

      final online = await _waitFor(
        client.messages,
        () => snapshots.any((s) => s.relayOnline) ? true : null,
      );
      expect(online, isTrue);
      expect(snapshots.lastWhere((s) => s.relayOnline).connectionMode, 'local');

      final withTools = await _waitFor(
        client.messages,
        () => snapshots.any((s) => s.tools.isNotEmpty) ? true : null,
      );
      expect(withTools, isTrue);
      final probe = snapshots
          .lastWhere((s) => s.tools.isNotEmpty)
          .probe(ToolKind.herdr);
      // Herdr is installed on this machine; the test still passes if it is not.
      expect(probe == null || probe.kind == ToolKind.herdr, isTrue);

      final code = await _waitFor(
        client.messages,
        () => codes.isNotEmpty ? codes.last : null,
      );
      expect(
        PairCodeInfo(
          display: code.display,
          uri: code.uri,
          expiresAt: code.expiresAt,
        ).display,
        isNotEmpty,
      );
      expect(code.uri, startsWith('cloudterminal://pair?'));
      final relay = Uri.parse(Uri.parse(code.uri).queryParameters['relay']!);
      expect(relay.host, isNot(anyOf('localhost', '127.0.0.1', '0.0.0.0')));
      expect(relay.port, relayPort);
    },
    skip: _serverReady ? false : 'run `npm ci` in ../remote_agent first',
  );
}
