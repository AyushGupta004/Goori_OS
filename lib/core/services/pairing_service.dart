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

  PairingService({
    required this.client,
    required this.secureStorage,
  });

  bool get isPairing => _isPairing;
  String? get errorMessage => _errorMessage;
  PairingResponse? get lastResponse => _lastResponse;

  /// Executes pairing against [device] using the 6-digit one-time [pinCode].
  ///
  /// On successful pairing, persists token and device metadata into [SecureStorageService].
  Future<PairingResponse> pairDevice({
    required WindowsDevice device,
    required String pinCode,
    BridgeMode mode = BridgeMode.dev,
  }) async {
    _isPairing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final config = BridgeConfig(
        host: device.host,
        port: device.port,
        mode: mode,
      );
      client.configure(config);

      // Connect to bridge endpoint if disconnected
      if (!client.currentConnectionState.isConnected) {
        await client.connect(config);
      }

      final response = await client.pair(pinCode);
      _lastResponse = response;

      if (response.success && response.sessionToken != null) {
        // Persist token exclusively into SecureStorage
        await secureStorage.saveConnectionInfo(
          host: device.host,
          port: device.port,
          deviceId: response.deviceId,
          deviceName: device.name,
          token: response.sessionToken!,
        );
        _errorMessage = null;
      } else {
        _errorMessage = response.errorMessage != null
            ? AppErrorMapper.map(response.errorMessage, host: device.host)
            : AppErrorMapper.mapFailure(response.failure ?? BridgeFailure.wrongPin, host: device.host);
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

  void reset() {
    _isPairing = false;
    _errorMessage = null;
    _lastResponse = null;
    notifyListeners();
  }
}
