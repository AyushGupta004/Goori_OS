import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../network/windows_bridge_client.dart';
import 'command_history_service.dart';

/// Service orchestrating submission and lifecycle tracking for Windows AI automation commands.
class CommandService extends ChangeNotifier {
  final WindowsBridgeClient client;
  final CommandHistoryService? historyService;

  final List<CommandResult> _history = [];
  final Map<String, CommandRequest> _outgoingRequests = {};
  bool _isExecuting = false;
  int _sequenceNumber = 0;
  StreamSubscription<CommandResult>? _resultsSubscription;

  final StreamController<CommandResult> _commandUpdatesController =
      StreamController<CommandResult>.broadcast();

  CommandService({
    required this.client,
    this.historyService,
  }) {
    _resultsSubscription = client.commandResults.listen(_handleCommandResult);
  }

  /// Complete execution history for session.
  List<CommandResult> get history => List.unmodifiable(_history);

  /// True if a command is currently in flight.
  bool get isExecuting => _isExecuting;

  /// Most recently processed command result, if any.
  CommandResult? get lastCommand => _history.isNotEmpty ? _history.first : null;

  /// Stream of command execution events.
  Stream<CommandResult> get commandUpdates => _commandUpdatesController.stream;

  /// Generates a unique request identifier conforming to the spec:
  /// cmd-{timestamp}-{sequence}
  String generateRequestId() {
    _sequenceNumber++;
    return 'cmd-${DateTime.now().millisecondsSinceEpoch}-$_sequenceNumber';
  }

  void _handleCommandResult(CommandResult result) {
    final existingIndex =
        _history.indexWhere((r) => r.commandId == result.commandId);
    if (existingIndex >= 0) {
      _history[existingIndex] = result;
    } else {
      _history.insert(0, result);
    }

    // Persist to local command history when result is final
    if (result.status == 'completed' ||
        result.status == 'failed' ||
        result.status == 'error') {
      final req = _outgoingRequests[result.commandId];
      final commandText = req?.payload ?? result.message;
      historyService?.addCommand(
        id: result.commandId,
        commandText: commandText,
        success: result.success,
        timestamp: result.timestamp,
        status: result.status,
        errorDetails: result.errorDetails,
      );
    }

    _commandUpdatesController.add(result);
    notifyListeners();
  }

  /// Sends a command to the Windows host with an optional specific request ID.
  /// Type can be "text" or "voice_transcript".
  Future<CommandResult> sendCommand(
    String payload, {
    String? requestId,
    String type = 'text',
    Map<String, String>? metadata,
  }) async {
    final cleanPayload = payload.trim();
    final commandId = requestId ?? generateRequestId();

    if (cleanPayload.isEmpty) {
      final emptyResult = CommandResult(
        commandId: commandId,
        success: false,
        status: 'failed',
        message: 'Command payload cannot be empty.',
        timestamp: DateTime.now(),
      );
      return emptyResult;
    }

    final request = CommandRequest(
      commandId: commandId,
      type: type,
      payload: cleanPayload,
      timestamp: DateTime.now(),
      metadata: metadata,
    );

    return sendCommandRequest(request);
  }

  /// Sends a structured [CommandRequest] to the Windows host.
  Future<CommandResult> sendCommandRequest(CommandRequest request) async {
    _isExecuting = true;
    _outgoingRequests[request.commandId] = request;
    notifyListeners();

    try {
      final result = await client.sendCommand(request);
      _isExecuting = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isExecuting = false;
      final errorResult = CommandResult(
        commandId: request.commandId,
        success: false,
        status: 'error',
        message: 'Failed to dispatch command: ${e.toString()}',
        timestamp: DateTime.now(),
        errorDetails: 'DISPATCH_ERROR',
      );
      _handleCommandResult(errorResult);
      notifyListeners();
      return errorResult;
    }
  }

  /// Clears in-memory session history.
  void clearHistory() {
    _history.clear();
    _outgoingRequests.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _resultsSubscription?.cancel();
    _commandUpdatesController.close();
    super.dispose();
  }
}
