import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import '../errors/app_errors.dart';
import '../models/models.dart';
import '../network/windows_bridge_client.dart';

/// Service orchestrating streamed photo transfers to the Windows AI bridge host.
/// Supports multi-photo staging, thumbnail-ready items, per-photo live progress, and batch dispatch.
class PhotoTransferService extends ChangeNotifier {
  final WindowsBridgeClient client;

  final List<PhotoTransferItem> _photos = [];
  TransferProgress? _currentProgress;
  bool _isUploading = false;
  String? _errorMessage;

  final StreamController<TransferProgress> _progressStreamController =
      StreamController<TransferProgress>.broadcast();

  PhotoTransferService({
    required this.client,
  });

  /// All staged, uploading, and completed photo items.
  List<PhotoTransferItem> get photos => List.unmodifiable(_photos);

  TransferProgress? get currentProgress => _currentProgress;
  bool get isUploading => _isUploading;
  String? get errorMessage => _errorMessage;
  Stream<TransferProgress> get progressStream =>
      _progressStreamController.stream;

  /// Whether there are pending photos waiting to be uploaded.
  bool get hasPendingPhotos =>
      _photos.any((p) => p.progress.status == TransferStatus.waiting);

  /// Whether there are any photos whose upload failed and can be retried.
  bool get hasFailedPhotos =>
      _photos.any((p) => p.progress.status == TransferStatus.failed);

  /// Whether there are photos that can be sent or retried (waiting or failed).
  bool get hasUploadablePhotos =>
      _photos.any((p) =>
          p.progress.status == TransferStatus.waiting ||
          p.progress.status == TransferStatus.failed);

  /// Count of currently failed photos.
  int get failedCount =>
      _photos.where((p) => p.progress.status == TransferStatus.failed).length;

  /// Count of currently waiting photos.
  int get waitingCount =>
      _photos.where((p) => p.progress.status == TransferStatus.waiting).length;

  /// Adds a single captured photo to the staged list.
  void addPhoto(File file) {
    addPhotos([file]);
  }

  /// Adds a batch of selected photos to the staged list.
  void addPhotos(List<File> files) {
    for (final file in files) {
      final id =
          'photo_${DateTime.now().millisecondsSinceEpoch}_${_photos.length + 1}';
      final fileName = file.uri.pathSegments.isNotEmpty
          ? file.uri.pathSegments.last
          : file.path.split(Platform.pathSeparator).last;

      int totalBytes = 0;
      try {
        if (file.existsSync()) {
          totalBytes = file.lengthSync();
        }
      } catch (_) {}

      final initialProgress = TransferProgress(
        transferId: id,
        bytesTransferred: 0,
        totalBytes: totalBytes,
        status: TransferStatus.waiting,
      );

      final item = PhotoTransferItem(
        id: id,
        file: file,
        fileName: fileName,
        totalBytes: totalBytes,
        progress: initialProgress,
      );

      _photos.add(item);
    }
    notifyListeners();
  }

  /// Removes a photo from the staged list (affordance ✕ per photo).
  void removePhoto(String id) {
    _photos.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  /// Clears completed or failed photos from the staging list.
  void clearCompleted() {
    _photos.removeWhere((item) => item.isFinished);
    notifyListeners();
  }

  /// Retries a single failed photo by its [id]. Completed photos are never re-sent.
  Future<void> retryPhoto(String id) async {
    final itemIndex = _photos.indexWhere((p) => p.id == id);
    if (itemIndex < 0) return;
    final item = _photos[itemIndex];
    if (item.progress.status == TransferStatus.completed) return;

    item.progress = TransferProgress(
      transferId: item.id,
      bytesTransferred: 0,
      totalBytes: item.totalBytes,
      status: TransferStatus.waiting,
    );
    notifyListeners();
    await uploadPhoto(item.file, transferId: item.id);
  }

  /// Retries all currently failed photos in sequence.
  Future<void> retryFailedPhotos() async {
    final failedItems = _photos
        .where((p) => p.progress.status == TransferStatus.failed)
        .toList();
    for (final item in failedItems) {
      await retryPhoto(item.id);
    }
  }

  /// Initiates a memory-safe streamed upload of [photo] to the Windows host.
  Future<void> uploadPhoto(
    File photo, {
    String? transferId,
    void Function(TransferProgress)? onProgress,
  }) async {
    final tId = transferId ??
        'photo_${DateTime.now().millisecondsSinceEpoch}_${_photos.length + 1}';

    // Check if item is registered in staged photos list
    PhotoTransferItem? item;
    final index = _photos.indexWhere((p) => p.id == tId || p.file.path == photo.path);
    if (index >= 0) {
      item = _photos[index];
    }

    _isUploading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await client.uploadPhoto(
        photo,
        onProgress: (progress) {
          _currentProgress = progress;
          if (item != null) {
            item.progress = progress;
            if (progress.totalBytes > 0) {
              item.totalBytes = progress.totalBytes;
            }
          }
          _progressStreamController.add(progress);
          onProgress?.call(progress);

          if (progress.status == TransferStatus.completed ||
              progress.status == TransferStatus.failed) {
            if (progress.status == TransferStatus.failed) {
              _errorMessage = progress.errorMessage != null
                  ? AppErrorMapper.map(progress.errorMessage)
                  : AppErrors.uploadFailed;
            }
          }
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint('[PhotoTransferService] uploadPhoto exception: $e');
      final friendly = AppErrorMapper.map(e, fallback: AppErrors.uploadFailed);
      if (item != null) {
        item.progress = TransferProgress(
          transferId: tId,
          bytesTransferred: item.progress.bytesTransferred,
          totalBytes: item.totalBytes,
          status: TransferStatus.failed,
          errorMessage: friendly,
        );
      }
      _errorMessage = friendly;
      notifyListeners();
    } finally {
      _isUploading = _photos.any((p) => p.isUploading);
      notifyListeners();
    }
  }

  /// Triggers [uploadPhoto] for all staged photos that are waiting or failed.
  /// Completed photos are never re-sent.
  Future<void> sendAllToPC() async {
    final uploadableItems = _photos
        .where((p) =>
            p.progress.status == TransferStatus.waiting ||
            p.progress.status == TransferStatus.failed)
        .toList();
    if (uploadableItems.isEmpty) return;

    _isUploading = true;
    _errorMessage = null;

    // Reset status of failed items to waiting
    for (final item in uploadableItems) {
      if (item.progress.status == TransferStatus.failed) {
        item.progress = TransferProgress(
          transferId: item.id,
          bytesTransferred: 0,
          totalBytes: item.totalBytes,
          status: TransferStatus.waiting,
        );
      }
    }
    notifyListeners();

    for (final item in uploadableItems) {
      await uploadPhoto(item.file, transferId: item.id);
    }

    _isUploading = false;
    notifyListeners();
  }

  /// Resets all staged photos and state.
  void reset() {
    _photos.clear();
    _currentProgress = null;
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
