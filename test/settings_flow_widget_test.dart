import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goori_os/app/app.dart';
import 'package:goori_os/app/theme.dart';
import 'package:goori_os/core/network/network.dart';
import 'package:goori_os/core/services/services.dart';
import 'package:goori_os/core/storage/secure_storage_service.dart';
import 'package:goori_os/features/files/services/file_picker_service.dart';
import 'package:goori_os/features/photos/services/image_picker_service.dart';
import 'package:goori_os/features/voice/services/speech_recognition_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Task 10: Settings Screen & Preference Wiring Tests', () {
    late MockWindowsBridgeClient mockClient;
    late SecureStorageService secureStorage;
    late BridgeConfigProvider configProvider;
    late DiscoveryService discoveryService;
    late PairingService pairingService;
    late AuthenticationService authService;
    late ConnectionService connectionService;
    late CommandHistoryService commandHistoryService;
    late SettingsService settingsService;
    late MockSpeechRecognitionService speechService;
    late CommandService commandService;
    late FileTransferService fileTransferService;
    late PhotoTransferService photoTransferService;
    late MockFilePickerService mockFilePickerService;
    late MockImagePickerService mockImagePickerService;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();

      mockClient = MockWindowsBridgeClient();
      secureStorage = SecureStorageService(useMemoryOnly: true);
      configProvider = BridgeConfigProvider(
        initialConfig: const BridgeConfig(
          host: '127.0.0.1',
          port: 7890,
          protocolVersion: '1.0',
          mode: BridgeMode.mock,
        ),
      );
      discoveryService = DiscoveryService();
      pairingService =
          PairingService(client: mockClient, secureStorage: secureStorage);
      authService =
          AuthenticationService(client: mockClient, secureStorage: secureStorage);
      connectionService = ConnectionService(
        client: mockClient,
        secureStorage: secureStorage,
        discoveryService: discoveryService,
        pairingService: pairingService,
        authService: authService,
      );
      commandHistoryService = CommandHistoryService(prefs: prefs);
      settingsService = SettingsService(prefs: prefs);
      speechService = MockSpeechRecognitionService();
      commandService = CommandService(
        client: mockClient,
        historyService: commandHistoryService,
      );
      fileTransferService = FileTransferService(client: mockClient);
      photoTransferService = PhotoTransferService(client: mockClient);
      mockFilePickerService = MockFilePickerService();
      mockImagePickerService = MockImagePickerService();

      // Setup connected state with mock device info
      await secureStorage.saveConnectionInfo(
        host: '127.0.0.1',
        port: 7890,
        deviceId: 'WIN-MOCK-DEV-01',
        deviceName: 'My Windows PC',
        token: 'mock_settings_active_token',
      );

      await mockClient.connect(const BridgeConfig(
        host: '127.0.0.1',
        port: 7890,
        mode: BridgeMode.mock,
      ));
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
        speechRecognitionService: speechService,
        fileTransferService: fileTransferService,
        photoTransferService: photoTransferService,
        filePickerService: mockFilePickerService,
        imagePickerService: mockImagePickerService,
      );
    }

    testWidgets(
      '1. Connection section renders read-only device name, IP address, and live status',
      (WidgetTester tester) async {
        await tester.pumpWidget(createTestApp());
        await tester.pump(const Duration(milliseconds: 650));
        await tester.pumpAndSettle();

        // Navigate to Settings tab (⚙)
        await tester.tap(find.byKey(const ValueKey('nav_settings')));
        await tester.pumpAndSettle();

        // Verify section header and read-only telemetry rows
        expect(find.text('CONNECTION'), findsOneWidget);
        expect(find.byKey(const ValueKey('connection_section')), findsOneWidget);
        expect(find.byKey(const ValueKey('settings_device_name')), findsOneWidget);
        expect(find.text('My Windows PC'), findsOneWidget);
        expect(find.byKey(const ValueKey('settings_ip_address')), findsOneWidget);
        expect(find.text('127.0.0.1:7890'), findsOneWidget);

        // Verify live status badge
        expect(find.byKey(const ValueKey('settings_connection_status')), findsOneWidget);
        expect(find.text('● Connected'), findsOneWidget);
      },
    );

    testWidgets(
      '2. Pairing section: "Unpair Device" requires confirmation, clears storage, and routes to discovery',
      (WidgetTester tester) async {
        await tester.pumpWidget(createTestApp());
        await tester.pump(const Duration(milliseconds: 650));
        await tester.pumpAndSettle();

        // Navigate to Settings tab
        await tester.tap(find.byKey(const ValueKey('nav_settings')));
        await tester.pumpAndSettle();

        expect(find.text('PAIRING'), findsOneWidget);
        final unpairBtn = find.byKey(const ValueKey('unpair_device_btn'));
        expect(unpairBtn, findsOneWidget);

        // 1. Tap Unpair -> opens confirmation dialog
        await tester.tap(unpairBtn);
        await tester.pumpAndSettle();

        expect(find.text('Unpair Windows PC?'), findsOneWidget);
        expect(
          find.text('Are you sure you want to unpair from this Windows computer? You will need to re-enter a 6-digit code to connect again.'),
          findsOneWidget,
        );

        // 2. Tap CANCEL -> dialog is dismissed without unpairing
        final cancelDialogBtn = find.byKey(const ValueKey('cancel_unpair_dialog_btn'));
        expect(cancelDialogBtn, findsOneWidget);
        await tester.tap(cancelDialogBtn);
        await tester.pumpAndSettle();

        expect(find.text('Unpair Windows PC?'), findsNothing);
        // Token still exists in secure storage
        expect(await secureStorage.getToken(), equals('mock_settings_active_token'));

        // 3. Tap Unpair again and confirm
        await tester.tap(unpairBtn);
        await tester.pumpAndSettle();

        final confirmDialogBtn = find.byKey(const ValueKey('confirm_unpair_dialog_btn'));
        expect(confirmDialogBtn, findsOneWidget);
        await tester.tap(confirmDialogBtn);
        await tester.pumpAndSettle();

        // 4. Verify routed to discovery flow
        expect(find.text('DEVICE DISCOVERY'), findsOneWidget);

        // 5. Verify secure storage credentials completely purged
        expect(await secureStorage.getToken(), isNull);
        expect(await secureStorage.getHost(), isNull);
        expect(await secureStorage.getDeviceId(), isNull);
        expect(connectionService.activeDevice, isNull);
      },
    );

    testWidgets(
      '3. Commands section: "Auto-send commands" toggle modifies voice flow end-to-end',
      (WidgetTester tester) async {
        await tester.pumpWidget(createTestApp());
        await tester.pump(const Duration(milliseconds: 650));
        await tester.pumpAndSettle();

        // -----------------------------------------------------------------
        // Part A: Initially confirmBeforeSend is true (autoSend = false)
        // -----------------------------------------------------------------
        expect(settingsService.autoSend, isFalse);

        // Navigate to Voice via mic button on Home
        await tester.tap(find.byKey(const ValueKey('mic_command_btn')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('voice_mic_btn')));
        await tester.pump();
        speechService.finishTranscript('open terminal');
        await tester.pumpAndSettle();

        // Because autoSend is false, review card with [SEND] and [CANCEL] is shown
        expect(find.byKey(const ValueKey('command_review_card')), findsOneWidget);
        expect(find.text('open terminal'), findsOneWidget);
        expect(find.byKey(const ValueKey('send_command_btn')), findsOneWidget);

        // Navigate back to Home and open Settings
        await tester.tap(find.byKey(const ValueKey('cancel_command_btn')));
        await tester.pumpAndSettle();
        Navigator.of(tester.element(find.byKey(const ValueKey('voice_screen')))).pop();
        await tester.pumpAndSettle();

        // Go to Settings tab
        await tester.tap(find.byKey(const ValueKey('nav_settings')));
        await tester.pumpAndSettle();

        // -----------------------------------------------------------------
        // Part B: Toggle "Auto-send commands" ON
        // -----------------------------------------------------------------
        await tester.drag(find.byKey(const ValueKey('settings_list_view')), const Offset(0, -200));
        await tester.pumpAndSettle();

        final autoSendSwitch = find.byKey(const ValueKey('auto_send_commands_switch'));
        expect(autoSendSwitch, findsOneWidget);
        await tester.tap(autoSendSwitch);
        await tester.pumpAndSettle();

        expect(settingsService.autoSend, isTrue);

        // Navigate back to Home and then to Voice
        await tester.tap(find.byKey(const ValueKey('nav_home')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('mic_command_btn')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('voice_mic_btn')));
        await tester.pump();
        speechService.finishTranscript('launch calculator');
        // Auto-send dispatches command immediately
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        // Verification: Command was auto-sent without confirmation card!
        expect(find.byKey(const ValueKey('command_review_card')), findsNothing);
        expect(find.text('✓ Command completed'), findsOneWidget);
      },
    );

    testWidgets(
      '4. Commands section: "Command history" toggle and "Clear command history" action work end-to-end',
      (WidgetTester tester) async {
        // Pre-populate history with 2 records
        await commandHistoryService.addCommand(
          id: 'cmd-pre-1',
          commandText: 'existing command 1',
          success: true,
          timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        );
        await commandHistoryService.addCommand(
          id: 'cmd-pre-2',
          commandText: 'existing command 2',
          success: true,
          timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
        );

        expect(commandHistoryService.history.length, equals(2));

        await tester.pumpWidget(createTestApp());
        await tester.pump(const Duration(milliseconds: 650));
        await tester.pumpAndSettle();

        // Navigate to Settings
        await tester.tap(find.byKey(const ValueKey('nav_settings')));
        await tester.pumpAndSettle();

        // Scroll commands section into view
        await tester.drag(find.byKey(const ValueKey('settings_list_view')), const Offset(0, -250));
        await tester.pumpAndSettle();

        // 1. Verify history switch and clear action are rendered
        expect(find.byKey(const ValueKey('command_history_switch')), findsOneWidget);
        expect(find.byKey(const ValueKey('clear_command_history_btn')), findsOneWidget);
        expect(find.textContaining('2 stored commands'), findsOneWidget);

        // 2. Toggle "Command history" OFF
        await tester.tap(find.byKey(const ValueKey('command_history_switch')));
        await tester.pumpAndSettle();

        expect(commandHistoryService.isEnabled, isFalse);

        // Attempt to log a command while logging is disabled
        await commandHistoryService.addCommand(
          id: 'cmd-stealth',
          commandText: 'stealth command',
          success: true,
          timestamp: DateTime.now(),
        );
        await tester.pumpAndSettle();

        // Verify history length did NOT increase
        expect(commandHistoryService.history.length, equals(2));
        expect(commandHistoryService.history.any((c) => c.commandText == 'stealth command'), isFalse);

        // 3. Clear command history action
        await tester.tap(find.byKey(const ValueKey('clear_command_history_btn')));
        await tester.pumpAndSettle();

        // Verify history is completely wiped
        expect(commandHistoryService.history.isEmpty, isTrue);
        expect(find.text('Command history cleared'), findsOneWidget);
        expect(find.textContaining('0 stored commands'), findsOneWidget);
      },
    );

    testWidgets(
      '5. Appearance section supports live Black/White theme toggle & About section shows metadata',
      (WidgetTester tester) async {
        await tester.pumpWidget(createTestApp());
        await tester.pump(const Duration(milliseconds: 650));
        await tester.pumpAndSettle();

        // Navigate to Settings
        await tester.tap(find.byKey(const ValueKey('nav_settings')));
        await tester.pumpAndSettle();

        // Scroll down to reveal Appearance and About sections
        await tester.drag(find.byKey(const ValueKey('settings_list_view')), const Offset(0, -400));
        await tester.pumpAndSettle();

        // 1. Appearance section
        expect(find.text('APPEARANCE'), findsOneWidget);
        expect(find.byKey(const ValueKey('appearance_section')), findsOneWidget);
        expect(find.text('White theme'), findsOneWidget);
        expect(find.byKey(const ValueKey('theme_mode_switch')), findsOneWidget);
        expect(find.byKey(const ValueKey('theme_black_btn')), findsOneWidget);
        expect(find.byKey(const ValueKey('theme_white_btn')), findsOneWidget);

        // Initially in dark mode
        expect(settingsService.themeMode, equals(AppThemeMode.dark));

        // Toggle to Light mode via switch
        await tester.tap(find.byKey(const ValueKey('theme_mode_switch')));
        await tester.pumpAndSettle();
        expect(settingsService.themeMode, equals(AppThemeMode.light));

        // Toggle back to Dark mode via segment button
        await tester.tap(find.byKey(const ValueKey('theme_black_btn')));
        await tester.pumpAndSettle();
        expect(settingsService.themeMode, equals(AppThemeMode.dark));

        // Toggle to Light mode via segment button
        await tester.tap(find.byKey(const ValueKey('theme_white_btn')));
        await tester.pumpAndSettle();
        expect(settingsService.themeMode, equals(AppThemeMode.light));

        // 2. About section
        expect(find.text('ABOUT'), findsOneWidget);
        expect(find.byKey(const ValueKey('about_section')), findsOneWidget);
        expect(find.text('APPLICATION'), findsOneWidget);
        expect(find.text('Windows Remote'), findsOneWidget);

        // App version matches pubspec (1.0.0+1)
        expect(find.byKey(const ValueKey('about_app_version')), findsOneWidget);
        expect(find.text('1.0.0+1'), findsOneWidget);

        // Protocol version matches BridgeConfig (1.0)
        expect(find.byKey(const ValueKey('about_protocol_version')), findsOneWidget);
        expect(find.text('1.0'), findsOneWidget);

        // Scroll down further to ensure bottom About items are fully in view
        await tester.drag(find.byKey(const ValueKey('settings_list_view')), const Offset(0, -150));
        await tester.pumpAndSettle();

        // Client mode interactive toggle
        expect(find.byKey(const ValueKey('settings_client_mode_toggle')), findsOneWidget);
        expect(find.text('MOCK'), findsOneWidget);

        // Tap to change mode to DEV
        await tester.tap(find.byKey(const ValueKey('settings_client_mode_toggle')));
        await tester.pumpAndSettle();
        expect(find.text('DEV'), findsOneWidget);
      },
    );
  });
}
