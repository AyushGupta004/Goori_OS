import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

/// Secure storage service using [FlutterSecureStorage] for sensitive credentials and connection info.
///
/// HARD CONSTRAINT:
/// Auth tokens are strictly stored here in encrypted storage.
/// Never stored in SharedPreferences, never written to log files.
class SecureStorageService {
  static const String _keyToken = AppConstants.secureAuthTokenKey;
  static const String _keyDeviceId = AppConstants.secureDeviceIdKey;
  static const String _keyDeviceName = 'win_bridge_device_name';
  static const String _keyHost = 'win_bridge_host';
  static const String _keyPort = 'win_bridge_port';

  final FlutterSecureStorage _storage;

  /// Optional in-memory store for headless unit testing without platform channels.
  final Map<String, String>? _memoryFallback;

  SecureStorageService({
    FlutterSecureStorage? storage,
    bool useMemoryOnly = false,
  })  : _memoryFallback = useMemoryOnly ? <String, String>{} : null,
        _storage = storage ?? const FlutterSecureStorage();

  // ---------------------------------------------------------------------------
  // Token Operations (Encrypted)
  // ---------------------------------------------------------------------------

  /// Persists authentication token securely.
  Future<void> saveToken(String token) async {
    final memory = _memoryFallback;
    if (memory != null) {
      memory[_keyToken] = token;
      return;
    }
    await _storage.write(key: _keyToken, value: token);
  }

  /// Retrieves stored authentication token.
  Future<String?> getToken() async {
    final memory = _memoryFallback;
    if (memory != null) {
      return memory[_keyToken];
    }
    return await _storage.read(key: _keyToken);
  }

  /// Deletes stored authentication token.
  Future<void> deleteToken() async {
    final memory = _memoryFallback;
    if (memory != null) {
      memory.remove(_keyToken);
      return;
    }
    await _storage.delete(key: _keyToken);
  }

  // ---------------------------------------------------------------------------
  // Device & Connection Info
  // ---------------------------------------------------------------------------

  /// Persists paired device ID.
  Future<void> saveDeviceId(String deviceId) async {
    final memory = _memoryFallback;
    if (memory != null) {
      memory[_keyDeviceId] = deviceId;
      return;
    }
    await _storage.write(key: _keyDeviceId, value: deviceId);
  }

  /// Retrieves paired device ID.
  Future<String?> getDeviceId() async {
    final memory = _memoryFallback;
    if (memory != null) {
      return memory[_keyDeviceId];
    }
    return await _storage.read(key: _keyDeviceId);
  }

  /// Persists paired device display name.
  Future<void> saveDeviceName(String deviceName) async {
    final memory = _memoryFallback;
    if (memory != null) {
      memory[_keyDeviceName] = deviceName;
      return;
    }
    await _storage.write(key: _keyDeviceName, value: deviceName);
  }

  /// Retrieves paired device display name.
  Future<String?> getDeviceName() async {
    final memory = _memoryFallback;
    if (memory != null) {
      return memory[_keyDeviceName];
    }
    return await _storage.read(key: _keyDeviceName);
  }

  /// Persists bridge host IP/hostname.
  Future<void> saveHost(String host) async {
    final memory = _memoryFallback;
    if (memory != null) {
      memory[_keyHost] = host;
      return;
    }
    await _storage.write(key: _keyHost, value: host);
  }

  /// Retrieves bridge host IP/hostname.
  Future<String?> getHost() async {
    final memory = _memoryFallback;
    if (memory != null) {
      return memory[_keyHost];
    }
    return await _storage.read(key: _keyHost);
  }

  /// Persists bridge port.
  Future<void> savePort(int port) async {
    final memory = _memoryFallback;
    if (memory != null) {
      memory[_keyPort] = port.toString();
      return;
    }
    await _storage.write(key: _keyPort, value: port.toString());
  }

  /// Retrieves bridge port.
  Future<int?> getPort() async {
    final memory = _memoryFallback;
    String? raw;
    if (memory != null) {
      raw = memory[_keyPort];
    } else {
      raw = await _storage.read(key: _keyPort);
    }
    if (raw != null) {
      return int.tryParse(raw);
    }
    return null;
  }

  /// Convenience method to save full connection tuple in one call.
  Future<void> saveConnectionInfo({
    required String host,
    required int port,
    required String deviceId,
    String? deviceName,
    required String token,
  }) async {
    await saveHost(host);
    await savePort(port);
    await saveDeviceId(deviceId);
    if (deviceName != null) {
      await saveDeviceName(deviceName);
    }
    await saveToken(token);
  }

  /// Clears all stored credentials and connection info.
  Future<void> clearAll() async {
    final memory = _memoryFallback;
    if (memory != null) {
      memory.clear();
      return;
    }
    await _storage.deleteAll();
  }
}
