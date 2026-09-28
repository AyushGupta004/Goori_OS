/// Represents an authenticated, paired Windows PC saved in SecureStorage.
class PairedDevice {
  final String host;
  final int port;
  final String deviceId;
  final String deviceName;
  final String token;
  final DateTime? pairedAt;
  DateTime? get pairedSince => pairedAt;

  const PairedDevice({
    required this.host,
    required this.port,
    required this.deviceId,
    required this.deviceName,
    required this.token,
    DateTime? pairedAt,
    DateTime? pairedSince,
  }) : pairedAt = pairedAt ?? pairedSince;

  /// Factory constructor from JSON map.
  factory PairedDevice.fromJson(Map<String, dynamic> json) {
    return PairedDevice(
      host: json['host'] as String,
      port: (json['port'] as num).toInt(),
      deviceId: json['deviceId'] as String? ?? json['device_id'] as String? ?? '',
      deviceName: json['deviceName'] as String? ?? json['device_name'] as String? ?? 'Windows PC',
      token: json['token'] as String? ?? '',
      pairedAt: json['pairedAt'] != null
          ? DateTime.tryParse(json['pairedAt'] as String)
          : null,
    );
  }

  /// Serializes [PairedDevice] to JSON map.
  Map<String, dynamic> toJson() {
    return {
      'host': host,
      'port': port,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'token': token,
      if (pairedAt != null) 'pairedAt': pairedAt!.toIso8601String(),
    };
  }

  /// Formatted "Paired since" string for display.
  String get formattedPairedSince {
    if (pairedAt == null) return 'Active';
    final dt = pairedAt!.toLocal();
    final year = dt.year;
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PairedDevice &&
          runtimeType == other.runtimeType &&
          host == other.host &&
          port == other.port &&
          deviceId == other.deviceId;

  @override
  int get hashCode => host.hashCode ^ port.hashCode ^ deviceId.hashCode;

  @override
  String toString() =>
      'PairedDevice(name: $deviceName, host: $host:$port, id: $deviceId)';
}
