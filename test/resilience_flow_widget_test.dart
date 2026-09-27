import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_test/flutter_test.dart';
import 'package:goori_os/app/app.dart';
import 'package:goori_os/core/errors/app_errors.dart';
import 'package:goori_os/core/models/models.dart';
import 'package:goori_os/core/network/bridge_config_provider.dart';
import 'package:goori_os/core/network/config.dart';
import 'package:goori_os/core/network/mock_windows_bridge_client.dart';
import 'package:goori_os/core/services/authentication_service.dart';
import 'package:goori_os/core/services/command_history_service.dart';
import 'package:goori_os/core/services/command_service.dart';
import 'package:goori_os/core/services/connection_service.dart';
import 'package:goori_os/core/services/discovery_service.dart';
import 'package:goori_os/core/services/network_connectivity_service.dart';
import 'package:goori_os/core/services/pairing_service.dart';
import 'package:goori_os/core/services/settings_service.dart';
import 'package:goori_os/core/storage/secure_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockWindowsBridgeClient mockClient;
  late BridgeConfigProvider configProvider;
  late SecureStorageService secureStorage;
  late DiscoveryService discoveryService;
  late PairingService pairingService;
  late AuthenticationService authService;
  late MockNetworkConnectivityService mockConnectivityService;
  late ConnectionService connectionService;
  late CommandHistoryService commandHistoryService;
  late SettingsService settingsService;
  late CommandService commandService;

  bool isInitialized = false;

  void initTestServices() {
    mockClient = MockWindowsBridgeClient();
    configProvider = BridgeConfigProvider(
      initialConfig: const BridgeConfig(
        host: '127.0.0.1',
        port: 7890,
        protocolVersion: '1.0',
        mode: BridgeMode.mock,
      ),
      client: mockClient,
    );
    secureStorage = SecureStorageService(useMemoryOnly: true);
    discoveryService = DiscoveryService();
    pairingService =
        PairingService(client: mockClient, secureStorage: secureStorage);
    authService =
        AuthenticationService(client: mockClient, secureStorage: secureStorage);
    mockConnectivityService =
        MockNetworkConnectivityService(initialType: NetworkType.wifi);

    connectionService = ConnectionService(
      client: mockClient,
      secureStorage: secureStorage,
      discoveryService: discoveryService,
      pairingService: pairingService,
      authService: authService,
      connectivityService: mockConnectivityService,
    );

    commandHistoryService = CommandHistoryService();
    settingsService = SettingsService();
    commandService = CommandService(
      client: mockClient,
      historyService: commandHistoryService,
    );
    isInitialized = true;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    if (isInitialized) {
      connectionService.dispose();
      commandService.dispose();
      mockClient.dispose();
      mockConnectivityService.dispose();
      isInitialized = false;
    }
  });

  Widget createTestApp() {
    return WindowsRemoteApp(
      configProvider: configProvider,
      secureStorage: secureStorage,
      discoveryService: discoveryService,
      pairingService: pairingService,
      authService: authService,
      connectionService: connectionService,
      commandService: commandService,
      commandHistoryService: commandHistoryService,
      settingsService: settingsService,
      connectivityService: mockConnectivityService,
    );
  }

  group('Task 11: Resilience Layer Tests', () {
    testWidgets(
      '1. Mid-session WebSocket drop triggers auto-reconnect with exponential backoff and re-authenticates',
      (WidgetTester tester) async {
        initTestServices();
        // Pre-pair device
        await secureStorage.saveConnectionInfo(
          host: '127.0.0.1',
          port: 7890,
          deviceId: 'WIN-MOCK-DEV-01',
          deviceName: 'My Windows PC',
          token: 'mock_valid_token_resilience',
        );

        await tester.pumpWidget(createTestApp());
        // Splash/home settles to Home
        await tester.pump(const Duration(milliseconds: 650));
        await tester.pumpAndSettle();

        // Verify initially connected
        expect(find.text('Connected'), findsOneWidget);
        expect(connectionService.currentState, equals(ConnectionState.connected));
        expect(connectionService.currentBackoffSeconds, equals(1));

        // -----------------------------------------------------------------
        // Simulate unexpected WebSocket disconnection mid-session
        // -----------------------------------------------------------------
        mockClient.simulateDisconnect();
        await tester.pump();
        await tester.pump();

        // 1. Verify connection lost message shown and reconnect scheduled
        expect(connectionService.errorMessage, equals(AppErrors.connectionLost));
        expect(connectionService.isReconnecting, isTrue);
        expect(find.text('Reconnecting...'), findsOneWidget);
        expect(connectionService.currentBackoffSeconds, equals(1));

        // 2. Advance time past 1-second backoff delay (does not hammer server immediately)
        await tester.pump(const Duration(seconds: 1));
        // Allow connect and authenticate simulated latency (300ms + 250ms = 550ms)
        await tester.pump(const Duration(milliseconds: 650));
        await tester.pumpAndSettle();

        // 3. Verify connection recovered gracefully to Connected
        expect(connectionService.currentState, equals(ConnectionState.connected));
        expect(find.text('Connected'), findsOneWidget);
        expect(connectionService.errorMessage, isNull);
        expect(connectionService.isReconnecting, isFalse);
        expect(connectionService.currentBackoffSeconds, equals(1));
      },
    );

    testWidgets(
      '2. Exponential backoff increases on repeated failures (1s, 2s, 4s, 8s, 16s capped)',
      (WidgetTester tester) async {
        initTestServices();
        await secureStorage.saveConnectionInfo(
          host: '127.0.0.1',
          port: 7890,
          deviceId: 'WIN-MOCK-DEV-01',
          deviceName: 'My Windows PC',
          token: 'mock_valid_token_backoff',
        );

        await tester.pumpWidget(createTestApp());
        await tester.pump(const Duration(milliseconds: 650));
        await tester.pumpAndSettle();

        expect(connectionService.currentBackoffSeconds, equals(1));

        // Force connection failures (e.g. host unreachable)
        mockClient.forceConnectFailure = true;

        // Disconnect mid-session
        mockClient.simulateDisconnect();
        await tester.pump();
        await tester.pump();

        // Attempt 1 fails after 1s delay + 300ms connect delay
        expect(connectionService.currentBackoffSeconds, equals(1));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
        // Backoff doubles to 2s
        expect(connectionService.currentBackoffSeconds, equals(2));

        // Attempt 2 fails after 2s delay + 300ms connect delay
        await tester.pump(const Duration(seconds: 2));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
        // Backoff doubles to 4s
        expect(connectionService.currentBackoffSeconds, equals(4));

        // Attempt 3 fails after 4s delay + 300ms connect delay
        await tester.pump(const Duration(seconds: 4));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
        // Backoff doubles to 8s
        expect(connectionService.currentBackoffSeconds, equals(8));

        // Attempt 4 fails after 8s delay + 300ms connect delay
        await tester.pump(const Duration(seconds: 8));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
        // Backoff doubles to 16s (capped)
        expect(connectionService.currentBackoffSeconds, equals(16));

        // Attempt 5 fails after 16s delay -> remains capped at 16s
        await tester.pump(const Duration(seconds: 16));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
        expect(connectionService.currentBackoffSeconds, equals(16));

        // Now host recovers
        mockClient.forceConnectFailure = false;
        await tester.pump(const Duration(seconds: 16));
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pumpAndSettle();

        // Gracefully recovered and backoff reset to 1
        expect(connectionService.currentState, equals(ConnectionState.connected));
        expect(connectionService.currentBackoffSeconds, equals(1));
      },
    );

    testWidgets(
      '3. Network connectivity changes (Wi-Fi <-> Mobile <-> Hotspot) trigger: disconnect -> rediscover -> reconnect -> authenticate',
      (WidgetTester tester) async {
        initTestServices();
        await secureStorage.saveConnectionInfo(
          host: '127.0.0.1',
          port: 7890,
          deviceId: 'WIN-MOCK-DEV-01',
          deviceName: 'My Windows PC',
          token: 'mock_valid_token_network',
        );

        await tester.pumpWidget(createTestApp());
        await tester.pump(const Duration(milliseconds: 650));
        await tester.pumpAndSettle();

        expect(find.text('Connected'), findsOneWidget);

        // -----------------------------------------------------------------
        // Simulate device switching networks (e.g. Wi-Fi to Windows Hotspot)
        // -----------------------------------------------------------------
        mockConnectivityService.triggerNetworkSwitch(
          NetworkType.hotspot,
          details: 'Switched to Windows Hotspot',
        );

        // Allow listener to start resilience sequence
        await tester.pump();
        await tester.pump();
        // Discovery delay (350ms) + connect (300ms) + auth (250ms) = ~900ms
        await tester.pump(const Duration(milliseconds: 1500));
        await tester.pumpAndSettle();

        // Verify app recovered and re-authenticated on the new network route
        expect(connectionService.currentState, equals(ConnectionState.connected));
        expect(find.text('Connected'), findsOneWidget);
        expect(connectionService.errorMessage, isNull);
      },
    );

    testWidgets(
      '4. Protocol version check on authenticate displays incompatible copy and aborts',
      (WidgetTester tester) async {
        initTestServices();
        // Configure mock client to report an incompatible protocol version (2.0 vs 1.0)
        mockClient.mockProtocolVersion = '2.0';

        await secureStorage.saveConnectionInfo(
          host: '127.0.0.1',
          port: 7890,
          deviceId: 'WIN-MOCK-DEV-01',
          deviceName: 'My Windows PC',
          token: 'mock_token_incompatible',
        );

        await tester.pumpWidget(createTestApp());
        await tester.pump(const Duration(milliseconds: 650));
        await tester.pumpAndSettle();

        // 1. Verify app refused to proceed to Connected
        expect(connectionService.currentState, isNot(equals(ConnectionState.connected)));

        // 2. Verify exact specification copy is shown in offline card
        expect(
          find.text('This Windows Bridge version is not compatible with this application'),
          findsOneWidget,
        );
        expect(
          connectionService.errorMessage,
          equals('This Windows Bridge version is not compatible with this application'),
        );
      },
    );

    testWidgets(
      '5. Centralized error copy: AppErrorMapper maps all technical exceptions to friendly messages',
      (WidgetTester tester) async {
        // 1. Windows not found
        expect(
          AppErrorMapper.map('no windows bridge hosts found on local network'),
          equals(AppErrors.windowsNotFound),
        );

        // 2. Pairing failed
        expect(
          AppErrorMapper.map('pairing_failed: HTTP 500'),
          equals(AppErrors.pairingFailed),
        );

        // 3. Invalid pairing code
        expect(
          AppErrorMapper.map('invalid_pairing_code: code must be 6 numeric digits'),
          equals(AppErrors.invalidPairingCode),
        );

        // 4. Token expired
        expect(
          AppErrorMapper.map('invalid_token: Provided authentication token was rejected'),
          equals(AppErrors.tokenExpired),
        );

        // 5. Authentication failed
        expect(
          AppErrorMapper.map('auth_timeout: Windows Bridge did not respond'),
          equals(AppErrors.authenticationFailed),
        );

        // 6. Connection lost
        expect(
          AppErrorMapper.map('SocketException: OS Error: Connection refused, errno = 111'),
          equals(AppErrors.connectionLost),
        );

        // 7. Upload failed
        expect(
          AppErrorMapper.map('multipart upload stream failed with error'),
          equals(AppErrors.uploadFailed),
        );

        // 8. Command failed
        expect(
          AppErrorMapper.map('dispatch_error: simulated_execution_failure'),
          equals(AppErrors.commandFailed),
        );

        // 9. Permission denied (mic and storage)
        expect(
          AppErrorMapper.map('microphone permission permanently denied'),
          equals(AppErrors.permissionDeniedMic),
        );
        expect(
          AppErrorMapper.map('storage permission denied by user'),
          equals(AppErrors.permissionDeniedStorage),
        );

        // 10. Incompatible protocol version
        expect(
          AppErrorMapper.map('incompatible bridge protocol version'),
          equals(AppErrors.versionMismatch),
        );
      },
    );
  });
}
