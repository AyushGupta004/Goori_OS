import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:goori_os/core/constants/app_constants.dart';
import 'package:goori_os/core/models/models.dart';
import 'package:goori_os/core/network/network.dart';
import 'package:goori_os/core/services/services.dart';
import 'package:goori_os/core/storage/secure_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Storage & Orchestration Services Headless Integration Flow', () {
    late MockWindowsBridgeClient mockClient;
    late SecureStorageService secureStorage;
    late DiscoveryService discoveryService;
    late PairingService pairingService;
    late AuthenticationService authService;
    late ConnectionService connectionService;
    late CommandService commandService;
    late FileTransferService fileTransferService;

    setUp(() {
      mockClient = MockWindowsBridgeClient();
      secureStorage = SecureStorageService(useMemoryOnly: true);
      discoveryService = DiscoveryService();
      pairingService = PairingService(
        client: mockClient,
        secureStorage: secureStorage,
      );
      authService = AuthenticationService(
        client: mockClient,
        secureStorage: secureStorage,
      );
      connectionService = ConnectionService(
        client: mockClient,
        secureStorage: secureStorage,
        discoveryService: discoveryService,
        pairingService: pairingService,
        authService: authService,
      );
      commandService = CommandService(client: mockClient);
      fileTransferService = FileTransferService(client: mockClient);
    });

    tearDown(() {
      connectionService.dispose();
      discoveryService.dispose();
      commandService.dispose();
      fileTransferService.dispose();
      mockClient.dispose();
    });

    test(
        'FULL HEADLESS LIFECYCLE: discover -> pair -> store token -> reconnect -> auto-authenticate',
        () async {
      // -----------------------------------------------------------------------
      // PHASE 1: Initial Startup Flow with zero credentials
      // -----------------------------------------------------------------------
      expect(await secureStorage.getToken(), isNull);

      final initialResult = await connectionService.runStartupFlow(
        mode: BridgeMode.mock,
      );

      // Verifies discovery ran, found device, and paused at pairingRequired
      expect(initialResult, StartupFlowResult.pairingRequired);
      expect(connectionService.activeDevice, isNotNull);
      expect(connectionService.activeDevice!.name, 'My Windows PC');

      final discoveredDevice = connectionService.activeDevice!;

      // -----------------------------------------------------------------------
      // PHASE 2: Pairing with 6-digit PIN & Secure Token Persistence
      // -----------------------------------------------------------------------
      final pairingResponse = await connectionService.pair(
        discoveredDevice,
        '482910',
        mode: BridgeMode.mock,
      );

      expect(pairingResponse.success, true);
      expect(pairingResponse.sessionToken, isNotNull);

      // Verify token and host info are persisted exclusively in SecureStorage
      final savedToken = await secureStorage.getToken();
      expect(savedToken, isNotNull);
      expect(savedToken, pairingResponse.sessionToken);
      expect(await secureStorage.getHost(), '127.0.0.1');
      expect(await secureStorage.getPort(), 7890);
      expect(await secureStorage.getDeviceId(), startsWith('WIN-MOCK-DEV-'));

      // -----------------------------------------------------------------------
      // PHASE 3: Disconnect (Simulate app quit / bridge offline)
      // -----------------------------------------------------------------------
      await connectionService.disconnect();
      expect(connectionService.currentState, ConnectionState.disconnected);

      // -----------------------------------------------------------------------
      // PHASE 4: Second Startup Flow (App relaunch with existing stored token)
      // -----------------------------------------------------------------------
      final lifecycleStates = <ConnectionState>[];
      final stateSub = connectionService.connectionState.listen(lifecycleStates.add);

      final reconnectResult = await connectionService.runStartupFlow(
        mode: BridgeMode.mock,
      );

      // Verifies automatic reconnection and token authentication
      expect(reconnectResult, StartupFlowResult.connected);
      expect(connectionService.currentState, ConnectionState.connected);
      expect(authService.isAuthenticated, true);

      // Settle stream microtasks
      await Future.delayed(const Duration(milliseconds: 50));
      expect(lifecycleStates, contains(ConnectionState.authenticating));
      expect(lifecycleStates, contains(ConnectionState.connected));

      await stateSub.cancel();

      // -----------------------------------------------------------------------
      // PHASE 5: Post-Reconnection Automation Command Dispatch
      // -----------------------------------------------------------------------
      final cmdResult = await commandService.sendCommand(
        'Launch AI Workflow',
        type: 'text',
      );

      expect(cmdResult.success, true);
      expect(cmdResult.status, 'completed');
      expect(commandService.history.length, 1);
      expect(commandService.history.first.message, contains('Launch AI Workflow'));

      // -----------------------------------------------------------------------
      // PHASE 6: Post-Reconnection Streamed File Upload
      // -----------------------------------------------------------------------
      final tempFile = File('${Directory.systemTemp.path}/orchestration_test.bin');
      await tempFile.writeAsBytes(List.filled(1024 * 512, 42)); // 512 KB

      final uploadUpdates = <TransferProgress>[];
      final progressSub =
          fileTransferService.progressStream.listen(uploadUpdates.add);

      await fileTransferService.uploadFile(tempFile);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(uploadUpdates.isNotEmpty, true);
      expect(fileTransferService.currentProgress?.status, TransferStatus.completed);
      expect(uploadUpdates.last.status, TransferStatus.completed);
      expect(uploadUpdates.last.fraction, 1.0);

      await progressSub.cancel();
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      // -----------------------------------------------------------------------
      // PHASE 7: Logout / Invalidation Teardown
      // -----------------------------------------------------------------------
      await authService.logout();
      expect(await secureStorage.getToken(), isNull);
      expect(authService.isAuthenticated, false);
      expect(connectionService.currentState, ConnectionState.disconnected);

      // Subsequent startup flow requires pairing again
      final loggedOutResult = await connectionService.runStartupFlow(
        mode: BridgeMode.mock,
      );
      expect(loggedOutResult, StartupFlowResult.pairingRequired);
    });

    test('DiscoveryService adds and selects manual host/port fallback', () async {
      discoveryService.addManualDevice('192.168.1.99', 8080, name: 'Workstation');

      expect(discoveryService.discoveredDevices.length, 1);
      final dev = discoveryService.discoveredDevices.first;
      expect(dev.host, '192.168.1.99');
      expect(dev.port, 8080);
      expect(dev.name, 'Workstation');
    });

    test('Invalid token triggers pairingRequired and clears bad token', () async {
      // Seed bad token in secure storage
      await secureStorage.saveConnectionInfo(
        host: '127.0.0.1',
        port: 7890,
        deviceId: 'TEST-DEV',
        token: 'corrupted_invalid_token',
      );

      final result = await connectionService.runStartupFlow(
        mode: BridgeMode.mock,
      );

      // Rejects bad token, clears it, and demands pairing
      expect(result, StartupFlowResult.pairingRequired);
      expect(await secureStorage.getToken(), isNull);
      expect(connectionService.currentState, ConnectionState.disconnected);
    });
  });
}
