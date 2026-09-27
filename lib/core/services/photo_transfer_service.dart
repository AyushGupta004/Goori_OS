import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
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

  /// Whether there are pending photos staged that have not been uploaded yet.
  bool get hasPendingPhotos => _photos.any((p) => !p.isFinished);

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
              _errorMessage = progress.errorMessage;
            }
          }
          notifyListeners();
        },
      );
    } catch (e) {
      if (item != null) {
        item.progress = TransferProgress(
          transferId: tId,
          bytesTransferred: item.progress.bytesTransferred,
          totalBytes: item.totalBytes,
          status: TransferStatus.failed,
          errorMessage: e.toString(),
        );
      }
      _errorMessage = e.toString();
      notifyListeners();
    } finally {
      _isUploading = _photos.any((p) => p.isUploading);
      notifyListeners();
    }
  }

  /// Triggers [uploadPhoto] for all staged photos that have not completed yet.
  Future<void> sendAllToPC() async {
    final pendingItems = _photos.where((p) => !p.isFinished).toList();
    if (pendingItems.isEmpty) return;

    _isUploading = true;
    _errorMessage = null;
    notifyListeners();

    for (final item in pendingItems) {
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
