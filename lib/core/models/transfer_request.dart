/// Initiation payload for streaming file or photo transfers to Windows Bridge.
class TransferRequest {
  final String transferId;
  final String fileName;
  final int fileSizeBytes;
  final String mimeType;
  final String transferType; // "file" | "photo"
  final String? sha256Hash;
  final DateTime timestamp;

  const TransferRequest({
    required this.transferId,
    required this.fileName,
    required this.fileSizeBytes,
    required this.mimeType,
    required this.transferType,
    this.sha256Hash,
    required this.timestamp,
  });

  /// Factory constructor to deserialize [TransferRequest] from JSON map.
  factory TransferRequest.fromJson(Map<String, dynamic> json) {
    return TransferRequest(
      transferId: json['transferId'] as String,
      fileName: json['fileName'] as String,
      fileSizeBytes: (json['fileSizeBytes'] as num).toInt(),
      mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
      transferType: json['transferType'] as String? ?? 'file',
      sha256Hash: json['sha256Hash'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }

  /// Serializes [TransferRequest] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'transferId': transferId,
      'fileName': fileName,
      'fileSizeBytes': fileSizeBytes,
      'mimeType': mimeType,
      'transferType': transferType,
      if (sha256Hash != null) 'sha256Hash': sha256Hash,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  String toString() =>
      'TransferRequest(id: $transferId, file: $fileName, size: $fileSizeBytes, type: $transferType)';
}
