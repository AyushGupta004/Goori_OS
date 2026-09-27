import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goori_os/app/app.dart';
import 'package:goori_os/core/network/network.dart';
import 'package:goori_os/core/services/services.dart';
import 'package:goori_os/core/storage/secure_storage_service.dart';
import 'package:goori_os/features/files/services/file_picker_service.dart';
import 'package:goori_os/features/photos/services/image_picker_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Task 9: Photo Transfer Flow End-to-End Widget Tests', () {
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
    late PhotoTransferService photoTransferService;
    late MockFilePickerService mockFilePickerService;
    late MockImagePickerService mockImagePickerService;

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
      photoTransferService = PhotoTransferService(client: mockClient);
      mockFilePickerService = MockFilePickerService();
      mockImagePickerService = MockImagePickerService();

      // Establish connected bridge state
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
        photoTransferService: photoTransferService,
        filePickerService: mockFilePickerService,
        imagePickerService: mockImagePickerService,
      );
    }

    testWidgets(
      '1. Initial state: permissions NOT requested on load, empty state shown, rationale appears on tap if denied',
      (WidgetTester tester) async {
        mockImagePickerService.setCameraPermissionGranted(false);
        mockImagePickerService.setPhotosPermissionGranted(false);

        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        // Navigate to PHOTOS tab in bottom nav
        await tester.tap(find.byKey(const ValueKey('nav_photos')));
        await tester.pumpAndSettle();

        // 1. Verify title and source buttons rendered
        expect(find.text('PHOTO TRANSMIT'), findsOneWidget);
        expect(find.byKey(const ValueKey('camera_btn')), findsOneWidget);
        expect(find.byKey(const ValueKey('gallery_btn')), findsOneWidget);

        // 2. Empty state card is shown
        expect(find.byKey(const ValueKey('empty_photos_card')), findsOneWidget);
        expect(find.text('NO PHOTOS STAGED'), findsOneWidget);

        // 3. Permissions were NOT requested on screen load
        expect(mockImagePickerService.wasCameraPermissionRequested, isFalse);
        expect(mockImagePickerService.wasPhotosPermissionRequested, isFalse);
        expect(find.byKey(const ValueKey('photo_permission_rationale_card')), findsNothing);

        // 4. Tap Camera button while permission is denied -> rationale appears
        await tester.tap(find.byKey(const ValueKey('camera_btn')));
        await tester.pumpAndSettle();

        expect(mockImagePickerService.wasCameraPermissionRequested, isTrue);
        expect(find.byKey(const ValueKey('photo_permission_rationale_card')), findsOneWidget);
        expect(
          find.text('Camera permission is required to capture photos for transfer to your Windows PC.'),
          findsOneWidget,
        );

        // 5. Tap Gallery button while permission is denied -> rationale updates
        await tester.tap(find.byKey(const ValueKey('gallery_btn')));
        await tester.pumpAndSettle();

        expect(mockImagePickerService.wasPhotosPermissionRequested, isTrue);
        expect(
          find.text('Photos permission is required to select photos for transfer to your Windows PC.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '2. Single camera capture and gallery multi-selection add thumbnails to grid with WAITING status',
      (WidgetTester tester) async {
        mockImagePickerService.setCameraPermissionGranted(true);
        mockImagePickerService.setPhotosPermissionGranted(true);

        mockImagePickerService.setStagedCameraPhoto(File('captured_camera_desk.jpg'));
        mockImagePickerService.setStagedGalleryPhotos([
          File('gallery_vacation_1.jpg'),
          File('gallery_vacation_2.jpg'),
        ]);

        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        // Navigate to PHOTOS
        await tester.tap(find.byKey(const ValueKey('nav_photos')));
        await tester.pumpAndSettle();

        // 1. Single capture from Camera
        await tester.tap(find.byKey(const ValueKey('camera_btn')));
        await tester.pump(const Duration(milliseconds: 20));

        expect(find.text('captured_camera_desk.jpg'), findsOneWidget);
        expect(find.text('1 TOTAL'), findsOneWidget);

        // 2. Multi-select from Gallery
        await tester.tap(find.byKey(const ValueKey('gallery_btn')));
        await tester.pump(const Duration(milliseconds: 20));

        expect(find.text('gallery_vacation_1.jpg'), findsOneWidget);
        expect(find.text('gallery_vacation_2.jpg'), findsOneWidget);
        expect(find.text('3 TOTAL'), findsOneWidget);

        // All 3 thumbnails are initially in WAITING state
        expect(find.text('WAITING'), findsNWidgets(3));

        // [SEND TO PC] button is now visible
        expect(find.byKey(const ValueKey('send_to_pc_btn')), findsOneWidget);
        expect(find.text('SEND TO PC (3)'), findsOneWidget);
      },
    );

    testWidgets(
      '3. Remove (✕) affordance removes individual photo from the thumbnail grid',
      (WidgetTester tester) async {
        mockImagePickerService.setCameraPermissionGranted(true);
        mockImagePickerService.setStagedCameraPhoto(File('photo_to_keep.jpg'));
        mockImagePickerService.setStagedGalleryPhotos([
          File('photo_to_delete.jpg'),
        ]);

        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        // Navigate to PHOTOS
        await tester.tap(find.byKey(const ValueKey('nav_photos')));
        await tester.pumpAndSettle();

        // Add both photos
        await tester.tap(find.byKey(const ValueKey('camera_btn')));
        await tester.pump(const Duration(milliseconds: 20));

        await tester.tap(find.byKey(const ValueKey('gallery_btn')));
        await tester.pump(const Duration(milliseconds: 20));

        expect(find.text('photo_to_keep.jpg'), findsOneWidget);
        expect(find.text('photo_to_delete.jpg'), findsOneWidget);
        expect(find.text('2 TOTAL'), findsOneWidget);

        // Find remove button for photo_to_delete
        final deletePhotoItem = photoTransferService.photos
            .firstWhere((p) => p.fileName == 'photo_to_delete.jpg');
        final removeBtn = find.byKey(ValueKey('remove_photo_btn_${deletePhotoItem.id}'));
        expect(removeBtn, findsOneWidget);

        // Tap remove (✕)
        await tester.tap(removeBtn);
        await tester.pumpAndSettle();

        // Verify photo_to_delete is removed and photo_to_keep remains
        expect(find.text('photo_to_delete.jpg'), findsNothing);
        expect(find.text('photo_to_keep.jpg'), findsOneWidget);
        expect(find.text('1 TOTAL'), findsOneWidget);
        expect(find.text('SEND TO PC (1)'), findsOneWidget);
      },
    );

    testWidgets(
      '4. [SEND TO PC] triggers batch streaming with live progress and completed states',
      (WidgetTester tester) async {
        mockImagePickerService.setCameraPermissionGranted(true);
        mockImagePickerService.setPhotosPermissionGranted(true);
        mockImagePickerService.setStagedGalleryPhotos([
          File('nature_sunset.jpg'),
          File('mountain_peak.jpg'),
        ]);

        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        // Navigate to PHOTOS
        await tester.tap(find.byKey(const ValueKey('nav_photos')));
        await tester.pumpAndSettle();

        // Stage 2 photos from gallery
        await tester.tap(find.byKey(const ValueKey('gallery_btn')));
        await tester.pump(const Duration(milliseconds: 20));

        expect(find.text('nature_sunset.jpg'), findsOneWidget);
        expect(find.text('mountain_peak.jpg'), findsOneWidget);

        // Tap [SEND TO PC]
        await tester.tap(find.byKey(const ValueKey('send_to_pc_btn')));
        await tester.pump(const Duration(milliseconds: 20));

        // Advance through simulated stream steps (4 steps of 80ms per photo)
        // First photo uploading -> completes
        await tester.pump(const Duration(milliseconds: 90));
        await tester.pump(const Duration(milliseconds: 90));
        await tester.pump(const Duration(milliseconds: 90));
        await tester.pump(const Duration(milliseconds: 90));
        await tester.pump(const Duration(milliseconds: 90));

        // Second photo uploading -> completes
        await tester.pump(const Duration(milliseconds: 90));
        await tester.pump(const Duration(milliseconds: 90));
        await tester.pump(const Duration(milliseconds: 90));
        await tester.pump(const Duration(milliseconds: 90));
        await tester.pump(const Duration(milliseconds: 90));
        await tester.pumpAndSettle();

        // Both photos reach ✓ COMPLETED state
        expect(find.text('✓ COMPLETED'), findsNWidgets(2));
      },
    );

    testWidgets(
      '5. Simulated failure case displays ✕ FAILED inline on thumbnail and clear completed resets',
      (WidgetTester tester) async {
        mockImagePickerService.setPhotosPermissionGranted(true);
        // Filename containing 'fail' triggers simulated failure in MockWindowsBridgeClient
        mockImagePickerService.setStagedGalleryPhotos([
          File('corrupted_upload_fail.jpg'),
          File('successful_photo.jpg'),
        ]);

        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        // Navigate to PHOTOS
        await tester.tap(find.byKey(const ValueKey('nav_photos')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('gallery_btn')));
        await tester.pump(const Duration(milliseconds: 20));

        // Start batch upload
        await tester.tap(find.byKey(const ValueKey('send_to_pc_btn')));
        await tester.pump(const Duration(milliseconds: 20));

        // Step through stream (first photo fails at ~160ms, second photo completes ~320ms)
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();

        // First photo displays ✕ FAILED, second displays ✓ COMPLETED
        expect(find.text('✕ FAILED'), findsOneWidget);
        expect(find.text('✓ COMPLETED'), findsOneWidget);

        // CLEAR button is visible in AppBar
        expect(find.byKey(const ValueKey('clear_completed_photos_btn')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('clear_completed_photos_btn')));
        await tester.pumpAndSettle();

        // Completed and failed photos cleared -> returns to empty state
        expect(find.byKey(const ValueKey('empty_photos_card')), findsOneWidget);
        expect(find.text('NO PHOTOS STAGED'), findsOneWidget);
      },
    );
  });
}
