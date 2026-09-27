import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goori_os/app/app.dart';
import 'package:goori_os/core/network/network.dart';
import 'package:goori_os/core/services/services.dart';
import 'package:goori_os/core/storage/secure_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Discovery & Manual Connect Flow End-to-End Widget Tests', () {
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
        'DELIVERABLE: Blank app -> reach discovery -> find mock device -> proceed to pairing',
        (WidgetTester tester) async {
      // 1. Launch blank app on home screen
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

      // Verify Home Screen initially shows DISCONNECTED and ready console
      expect(find.text('WINDOWS REMOTE'), findsOneWidget);
      expect(find.text('Disconnected'), findsOneWidget);
      expect(find.byKey(const ValueKey('home_connect_link')), findsOneWidget);

      // 2. User taps CONNECT link on Home Screen
      await tester.tap(find.byKey(const ValueKey('home_connect_link')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Discovery Screen is reached and shows searching state
      expect(find.text('DEVICE DISCOVERY'), findsOneWidget);
      expect(find.text('Searching for Windows...'), findsOneWidget);

      // Settle discovery scan animation & mock device discovery delay (350ms)
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // 3. Verify mock device is found and displayed
      expect(find.text('AVAILABLE WINDOWS BRIDGES (1)'), findsOneWidget);
      expect(find.text('My Windows PC'), findsOneWidget);
      expect(find.text('Windows AI Bridge'), findsOneWidget);
      expect(find.text('127.0.0.1:7890'), findsOneWidget);

      final connectBtnFinder =
          find.byKey(const ValueKey('connect_btn_mock-win-pc-01'));
      expect(connectBtnFinder, findsOneWidget);

      // 4. User taps CONNECT on the discovered device card -> proceeds to pairing
      await tester.tap(connectBtnFinder);
      await tester.pumpAndSettle();

      // Verify Pairing Screen is reached with the target device
      expect(find.text('DEVICE PAIRING'), findsOneWidget);
      expect(find.text('ENTER PAIRING PIN'), findsOneWidget);
      expect(find.text('My Windows PC'), findsOneWidget);
      expect(find.text('127.0.0.1:7890'), findsOneWidget);
      expect(find.byKey(const ValueKey('pairing_pin_input')), findsOneWidget);
      expect(find.byKey(const ValueKey('pairing_submit_btn')), findsOneWidget);

      // 5. Complete pairing verification with 6-digit PIN
      await tester.enterText(
        find.byKey(const ValueKey('pairing_pin_input')),
        '123456',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('pairing_submit_btn')));
      await tester.pump(); // Start submission

      // Settle simulated pairing verification delay (connect: 300ms + pair: 500ms = 800ms)
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();

      // Verify returned to home screen with paired success state
      expect(find.text('WINDOWS REMOTE'), findsOneWidget);
      expect(find.text('✓ Device paired'), findsOneWidget);
    });

    testWidgets('Manual Connect sheet opens, validates, and navigates to pairing',
        (WidgetTester tester) async {
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

      // Navigate to discovery
      await tester.tap(find.byKey(const ValueKey('home_connect_link')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // Tap "Connect manually" link
      expect(find.text('Connect manually'), findsOneWidget);
      await tester.tap(find.text('Connect manually'));
      await tester.pumpAndSettle();

      // Verify manual connect bottom sheet opened
      expect(find.text('MANUAL BRIDGE CONNECTION'), findsOneWidget);
      expect(find.byKey(const ValueKey('manual_host_input')), findsOneWidget);
      expect(find.byKey(const ValueKey('manual_port_input')), findsOneWidget);

      // Enter manual connection data
      await tester.enterText(
        find.byKey(const ValueKey('manual_host_input')),
        '192.168.1.88',
      );
      await tester.enterText(
        find.byKey(const ValueKey('manual_port_input')),
        '8443',
      );
      await tester.pumpAndSettle();

      // Submit manual connect
      await tester.tap(find.byKey(const ValueKey('manual_connect_submit_btn')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Verify navigated to pairing screen with manual host
      expect(find.text('DEVICE PAIRING'), findsOneWidget);
      expect(find.text('192.168.1.88:8443'), findsOneWidget);
      expect(configProvider.config.host, '192.168.1.88');
      expect(configProvider.config.port, 8443);
    });

    testWidgets('DiscoveryScreen renders not-found state with retry & manual options',
        (WidgetTester tester) async {
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

      // Clear any discovered devices to simulate network scan returning 0 devices
      discoveryService.clearDiscovered();

      await tester.tap(find.byKey(const ValueKey('home_connect_link')));
      await tester.pump();
      // Wait for scanning to finish without any mock devices added
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Manually stop and clear to inspect not-found state
      await discoveryService.stopDiscovery();
      discoveryService.clearDiscovered();
      await tester.pumpAndSettle();

      expect(find.text('NO WINDOWS HOSTS FOUND'), findsOneWidget);
      expect(
        find.textContaining('Couldn\'t connect to Windows.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('retry_scan_btn')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('not_found_manual_connect_btn')),
        findsOneWidget,
      );
    });
  });
}
