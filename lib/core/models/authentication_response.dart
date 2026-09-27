/// Response returned by the Windows Bridge following an authentication handshake.
class AuthenticationResponse {
  final bool authenticated;
  final String deviceId;
  final String serverVersion;
  final String protocolVersion;
  final DateTime? sessionExpiresAt;
  final List<String> permissions;
  final String? errorMessage;

  const AuthenticationResponse({
    required this.authenticated,
    required this.deviceId,
    required this.serverVersion,
    this.protocolVersion = '1.0',
    this.sessionExpiresAt,
    this.permissions = const [],
    this.errorMessage,
  });

  /// Factory constructor to deserialize [AuthenticationResponse] from JSON map.
  factory AuthenticationResponse.fromJson(Map<String, dynamic> json) {
    final sVersion = json['version'] as String? ??
        json['serverVersion'] as String? ??
        '1.0';
    return AuthenticationResponse(
      authenticated: json['success'] as bool? ??
          json['authenticated'] as bool? ??
          false,
      deviceId: json['device_id'] as String? ??
          json['deviceId'] as String? ??
          '',
      serverVersion: sVersion,
      protocolVersion: json['protocol_version'] as String? ??
          json['protocolVersion'] as String? ??
          sVersion,
      sessionExpiresAt: json['sessionExpiresAt'] != null
          ? DateTime.parse(json['sessionExpiresAt'] as String)
          : null,
      permissions: (json['permissions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      errorMessage: json['error'] as String? ?? json['errorMessage'] as String?,
    );
  }

  /// Serializes [AuthenticationResponse] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'authenticated': authenticated,
      'deviceId': deviceId,
      'serverVersion': serverVersion,
      'protocolVersion': protocolVersion,
      if (sessionExpiresAt != null)
        'sessionExpiresAt': sessionExpiresAt!.toIso8601String(),
      'permissions': permissions,
      if (errorMessage != null) 'errorMessage': errorMessage,
    };
  }

  @override
  String toString() =>
      'AuthenticationResponse(authenticated: $authenticated, deviceId: $deviceId, version: $serverVersion, protocol: $protocolVersion)';
}
