import '../constants/app_constants.dart';

/// Progress status for an in-flight file or photo upload stream.
class TransferProgress {
  final String transferId;
  final int bytesTransferred;
  final int totalBytes;
  final TransferStatus status;
  final double speedBytesPerSecond;
  final String? errorMessage;

  const TransferProgress({
    required this.transferId,
    required this.bytesTransferred,
    required this.totalBytes,
    required this.status,
    this.speedBytesPerSecond = 0.0,
    this.errorMessage,
  });

  /// Fraction completed between 0.0 and 1.0.
  double get fraction =>
      totalBytes > 0 ? (bytesTransferred / totalBytes).clamp(0.0, 1.0) : 0.0;

  /// Integer percentage between 0 and 100.
  int get percentage => (fraction * 100).round();

  /// True if the transfer is in an active uploading state.
  bool get isUploading => status == TransferStatus.uploading;

  /// True if terminal status reached (completed, failed, or cancelled).
  bool get isFinished =>
      status == TransferStatus.completed ||
      status == TransferStatus.failed ||
      status == TransferStatus.cancelled;

  /// Factory constructor to deserialize [TransferProgress] from JSON map.
  factory TransferProgress.fromJson(Map<String, dynamic> json) {
    return TransferProgress(
      transferId: json['transferId'] as String,
      bytesTransferred: (json['bytesTransferred'] as num).toInt(),
      totalBytes: (json['totalBytes'] as num).toInt(),
      status: TransferStatus.fromString(json['status'] as String? ?? 'waiting'),
      speedBytesPerSecond:
          (json['speedBytesPerSecond'] as num?)?.toDouble() ?? 0.0,
      errorMessage: json['errorMessage'] as String?,
    );
  }

  /// Serializes [TransferProgress] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'transferId': transferId,
      'bytesTransferred': bytesTransferred,
      'totalBytes': totalBytes,
      'status': status.toJson(),
      'speedBytesPerSecond': speedBytesPerSecond,
      if (errorMessage != null) 'errorMessage': errorMessage,
    };
  }

  @override
  String toString() =>
      'TransferProgress(id: $transferId, $bytesTransferred/$totalBytes bytes ($percentage%), status: $status)';
}
