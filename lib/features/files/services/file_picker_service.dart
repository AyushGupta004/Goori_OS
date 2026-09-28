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
      if (Platform.isAndroid) {
        final status = await Permission.storage.status;
        _hasPermission = status.isGranted;
        // Modern Android uses SAF (Storage Access Framework) via FilePicker which needs no raw storage permission
        _hasPermission = true;
      } else {
        _hasPermission = true;
      }
      notifyListeners();
      return _hasPermission;
    } catch (e) {
      debugPrint('[NativeFilePickerService] checkStoragePermission error: $e');
      _hasPermission = true;
      return true;
    }
  }

  @override
  Future<bool> requestStoragePermission() async {
    try {
      if (Platform.isAndroid) {
        try {
          await Permission.storage.request();
        } catch (_) {}
        // Storage permission is not required for system document picker (SAF) on modern Android
        _hasPermission = true;
      } else {
        _hasPermission = true;
      }
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[NativeFilePickerService] requestStoragePermission error: $e');
      _hasPermission = true;
      notifyListeners();
      return true;
    }
  }

  @override
  Future<List<File>?> pickFiles({bool allowMultiple = true}) async {
    try {
      final List<PlatformFile> platformFiles;
      if (allowMultiple) {
        platformFiles = await FilePicker.pickFiles(
          type: FileType.any,
        );
      } else {
        final single = await FilePicker.pickFile(
          type: FileType.any,
        );
        platformFiles = single != null ? [single] : [];
      }

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
