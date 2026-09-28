import 'package:flutter/foundation.dart';

import '../errors/app_errors.dart';
import '../models/models.dart';
import '../network/config.dart';
import '../network/windows_bridge_client.dart';
import '../storage/secure_storage_service.dart';

/// Service orchestrating the cryptographic pairing PIN exchange and secure token storage.
class PairingService extends ChangeNotifier {
  final WindowsBridgeClient client;
  final SecureStorageService secureStorage;

  bool _isPairing = false;
  String? _errorMessage;
  PairingResponse? _lastResponse;
  HealthResult? _lastHealthResult;
  bool _liveConnectionFailed = false;

  PairingService({
    required this.client,
    required this.secureStorage,
  });

  bool get isPairing => _isPairing;
  String? get errorMessage => _errorMessage;
  PairingResponse? get lastResponse => _lastResponse;
  HealthResult? get lastHealthResult => _lastHealthResult;
  bool get liveConnectionFailed => _liveConnectionFailed;

  /// Executes pairing against [device] using the 6-digit one-time [pinCode].
  ///
  /// Conforms strictly to Task 1 order:
  /// configure(config) -> health probe -> POST /pair -> save credentials -> THEN connect WebSocket + authenticate.
  Future<PairingResponse> pairDevice({
    required WindowsDevice device,
    required String pinCode,
    BridgeMode mode = BridgeMode.dev,
  }) async {
    _isPairing = true;
    _errorMessage = null;
    _liveConnectionFailed = false;
    notifyListeners();

    try {
      // 1. configure(config)
      final config = BridgeConfig(
        host: device.host,
        port: device.port,
        mode: mode,
      );
      client.configure(config);

      // 2. health probe
      final health = await client.checkHealth();
      _lastHealthResult = health;
      if (!health.ok) {
        _isPairing = false;
        final failure = (health.kind == HealthResultKind.versionMismatch)
            ? BridgeFailure.versionMismatch
            : (health.kind == HealthResultKind.serverError)
                ? BridgeFailure.serverError
                : BridgeFailure.unreachable;
        final errorResponse = PairingResponse(
          success: false,
          deviceId: health.deviceId ?? '',
          failure: failure,
          errorMessage: health.details ?? health.friendlyHeadline,
          protocolVersion: health.protocolVersion ?? '1.0',
        );
        _errorMessage = errorResponse.errorMessage;
        _lastResponse = errorResponse;
        notifyListeners();
        return errorResponse;
      }

      // 3. POST /pair (over HTTP only) with stable clientId
      final clientId = await secureStorage.getOrCreateClientId();
      final response = await client.pair(pinCode, clientId: clientId);
      _lastResponse = response;

      if (response.success && response.sessionToken != null) {
        // 4. Save credentials into SecureStorage
        await secureStorage.saveConnectionInfo(
          host: device.host,
          port: device.port,
          deviceId: response.deviceId,
          deviceName: device.name,
          token: response.sessionToken!,
        );
        _errorMessage = null;

        // 5. THEN connect WebSocket + authenticate
        try {
          await client.connect(config);
          final auth = await client.authenticate(response.sessionToken!);
          if (!auth.authenticated) {
            _liveConnectionFailed = true;
            _errorMessage = 'Paired, but the live connection failed';
          }
        } catch (wsError) {
          debugPrint(
            '[PairingService] WebSocket connection failed after pairing: $wsError',
          );
          // Keep credentials! Never clear token and never call this "Can't reach your PC"
          _liveConnectionFailed = true;
          _errorMessage = 'Paired, but the live connection failed';
        }
      } else {
        _errorMessage = response.errorMessage != null
            ? AppErrorMapper.map(response.errorMessage, host: device.host)
            : AppErrorMapper.mapFailure(
                response.failure ?? BridgeFailure.wrongPin,
                host: device.host,
              );
      }

      _isPairing = false;
      notifyListeners();
      return response;
    } catch (e) {
      debugPrint('[PairingService] pairDevice exception: $e');
      final errorResponse = PairingResponse(
        success: false,
        deviceId: '',
        failure: BridgeFailure.unreachable,
        errorMessage: AppErrorMapper.map(e, host: device.host),
        protocolVersion: '1.0',
      );
      _errorMessage = errorResponse.errorMessage;
      _lastResponse = errorResponse;
      _isPairing = false;
      notifyListeners();
      return errorResponse;
    }
  }

  /// Retries the live WebSocket connection using previously saved credentials.
  Future<bool> retryLiveConnection({
    required WindowsDevice device,
    BridgeMode mode = BridgeMode.dev,
  }) async {
    _isPairing = true;
    notifyListeners();

    try {
      final config = BridgeConfig(
        host: device.host,
        port: device.port,
        mode: mode,
      );
      client.configure(config);

      final token = await secureStorage.getToken();
      if (token == null || token.isEmpty) {
        _isPairing = false;
        _errorMessage = 'No saved session token found. Please re-pair.';
        notifyListeners();
        return false;
      }

      await client.connect(config);
      final auth = await client.authenticate(token);
      if (auth.authenticated) {
        _liveConnectionFailed = false;
        _errorMessage = null;
        _isPairing = false;
        notifyListeners();
        return true;
      } else {
        _liveConnectionFailed = true;
        _errorMessage = 'Paired, but the live connection failed';
        _isPairing = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _liveConnectionFailed = true;
      _errorMessage = 'Paired, but the live connection failed';
      _isPairing = false;
      notifyListeners();
      return false;
    }
  }

  void reset() {
    _isPairing = false;
    _errorMessage = null;
    _lastResponse = null;
    _lastHealthResult = null;
    _liveConnectionFailed = false;
    notifyListeners();
  }

}
