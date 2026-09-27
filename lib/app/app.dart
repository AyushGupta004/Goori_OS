import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../core/network/bridge_config_provider.dart';
import '../core/network/config.dart';
import '../core/services/services.dart';
import '../core/storage/secure_storage_service.dart';
import '../features/files/services/file_picker_service.dart';
import '../features/photos/services/image_picker_service.dart';
import '../features/voice/services/speech_recognition_service.dart';
import 'routes.dart';
import 'theme.dart';

/// Root Application Widget configuring dependency injection, dark theme, and routes.
class WindowsRemoteApp extends StatelessWidget {
  final BridgeConfigProvider? configProvider;
  final SecureStorageService? secureStorage;
  final DiscoveryService? discoveryService;
  final PairingService? pairingService;
  final AuthenticationService? authService;
  final ConnectionService? connectionService;
  final CommandService? commandService;
  final CommandHistoryService? commandHistoryService;
  final SettingsService? settingsService;
  final SpeechRecognitionService? speechRecognitionService;
  final FilePickerService? filePickerService;
  final FileTransferService? fileTransferService;
  final ImagePickerService? imagePickerService;
  final PhotoTransferService? photoTransferService;
  final NetworkConnectivityService? connectivityService;

  const WindowsRemoteApp({
    super.key,
    this.configProvider,
    this.secureStorage,
    this.discoveryService,
    this.pairingService,
    this.authService,
    this.connectionService,
    this.commandService,
    this.commandHistoryService,
    this.settingsService,
    this.speechRecognitionService,
    this.filePickerService,
    this.fileTransferService,
    this.imagePickerService,
    this.photoTransferService,
    this.connectivityService,
  });

  @override
  Widget build(BuildContext context) {
    // If external providers are already supplied in widget tests, use them;
    // otherwise construct standard production hierarchy.
    final localConfigProvider = configProvider ?? BridgeConfigProvider();
    final localSecureStorage = secureStorage ?? SecureStorageService();
    final localDiscoveryService = discoveryService ?? DiscoveryService();
    final localHistoryService =
        commandHistoryService ?? CommandHistoryService();
    final localSettingsService = settingsService ?? SettingsService();
    final localConnectivityService = connectivityService ??
        (localConfigProvider.config.mode == BridgeMode.mock
            ? MockNetworkConnectivityService()
            : RealNetworkConnectivityService());
    final localSpeechService = speechRecognitionService ??
        (localConfigProvider.config.mode == BridgeMode.mock
            ? MockSpeechRecognitionService()
            : NativeSpeechRecognitionService());
    final localFilePickerService = filePickerService ??
        (localConfigProvider.config.mode == BridgeMode.mock
            ? MockFilePickerService()
            : NativeFilePickerService());
    final localImagePickerService = imagePickerService ??
        (localConfigProvider.config.mode == BridgeMode.mock
            ? MockImagePickerService()
            : NativeImagePickerService());

    final localPairingService = pairingService ??
        PairingService(
          client: localConfigProvider.client,
          secureStorage: localSecureStorage,
        );

    final localAuthService = authService ??
        AuthenticationService(
          client: localConfigProvider.client,
          secureStorage: localSecureStorage,
        );

    final localConnectionService = connectionService ??
        ConnectionService(
          client: localConfigProvider.client,
          secureStorage: localSecureStorage,
          discoveryService: localDiscoveryService,
          pairingService: localPairingService,
          authService: localAuthService,
          connectivityService: localConnectivityService,
        );

    final localCommandService = commandService ??
        CommandService(
          client: localConfigProvider.client,
          historyService: localHistoryService,
        );

    final localFileService = fileTransferService ??
        FileTransferService(client: localConfigProvider.client);

    final localPhotoService = photoTransferService ??
        PhotoTransferService(client: localConfigProvider.client);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<BridgeConfigProvider>.value(
          value: localConfigProvider,
        ),
        Provider<SecureStorageService>.value(
          value: localSecureStorage,
        ),
        Provider<NetworkConnectivityService>.value(
          value: localConnectivityService,
        ),
        ChangeNotifierProvider<DiscoveryService>.value(
          value: localDiscoveryService,
        ),
        ChangeNotifierProvider<PairingService>.value(
          value: localPairingService,
        ),
        ChangeNotifierProvider<AuthenticationService>.value(
          value: localAuthService,
        ),
        ChangeNotifierProvider<ConnectionService>.value(
          value: localConnectionService,
        ),
        ChangeNotifierProvider<CommandHistoryService>.value(
          value: localHistoryService,
        ),
        ChangeNotifierProvider<SettingsService>.value(
          value: localSettingsService,
        ),
        ChangeNotifierProvider<SpeechRecognitionService>.value(
          value: localSpeechService,
        ),
        ChangeNotifierProvider<FilePickerService>.value(
          value: localFilePickerService,
        ),
        ChangeNotifierProvider<ImagePickerService>.value(
          value: localImagePickerService,
        ),
        ChangeNotifierProvider<CommandService>.value(
          value: localCommandService,
        ),
        ChangeNotifierProvider<FileTransferService>.value(
          value: localFileService,
        ),
        ChangeNotifierProvider<PhotoTransferService>.value(
          value: localPhotoService,
        ),
      ],
      child: Consumer<SettingsService>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: settings.themeMode == AppThemeMode.light
                ? ThemeMode.light
                : ThemeMode.dark,
            initialRoute: AppRoutes.home,
            routes: AppRoutes.routes,
            onGenerateRoute: AppRoutes.onGenerateRoute,
          );
        },
      ),
    );
  }
}
