import 'package:http/http.dart' as http;

import 'config.dart';
import 'mock_windows_bridge_client.dart';
import 'real_windows_bridge_client.dart';
import 'windows_bridge_client.dart';

/// Factory responsible for instantiating the appropriate [WindowsBridgeClient]
/// according to the runtime [BridgeMode] defined in [BridgeConfig].
class BridgeClientFactory {
  BridgeClientFactory._();

  /// Creates and returns either [MockWindowsBridgeClient] or [RealWindowsBridgeClient]
  /// based entirely on [config.mode].
  ///
  /// Consumers interact solely with the abstract [WindowsBridgeClient] interface.
  static WindowsBridgeClient createClient(
    BridgeConfig config, {
    http.Client? httpClient,
  }) {
    switch (config.mode) {
      case BridgeMode.mock:
        return MockWindowsBridgeClient();
      case BridgeMode.dev:
      case BridgeMode.production:
        return RealWindowsBridgeClient(httpClient: httpClient);
    }
  }
}
