import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goori_os/app/app.dart';
import 'package:goori_os/core/network/network.dart';
import 'package:goori_os/core/services/services.dart';
import 'package:goori_os/core/storage/secure_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Task 6: Home Screen Layout & Persistent App Shell Navigation', () {
    late MockWindowsBridgeClient mockClient;
    late SecureStorageService secureStorage;
    late DiscoveryService discoveryService;
    late PairingService pairingService;
    late AuthenticationService authService;
    late ConnectionService connectionService;
    late CommandService commandService;
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
      commandService = CommandService(client: mockClient);
    });

    testWidgets(
        '1. Persistent App Shell: bottom nav switches between HOME, FILES, PHOTOS, and ⚙',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        WindowsRemoteApp(
          configProvider: configProvider,
          secureStorage: secureStorage,
          discoveryService: discoveryService,
          pairingService: pairingService,
          authService: authService,
          connectionService: connectionService,
          commandService: commandService,
        ),
      );
      await tester.pumpAndSettle();

      // Verify bottom navigation bar exists with 4 items
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.byKey(const ValueKey('nav_home')), findsOneWidget);
      expect(find.byKey(const ValueKey('nav_files')), findsOneWidget);
      expect(find.byKey(const ValueKey('nav_photos')), findsOneWidget);
      expect(find.byKey(const ValueKey('nav_settings')), findsOneWidget);

      // Verify initially on HOME
      expect(find.text('WINDOWS REMOTE'), findsOneWidget);

      // Switch to FILES tab
      await tester.tap(find.byKey(const ValueKey('nav_files')));
      await tester.pumpAndSettle();
      expect(find.text('FILE STREAM'), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsOneWidget); // Persistent shell

      // Switch to PHOTOS tab
      await tester.tap(find.byKey(const ValueKey('nav_photos')));
      await tester.pumpAndSettle();
      expect(find.text('PHOTO TRANSMIT'), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsOneWidget);

      // Switch to ⚙ (Settings) tab
      await tester.tap(find.byKey(const ValueKey('nav_settings')));
      await tester.pumpAndSettle();
      expect(find.text('SETTINGS & CONFIG'), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsOneWidget);

      // Switch back to HOME tab
      await tester.tap(find.byKey(const ValueKey('nav_home')));
      await tester.pumpAndSettle();
      expect(find.text('WINDOWS REMOTE'), findsOneWidget);
    });

    testWidgets(
        '2. Home Screen Layout: status block, mic button, last command, and quick links',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        WindowsRemoteApp(
          configProvider: configProvider,
          secureStorage: secureStorage,
          discoveryService: discoveryService,
          pairingService: pairingService,
          authService: authService,
          connectionService: connectionService,
          commandService: commandService,
        ),
      );
      await tester.pumpAndSettle();

      // 1. Status Block: in disconnected state initially
      expect(find.byKey(const ValueKey('home_status_block')), findsOneWidget);
      expect(find.textContaining('WINDOWS / My Windows PC / '), findsOneWidget);
      expect(find.text('Disconnected'), findsOneWidget);

      // Offline card with RETRY button shown when disconnected
      expect(find.byKey(const ValueKey('offline_state_card')), findsOneWidget);
      expect(find.text('BRIDGE OFFLINE'), findsOneWidget);
      expect(find.byKey(const ValueKey('offline_retry_btn')), findsOneWidget);

      // 2. Large centered microphone button
      expect(find.byKey(const ValueKey('mic_command_btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('tap_to_command_caption')), findsOneWidget);
      expect(find.text('Tap to give a command'), findsOneWidget);

      // 3. Last command section (empty initial state)
      expect(find.text('LAST COMMAND'), findsOneWidget);
      expect(find.text('No commands executed yet'), findsOneWidget);

      // 4. Quick links row
      expect(find.text('QUICK ACTIONS'), findsOneWidget);
      expect(find.byKey(const ValueKey('quick_link_commands')), findsOneWidget);
      expect(find.byKey(const ValueKey('quick_link_files')), findsOneWidget);
      expect(find.byKey(const ValueKey('quick_link_photos')), findsOneWidget);
    });

    testWidgets(
        '3. Live connection state update: offline card hides and status changes to Connected',
        (WidgetTester tester) async {
      await secureStorage.saveConnectionInfo(
        host: '127.0.0.1',
        port: 7890,
        deviceId: 'mock-win-pc-01',
        deviceName: 'My Windows PC',
        token: 'mock_token_live_test',
      );

      await tester.pumpWidget(
        WindowsRemoteApp(
          configProvider: configProvider,
          secureStorage: secureStorage,
          discoveryService: discoveryService,
          pairingService: pairingService,
          authService: authService,
          connectionService: connectionService,
          commandService: commandService,
        ),
      );

      // Initially offline before connection resolves
      expect(find.text('Disconnected'), findsOneWidget);
      expect(find.byKey(const ValueKey('offline_state_card')), findsOneWidget);

      // Tap RETRY button to trigger connection flow
      await tester.tap(find.byKey(const ValueKey('offline_retry_btn')));
      await tester.pump();
      // Settle connection (300ms) + authenticate (250ms)
      await tester.pump(const Duration(milliseconds: 650));
      await tester.pumpAndSettle();

      // Real-time status update: status block now shows Connected
      expect(find.text('Connected'), findsOneWidget);
      expect(find.textContaining('WINDOWS / My Windows PC / '), findsOneWidget);

      // Offline card is now hidden
      expect(find.byKey(const ValueKey('offline_state_card')), findsNothing);
    });

    testWidgets(
        '4. Last command telemetry: updates with text and ✓ / ✕ status',
        (WidgetTester tester) async {
      await secureStorage.saveConnectionInfo(
        host: '127.0.0.1',
        port: 7890,
        deviceId: 'mock-win-pc-01',
        deviceName: 'My Windows PC',
        token: 'mock_token_cmd_test',
      );

      await tester.pumpWidget(
        WindowsRemoteApp(
          configProvider: configProvider,
          secureStorage: secureStorage,
          discoveryService: discoveryService,
          pairingService: pairingService,
          authService: authService,
          connectionService: connectionService,
          commandService: commandService,
        ),
      );
      await tester.pump(const Duration(milliseconds: 650));
      await tester.pumpAndSettle();

      // Dispatch a command via commandService
      final commandFuture = commandService.sendCommand('open notepad');
      await tester.pump(); // emits 'received'
      await tester.pump(const Duration(milliseconds: 160)); // emits 'executing'
      await tester.pump(const Duration(milliseconds: 360)); // completes
      await commandFuture;
      await tester.pumpAndSettle();

      // Verify Last Command card displays telemetry
      expect(find.byKey(const ValueKey('last_command_block')), findsOneWidget);
      expect(find.text('✓'), findsOneWidget);
      expect(find.textContaining('open notepad'), findsOneWidget);
      expect(find.text('COMPLETED'), findsOneWidget);
    });

    testWidgets(
        '5. Quick Links: tap COMMANDS, FILES, and PHOTOS navigates correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        WindowsRemoteApp(
          configProvider: configProvider,
          secureStorage: secureStorage,
          discoveryService: discoveryService,
          pairingService: pairingService,
          authService: authService,
          connectionService: connectionService,
          commandService: commandService,
        ),
      );
      await tester.pumpAndSettle();

      // Tap quick link FILES
      await tester.ensureVisible(find.byKey(const ValueKey('quick_link_files')));
      await tester.tap(find.byKey(const ValueKey('quick_link_files')));
      await tester.pumpAndSettle();
      expect(find.text('FILE STREAM'), findsOneWidget);

      // Switch back to HOME via bottom nav
      await tester.tap(find.byKey(const ValueKey('nav_home')));
      await tester.pumpAndSettle();
      expect(find.text('WINDOWS REMOTE'), findsOneWidget);

      // Tap quick link PHOTOS
      await tester.ensureVisible(find.byKey(const ValueKey('quick_link_photos')));
      await tester.tap(find.byKey(const ValueKey('quick_link_photos')));
      await tester.pumpAndSettle();
      expect(find.text('PHOTO TRANSMIT'), findsOneWidget);

      // Switch back to HOME via bottom nav
      await tester.tap(find.byKey(const ValueKey('nav_home')));
      await tester.pumpAndSettle();
      expect(find.text('WINDOWS REMOTE'), findsOneWidget);

      // Tap quick link COMMANDS
      await tester.ensureVisible(find.byKey(const ValueKey('quick_link_commands')));
      await tester.tap(find.byKey(const ValueKey('quick_link_commands')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('commands_screen')), findsOneWidget);
    });
  });
}
