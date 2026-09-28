import 'dart:async';
import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import '../errors/app_errors.dart';
import '../models/models.dart';
import '../network/config.dart';
import '../network/windows_bridge_client.dart';
import '../network/mock_windows_bridge_client.dart';
import '../storage/secure_storage_service.dart';
import 'authentication_service.dart';
import 'discovery_service.dart';
import 'network_connectivity_service.dart';
import 'pairing_service.dart';

/// Outcome of the single orchestrated startup flow.
enum StartupFlowResult {
  /// Token validated and bridge session is actively connected.
  connected,

  /// Device identified or found, but valid pairing PIN / token is required.
  pairingRequired,

  /// No bridge devices were found on the local network.
  deviceNotFound,

  /// Connection attempt to target bridge failed.
  connectionFailed,
}

/// Central connection orchestration service managing discovery, pairing,
/// authentication, automatic resilience/reconnect with exponential backoff,
/// and network change lifecycles.
class ConnectionService extends ChangeNotifier {
  final WindowsBridgeClient client;
  final SecureStorageService secureStorage;
  final DiscoveryService discoveryService;
  final PairingService pairingService;
  final AuthenticationService authService;
  final NetworkConnectivityService? connectivityService;

  WindowsDevice? _activeDevice;
  bool _isOrchestrating = false;
  String? _errorMessage;
  StreamSubscription<ConnectionState>? _connectionStateSub;
  StreamSubscription<NetworkChangeEvent>? _networkChangeSub;

  final StreamController<ConnectionState> _connectionStateController =
      StreamController<ConnectionState>.broadcast();

  // Exponential backoff reconnect state
  int _currentBackoffSeconds = 1;
  static const int _maxBackoffSeconds = 16;
  Timer? _reconnectTimer;
  bool _isReconnecting = false;
  bool _isManualDisconnect = false;

  ConnectionService({
    required this.client,
    required this.secureStorage,
    required this.discoveryService,
    required this.pairingService,
    required this.authService,
    this.connectivityService,
  }) {
    _connectionStateSub =
        client.connectionState.listen(_handleConnectionStateChange);

    if (connectivityService != null) {
      _networkChangeSub =
          connectivityService!.onNetworkChanged.listen(_handleNetworkChange);
    }
  }

  /// Stream of connection lifecycle events emitted throughout connection/auth.
  Stream<ConnectionState> get connectionState =>
      _connectionStateController.stream;

  /// Instantaneous connection state.
  ConnectionState get currentState => client.currentConnectionState;

  /// True if client is connected and active session is authenticated.
  bool get isAuthenticated {
    if (!currentState.isConnected) return false;
    if (client is MockWindowsBridgeClient) {
      return authService.lastResponse?.authenticated ?? true;
    }
    return authService.isAuthenticated;
  }

  /// Currently active or target Windows device.
  WindowsDevice? get activeDevice => _activeDevice;

  /// True if startup orchestration is actively running.
  bool get isOrchestrating => _isOrchestrating;

  /// True if automatic reconnect is in progress.
  bool get isReconnecting => _isReconnecting;

  /// Current exponential backoff interval in seconds.
  int get currentBackoffSeconds => _currentBackoffSeconds;

  /// Last error message, if any (mapped to centralized user-facing copy).
  String? get errorMessage => _errorMessage;

  void _handleConnectionStateChange(ConnectionState state) {
    _connectionStateController.add(state);

    // If WebSocket dropped unexpectedly mid-session
    if (state == ConnectionState.disconnected &&
        !_isManualDisconnect &&
        _activeDevice != null &&
        !_isReconnecting &&
        !_isOrchestrating &&
        _errorMessage != AppErrors.versionMismatch &&
        _errorMessage != AppErrors.tokenExpired) {
      _scheduleAutomaticReconnect();
    }

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // 1. Exponential Backoff Automatic Reconnect
  // ---------------------------------------------------------------------------

  void _scheduleAutomaticReconnect() {
    _reconnectTimer?.cancel();
    if (_isManualDisconnect || _activeDevice == null) return;
    if (_errorMessage == AppErrors.versionMismatch ||
        _errorMessage == AppErrors.tokenExpired) {
      return;
    }

    _isReconnecting = true;
    _errorMessage = AppErrors.connectionLost;
    notifyListeners();

    debugPrint(
      '[ConnectionService] WebSocket dropped. Scheduling auto-reconnect in ${_currentBackoffSeconds}s (max: ${_maxBackoffSeconds}s)...',
    );

    _reconnectTimer =
        Timer(Duration(seconds: _currentBackoffSeconds), () async {
      await _executeReconnectAttempt();
    });
  }

  Future<void> _executeReconnectAttempt() async {
    debugPrint('[ConnectionService] _executeReconnectAttempt started with backoff: $_currentBackoffSeconds');
    if (_isManualDisconnect) return;

    final token = await secureStorage.getToken();
    final host = await secureStorage.getHost() ?? _activeDevice?.host;
    final port = await secureStorage.getPort() ??
        _activeDevice?.port ??
        AppConstants.defaultHttpPort;

    if (token == null || token.isEmpty || host == null || host.isEmpty) {
      _resetBackoff();
      return;
    }

    _isReconnecting = true;
    notifyListeners();

    try {
      final config = BridgeConfig(host: host, port: port);
      client.configure(config);
      await client.connect(config);

      // Authenticate with stored token
      final authResp = await authService.authenticate(token);

      // Protocol version validation
      if (authResp.protocolVersion != config.protocolVersion) {
        debugPrint(
          '[ConnectionService] Protocol version mismatch on reconnect: ${authResp.protocolVersion} vs expected ${config.protocolVersion}',
        );
        _isReconnecting = false;
        _errorMessage = AppErrors.versionMismatch;
        _resetBackoff();
        _isManualDisconnect = true;
        await client.disconnect();
        _isManualDisconnect = false;
        notifyListeners();
        return;
      }

      if (authResp.authenticated) {
        debugPrint('[ConnectionService] Auto-reconnect and re-auth succeeded.');
        _resetBackoff();
        _isReconnecting = false;
        _errorMessage = null;
        notifyListeners();
      } else {
        // Token was rejected or expired -> do not retry
        debugPrint(
          '[ConnectionService] Auto-reconnect auth rejected token: ${authResp.errorMessage}',
        );
        _resetBackoff();
        _isReconnecting = false;
        _isManualDisconnect = true;
        await secureStorage.deleteToken();
        _errorMessage = AppErrors.tokenExpired;
        await client.disconnect();
        _isManualDisconnect = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint(
        '[ConnectionService] Auto-reconnect failed ($e). Increasing backoff.',
      );
      _isReconnecting = false;
      // Exponential backoff capped at _maxBackoffSeconds (1s, 2s, 4s, 8s, 16s)
      _currentBackoffSeconds =
          (_currentBackoffSeconds * 2).clamp(1, _maxBackoffSeconds);
      _scheduleAutomaticReconnect();
    }
  }

  void _resetBackoff() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _currentBackoffSeconds = 1;
    _isReconnecting = false;
  }

  // ---------------------------------------------------------------------------
  // 2. Network Connectivity Change Handling
  // ---------------------------------------------------------------------------

  Future<void> _handleNetworkChange(NetworkChangeEvent event) async {
    debugPrint('[ConnectionService] Network connectivity changed: $event');
    if (_activeDevice == null && (await secureStorage.getToken()) == null) {
      return;
    }

    // Trigger resilience sequence: disconnect -> rediscover -> reconnect -> authenticate
    await triggerNetworkTransitionReconnect(
      mode: client is MockWindowsBridgeClient ? BridgeMode.mock : BridgeMode.dev,
    );
  }

  /// Triggers full resilience sequence on network change:
  /// disconnect -> rediscover -> reconnect -> authenticate
  Future<StartupFlowResult> triggerNetworkTransitionReconnect({
    BridgeMode mode = BridgeMode.dev,
    Duration discoveryTimeout = const Duration(seconds: 3),
  }) async {
    _isOrchestrating = true;
    _isReconnecting = true;
    _errorMessage = null;
    _resetBackoff();
    notifyListeners();

    try {
      // Step 1: Disconnect cleanly from old route
      try {
        await client.disconnect();
      } catch (_) {}

      // Step 2: Rediscover Windows bridge on the new network
      await discoveryService.startDiscovery(
        mode: mode,
        timeout: discoveryTimeout,
      );

      String? targetHost;
      int? targetPort;

      if (discoveryService.discoveredDevices.isNotEmpty) {
        final discovered = discoveryService.discoveredDevices.first;
        targetHost = discovered.host;
        targetPort = discovered.port;
        _activeDevice = discovered;
      } else {
        targetHost = await secureStorage.getHost();
        targetPort = await secureStorage.getPort();
      }

      if (targetHost == null || targetHost.isEmpty) {
        _isOrchestrating = false;
        _isReconnecting = false;
        _errorMessage = AppErrors.windowsNotFound;
        notifyListeners();
        return StartupFlowResult.deviceNotFound;
      }

      // Step 3: Reconnect to newly discovered or stored host
      final config = BridgeConfig(
        host: targetHost,
        port: targetPort ?? AppConstants.defaultHttpPort,
        mode: mode,
      );
      client.configure(config);
      await client.connect(config);

      // Step 4: Authenticate with stored token
      final token = await secureStorage.getToken();
      if (token == null || token.isEmpty) {
        _isOrchestrating = false;
        _isReconnecting = false;
        notifyListeners();
        return StartupFlowResult.pairingRequired;
      }

      final authResp = await authService.authenticate(token);

      // Protocol version validation
      if (authResp.protocolVersion != config.protocolVersion) {
        _isOrchestrating = false;
        _isReconnecting = false;
        _errorMessage = AppErrors.versionMismatch;
        await client.disconnect();
        notifyListeners();
        return StartupFlowResult.connectionFailed;
      }

      _isOrchestrating = false;
      _isReconnecting = false;

      if (authResp.authenticated) {
        _errorMessage = null;
        _resetBackoff();
        notifyListeners();
        return StartupFlowResult.connected;
      } else {
        await secureStorage.deleteToken();
        _errorMessage = AppErrors.tokenExpired;
        notifyListeners();
        return StartupFlowResult.pairingRequired;
      }
    } catch (e) {
      debugPrint('[ConnectionService] triggerNetworkTransitionReconnect error: $e');
      _isOrchestrating = false;
      _isReconnecting = false;
      _errorMessage = AppErrorMapper.map(e);
      notifyListeners();
      return StartupFlowResult.connectionFailed;
    }
  }

  // ---------------------------------------------------------------------------
  // Single Orchestrated Startup Flow
  // ---------------------------------------------------------------------------

  /// Executes the unified startup flow:
  /// 1. discover (check stored host or scan network)
  /// 2. check stored token in secure storage
  /// 3. if none -> return [StartupFlowResult.pairingRequired]
  /// 4. if exists -> connect -> authenticate -> return [StartupFlowResult.connected]
  ///
  /// Emits [ConnectionState] changes throughout for the UI to observe.
  Future<StartupFlowResult> runStartupFlow({
    BridgeMode mode = BridgeMode.dev,
    Duration discoveryTimeout = const Duration(seconds: 3),
  }) async {
    _isManualDisconnect = false;
    _resetBackoff();
    _isOrchestrating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Step 0: Delete any stored token starting with "mock_" whenever mode is not mock
      if (mode != BridgeMode.mock) {
        final existingToken = await secureStorage.getToken();
        if (existingToken != null && existingToken.startsWith('mock_')) {
          debugPrint(
            '[ConnectionService] Purged stale mock token ($existingToken) in non-mock mode',
          );
          await secureStorage.deleteToken();
        }
      }

      // Step 1: Discover / Identify Target Host
      String? targetHost = await secureStorage.getHost();
      int? targetPort = await secureStorage.getPort();

      if (targetHost == null || targetHost.isEmpty) {
        await discoveryService.startDiscovery(
          mode: mode,
          timeout: discoveryTimeout,
        );

        if (discoveryService.discoveredDevices.isEmpty) {
          _isOrchestrating = false;
          _errorMessage = AppErrors.windowsNotFound;
          notifyListeners();
          return StartupFlowResult.deviceNotFound;
        }

        final discovered = discoveryService.discoveredDevices.first;
        targetHost = discovered.host;
        targetPort = discovered.port;
        _activeDevice = discovered;
      } else {
        final deviceId = await secureStorage.getDeviceId() ?? 'known_host';
        final deviceName =
            await secureStorage.getDeviceName() ?? 'Windows Host';
        _activeDevice = WindowsDevice(
          id: deviceId,
          name: deviceName,
          host: targetHost,
          port: targetPort ?? AppConstants.defaultHttpPort,
          isPaired: true,
        );
      }

      // Always configure client host/port before attempting sockets or authentication
      final config = BridgeConfig(
        host: targetHost,
        port: targetPort ?? AppConstants.defaultHttpPort,
        mode: mode,
      );
      client.configure(config);

      // Step 2: Check Stored Token
      final token = await secureStorage.getToken();
      if (token == null || token.isEmpty) {
        _isOrchestrating = false;
        notifyListeners();
        return StartupFlowResult.pairingRequired;
      }

      // Step 3: Preflight GET /health before WebSocket connection
      final isHealthy = await client.checkHealth();
      if (!isHealthy) {
        debugPrint(
          '[ConnectionService] Preflight health check failed for $targetHost:${config.port}',
        );
        _isOrchestrating = false;
        _errorMessage = AppErrorMapper.mapFailure(
          BridgeFailure.unreachable,
          host: targetHost,
        );
        notifyListeners();
        return StartupFlowResult.connectionFailed;
      }

      // Step 4: Connect WebSocket (5s timeout)
      await client.connect(config);

      // Step 5: Authenticate
      final authResp = await authService.authenticate(token);
      _isOrchestrating = false;

      // Protocol version validation
      if (authResp.protocolVersion != config.protocolVersion) {
        _isOrchestrating = false;
        _errorMessage = AppErrors.versionMismatch;
        _isManualDisconnect = true;
        await client.disconnect();
        _isManualDisconnect = false;
        notifyListeners();
        return StartupFlowResult.connectionFailed;
      }

      if (authResp.authenticated) {
        _errorMessage = null;
        _resetBackoff();
        notifyListeners();
        return StartupFlowResult.connected;
      } else {
        // Stored token was invalid or expired: clear all stored credentials and request re-pairing
        await secureStorage.clearAll();
        _errorMessage = AppErrors.tokenExpired;
        _isManualDisconnect = true;
        await client.disconnect();
        _isManualDisconnect = false;
        notifyListeners();
        return StartupFlowResult.pairingRequired;
      }
    } catch (e) {
      debugPrint('[ConnectionService] runStartupFlow exception: $e');
      _isOrchestrating = false;
      _errorMessage = AppErrorMapper.map(e, host: _activeDevice?.host);
      notifyListeners();
      return StartupFlowResult.connectionFailed;
    }
  }

  /// Explicitly initiates pairing for [device] using [pinCode].
  Future<PairingResponse> pair(
    WindowsDevice device,
    String pinCode, {
    BridgeMode mode = BridgeMode.dev,
  }) async {
    _activeDevice = device;
    _isManualDisconnect = false;
    final config = BridgeConfig(
      host: device.host,
      port: device.port,
      mode: mode,
    );
    client.configure(config);

    final result = await pairingService.pairDevice(
      device: device,
      pinCode: pinCode,
      mode: mode,
    );
    if (result.success) {
      _activeDevice = device.copyWith(isPaired: true);
      _errorMessage = null;
    } else {
      _errorMessage = AppErrorMapper.map(
        result.errorMessage ?? AppErrors.pairingFailed,
        host: device.host,
      );
    }
    notifyListeners();
    return result;
  }

  /// Disconnects from current bridge host and resets session.
  Future<void> disconnect() async {
    _isManualDisconnect = true;
    _resetBackoff();
    await client.disconnect();
    notifyListeners();
  }

  /// Attempts silent re-authentication on app launch when a token already exists.
  Future<StartupFlowResult> silentReauthenticate({
    BridgeMode mode = BridgeMode.dev,
  }) async {
    final token = await secureStorage.getToken();
    if (token == null || token.isEmpty) {
      return StartupFlowResult.pairingRequired;
    }
    return runStartupFlow(mode: mode);
  }

  /// Unpairs active device: cleanly disconnects client, purges all stored credentials,
  /// tokens, and connection metadata from [SecureStorageService], and resets active device session.
  Future<void> unpair() async {
    _isManualDisconnect = true;
    _resetBackoff();
    try {
      await client.disconnect();
    } catch (_) {}
    await secureStorage.clearAll();
    _activeDevice = null;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _resetBackoff();
    _connectionStateSub?.cancel();
    _networkChangeSub?.cancel();
    _connectionStateController.close();
    super.dispose();
  }
}
