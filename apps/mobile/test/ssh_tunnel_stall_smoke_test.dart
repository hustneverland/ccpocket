// Fork-only smoke test: a jump host that stops answering without closing the
// connection (docker pause), as after a network change in an elevator.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ccpocket/models/machine.dart';
import 'package:ccpocket/services/machine_manager_service.dart';
import 'package:ccpocket/services/ssh_bridge_tunnel_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _MemorySecureStorage implements FlutterSecureStorage {
  final Map<String, String> values = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => values[key];

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _compose(String action) async {
  final result = await Process.run('docker', [
    'compose',
    '-f',
    '../../tools/ssh-jump-smoke/docker-compose.yml',
    action,
    'jump-sshd',
  ]);
  if (result.exitCode != 0) {
    throw StateError('docker compose $action failed: ${result.stderr}');
  }
}

void main() {
  final enabled = Platform.environment['CCPOCKET_SSH_TUNNEL_STALL_SMOKE'] == '1';

  test(
    'stalled jump host closes open sockets and recovers on the same URL',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final manager = MachineManagerService(prefs, _MemorySecureStorage());
      final tunnelService = SshBridgeTunnelService(
        manager,
        connectionTimeout: const Duration(seconds: 5),
        debugLog: (message) {
          if (message != null) printOnFailure(message);
        },
      );
      addTearDown(tunnelService.closeAll);
      addTearDown(() => _compose('unpause').catchError((Object _) {}));
      manager.configureBridgeTunnelResolvers(
        wsUrlResolver: tunnelService.buildWsUrl,
        httpBaseUrlResolver: tunnelService.buildHttpBaseUrl,
      );
      await manager.addMachine(
        Machine(
          id: 'm1',
          host: 'target-sshd',
          port: 8765,
          sshEnabled: true,
          sshUsername: 'ccpocket',
          sshJumpHost: '127.0.0.1',
          sshJumpPort: 22220,
        ),
        sshPassword: 'ccpocket',
      );

      final wsUrl = await manager.buildWsUrl('m1');
      final httpBaseUrl = wsUrl.replaceFirst('ws://', 'http://');
      final before = await http
          .get(Uri.parse('$httpBaseUrl/health'))
          .timeout(const Duration(seconds: 10));
      expect(before.body, 'ok');

      final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      await channel.ready.timeout(const Duration(seconds: 10));
      final closed = Completer<void>();
      channel.stream.listen(
        (message) => printOnFailure('ws message: $message'),
        onDone: closed.complete,
        onError: (Object _) {},
      );

      final stalledAt = DateTime.now();
      await _compose('pause');
      // Health checks run every 15 s and wait 5 s (connectionTimeout) for an
      // answer, so the open socket must be closed well within 40 s.
      await closed.future.timeout(const Duration(seconds: 40));
      printOnFailure(
        'socket closed after ${DateTime.now().difference(stalledAt)}',
      );

      await _compose('unpause');
      final after = await http
          .get(Uri.parse('$httpBaseUrl/health'))
          .timeout(const Duration(seconds: 30));
      expect(after.statusCode, 200);
      expect(after.body, 'ok');
      expect(jsonEncode(await manager.buildWsUrl('m1')), jsonEncode(wsUrl));
    },
    skip: enabled ? false : 'Set CCPOCKET_SSH_TUNNEL_STALL_SMOKE=1',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
