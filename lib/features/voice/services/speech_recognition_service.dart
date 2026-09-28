import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Speech recognition operational states.
enum SpeechRecognitionState {
  /// Idle state: mic waiting for user action.
  idle,

  /// Active listening: capturing microphone audio with live transcript.
  listening,

  /// Recognition finished, transcript available for review.
  done,

  /// Microphone permission was denied by the user.
  permissionDenied,

  /// Recognition or hardware error occurred.
  error,
}

/// Abstract contract for Speech-to-Text engines (both Android native and test mock).
abstract class SpeechRecognitionService extends ChangeNotifier {
  SpeechRecognitionState get state;
  String get transcript;
  bool get isListening;
  bool get hasPermission;

  Future<bool> checkPermission();
  Future<bool> requestPermission();
  Future<bool> initialize();
  Future<void> startListening({
    required void Function(String words, bool isFinal) onResult,
    void Function(String error)? onError,
  });
  Future<void> stopListening();
  Future<void> cancelListening();
  void reset();
}

/// Production implementation connecting to Android native SpeechRecognizer via speech_to_text.
class NativeSpeechRecognitionService extends SpeechRecognitionService {
  final stt.SpeechToText _speechToText = stt.SpeechToText();

  SpeechRecognitionState _state = SpeechRecognitionState.idle;
  String _transcript = '';
  bool _isInitialized = false;
  bool _hasPermission = false;

  void Function(String words, bool isFinal)? _activeResultCallback;
  void Function(String error)? _activeErrorCallback;

  @override
  SpeechRecognitionState get state => _state;

  @override
  String get transcript => _transcript;

  @override
  bool get isListening => _state == SpeechRecognitionState.listening;

  @override
  bool get hasPermission => _hasPermission;

  @override
  Future<bool> checkPermission() async {
    try {
      final status = await Permission.microphone.status;
      _hasPermission = status.isGranted;
      notifyListeners();
      return _hasPermission;
    } catch (e) {
      debugPrint('[NativeSpeechService] checkPermission error: $e');
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      final status = await Permission.microphone.request();
      _hasPermission = status.isGranted;
      if (!_hasPermission) {
        _state = SpeechRecognitionState.permissionDenied;
      }
      notifyListeners();
      return _hasPermission;
    } catch (e) {
      debugPrint('[NativeSpeechService] requestPermission error: $e');
      _state = SpeechRecognitionState.permissionDenied;
      notifyListeners();
      return false;
    }
  }

  @override
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _isInitialized = await _speechToText.initialize(
        onError: (val) {
          debugPrint('[NativeSpeechService] onError: ${val.errorMsg}');
          _state = SpeechRecognitionState.error;
          _activeErrorCallback?.call(val.errorMsg);
          notifyListeners();
        },
        onStatus: (val) {
          debugPrint('[NativeSpeechService] onStatus: $val');
          if (val == 'done' || val == 'notListening') {
            if (_state == SpeechRecognitionState.listening) {
              _state = SpeechRecognitionState.done;
              if (_transcript.trim().isNotEmpty) {
                _activeResultCallback?.call(_transcript.trim(), true);
              }
              notifyListeners();
            }
          }
        },
      );
      return _isInitialized;
    } catch (e) {
      debugPrint('[NativeSpeechService] initialize exception: $e');
      _isInitialized = false;
      return false;
    }
  }

  @override
  Future<void> startListening({
    required void Function(String words, bool isFinal) onResult,
    void Function(String error)? onError,
  }) async {
    _activeResultCallback = onResult;
    _activeErrorCallback = onError;
    _transcript = '';

    // Step 1: Ensure permission
    if (!_hasPermission) {
      final granted = await requestPermission();
      if (!granted) return;
    }

    // Step 2: Ensure initialized
    final initialized = await initialize();
    if (!initialized) {
      _state = SpeechRecognitionState.error;
      onError?.call('Speech recognition initialization failed.');
      notifyListeners();
      return;
    }

    // Step 3: Begin listening
    _state = SpeechRecognitionState.listening;
    notifyListeners();

    try {
      await _speechToText.listen(
        onResult: (result) {
          _transcript = result.recognizedWords;
          final isFinal = result.finalResult;
          _activeResultCallback?.call(_transcript, isFinal);
          if (isFinal) {
            _state = SpeechRecognitionState.done;
          }
          notifyListeners();
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.confirmation,
          partialResults: true,
          cancelOnError: false,
        ),
      );
    } catch (e) {
      debugPrint('[NativeSpeechService] listen exception: $e');
      _state = SpeechRecognitionState.error;
      onError?.call('Microphone capture error: $e');
      notifyListeners();
    }
  }

  @override
  Future<void> stopListening() async {
    try {
      await _speechToText.stop();
    } catch (_) {}
    _state = SpeechRecognitionState.done;
    if (_transcript.trim().isNotEmpty) {
      _activeResultCallback?.call(_transcript.trim(), true);
    }
    notifyListeners();
  }

  @override
  Future<void> cancelListening() async {
    try {
      await _speechToText.cancel();
    } catch (_) {}
    _transcript = '';
    _state = SpeechRecognitionState.idle;
    notifyListeners();
  }

  @override
  void reset() {
    _transcript = '';
    _state = SpeechRecognitionState.idle;
    notifyListeners();
  }
}

/// Mock implementation for headless widget tests and simulator verification.
class MockSpeechRecognitionService extends SpeechRecognitionService {
  SpeechRecognitionState _state = SpeechRecognitionState.idle;
  String _transcript = '';
  bool _hasPermission = true;
  void Function(String words, bool isFinal)? _activeResultCallback;
  void Function(String error)? _activeErrorCallback;

  @override
  SpeechRecognitionState get state => _state;

  @override
  String get transcript => _transcript;

  @override
  bool get isListening => _state == SpeechRecognitionState.listening;

  @override
  bool get hasPermission => _hasPermission;

  void setPermissionGranted(bool granted) {
    _hasPermission = granted;
    if (!granted && _state == SpeechRecognitionState.listening) {
      _state = SpeechRecognitionState.permissionDenied;
    }
    notifyListeners();
  }

  @override
  Future<bool> checkPermission() async {
    return _hasPermission;
  }

  @override
  Future<bool> requestPermission() async {
    if (!_hasPermission) {
      _state = SpeechRecognitionState.permissionDenied;
      notifyListeners();
      return false;
    }
    return true;
  }

  @override
  Future<bool> initialize() async {
    return true;
  }

  @override
  Future<void> startListening({
    required void Function(String words, bool isFinal) onResult,
    void Function(String error)? onError,
  }) async {
    _activeResultCallback = onResult;
    _activeErrorCallback = onError;
    _transcript = '';

    if (!_hasPermission) {
      _state = SpeechRecognitionState.permissionDenied;
      notifyListeners();
      return;
    }

    _state = SpeechRecognitionState.listening;
    notifyListeners();
  }

  /// Helper for tests to simulate partial speech transcript stream.
  void emitPartialTranscript(String partial) {
    if (_state != SpeechRecognitionState.listening) return;
    _transcript = partial;
    _activeResultCallback?.call(partial, false);
    notifyListeners();
  }

  /// Helper for tests to finalize speech recognition.
  void finishTranscript(String finalWords) {
    _transcript = finalWords;
    _state = SpeechRecognitionState.done;
    _activeResultCallback?.call(finalWords, true);
    notifyListeners();
  }

  /// Helper for tests to simulate a recognition error.
  void simulateError(String errorMessage) {
    _state = SpeechRecognitionState.error;
    _activeErrorCallback?.call(errorMessage);
    notifyListeners();
  }

  @override
  Future<void> stopListening() async {
    _state = SpeechRecognitionState.done;
    notifyListeners();
  }

  @override
  Future<void> cancelListening() async {
    _transcript = '';
    _state = SpeechRecognitionState.idle;
    notifyListeners();
  }

  @override
  void reset() {
    _transcript = '';
    _state = SpeechRecognitionState.idle;
    notifyListeners();
  }
}
