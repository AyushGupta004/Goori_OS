/// Strongly typed failure reasons for bridge connection and pairing operations.
enum BridgeFailure {
  unreachable,
  wrongPin,
  expiredPin,
  versionMismatch,
  serverError,
  unknown;

  static BridgeFailure? fromString(String? val) {
    if (val == null) return null;
    final lower = val.toLowerCase();
    if (lower.contains('unreachable') || lower.contains('not_found') || lower.contains('refused')) {
      return BridgeFailure.unreachable;
    }
    if (lower.contains('wrong_pin') || lower.contains('invalid_pairing_code') || lower.contains('invalid_code')) {
      return BridgeFailure.wrongPin;
    }
    if (lower.contains('expired')) {
      return BridgeFailure.expiredPin;
    }
    if (lower.contains('version') || lower.contains('incompatible')) {
      return BridgeFailure.versionMismatch;
    }
    if (lower.contains('server_error') || lower.contains('500') || lower.contains('502')) {
      return BridgeFailure.serverError;
    }
    return BridgeFailure.unknown;
  }
}

/// Response payload returned by the Windows Bridge during device pairing.
class PairingResponse {
  final bool success;
  final String deviceId;
  final String? sessionToken;
  final String? refreshToken;
  final DateTime? expiresAt;
  final String? errorMessage;
  final String protocolVersion;
  final BridgeFailure? failure;

  const PairingResponse({
    required this.success,
    required this.deviceId,
    this.sessionToken,
    this.refreshToken,
    this.expiresAt,
    this.errorMessage,
    required this.protocolVersion,
    this.failure,
  });

  /// Factory constructor to deserialize [PairingResponse] from JSON map.
  factory PairingResponse.fromJson(Map<String, dynamic> json) {
    final failureStr = json['failure'] as String? ?? json['failure_code'] as String?;
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
      failure: BridgeFailure.fromString(failureStr),
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
      if (failure != null) 'failure': failure!.name,
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
    BridgeFailure? failure,
  }) {
    return PairingResponse(
      success: success ?? this.success,
      deviceId: deviceId ?? this.deviceId,
      sessionToken: sessionToken ?? this.sessionToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
      errorMessage: errorMessage ?? this.errorMessage,
      protocolVersion: protocolVersion ?? this.protocolVersion,
      failure: failure ?? this.failure,
    );
  }

  @override
  String toString() =>
      'PairingResponse(success: $success, deviceId: $deviceId, error: $errorMessage, failure: $failure)';
}
