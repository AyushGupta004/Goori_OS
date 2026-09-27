/// Strongly typed domain error returned or thrown during Windows Bridge interactions.
class BridgeError implements Exception {
  final String code;
  final String message;
  final String? details;
  final DateTime timestamp;

  const BridgeError({
    required this.code,
    required this.message,
    this.details,
    required this.timestamp,
  });

  /// Factory constructor to deserialize [BridgeError] from JSON map.
  factory BridgeError.fromJson(Map<String, dynamic> json) {
    return BridgeError(
      code: json['code'] as String? ?? 'UNKNOWN_ERROR',
      message: json['message'] as String? ?? 'An unexpected bridge error occurred.',
      details: json['details'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }

  /// Serializes [BridgeError] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'message': message,
      if (details != null) 'details': details,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  String toString() =>
      'BridgeError(code: $code, message: $message, details: $details)';
}
