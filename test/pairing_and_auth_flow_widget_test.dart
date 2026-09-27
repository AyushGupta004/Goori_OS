import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goori_os/app/app.dart';
import 'package:goori_os/core/models/models.dart';
import 'package:goori_os/core/network/network.dart';
import 'package:goori_os/core/services/services.dart';
import 'package:goori_os/core/storage/secure_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Task 5: Pairing, Silent Re-Authentication & Unpair Flows', () {
    late MockWindowsBridgeClient mockClient;
    late SecureStorageService secureStorage;
    late DiscoveryService discoveryService;
    late PairingService pairingService;
    late AuthenticationService authService;
    late ConnectionService connectionService;
    late BridgeConfigProvider configProvider;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockClient = MockWindowsBridgeClient();
      secureStorage = SecureStorageService(useMemoryOnly: true);
      discoveryService = DiscoveryService();
      configProvider = BridgeConfigProvider(
        initialConfig: const BridgeConfig(
          host: '127.0.0.1',
          port: 7890,
          mode: BridgeMode.mock,
        ),
      );
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
    });

    testWidgets(
        '1. Pairing Screen: UI copy, [CONNECT] button, invalid code error, success state and token storage',
        (WidgetTester tester) async {
      const testDevice = WindowsDevice(
        id: 'mock-win-pc-01',
        name: 'My Windows PC',
        host: '127.0.0.1',
        port: 7890,
      );

      await tester.pumpWidget(
        WindowsRemoteApp(
          configProvider: configProvider,
          secureStorage: secureStorage,
          discoveryService: discoveryService,
          pairingService: pairingService,
          authService: authService,
          connectionService: connectionService,
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to discovery then pairing
      await tester.tap(find.byKey(const ValueKey('home_connect_link')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('connect_btn_mock-win-pc-01')));
      await tester.pumpAndSettle();

      // Verify Pairing Screen UI copy matches prompt
      expect(find.text('DEVICE PAIRING'), findsOneWidget);
      expect(
        find.text('Enter the 6-digit code shown on your Windows computer'),
        findsOneWidget,
      );
      expect(find.text('CONNECT'), findsOneWidget);
      expect(find.byKey(const ValueKey('pairing_submit_btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('pairing_pin_input')), findsOneWidget);

      // Verify validation rejects empty / short PIN
      await tester.enterText(
        find.byKey(const ValueKey('pairing_pin_input')),
        '123',
      );
      await tester.tap(find.byKey(const ValueKey('pairing_submit_btn')));
      await tester.pumpAndSettle();
      expect(find.text('PIN must be exactly 6 digits'), findsOneWidget);

      // Submit valid 6-digit PIN
      await tester.enterText(
        find.byKey(const ValueKey('pairing_pin_input')),
        '654321',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('pairing_submit_btn')));
      await tester.pump();

      // Settle pairing execution (connect 300ms + pair 500ms = 800ms)
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();

      // Verify success state "✓ Device paired" and navigation to Home
      expect(find.text('WINDOWS REMOTE'), findsOneWidget);
      expect(find.text('✓ Device paired'), findsOneWidget);

      // Verify token was securely stored in SecureStorageService
      final storedToken = await secureStorage.getToken();
      expect(storedToken, isNotNull);
      expect(storedToken!.startsWith('mock_token_654321'), isTrue);

      final storedHost = await secureStorage.getHost();
      expect(storedHost, testDevice.host);
      expect(await secureStorage.getPort(), testDevice.port);
    });

    testWidgets(
        '2. Silent Re-Authentication on app launch: skips pairing, auto-authenticates to Home',
        (WidgetTester tester) async {
      // Pre-populate secure storage with existing session credentials (returning user)
      await secureStorage.saveConnectionInfo(
        host: '127.0.0.1',
        port: 7890,
        deviceId: 'WIN-MOCK-DEV-01',
        deviceName: 'My Windows PC',
        token: 'mock_token_existing_valid_token',
      );

      // Launch application fresh
      await tester.pumpWidget(
        WindowsRemoteApp(
          configProvider: configProvider,
          secureStorage: secureStorage,
          discoveryService: discoveryService,
          pairingService: pairingService,
          authService: authService,
          connectionService: connectionService,
        ),
      );

      // Settle silent re-auth (connect 300ms + authenticate 250ms = 550ms)
      await tester.pump(const Duration(milliseconds: 650));
      await tester.pumpAndSettle();

      // Verify Pairing Screen was SKIPPED completely and Home is directly CONNECTED
      expect(find.text('DEVICE PAIRING'), findsNothing);
      expect(find.text('ENTER PAIRING PIN'), findsNothing);
      expect(find.text('WINDOWS REMOTE'), findsOneWidget);
      expect(find.textContaining('WINDOWS / My Windows PC / '), findsOneWidget);
      expect(find.text('Connected'), findsOneWidget);
      expect(connectionService.currentState.isConnected, isTrue);
    });

    testWidgets(
        '3. INVALID_TOKEN failure path: clears stale token and routes user back to pairing',
        (WidgetTester tester) async {
      // Pre-populate secure storage with an invalid token
      await secureStorage.saveConnectionInfo(
        host: '127.0.0.1',
        port: 7890,
        deviceId: 'WIN-MOCK-DEV-01',
        deviceName: 'My Windows PC',
        token: 'invalid_expired_token_999',
      );

      // Launch application
      await tester.pumpWidget(
        WindowsRemoteApp(
          configProvider: configProvider,
          secureStorage: secureStorage,
          discoveryService: discoveryService,
          pairingService: pairingService,
          authService: authService,
          connectionService: connectionService,
        ),
      );

      // Settle silent re-auth failure (connect 300ms + auth rejection 250ms = 550ms)
      await tester.pump(const Duration(milliseconds: 650));
      await tester.pumpAndSettle();

      // Verify routed to pairing screen
      expect(find.text('DEVICE PAIRING'), findsOneWidget);
      expect(
        find.text('Enter the 6-digit code shown on your Windows computer'),
        findsOneWidget,
      );

      // Verify stale token was purged from SecureStorageService
      final remainingToken = await secureStorage.getToken();
      expect(remainingToken, isNull);
    });

    testWidgets(
        '4. Unpair Device: clears secure storage and returns to discovery/pairing flow',
        (WidgetTester tester) async {
      // Setup connected state
      await secureStorage.saveConnectionInfo(
        host: '127.0.0.1',
        port: 7890,
        deviceId: 'WIN-MOCK-DEV-01',
        deviceName: 'My Windows PC',
        token: 'mock_token_to_unpair',
      );

      await tester.pumpWidget(
        WindowsRemoteApp(
          configProvider: configProvider,
          secureStorage: secureStorage,
          discoveryService: discoveryService,
          pairingService: pairingService,
          authService: authService,
          connectionService: connectionService,
        ),
      );
      await tester.pump(const Duration(milliseconds: 650));
      await tester.pumpAndSettle();

      expect(find.textContaining('WINDOWS / My Windows PC / '), findsOneWidget);
      expect(find.text('Connected'), findsOneWidget);
      expect(find.byKey(const ValueKey('home_unpair_link')), findsOneWidget);

      // Tap UNPAIR link on Home
      await tester.tap(find.byKey(const ValueKey('home_unpair_link')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Verify returned to discovery/pairing flow
      expect(find.text('DEVICE DISCOVERY'), findsOneWidget);

      // Verify secure storage is completely cleared
      expect(await secureStorage.getToken(), isNull);
      expect(await secureStorage.getHost(), isNull);
      expect(await secureStorage.getDeviceId(), isNull);
      expect(connectionService.activeDevice, isNull);
    });

    testWidgets(
        '5. Settings Screen: Unpair Device button clears storage and resets connection',
        (WidgetTester tester) async {
      await secureStorage.saveConnectionInfo(
        host: '127.0.0.1',
        port: 7890,
        deviceId: 'WIN-MOCK-DEV-01',
        deviceName: 'My Windows PC',
        token: 'mock_token_settings_test',
      );

      await tester.pumpWidget(
        WindowsRemoteApp(
          configProvider: configProvider,
          secureStorage: secureStorage,
          discoveryService: discoveryService,
          pairingService: pairingService,
          authService: authService,
          connectionService: connectionService,
        ),
      );
      await tester.pump(const Duration(milliseconds: 650));
      await tester.pumpAndSettle();

      // Navigate to Settings
      await tester.tap(find.byTooltip('Settings'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('SETTINGS & CONFIG'), findsOneWidget);
      expect(find.text('My Windows PC'), findsOneWidget);
      expect(find.byKey(const ValueKey('unpair_device_btn')), findsOneWidget);

      // Tap UNPAIR DEVICE in Settings
      await tester.tap(find.byKey(const ValueKey('unpair_device_btn')));
      await tester.pumpAndSettle();

      // Confirm dialog per Task 10 unpair flow specification
      final confirmBtn = find.byKey(const ValueKey('confirm_unpair_dialog_btn'));
      if (confirmBtn.evaluate().isNotEmpty) {
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();
      }

      // Verify returned to discovery/pairing flow with credentials cleared
      expect(find.text('DEVICE DISCOVERY'), findsOneWidget);
      expect(await secureStorage.getToken(), isNull);
      expect(await secureStorage.getHost(), isNull);
    });
  });
}
