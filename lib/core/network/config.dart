import '../constants/app_constants.dart';

/// Operating mode for the Windows Bridge client.
enum BridgeMode {
  dev,
  production,
  mock;

  /// Parses a string into a [BridgeMode].
  static BridgeMode fromString(String value) {
    return BridgeMode.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => BridgeMode.mock,
    );
  }

  /// Serializes [BridgeMode] to string.
  String toJson() => name;
}

/// Configuration settings for connecting to a Windows Bridge host.
/// Zero hard-coded host/port/token values — loaded from user input, discovery, or config provider.
class BridgeConfig {
  final String host;
  final int port;
  final int? wsPort;
  final String protocolVersion;
  final BridgeMode mode;
  final bool useTls;

  const BridgeConfig({
    required this.host,
    required this.port,
    this.wsPort,
    this.protocolVersion = AppConstants.protocolVersion,
    this.mode = BridgeMode.mock,
    this.useTls = false,
  });

  /// Factory constructor to deserialize [BridgeConfig] from JSON map.
  factory BridgeConfig.fromJson(Map<String, dynamic> json) {
    final httpPort =
        (json['port'] as num?)?.toInt() ?? AppConstants.defaultHttpPort;
    final wsPort =
        (json['wsPort'] as num? ?? json['ws_port'] as num?)?.toInt();
    return BridgeConfig(
      host: json['host'] as String? ?? '127.0.0.1',
      port: httpPort,
      wsPort: wsPort,
      protocolVersion:
          json['protocolVersion'] as String? ?? AppConstants.protocolVersion,
      mode: BridgeMode.fromString(json['mode'] as String? ?? 'mock'),
      useTls: json['useTls'] as bool? ?? false,
    );
  }

  /// Serializes [BridgeConfig] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'host': host,
      'port': port,
      if (wsPort != null) 'wsPort': wsPort,
      'protocolVersion': protocolVersion,
      'mode': mode.toJson(),
      'useTls': useTls,
    };
  }

  /// Resolved WebSocket port matching canonical protocol (7891 when HTTP is 7890).
  int get effectiveWsPort =>
      wsPort ??
      (port == AppConstants.defaultHttpPort
          ? AppConstants.defaultWebSocketPort
          : port);

  /// HTTP scheme base url.
  String get httpBaseUrl =>
      '${useTls ? "https" : "http"}://$host:$port';

  /// WebSocket scheme base url.
  String get wsBaseUrl =>
      '${useTls ? "wss" : "ws"}://$host:$effectiveWsPort/ws';

  /// Convenience copyWith method.
  BridgeConfig copyWith({
    String? host,
    int? port,
    int? wsPort,
    String? protocolVersion,
    BridgeMode? mode,
    bool? useTls,
  }) {
    return BridgeConfig(
      host: host ?? this.host,
      port: port ?? this.port,
      wsPort: wsPort ?? this.wsPort,
      protocolVersion: protocolVersion ?? this.protocolVersion,
      mode: mode ?? this.mode,
      useTls: useTls ?? this.useTls,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BridgeConfig &&
          runtimeType == other.runtimeType &&
          host == other.host &&
          port == other.port &&
          wsPort == other.wsPort &&
          protocolVersion == other.protocolVersion &&
          mode == other.mode &&
          useTls == other.useTls;

  @override
  int get hashCode =>
      host.hashCode ^
      port.hashCode ^
      wsPort.hashCode ^
      protocolVersion.hashCode ^
      mode.hashCode ^
      useTls.hashCode;

  @override
  String toString() =>
      'BridgeConfig(host: $host, port: $port, wsPort: $effectiveWsPort, mode: $mode, tls: $useTls)';
}
