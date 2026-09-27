/// Result payload received from Windows Bridge after a command is processed.
class CommandResult {
  final String commandId;
  final bool success;
  final String status; // e.g. "executed" | "failed" | "processing"
  final String message;
  final DateTime timestamp;
  final int? executionTimeMs;
  final String? errorDetails;

  const CommandResult({
    required this.commandId,
    required this.success,
    required this.status,
    required this.message,
    required this.timestamp,
    this.executionTimeMs,
    this.errorDetails,
  });

  /// Factory constructor to deserialize [CommandResult] from JSON map.
  factory CommandResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final timestampVal = json['timestamp'];
    final DateTime ts;
    if (timestampVal is int) {
      ts = DateTime.fromMillisecondsSinceEpoch(timestampVal);
    } else if (timestampVal is String) {
      ts = DateTime.tryParse(timestampVal) ?? DateTime.now();
    } else {
      ts = DateTime.now();
    }

    final success =
        json['success'] as bool? ?? (data['status'] == 'completed');
    final executionMs = (data['execution_time_ms'] as num? ??
            data['executionTimeMs'] as num? ??
            json['execution_time_ms'] as num? ??
            json['executionTimeMs'] as num?)
        ?.toInt();

    return CommandResult(
      commandId: json['request_id'] as String? ??
          json['commandId'] as String? ??
          data['commandId'] as String? ??
          '',
      success: success,
      status: data['status'] as String? ??
          json['status'] as String? ??
          (success ? 'completed' : 'failed'),
      message:
          data['message'] as String? ?? json['message'] as String? ?? '',
      timestamp: ts,
      executionTimeMs: executionMs,
      errorDetails: data['error'] as String? ??
          data['errorDetails'] as String? ??
          json['error'] as String? ??
          json['errorDetails'] as String?,
    );
  }

  /// Serializes [CommandResult] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'commandId': commandId,
      'success': success,
      'status': status,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      if (executionTimeMs != null) 'executionTimeMs': executionTimeMs,
      if (errorDetails != null) 'errorDetails': errorDetails,
    };
  }

  @override
  String toString() =>
      'CommandResult(id: $commandId, success: $success, status: $status, msg: $message)';
}
