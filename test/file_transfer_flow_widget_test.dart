import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goori_os/app/app.dart';
import 'package:goori_os/core/errors/app_errors.dart';
import 'package:goori_os/core/network/network.dart';
import 'package:goori_os/core/services/services.dart';
import 'package:goori_os/core/storage/secure_storage_service.dart';
import 'package:goori_os/features/files/services/file_picker_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Task 8: File Transfer Flow End-to-End Widget Tests', () {
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
    late FileTransferService fileTransferService;
    late MockFilePickerService mockPickerService;

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
      commandService = CommandService(
        client: mockClient,
        historyService: commandHistoryService,
      );
      fileTransferService = FileTransferService(client: mockClient);
      mockPickerService = MockFilePickerService();

      // Establish connected state
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
        fileTransferService: fileTransferService,
        filePickerService: mockPickerService,
      );
    }

    testWidgets(
      '1. FilesScreen initial state: no permission requested on load, shows empty transfers',
      (WidgetTester tester) async {
        mockPickerService.setStoragePermissionGranted(false);

        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        // Navigate to FILES tab via bottom nav
        await tester.tap(find.byKey(const ValueKey('nav_files')));
        await tester.pumpAndSettle();

        // 1. Title and Action Button are rendered
        expect(find.text('FILE STREAM'), findsOneWidget);
        expect(find.byKey(const ValueKey('select_files_btn')), findsOneWidget);
        expect(find.text('Select Files'), findsOneWidget);

        // 2. Empty state is shown initially
        expect(find.byKey(const ValueKey('empty_transfers_card')), findsOneWidget);
        expect(find.text('NO ACTIVE TRANSFERS'), findsOneWidget);

        // 3. Permission rationale is NOT shown on screen load
        expect(
          find.byKey(const ValueKey('storage_permission_rationale_card')),
          findsNothing,
        );

        // 4. Tap "+ Select Files" while permission is denied -> rationale card appears
        await tester.tap(find.byKey(const ValueKey('select_files_btn')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('storage_permission_rationale_card')),
          findsOneWidget,
        );
        expect(
          find.text('Storage permission is required to select and stream files to your Windows PC.'),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('grant_storage_permission_btn')),
          findsOneWidget,
        );

        // 5. Grant permission and tap grant button -> rationale disappears
        mockPickerService.setStoragePermissionGranted(true);
        await tester.tap(find.byKey(const ValueKey('grant_storage_permission_btn')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('storage_permission_rationale_card')),
          findsNothing,
        );
      },
    );

    testWidgets(
      '2. Multi-file selection & simulated upload with live progress bars and completed state',
      (WidgetTester tester) async {
        mockPickerService.setStoragePermissionGranted(true);
        mockPickerService.setStagedFiles([
          File('presentation_notes.pdf'),
          File('dataset_archive.zip'),
        ]);

        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        // Navigate to FILES tab
        await tester.tap(find.byKey(const ValueKey('nav_files')));
        await tester.pumpAndSettle();

        // Tap "+ Select Files"
        await tester.tap(find.byKey(const ValueKey('select_files_btn')));
        await tester.pump(const Duration(milliseconds: 20)); // Queues the files

        // Both files appear in Active Transfers list
        expect(find.text('presentation_notes.pdf'), findsOneWidget);
        expect(find.text('dataset_archive.zip'), findsOneWidget);

        // Step through stream progression (each step ~80ms in MockBridgeClient)
        await tester.pump(const Duration(milliseconds: 90));
        await tester.pump(const Duration(milliseconds: 90));
        await tester.pump(const Duration(milliseconds: 90));
        await tester.pump(const Duration(milliseconds: 90));
        await tester.pump(const Duration(milliseconds: 90));
        await tester.pumpAndSettle();

        // Both files reach completed state with ✓ COMPLETED badges
        expect(find.text('✓ COMPLETED'), findsNWidgets(2));
      },
    );

    testWidgets(
      '3. Support cancel on an in-progress upload',
      (WidgetTester tester) async {
        mockPickerService.setStoragePermissionGranted(true);
        mockPickerService.setStagedFiles([
          File('large_video.mp4'),
        ]);

        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        // Navigate to FILES
        await tester.tap(find.byKey(const ValueKey('nav_files')));
        await tester.pumpAndSettle();

        // Tap "+ Select Files"
        await tester.tap(find.byKey(const ValueKey('select_files_btn')));
        await tester.pump(const Duration(milliseconds: 20)); // Starts upload

        // Verify task appears
        expect(find.text('large_video.mp4'), findsOneWidget);

        // Advance slightly so it enters uploading state
        await tester.pump(const Duration(milliseconds: 85));

        // Find and tap CANCEL button on the transfer
        final cancelBtn = find.text('CANCEL');
        expect(cancelBtn, findsOneWidget);
        await tester.tap(cancelBtn);
        await tester.pump();

        // State changes to CANCELLED
        expect(find.text('CANCELLED'), findsOneWidget);

        // Advance time; verify it remains CANCELLED and does not finish completed
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        expect(find.text('CANCELLED'), findsOneWidget);
        expect(find.text('✓ COMPLETED'), findsNothing);
      },
    );

    testWidgets(
      '4. Simulated failure case displays ✕ FAILED and error message',
      (WidgetTester tester) async {
        mockPickerService.setStoragePermissionGranted(true);
        // Filename containing 'fail' triggers simulated failure in MockWindowsBridgeClient
        mockPickerService.setStagedFiles([
          File('corrupted_upload_fail.bin'),
        ]);

        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        // Navigate to FILES
        await tester.tap(find.byKey(const ValueKey('nav_files')));
        await tester.pumpAndSettle();

        // Tap "+ Select Files"
        await tester.tap(find.byKey(const ValueKey('select_files_btn')));
        await tester.pump(const Duration(milliseconds: 20));

        expect(find.text('corrupted_upload_fail.bin'), findsOneWidget);

        // Advance through failure step (at ~160ms MockWindowsBridgeClient triggers failure)
        await tester.pump(const Duration(milliseconds: 180));
        await tester.pumpAndSettle();

        // Displays ✕ FAILED badge
        expect(find.text('✕ FAILED'), findsOneWidget);
        expect(
          find.text(AppErrors.uploadFailed),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '5. Clear completed transfers resets list to empty state',
      (WidgetTester tester) async {
        mockPickerService.setStoragePermissionGranted(true);
        mockPickerService.setStagedFiles([
          File('completed_file.txt'),
        ]);

        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        // Navigate to FILES
        await tester.tap(find.byKey(const ValueKey('nav_files')));
        await tester.pumpAndSettle();

        // Start & complete upload
        await tester.tap(find.byKey(const ValueKey('select_files_btn')));
        await tester.pump(const Duration(milliseconds: 20));
        expect(find.text('completed_file.txt'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        expect(find.text('✓ COMPLETED'), findsOneWidget);

        // CLEAR action is visible in the AppBar
        expect(find.byKey(const ValueKey('clear_completed_transfers_btn')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('clear_completed_transfers_btn')));
        await tester.pumpAndSettle();

        // Transfers cleared, returns to empty state
        expect(find.byKey(const ValueKey('empty_transfers_card')), findsOneWidget);
        expect(find.text('NO ACTIVE TRANSFERS'), findsOneWidget);
      },
    );
  });
}
