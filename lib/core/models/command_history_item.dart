/// Persistent local record of an executed command.
class CommandHistoryItem {
  final String id;
  final String commandText;
  final bool success;
  final DateTime timestamp;
  final String status;
  final String? errorDetails;

  const CommandHistoryItem({
    required this.id,
    required this.commandText,
    required this.success,
    required this.timestamp,
    required this.status,
    this.errorDetails,
  });

  /// Factory constructor to deserialize [CommandHistoryItem] from JSON map.
  factory CommandHistoryItem.fromJson(Map<String, dynamic> json) {
    return CommandHistoryItem(
      id: json['id'] as String? ?? '',
      commandText: json['commandText'] as String? ?? '',
      success: json['success'] as bool? ?? false,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      status: json['status'] as String? ?? 'unknown',
      errorDetails: json['errorDetails'] as String?,
    );
  }

  /// Serializes [CommandHistoryItem] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'commandText': commandText,
      'success': success,
      'timestamp': timestamp.toIso8601String(),
      'status': status,
      if (errorDetails != null) 'errorDetails': errorDetails,
    };
  }

  @override
  String toString() =>
      'CommandHistoryItem(id: $id, text: "$commandText", success: $success, time: $timestamp)';
}
