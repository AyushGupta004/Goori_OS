import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:goori_os/core/constants/app_constants.dart';
import 'package:goori_os/core/models/models.dart';
import 'package:goori_os/core/network/network.dart';

/// Test consumer class demonstrating that controllers/services only depend
/// on the abstract [WindowsBridgeClient] interface.
class SampleCommandController {
  final WindowsBridgeClient client;

  SampleCommandController(this.client);

  Future<CommandResult> runAutomation(String text) async {
    final request = CommandRequest(
      commandId: 'cmd_${DateTime.now().millisecondsSinceEpoch}',
      type: 'text',
      payload: text,
      timestamp: DateTime.now(),
    );
    return await client.sendCommand(request);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MockWindowsBridgeClient Implementation Verification', () {
    late MockWindowsBridgeClient mockClient;

    setUp(() {
      mockClient = MockWindowsBridgeClient();
    });

    tearDown(() {
      mockClient.dispose();
    });

    test('connect() transitions through connecting -> connected', () async {
      final states = <ConnectionState>[];
      final sub = mockClient.connectionState.listen(states.add);

      expect(mockClient.currentConnectionState, ConnectionState.disconnected);

      await mockClient.connect(
        const BridgeConfig(host: '127.0.0.1', port: 7890, mode: BridgeMode.mock),
      );

      await Future.delayed(const Duration(milliseconds: 50));
      expect(states, [ConnectionState.connecting, ConnectionState.connected]);
      expect(mockClient.currentConnectionState, ConnectionState.connected);

      await sub.cancel();
    });

    test('pair() accepts 6-digit PIN and returns session token', () async {
      final response = await mockClient.pair('123456');

      expect(response.success, true);
      expect(response.sessionToken, isNotNull);
      expect(response.sessionToken!.startsWith('mock_token_123456'), true);
      expect(response.deviceId.startsWith('WIN-MOCK-DEV-'), true);
    });

    test('pair() rejects invalid non-6-digit PIN', () async {
      final response = await mockClient.pair('123');

      expect(response.success, false);
      expect(response.sessionToken, isNull);
      expect(response.errorMessage, contains('INVALID_PAIRING_CODE'));
    });

    test('authenticate() validates token and emits authenticating -> connected',
        () async {
      await mockClient.connect(
        const BridgeConfig(host: '127.0.0.1', port: 7890, mode: BridgeMode.mock),
      );

      final pairResp = await mockClient.pair('654321');
      final validToken = pairResp.sessionToken!;

      final states = <ConnectionState>[];
      final sub = mockClient.connectionState.listen(states.add);

      final authResp = await mockClient.authenticate(validToken);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(authResp.authenticated, true);
      expect(authResp.permissions, contains('command'));
      expect(states, [ConnectionState.authenticating, ConnectionState.connected]);

      await sub.cancel();
    });

    test('authenticate() rejects invalid token and disconnects', () async {
      await mockClient.connect(
        const BridgeConfig(host: '127.0.0.1', port: 7890, mode: BridgeMode.mock),
      );

      final authResp = await mockClient.authenticate('bad_token');

      expect(authResp.authenticated, false);
      expect(authResp.errorMessage, contains('INVALID_TOKEN'));
      expect(mockClient.currentConnectionState, ConnectionState.disconnected);
    });

    test('sendCommand() emits received -> executing -> completed via commandResults stream',
        () async {
      await mockClient.connect(
        const BridgeConfig(host: '127.0.0.1', port: 7890, mode: BridgeMode.mock),
      );

      final commandId = 'test-cmd-001';
      final streamResults = <CommandResult>[];
      final sub = mockClient.commandResults.listen(streamResults.add);

      final request = CommandRequest(
        commandId: commandId,
        type: 'voice_transcript',
        payload: 'open notepad',
        timestamp: DateTime.now(),
      );

      final finalResult = await mockClient.sendCommand(request);

      expect(finalResult.commandId, commandId);
      expect(finalResult.success, true);
      expect(finalResult.status, 'completed');

      // Allow stream timers to settle
      await Future.delayed(const Duration(milliseconds: 100));

      final statuses = streamResults.map((r) => r.status).toList();
      expect(statuses, containsAllInOrder(['received', 'executing', 'completed']));

      await sub.cancel();
    });

    test('uploadFile() emits progressive TransferProgress from 0% to 100%',
        () async {
      final tempFile = File('${Directory.systemTemp.path}/test_upload.txt');
      await tempFile.writeAsString('Test upload payload content');

      final progressUpdates = <TransferProgress>[];

      await mockClient.uploadFile(
        tempFile,
        onProgress: (p) => progressUpdates.add(p),
      );

      expect(progressUpdates.isNotEmpty, true);
      expect(progressUpdates.first.status, TransferStatus.waiting);
      expect(progressUpdates.last.status, TransferStatus.completed);
      expect(progressUpdates.last.fraction, 1.0);
      expect(progressUpdates.last.percentage, 100);

      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    });

    test('disconnect() cleanly tears down state to disconnected', () async {
      await mockClient.connect(
        const BridgeConfig(host: '127.0.0.1', port: 7890, mode: BridgeMode.mock),
      );
      expect(mockClient.currentConnectionState, ConnectionState.connected);

      await mockClient.disconnect();
      expect(mockClient.currentConnectionState, ConnectionState.disconnected);
    });
  });

  group('BridgeClientFactory and Mock <-> Real Swapping', () {
    test('Factory returns MockWindowsBridgeClient when mode is mock', () {
      const mockConfig = BridgeConfig(
        host: '127.0.0.1',
        port: 7890,
        mode: BridgeMode.mock,
      );

      final client = BridgeClientFactory.createClient(mockConfig);
      expect(client, isA<MockWindowsBridgeClient>());
      expect(client, isA<WindowsBridgeClient>());
    });

    test('Factory returns RealWindowsBridgeClient when mode is dev or production',
        () {
      const devConfig = BridgeConfig(
        host: '192.168.1.150',
        port: 7890,
        mode: BridgeMode.dev,
      );

      const prodConfig = BridgeConfig(
        host: '192.168.1.150',
        port: 7890,
        mode: BridgeMode.production,
      );

      final devClient = BridgeClientFactory.createClient(devConfig);
      expect(devClient, isA<RealWindowsBridgeClient>());
      expect(devClient, isA<WindowsBridgeClient>());

      final prodClient = BridgeClientFactory.createClient(prodConfig);
      expect(prodClient, isA<RealWindowsBridgeClient>());
      expect(prodClient, isA<WindowsBridgeClient>());
    });

    test('Zero consumer code changes when swapping Mock <-> Real via config',
        () async {
      // Configuration 1: Mock Mode
      const mockConfig = BridgeConfig(
        host: '127.0.0.1',
        port: 7890,
        mode: BridgeMode.mock,
      );

      final mockClient = BridgeClientFactory.createClient(mockConfig);
      await mockClient.connect(mockConfig);

      // Consumer depends ONLY on abstract WindowsBridgeClient interface
      final controllerUsingMock = SampleCommandController(mockClient);
      final mockResult =
          await controllerUsingMock.runAutomation('test mock automation');

      expect(mockResult.success, true);
      expect(mockResult.status, 'completed');

      // Configuration 2: Switch to Real Mode by changing config only
      const realConfig = BridgeConfig(
        host: '192.168.1.200',
        port: 7890,
        mode: BridgeMode.dev,
      );

      final realClient = BridgeClientFactory.createClient(realConfig);
      // Consumer uses the exact same interface with zero modifications
      final controllerUsingReal = SampleCommandController(realClient);

      expect(controllerUsingReal.client, isA<WindowsBridgeClient>());
      expect(controllerUsingReal.client, isA<RealWindowsBridgeClient>());
    });

    test('BridgeConfigProvider dynamically swaps active client on config change',
        () async {
      final provider = BridgeConfigProvider(
        initialConfig: const BridgeConfig(
          host: '127.0.0.1',
          port: 7890,
          mode: BridgeMode.mock,
        ),
      );

      expect(provider.client, isA<MockWindowsBridgeClient>());

      // Swap to dev (Real client)
      await provider.updateConfig(
        const BridgeConfig(
          host: '192.168.1.50',
          port: 7890,
          mode: BridgeMode.dev,
        ),
        persist: false,
      );

      expect(provider.client, isA<RealWindowsBridgeClient>());

      // Swap back to mock
      await provider.updateConfig(
        const BridgeConfig(
          host: '127.0.0.1',
          port: 7890,
          mode: BridgeMode.mock,
        ),
        persist: false,
      );

      expect(provider.client, isA<MockWindowsBridgeClient>());
    });
  });
}
