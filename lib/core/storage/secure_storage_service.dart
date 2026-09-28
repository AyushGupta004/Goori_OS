import 'dart:io';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';
import '../models/models.dart';

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
  static const String _keyClientId = 'win_bridge_client_id';
  static const String _keyPairedAt = 'win_bridge_paired_at';

  final FlutterSecureStorage _storage;
  final bool _useMemoryOnly;
  final Map<String, String> _memoryFallback;

  SecureStorageService({
    FlutterSecureStorage? storage,
    bool? useMemoryOnly,
  })  : _useMemoryOnly = useMemoryOnly ?? Platform.environment.containsKey('FLUTTER_TEST'),
        _memoryFallback = <String, String>{},
        _storage = storage ?? const FlutterSecureStorage();

  Future<String?> _readKey(String key) async {
    if (_useMemoryOnly) return _memoryFallback[key];
    try {
      final val = await _storage
          .read(key: key)
          .timeout(const Duration(milliseconds: 100));
      if (val != null) _memoryFallback[key] = val;
      return val ?? _memoryFallback[key];
    } catch (_) {
      return _memoryFallback[key];
    }
  }

  Future<void> _writeKey(String key, String value) async {
    _memoryFallback[key] = value;
    if (_useMemoryOnly) return;
    try {
      await _storage
          .write(key: key, value: value)
          .timeout(const Duration(milliseconds: 100));
    } catch (_) {}
  }

  Future<void> _deleteKey(String key) async {
    _memoryFallback.remove(key);
    if (_useMemoryOnly) return;
    try {
      await _storage
          .delete(key: key)
          .timeout(const Duration(milliseconds: 100));
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Token Operations (Encrypted)
  // ---------------------------------------------------------------------------

  /// Persists authentication token securely.
  Future<void> saveToken(String token) => _writeKey(_keyToken, token);

  /// Retrieves stored authentication token.
  Future<String?> getToken() => _readKey(_keyToken);

  /// Deletes stored authentication token.
  Future<void> deleteToken() => _deleteKey(_keyToken);

  // ---------------------------------------------------------------------------
  // Device & Connection Info
  // ---------------------------------------------------------------------------

  /// Persists paired device ID.
  Future<void> saveDeviceId(String deviceId) => _writeKey(_keyDeviceId, deviceId);

  /// Retrieves paired device ID.
  Future<String?> getDeviceId() => _readKey(_keyDeviceId);

  /// Persists paired device display name.
  Future<void> saveDeviceName(String deviceName) =>
      _writeKey(_keyDeviceName, deviceName);

  /// Retrieves paired device display name.
  Future<String?> getDeviceName() => _readKey(_keyDeviceName);

  /// Persists bridge host IP/hostname.
  Future<void> saveHost(String host) => _writeKey(_keyHost, host);

  /// Retrieves bridge host IP/hostname.
  Future<String?> getHost() => _readKey(_keyHost);

  /// Persists bridge port.
  Future<void> savePort(int port) => _writeKey(_keyPort, port.toString());

  /// Retrieves bridge port.
  Future<int?> getPort() async {
    final str = await _readKey(_keyPort);
    if (str == null) return null;
    return int.tryParse(str);
  }

  /// Persists pairedAt ISO-8601 timestamp string.
  Future<void> savePairedSince(DateTime timestamp) =>
      _writeKey(_keyPairedAt, timestamp.toIso8601String());

  /// Retrieves pairedAt timestamp.
  Future<DateTime?> getPairedSince() async {
    final str = await _readKey(_keyPairedAt);
    if (str == null || str.isEmpty) return null;
    try {
      return DateTime.parse(str);
    } catch (_) {
      return null;
    }
  }

  /// Helper to aggregate paired device information.
  Future<PairedDevice?> getPairedDevice() async {
    final host = await getHost();
    final port = await getPort();
    final token = await getToken();
    final deviceId = await getDeviceId();
    final deviceName = await getDeviceName();
    final pairedAt = await getPairedSince();

    if (host == null || host.isEmpty || token == null || token.isEmpty) {
      return null;
    }

    return PairedDevice(
      host: host,
      port: port ?? 7890,
      deviceId: deviceId ?? 'unknown',
      deviceName: deviceName ?? 'Windows PC',
      token: token,
      pairedSince: pairedAt,
    );
  }

  /// Convenience batch saver for successful pairing / startup flow.
  Future<void> saveConnectionInfo({
    required String host,
    required int port,
    required String deviceId,
    String? deviceName,
    required String token,
    DateTime? pairedSince,
  }) async {
    await saveHost(host);
    await savePort(port);
    await saveDeviceId(deviceId);
    if (deviceName != null) {
      await saveDeviceName(deviceName);
    }
    await saveToken(token);
    await savePairedSince(pairedSince ?? DateTime.now());
  }

  // ---------------------------------------------------------------------------
  // Client ID Operations (Stable UUID)
  // ---------------------------------------------------------------------------

  /// Retrieves or generates a stable RFC4122 v4 UUID clientId.
  Future<String> getOrCreateClientId() async {
    final existing = await _readKey(_keyClientId);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final newId = _generateUuidV4();
    await _writeKey(_keyClientId, newId);
    return newId;
  }

  /// Retrieves clientId if already generated.
  Future<String?> getClientId() => _readKey(_keyClientId);

  /// Saves clientId explicitly.
  Future<void> saveClientId(String clientId) => _writeKey(_keyClientId, clientId);

  static String _generateUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // Version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // Variant 10xxxxxx
    final hexChars =
        bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).toList();
    return '${hexChars.sublist(0, 4).join()}-${hexChars.sublist(4, 6).join()}-${hexChars.sublist(6, 8).join()}-${hexChars.sublist(8, 10).join()}-${hexChars.sublist(10, 16).join()}';
  }

  // ---------------------------------------------------------------------------
  // Teardown / Unpair
  // ---------------------------------------------------------------------------

  /// Purges all stored credentials (token, device info, connection parameters),
  /// while preserving client ID for re-pairing continuity.
  Future<void> clearAll() async {
    final clientId = _memoryFallback[_keyClientId];
    _memoryFallback.clear();
    if (clientId != null) {
      _memoryFallback[_keyClientId] = clientId;
    }

    if (_useMemoryOnly) return;

    try {
      await _storage.delete(key: _keyToken);
      await _storage.delete(key: _keyDeviceId);
      await _storage.delete(key: _keyDeviceName);
      await _storage.delete(key: _keyHost);
      await _storage.delete(key: _keyPort);
      await _storage.delete(key: _keyPairedAt);
    } catch (_) {}
  }
}
