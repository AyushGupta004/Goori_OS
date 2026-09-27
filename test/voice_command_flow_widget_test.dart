import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goori_os/app/app.dart';
import 'package:goori_os/core/network/network.dart';
import 'package:goori_os/core/services/services.dart';
import 'package:goori_os/core/storage/secure_storage_service.dart';
import 'package:goori_os/features/voice/services/speech_recognition_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Task 7: Voice Command Flow End-to-End Tests', () {
    late MockWindowsBridgeClient mockClient;
    late SecureStorageService secureStorage;
    late BridgeConfigProvider configProvider;
    late DiscoveryService discoveryService;
    late PairingService pairingService;
    late AuthenticationService authService;
    late ConnectionService connectionService;
    late CommandHistoryService commandHistoryService;
    late SettingsService settingsService;
    late CommandService commandService;
    late MockSpeechRecognitionService mockSpeechService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      mockClient = MockWindowsBridgeClient();
      secureStorage = SecureStorageService(useMemoryOnly: true);
      configProvider = BridgeConfigProvider(
        initialConfig: const BridgeConfig(
          host: '127.0.0.1',
          port: 7890,
          mode: BridgeMode.mock,
        ),
      );
      discoveryService = DiscoveryService();
      pairingService = PairingService(client: mockClient, secureStorage: secureStorage);
      authService = AuthenticationService(client: mockClient, secureStorage: secureStorage);
      connectionService = ConnectionService(
        client: mockClient,
        secureStorage: secureStorage,
        discoveryService: discoveryService,
        pairingService: pairingService,
        authService: authService,
      );
      commandHistoryService = CommandHistoryService(prefs: prefs);
      settingsService = SettingsService(prefs: prefs);
      commandService = CommandService(
        client: mockClient,
        historyService: commandHistoryService,
      );
      mockSpeechService = MockSpeechRecognitionService();

      // Establish connected state
      await mockClient.connect(const BridgeConfig(
        host: '127.0.0.1',
        port: 7890,
        mode: BridgeMode.mock,
      ));
    });

    Widget createTestApp({Widget? home}) {
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
        speechRecognitionService: mockSpeechService,
      );
    }

    testWidgets(
      '1. Mic idle state shows "○ MIC / Tap to command" & permission rationale when denied',
      (WidgetTester tester) async {
        mockSpeechService.setPermissionGranted(false);

        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        // Navigate to VoiceScreen via HomeScreen mic button
        await tester.tap(find.byKey(const ValueKey('mic_command_btn')));
        await tester.pumpAndSettle();

        // 1. Initially displays idle indicator
        expect(find.text('○ MIC / Tap to command'), findsOneWidget);
        expect(find.byKey(const ValueKey('voice_idle_indicator')), findsOneWidget);

        // 2. Tap mic without permission -> displays friendly rationale card
        await tester.tap(find.byKey(const ValueKey('voice_mic_btn')));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('mic_permission_rationale_card')), findsOneWidget);
        expect(
          find.text('Microphone access is needed to capture voice commands for your Windows PC.'),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('grant_permission_btn')), findsOneWidget);

        // 3. Grant permission -> rationale disappears and returns to idle
        mockSpeechService.setPermissionGranted(true);
        await tester.tap(find.byKey(const ValueKey('grant_permission_btn')));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('mic_permission_rationale_card')), findsNothing);
        expect(find.text('○ MIC / Tap to command'), findsOneWidget);
      },
    );

    testWidgets(
      '2. Wire speech-to-text: tap -> "● LISTENING..." -> live transcript -> review card with [SEND] / [CANCEL]',
      (WidgetTester tester) async {
        mockSpeechService.setPermissionGranted(true);

        await tester.pumpWidget(
          createTestApp(),
        );
        await tester.pumpAndSettle();

        // Navigate to VoiceScreen via HomeScreen mic button
        await tester.tap(find.byKey(const ValueKey('mic_command_btn')));
        await tester.pumpAndSettle();
        expect(find.text('VOICE TRANSMIT'), findsOneWidget);

        // Tap to start listening
        await tester.tap(find.byKey(const ValueKey('voice_mic_btn')));
        await tester.pump();

        // Shows listening indicator
        expect(find.text('● LISTENING...'), findsOneWidget);

        // Stream partial transcripts
        mockSpeechService.emitPartialTranscript('open cal');
        await tester.pump();
        expect(find.text('open cal'), findsOneWidget);

        mockSpeechService.emitPartialTranscript('open calculator');
        await tester.pump();
        expect(find.text('open calculator'), findsOneWidget);

        // Speech finishes
        mockSpeechService.finishTranscript('open calculator');
        await tester.pumpAndSettle();

        // Shows COMMAND review card
        expect(find.byKey(const ValueKey('command_review_card')), findsOneWidget);
        expect(find.text('open calculator'), findsOneWidget);
        expect(find.byKey(const ValueKey('send_command_btn')), findsOneWidget);
        expect(find.byKey(const ValueKey('cancel_command_btn')), findsOneWidget);

        // Tap [CANCEL] -> discards and returns to idle
        await tester.tap(find.byKey(const ValueKey('cancel_command_btn')));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('command_review_card')), findsNothing);
        expect(find.text('○ MIC / Tap to command'), findsOneWidget);
      },
    );

    testWidgets(
      '3. Settings-driven toggle: auto-send vs confirm-before-send',
      (WidgetTester tester) async {
        mockSpeechService.setPermissionGranted(true);

        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        // 1. Enable Auto-send via SettingsService
        await settingsService.setConfirmBeforeSend(false);
        expect(settingsService.confirmBeforeSend, isFalse);

        // Navigate to voice
        await tester.tap(find.byKey(const ValueKey('mic_command_btn')));
        await tester.pumpAndSettle();

        // Tap mic to start listening
        await tester.tap(find.byKey(const ValueKey('voice_mic_btn')));
        await tester.pump();

        // Finish speech transcript with auto-send enabled
        mockSpeechService.finishTranscript('launch browser');
        await tester.pump();

        // Should NOT show review card; dispatches directly to Windows
        expect(find.byKey(const ValueKey('command_review_card')), findsNothing);

        // Wait for mock bridge execution
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        // Displays success badge
        expect(find.text('✓ Command completed'), findsOneWidget);
      },
    );

    testWidgets(
      '4. Successful command dispatch displays "✓ Command completed" without raw JSON',
      (WidgetTester tester) async {
        mockSpeechService.setPermissionGranted(true);

        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        // Ensure confirm-before-send is active
        await settingsService.setConfirmBeforeSend(true);

        // Open VoiceScreen
        await tester.tap(find.byKey(const ValueKey('mic_command_btn')));
        await tester.pumpAndSettle();

        // Start listening & finalize
        await tester.tap(find.byKey(const ValueKey('voice_mic_btn')));
        await tester.pump();
        mockSpeechService.finishTranscript('take screenshot');
        await tester.pumpAndSettle();

        // Tap [SEND]
        await tester.tap(find.byKey(const ValueKey('send_command_btn')));
        await tester.pump();

        // Transmitting indicator appears
        expect(find.text('TRANSMITTING TO WINDOWS...'), findsOneWidget);

        // Await bridge execution completion
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        // Result displays "✓ Command completed"
        expect(find.byKey(const ValueKey('command_completed_text')), findsOneWidget);
        expect(find.text('✓ Command completed'), findsOneWidget);
        // Verify no raw JSON is rendered
        expect(find.textContaining('{'), findsNothing);
      },
    );

    testWidgets(
      '5. Simulated failure case displays "✕ Command failed" without raw JSON',
      (WidgetTester tester) async {
        mockSpeechService.setPermissionGranted(true);

        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        // Open VoiceScreen
        await tester.tap(find.byKey(const ValueKey('mic_command_btn')));
        await tester.pumpAndSettle();

        // Start listening & emit command containing 'fail' (triggers mock bridge failure)
        await tester.tap(find.byKey(const ValueKey('voice_mic_btn')));
        await tester.pump();
        mockSpeechService.finishTranscript('cause error fail test');
        await tester.pumpAndSettle();

        // Tap [SEND]
        await tester.tap(find.byKey(const ValueKey('send_command_btn')));
        await tester.pump();

        // Await bridge execution
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        // Result displays "✕ Command failed"
        expect(find.byKey(const ValueKey('command_failed_text')), findsOneWidget);
        expect(find.text('✕ Command failed'), findsOneWidget);
        // Verify no raw exception or JSON is shown to user
        expect(find.textContaining('SIMULATED_EXECUTION_FAILURE'), findsNothing);
      },
    );

    testWidgets(
      '6. Local command history persistence and "COMMANDS" screen displays newest first',
      (WidgetTester tester) async {
        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        // 1. Execute two commands via commandService
        final cmd1Future = commandService.sendCommand('first command');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 160));
        await tester.pump(const Duration(milliseconds: 360));
        await cmd1Future;

        final cmd2Future = commandService.sendCommand('fail second command');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 160));
        await tester.pump(const Duration(milliseconds: 360));
        await cmd2Future;
        await tester.pumpAndSettle();

        // 2. Verify Home screen's LAST COMMAND block displays the latest command
        expect(find.byKey(const ValueKey('last_command_block')), findsOneWidget);

        // 3. Tap Home's quick link "COMMANDS"
        await tester.ensureVisible(find.byKey(const ValueKey('quick_link_commands')));
        await tester.tap(find.byKey(const ValueKey('quick_link_commands')));
        await tester.pumpAndSettle();

        // Should be on COMMANDS screen
        expect(find.byKey(const ValueKey('commands_screen')), findsOneWidget);
        expect(find.byKey(const ValueKey('command_history_list')), findsOneWidget);

        // Newest command ("fail second command") is listed first (index 0)
        expect(find.byKey(const ValueKey('command_item_0')), findsOneWidget);
        expect(find.text('fail second command'), findsOneWidget);
        expect(find.text('first command'), findsOneWidget);

        // 4. Test clearing history
        await tester.tap(find.byKey(const ValueKey('clear_history_btn')));
        await tester.pumpAndSettle();

        // Confirm in dialog
        await tester.tap(find.byKey(const ValueKey('confirm_clear_btn')));
        await tester.pumpAndSettle();

        // History is now empty
        expect(find.text('NO COMMANDS RECORDED'), findsOneWidget);
      },
    );
  });
}
