import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bridge_client_factory.dart';
import 'config.dart';
import 'windows_bridge_client.dart';

/// Provider managing active [BridgeConfig] and lifecycle of the active [WindowsBridgeClient].
class BridgeConfigProvider extends ChangeNotifier {
  static const String _prefHostKey = 'bridge_cfg_host';
  static const String _prefPortKey = 'bridge_cfg_port';
  static const String _prefModeKey = 'bridge_cfg_mode';
  static const String _prefTlsKey = 'bridge_cfg_tls';

  BridgeConfig _config;
  WindowsBridgeClient _activeClient;

  BridgeConfigProvider({
    BridgeConfig? initialConfig,
    WindowsBridgeClient? client,
  })  : _config = initialConfig ??
            const BridgeConfig(
              host: '127.0.0.1',
              port: 7890,
              mode: BridgeMode.mock,
            ),
        _activeClient = client ??
            BridgeClientFactory.createClient(
              initialConfig ??
                  const BridgeConfig(
                    host: '127.0.0.1',
                    port: 7890,
                    mode: BridgeMode.mock,
                  ),
            );

  /// Current active configuration.
  BridgeConfig get config => _config;

  /// Current active bridge client instance (Mock or Real based on config).
  WindowsBridgeClient get client => _activeClient;

  /// Loads persisted configuration from [SharedPreferences] if available.
  Future<void> loadSavedConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final host = prefs.getString(_prefHostKey);
      final port = prefs.getInt(_prefPortKey);
      final modeStr = prefs.getString(_prefModeKey);
      final useTls = prefs.getBool(_prefTlsKey);

      if (host != null && port != null) {
        final loadedConfig = BridgeConfig(
          host: host,
          port: port,
          mode: modeStr != null ? BridgeMode.fromString(modeStr) : _config.mode,
          useTls: useTls ?? _config.useTls,
        );
        updateConfig(loadedConfig, persist: false);
      }
    } catch (_) {
      // In tests or headless environments, keep in-memory config
    }
  }

  /// Updates active configuration, cleanly tears down previous client,
  /// and instantiates a new [WindowsBridgeClient] via [BridgeClientFactory].
  Future<void> updateConfig(BridgeConfig newConfig, {bool persist = true}) async {
    if (_config == newConfig) return;

    // Disconnect old client before swapping
    try {
      await _activeClient.disconnect();
    } catch (_) {}

    _config = newConfig;
    _activeClient = BridgeClientFactory.createClient(_config);

    if (persist) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefHostKey, _config.host);
        await prefs.setInt(_prefPortKey, _config.port);
        await prefs.setString(_prefModeKey, _config.mode.toJson());
        await prefs.setBool(_prefTlsKey, _config.useTls);
      } catch (_) {}
    }

    notifyListeners();
  }
}
