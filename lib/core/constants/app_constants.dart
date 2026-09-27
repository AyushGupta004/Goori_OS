/// Core constants for Windows Remote application and bridge communication protocol.
class AppConstants {
  AppConstants._();

  /// Protocol version for Windows Bridge communication handshake.
  static const String protocolVersion = '1.0';

  /// Default port for Windows Bridge HTTP API (REST endpoints & file streaming).
  static const int defaultHttpPort = 7890;

  /// Default port for Windows Bridge WebSocket real-time duplex channel.
  static const int defaultWebSocketPort = 7891;

  /// Default mDNS/NSD service discovery type for finding Windows Bridge hosts on LAN.
  static const String mdnsServiceType = '_winbridge._tcp';

  /// Default mDNS service domain.
  static const String mdnsDomain = 'local.';

  /// Application display title.
  static const String appName = 'Windows Remote';

  /// Application version matching pubspec.yaml.
  static const String appVersion = '1.0.0+1';

  /// Storage key for authentication token in flutter_secure_storage.
  static const String secureAuthTokenKey = 'win_bridge_auth_token';

  /// Storage key for active paired device id in flutter_secure_storage.
  static const String secureDeviceIdKey = 'win_bridge_device_id';

  /// File transfer buffer chunk size (64 KB) for streaming uploads without RAM spikes.
  static const int fileChunkSizeBytes = 64 * 1024;
}

/// Status lifecycle for streamed file and photo transfers.
enum TransferStatus {
  waiting,
  uploading,
  completed,
  failed,
  cancelled;

  /// Converts a serialized JSON string to [TransferStatus].
  static TransferStatus fromString(String value) {
    return TransferStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => TransferStatus.failed,
    );
  }

  /// Serializes [TransferStatus] to a string.
  String toJson() => name;
}
