import 'dart:io';
import '../constants/app_constants.dart';
import 'file_transfer_task.dart';
import 'transfer_progress.dart';

/// Represents a selected or staged photo for streaming to the Windows Bridge.
class PhotoTransferItem {
  final String id;
  final File file;
  final String fileName;
  int totalBytes;
  TransferProgress progress;

  PhotoTransferItem({
    required this.id,
    required this.file,
    required this.fileName,
    this.totalBytes = 0,
    required this.progress,
  });

  /// Human-readable file size string.
  String get formattedTotalSize => FileTransferTask.formatBytes(totalBytes);

  /// Status convenience getters.
  bool get isWaiting => progress.status == TransferStatus.waiting;
  bool get isUploading => progress.status == TransferStatus.uploading;
  bool get isCompleted => progress.status == TransferStatus.completed;
  bool get isFailed => progress.status == TransferStatus.failed;
  bool get isCancelled => progress.status == TransferStatus.cancelled;
  bool get isFinished => progress.isFinished;
}
