import 'transfer_progress.dart';

/// Represents an active or completed file transfer task in the UI.
class FileTransferTask {
  final String transferId;
  final String fileName;
  final String filePath;
  int totalBytes;
  TransferProgress progress;
  bool isCancelled;

  FileTransferTask({
    required this.transferId,
    required this.fileName,
    required this.filePath,
    required this.totalBytes,
    required this.progress,
    this.isCancelled = false,
  });

  /// Human-readable file size string (e.g. "1.2 MB", "450 KB").
  String get formattedTotalSize => formatBytes(totalBytes);

  /// Human-readable transferred size string.
  String get formattedTransferredSize =>
      formatBytes(progress.bytesTransferred);

  /// Formats raw byte count into human-readable representation.
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
