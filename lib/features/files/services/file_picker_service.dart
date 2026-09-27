import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Contract for selecting files and checking storage permissions.
abstract class FilePickerService extends ChangeNotifier {
  bool get hasStoragePermission;

  Future<bool> checkStoragePermission();
  Future<bool> requestStoragePermission();
  Future<List<File>?> pickFiles({bool allowMultiple = true});
}

/// Production implementation using file_picker and permission_handler.
class NativeFilePickerService extends FilePickerService {
  bool _hasPermission = false;

  @override
  bool get hasStoragePermission => _hasPermission;

  @override
  Future<bool> checkStoragePermission() async {
    try {
      // On Android 13+ (API 33+), file_picker uses SAF and does not require raw storage permission.
      // However, we check Permission.storage or manageExternalStorage if needed.
      final status = await Permission.storage.status;
      _hasPermission = status.isGranted;
      notifyListeners();
      return _hasPermission;
    } catch (e) {
      debugPrint('[NativeFilePickerService] checkStoragePermission error: $e');
      return true; // Fallback to SAF
    }
  }

  @override
  Future<bool> requestStoragePermission() async {
    try {
      final status = await Permission.storage.request();
      _hasPermission = status.isGranted;
      notifyListeners();
      return _hasPermission;
    } catch (e) {
      debugPrint('[NativeFilePickerService] requestStoragePermission error: $e');
      _hasPermission = true; // Fallback to SAF on newer Android versions
      notifyListeners();
      return true;
    }
  }

  @override
  Future<List<File>?> pickFiles({bool allowMultiple = true}) async {
    try {
      final platformFiles = await FilePickerPlatform.instance.pickFiles(
        type: FileType.any,
      );

      if (platformFiles.isEmpty) {
        return null;
      }

      final files = <File>[];
      for (final platformFile in platformFiles) {
        if (platformFile.path != null && platformFile.path!.isNotEmpty) {
          files.add(File(platformFile.path!));
        }
      }

      return files.isNotEmpty ? files : null;
    } catch (e) {
      debugPrint('[NativeFilePickerService] pickFiles error: $e');
      return null;
    }
  }
}

/// Mock implementation for headless widget tests and offline testing.
class MockFilePickerService extends FilePickerService {
  bool _hasPermission = true;
  List<File>? _stagedFiles;

  @override
  bool get hasStoragePermission => _hasPermission;

  void setStoragePermissionGranted(bool granted) {
    _hasPermission = granted;
    notifyListeners();
  }

  void setStagedFiles(List<File>? files) {
    _stagedFiles = files;
  }

  @override
  Future<bool> checkStoragePermission() async {
    return _hasPermission;
  }

  @override
  Future<bool> requestStoragePermission() async {
    return _hasPermission;
  }

  @override
  Future<List<File>?> pickFiles({bool allowMultiple = true}) async {
    if (!_hasPermission) {
      return null;
    }
    return _stagedFiles;
  }
}
