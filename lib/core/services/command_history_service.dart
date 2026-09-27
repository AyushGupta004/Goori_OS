import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/command_history_item.dart';

/// Service managing persistent local storage of executed commands in SharedPreferences.
class CommandHistoryService extends ChangeNotifier {
  static const String storageKey = 'local_command_history';

  SharedPreferences? _prefs;
  final List<CommandHistoryItem> _history = [];
  bool _isInitialized = false;
  bool _isEnabled = true;

  CommandHistoryService({SharedPreferences? prefs}) {
    _prefs = prefs;
    if (_prefs != null) {
      _loadFromPrefs();
      _isInitialized = true;
    } else {
      _initAsync();
    }
  }

  bool get isInitialized => _isInitialized;

  /// Whether new commands are recorded to history.
  bool get isEnabled => _isEnabled;
  set isEnabled(bool value) {
    if (_isEnabled != value) {
      _isEnabled = value;
      notifyListeners();
    }
  }

  /// Returns unmodifiable command history sorted newest first.
  List<CommandHistoryItem> get history => List.unmodifiable(_history);

  Future<void> _initAsync() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _loadFromPrefs();
    } catch (e) {
      debugPrint('[CommandHistoryService] Failed to load SharedPreferences: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  void _loadFromPrefs() {
    if (_prefs == null) return;
    final jsonList = _prefs!.getStringList(storageKey);
    if (jsonList != null && jsonList.isNotEmpty) {
      _history.clear();
      for (final raw in jsonList) {
        try {
          final map = jsonDecode(raw) as Map<String, dynamic>;
          _history.add(CommandHistoryItem.fromJson(map));
        } catch (e) {
          debugPrint('[CommandHistoryService] Corrupt history entry skipped: $e');
        }
      }
      // Sort newest first
      _history.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      notifyListeners();
    }
    final enabledVal = _prefs!.getBool('settings_command_history_enabled');
    if (enabledVal != null) {
      _isEnabled = enabledVal;
    }
  }

  /// Appends a new command record to history and persists to local storage.
  Future<void> addCommand({
    required String id,
    required String commandText,
    required bool success,
    required DateTime timestamp,
    String status = 'completed',
    String? errorDetails,
  }) async {
    if (!_isEnabled) return;
    final item = CommandHistoryItem(
      id: id,
      commandText: commandText,
      success: success,
      timestamp: timestamp,
      status: status,
      errorDetails: errorDetails,
    );

    // Insert at index 0 (newest first)
    _history.insert(0, item);
    await _persist();
    notifyListeners();
  }

  /// Clears all local command history records.
  Future<void> clearHistory() async {
    _history.clear();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    if (_prefs == null) {
      try {
        _prefs = await SharedPreferences.getInstance();
      } catch (_) {
        return;
      }
    }
    final jsonList = _history.map((e) => jsonEncode(e.toJson())).toList();
    await _prefs!.setStringList(storageKey, jsonList);
  }
}
