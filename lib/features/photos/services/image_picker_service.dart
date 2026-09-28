import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

/// Contract for camera capture, gallery selection, and runtime permission requests.
abstract class ImagePickerService extends ChangeNotifier {
  bool get hasCameraPermission;
  bool get hasPhotosPermission;

  Future<bool> requestCameraPermission();
  Future<bool> requestPhotosPermission();
  Future<File?> capturePhotoFromCamera();
  Future<List<File>?> pickMultiImageFromGallery();
}

/// Production implementation using native image_picker and permission_handler.
class NativeImagePickerService extends ImagePickerService {
  final ImagePicker _picker = ImagePicker();
  bool _hasCameraPermission = false;
  bool _hasPhotosPermission = false;

  @override
  bool get hasCameraPermission => _hasCameraPermission;

  @override
  bool get hasPhotosPermission => _hasPhotosPermission;

  @override
  Future<bool> requestCameraPermission() async {
    try {
      final status = await Permission.camera.request();
      _hasCameraPermission = status.isGranted;
      notifyListeners();
      return _hasCameraPermission;
    } catch (e) {
      debugPrint('[NativeImagePickerService] requestCameraPermission error: $e');
      _hasCameraPermission = true;
      notifyListeners();
      return true;
    }
  }

  @override
  Future<bool> requestPhotosPermission() async {
    try {
      if (Platform.isAndroid) {
        // On Android 13+ (API 33+), image_picker uses the Android Photo Picker
        // which operates via system intent and does not require runtime storage/photos permission.
        try {
          final status = await Permission.photos.request();
          if (!status.isGranted && !status.isLimited) {
            await Permission.storage.request();
          }
        } catch (_) {}
        // Android system photo picker is always available to pick photos
        _hasPhotosPermission = true;
      } else {
        final status = await Permission.photos.request();
        _hasPhotosPermission = status.isGranted || status.isLimited;
      }
      notifyListeners();
      return _hasPhotosPermission;
    } catch (e) {
      debugPrint('[NativeImagePickerService] requestPhotosPermission error: $e');
      _hasPhotosPermission = true;
      notifyListeners();
      return true;
    }
  }

  @override
  Future<File?> capturePhotoFromCamera() async {
    try {
      final xFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );
      if (xFile != null) {
        return File(xFile.path);
      }
      return null;
    } catch (e) {
      debugPrint('[NativeImagePickerService] capturePhotoFromCamera error: $e');
      return null;
    }
  }

  @override
  Future<List<File>?> pickMultiImageFromGallery() async {
    try {
      final xFiles = await _picker.pickMultiImage(
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );
      if (xFiles.isNotEmpty) {
        return xFiles.map((x) => File(x.path)).toList();
      }
      return null;
    } catch (e) {
      debugPrint('[NativeImagePickerService] pickMultiImageFromGallery error: $e');
      return null;
    }
  }
}

/// Mock implementation for headless widget testing and offline demonstration.
class MockImagePickerService extends ImagePickerService {
  bool _cameraPermissionGranted = true;
  bool _photosPermissionGranted = true;
  File? _stagedCameraPhoto;
  List<File>? _stagedGalleryPhotos;

  bool wasCameraPermissionRequested = false;
  bool wasPhotosPermissionRequested = false;

  @override
  bool get hasCameraPermission => _cameraPermissionGranted;

  @override
  bool get hasPhotosPermission => _photosPermissionGranted;

  void setCameraPermissionGranted(bool granted) {
    _cameraPermissionGranted = granted;
    notifyListeners();
  }

  void setPhotosPermissionGranted(bool granted) {
    _photosPermissionGranted = granted;
    notifyListeners();
  }

  void setStagedCameraPhoto(File? photo) {
    _stagedCameraPhoto = photo;
  }

  void setStagedGalleryPhotos(List<File>? photos) {
    _stagedGalleryPhotos = photos;
  }

  @override
  Future<bool> requestCameraPermission() async {
    wasCameraPermissionRequested = true;
    return _cameraPermissionGranted;
  }

  @override
  Future<bool> requestPhotosPermission() async {
    wasPhotosPermissionRequested = true;
    return _photosPermissionGranted;
  }

  @override
  Future<File?> capturePhotoFromCamera() async {
    if (!_cameraPermissionGranted) {
      return null;
    }
    return _stagedCameraPhoto;
  }

  @override
  Future<List<File>?> pickMultiImageFromGallery() async {
    if (!_photosPermissionGranted) {
      return null;
    }
    return _stagedGalleryPhotos;
  }
}
