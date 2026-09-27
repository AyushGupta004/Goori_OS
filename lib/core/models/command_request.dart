/// Outgoing command payload sent to Windows Bridge for automation execution.
class CommandRequest {
  final String commandId;
  final String type; // e.g. "text" | "voice_transcript"
  final String payload;
  final DateTime timestamp;
  final Map<String, String>? metadata;

  const CommandRequest({
    required this.commandId,
    required this.type,
    required this.payload,
    required this.timestamp,
    this.metadata,
  });

  /// Factory constructor to deserialize [CommandRequest] from JSON map.
  factory CommandRequest.fromJson(Map<String, dynamic> json) {
    return CommandRequest(
      commandId: json['commandId'] as String,
      type: json['type'] as String? ?? 'text',
      payload: json['payload'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      metadata: (json['metadata'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
    );
  }

  /// Serializes [CommandRequest] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'commandId': commandId,
      'type': type,
      'payload': payload,
      'timestamp': timestamp.toIso8601String(),
      if (metadata != null) 'metadata': metadata,
    };
  }

  @override
  String toString() =>
      'CommandRequest(id: $commandId, type: $type, payload: $payload)';
}
