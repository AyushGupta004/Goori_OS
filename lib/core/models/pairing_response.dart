/// Response payload returned by the Windows Bridge during device pairing.
class PairingResponse {
  final bool success;
  final String deviceId;
  final String? sessionToken;
  final String? refreshToken;
  final DateTime? expiresAt;
  final String? errorMessage;
  final String protocolVersion;

  const PairingResponse({
    required this.success,
    required this.deviceId,
    this.sessionToken,
    this.refreshToken,
    this.expiresAt,
    this.errorMessage,
    required this.protocolVersion,
  });

  /// Factory constructor to deserialize [PairingResponse] from JSON map.
  factory PairingResponse.fromJson(Map<String, dynamic> json) {
    return PairingResponse(
      success: json['success'] as bool? ?? false,
      deviceId: json['deviceId'] as String? ?? json['device_id'] as String? ?? '',
      sessionToken:
          json['sessionToken'] as String? ?? json['session_token'] as String?,
      refreshToken:
          json['refreshToken'] as String? ?? json['refresh_token'] as String?,
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'] as String)
          : (json['expires_at'] != null
              ? DateTime.tryParse(json['expires_at'] as String)
              : null),
      errorMessage:
          json['errorMessage'] as String? ?? json['error'] as String?,
      protocolVersion: json['protocolVersion'] as String? ??
          json['protocol_version'] as String? ??
          '1.0',
    );
  }

  /// Serializes [PairingResponse] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'deviceId': deviceId,
      if (sessionToken != null) 'sessionToken': sessionToken,
      if (refreshToken != null) 'refreshToken': refreshToken,
      if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
      if (errorMessage != null) 'errorMessage': errorMessage,
      'protocolVersion': protocolVersion,
    };
  }

  /// Creates a copy of [PairingResponse] with modified fields.
  PairingResponse copyWith({
    bool? success,
    String? deviceId,
    String? sessionToken,
    String? refreshToken,
    DateTime? expiresAt,
    String? errorMessage,
    String? protocolVersion,
  }) {
    return PairingResponse(
      success: success ?? this.success,
      deviceId: deviceId ?? this.deviceId,
      sessionToken: sessionToken ?? this.sessionToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
      errorMessage: errorMessage ?? this.errorMessage,
      protocolVersion: protocolVersion ?? this.protocolVersion,
    );
  }

  @override
  String toString() =>
      'PairingResponse(success: $success, deviceId: $deviceId, error: $errorMessage)';
}
