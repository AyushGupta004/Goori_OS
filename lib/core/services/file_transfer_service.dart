import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import '../models/models.dart';
import '../network/windows_bridge_client.dart';

/// Service orchestrating streamed file transfers to the Windows AI bridge host.
/// Supports multi-file queuing, live progress tracking, and cancellation.
class FileTransferService extends ChangeNotifier {
  final WindowsBridgeClient client;

  final List<FileTransferTask> _transfers = [];
  final Set<String> _cancelledTransferIds = {};
  bool _isUploading = false;
  String? _errorMessage;

  final StreamController<TransferProgress> _progressStreamController =
      StreamController<TransferProgress>.broadcast();

  FileTransferService({
    required this.client,
  });

  /// All active, queued, and completed transfer tasks.
  List<FileTransferTask> get transfers => List.unmodifiable(_transfers);

  /// Backwards-compatible progress getter for the most active transfer.
  TransferProgress? get currentProgress =>
      _transfers.isNotEmpty ? _transfers.first.progress : null;

  bool get isUploading => _isUploading;
  String? get errorMessage => _errorMessage;
  Stream<TransferProgress> get progressStream =>
      _progressStreamController.stream;

  /// Checks whether a transfer has been flagged as cancelled.
  bool isCancelled(String transferId) =>
      _cancelledTransferIds.contains(transferId);

  /// Cancels an active or queued transfer task.
  void cancelTransfer(String transferId) {
    _cancelledTransferIds.add(transferId);
    final index = _transfers.indexWhere((t) => t.transferId == transferId);
    if (index >= 0) {
      final task = _transfers[index];
      task.isCancelled = true;
      task.progress = TransferProgress(
        transferId: transferId,
        bytesTransferred: task.progress.bytesTransferred,
        totalBytes: task.totalBytes,
        status: TransferStatus.cancelled,
        errorMessage: 'Transfer cancelled by user',
      );
      _progressStreamController.add(task.progress);
      notifyListeners();
    }
  }

  /// Initiates a memory-safe streamed upload of [file] to the Windows host.
  Future<void> uploadFile(File file, {String? transferId}) async {
    final tId = transferId ??
        'file_${DateTime.now().millisecondsSinceEpoch}_${_transfers.length + 1}';
    final fileName = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : file.path.split(Platform.pathSeparator).last;

    final initialProgress = TransferProgress(
      transferId: tId,
      bytesTransferred: 0,
      totalBytes: 0,
      status: TransferStatus.waiting,
    );

    final task = FileTransferTask(
      transferId: tId,
      fileName: fileName,
      filePath: file.path,
      totalBytes: 0,
      progress: initialProgress,
    );

    _transfers.insert(0, task);
    _isUploading = true;
    _errorMessage = null;
    notifyListeners();

    if (_cancelledTransferIds.contains(tId)) {
      task.isCancelled = true;
      task.progress = TransferProgress(
        transferId: tId,
        bytesTransferred: 0,
        totalBytes: 0,
        status: TransferStatus.cancelled,
      );
      _isUploading = _transfers.any((t) => t.progress.isUploading);
      notifyListeners();
      return;
    }

    int totalBytes = 0;
    try {
      if (file.existsSync()) {
        totalBytes = file.lengthSync();
        task.totalBytes = totalBytes;
        task.progress = TransferProgress(
          transferId: tId,
          bytesTransferred: task.progress.bytesTransferred,
          totalBytes: totalBytes,
          status: task.progress.status,
        );
      }
    } catch (_) {}

    try {
      await client.uploadFile(
        file,
        onProgress: (progress) {
          if (_cancelledTransferIds.contains(tId)) {
            return;
          }
          task.progress = progress;
          if (progress.totalBytes > 0) {
            task.totalBytes = progress.totalBytes;
          }
          _progressStreamController.add(progress);
          if (progress.status == TransferStatus.completed ||
              progress.status == TransferStatus.failed ||
              progress.status == TransferStatus.cancelled) {
            if (progress.status == TransferStatus.failed) {
              _errorMessage = progress.errorMessage;
            }
          }
          notifyListeners();
        },
      );
    } catch (e) {
      if (!_cancelledTransferIds.contains(tId)) {
        task.progress = TransferProgress(
          transferId: tId,
          bytesTransferred: task.progress.bytesTransferred,
          totalBytes: task.totalBytes,
          status: TransferStatus.failed,
          errorMessage: e.toString(),
        );
        _errorMessage = e.toString();
        notifyListeners();
      }
    } finally {
      // Check if there are other transfers still uploading
      _isUploading = _transfers.any((t) => t.progress.isUploading);
      notifyListeners();
    }
  }

  /// Queues and uploads a batch of files sequentially.
  Future<void> uploadFiles(List<File> files) async {
    for (final file in files) {
      await uploadFile(file);
    }
  }

  /// Clears completed, failed, or cancelled transfers from history.
  void clearCompleted() {
    _transfers.removeWhere((t) => t.progress.isFinished);
    notifyListeners();
  }

  /// Resets all transfers and state.
  void reset() {
    _transfers.clear();
    _cancelledTransferIds.clear();
    _isUploading = false;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _progressStreamController.close();
    super.dispose();
  }
}
