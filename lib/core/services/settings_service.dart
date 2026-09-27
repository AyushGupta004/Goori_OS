import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/theme.dart';

/// Service managing user application preferences including command confirmation mode,
/// auto-send behavior, command history persistence toggles, and appearance theme mode.
class SettingsService extends ChangeNotifier {
  static const String keyConfirmBeforeSend = 'settings_confirm_before_send';
  static const String keyCommandHistoryEnabled =
      'settings_command_history_enabled';
  static const String keyThemeMode = 'settings_theme_mode';

  SharedPreferences? _prefs;
  bool _confirmBeforeSend = true; // Default: confirm before send (autoSend = false)
  bool _commandHistoryEnabled = true; // Default: command history enabled
  AppThemeMode _themeMode = AppThemeMode.dark; // Default: Black console theme
  bool _isInitialized = false;

  SettingsService({SharedPreferences? prefs}) {
    _prefs = prefs;
    if (_prefs != null) {
      _loadFromPrefs();
      _isInitialized = true;
    } else {
      _initAsync();
    }
  }

  bool get isInitialized => _isInitialized;

  /// Whether user must confirm recognized voice command prior to dispatch.
  bool get confirmBeforeSend => _confirmBeforeSend;

  /// Whether voice commands are auto-sent immediately without confirmation review.
  bool get autoSend => !_confirmBeforeSend;

  /// Whether local command history logging is enabled.
  bool get commandHistoryEnabled => _commandHistoryEnabled;

  /// Active theme mode (dark / light).
  AppThemeMode get themeMode => _themeMode;

  Future<void> _initAsync() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _loadFromPrefs();
    } catch (e) {
      debugPrint('[SettingsService] Failed to load SharedPreferences: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  void _loadFromPrefs() {
    if (_prefs == null) return;
    _confirmBeforeSend = _prefs!.getBool(keyConfirmBeforeSend) ?? true;
    _commandHistoryEnabled = _prefs!.getBool(keyCommandHistoryEnabled) ?? true;
    final themeStr = _prefs!.getString(keyThemeMode);
    _themeMode = AppThemeMode.fromString(themeStr);
    notifyListeners();
  }

  /// Updates the confirmation mode.
  Future<void> setConfirmBeforeSend(bool value) async {
    _confirmBeforeSend = value;
    notifyListeners();

    if (_prefs == null) {
      try {
        _prefs = await SharedPreferences.getInstance();
      } catch (_) {
        return;
      }
    }
    await _prefs!.setBool(keyConfirmBeforeSend, value);
  }

  /// Updates the auto-send mode (inverse of confirmBeforeSend).
  Future<void> setAutoSend(bool value) async {
    await setConfirmBeforeSend(!value);
  }

  /// Updates whether command history logging is active.
  Future<void> setCommandHistoryEnabled(bool value) async {
    _commandHistoryEnabled = value;
    notifyListeners();

    if (_prefs == null) {
      try {
        _prefs = await SharedPreferences.getInstance();
      } catch (_) {
        return;
      }
    }
    await _prefs!.setBool(keyCommandHistoryEnabled, value);
  }

  /// Updates the appearance theme mode and persists choice.
  Future<void> setThemeMode(AppThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();

    if (_prefs == null) {
      try {
        _prefs = await SharedPreferences.getInstance();
      } catch (_) {
        return;
      }
    }
    await _prefs!.setString(keyThemeMode, mode.name);
  }
}

