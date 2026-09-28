import 'dart:async';
import 'dart:io';

import '../constants/app_constants.dart';
import '../models/models.dart';
import 'config.dart';
import 'windows_bridge_client.dart';

/// Fully functional mock implementation of [WindowsBridgeClient] for standalone development,
/// automated testing, and offline demos.
///
/// Simulates realistic network round-trips, pairing PIN validation, token auth,
/// multi-stage command execution streams, and streamed file upload progress.
class MockWindowsBridgeClient implements WindowsBridgeClient {
  final StreamController<ConnectionState> _connectionStateController =
      StreamController<ConnectionState>.broadcast();

  final StreamController<CommandResult> _commandResultsController =
      StreamController<CommandResult>.broadcast();

  ConnectionState _currentState = ConnectionState.disconnected;
  String _activeToken = 'mock_valid_token_123456';
  final List<Timer> _activeTimers = [];
  bool _isDisposed = false;

  /// Optional hook to force failure modes in tests.
  bool forceConnectFailure = false;
  bool forceAuthFailure = false;
  bool forceCommandFailure = false;
  bool forceUploadFailure = false;
  String? mockProtocolVersion;

  /// Simulates an unexpected WebSocket disconnection mid-session.
  void simulateDisconnect() {
    _emitState(ConnectionState.disconnected);
  }

  MockWindowsBridgeClient({
    String? initialToken,
  }) {
    if (initialToken != null) {
      _activeToken = initialToken;
    }
  }

  @override
  Stream<ConnectionState> get connectionState =>
      _connectionStateController.stream;

  @override
  ConnectionState get currentConnectionState => _currentState;

  @override
  Stream<CommandResult> get commandResults => _commandResultsController.stream;

  void _emitState(ConnectionState state) {
    if (_isDisposed) return;
    _currentState = state;
    _connectionStateController.add(state);
  }

  @override
  void configure(BridgeConfig config) {
    // No-op for mock client: only sets host/port/protocol without opening sockets
  }

  @override
  Future<bool> checkHealth() async {
    await Future.delayed(const Duration(milliseconds: 50));
    return !forceConnectFailure;
  }

  @override
  Future<void> connect(BridgeConfig config) async {
    _emitState(ConnectionState.connecting);

    // Simulate LAN discovery and TCP/WebSocket handshake delay
    await Future.delayed(const Duration(milliseconds: 300));
    if (_isDisposed) return;

    if (forceConnectFailure) {
      _emitState(ConnectionState.disconnected);
      throw const SocketException('Connection refused: Windows AI Bridge offline');
    }

    _emitState(ConnectionState.connected);
  }

  @override
  Future<PairingResponse> pair(String code) async {
    // Simulate host PIN cryptographic verification delay
    await Future.delayed(const Duration(milliseconds: 500));

    final trimmed = code.trim();
    if (trimmed.length == 6 && int.tryParse(trimmed) != null) {
      _activeToken =
          'mock_token_${trimmed}_${DateTime.now().millisecondsSinceEpoch}';
      return PairingResponse(
        success: true,
        deviceId: 'WIN-MOCK-DEV-${trimmed.substring(0, 3)}',
        sessionToken: _activeToken,
        refreshToken: 'mock_refresh_$trimmed',
        expiresAt: DateTime.now().add(const Duration(days: 30)),
        protocolVersion: AppConstants.protocolVersion,
      );
    } else {
      return const PairingResponse(
        success: false,
        deviceId: '',
        errorMessage: 'INVALID_PAIRING_CODE: Code must be 6 numeric digits.',
        protocolVersion: AppConstants.protocolVersion,
      );
    }
  }

  @override
  Future<AuthenticationResponse> authenticate(String token) async {
    _emitState(ConnectionState.authenticating);
    await Future.delayed(const Duration(milliseconds: 250));

    if (forceAuthFailure ||
        token.isEmpty ||
        (!token.startsWith('mock_') &&
            token != _activeToken &&
            token != 'valid_token')) {
      _emitState(ConnectionState.disconnected);
      return const AuthenticationResponse(
        authenticated: false,
        deviceId: '',
        serverVersion: '1.0.0-mock',
        errorMessage:
            'INVALID_TOKEN: Provided authentication token was rejected.',
      );
    }

    _emitState(ConnectionState.connected);
    return AuthenticationResponse(
      authenticated: true,
      deviceId: 'WIN-MOCK-DEV-01',
      serverVersion: mockProtocolVersion ?? '1.0.0-mock',
      protocolVersion: mockProtocolVersion ?? '1.0',
      sessionExpiresAt: DateTime.now().add(const Duration(days: 7)),
      permissions: const [
        'command',
        'file_upload',
        'photo_upload',
        'voice_stream'
      ],
    );
  }

  @override
  Future<CommandResult> sendCommand(CommandRequest request) async {
    if (_currentState != ConnectionState.connected) {
      final failure = CommandResult(
        commandId: request.commandId,
        success: false,
        status: 'failed',
        message: 'Cannot send command: client is disconnected.',
        timestamp: DateTime.now(),
        errorDetails: 'NOT_CONNECTED',
      );
      _commandResultsController.add(failure);
      return failure;
    }

    // Step 1: "received"
    final receivedResult = CommandResult(
      commandId: request.commandId,
      success: true,
      status: 'received',
      message: 'Command acknowledged by Windows AI bridge',
      timestamp: DateTime.now(),
    );
    _commandResultsController.add(receivedResult);

    // Step 2: "executing"
    final executingTimer = Timer(const Duration(milliseconds: 150), () {
      if (_isDisposed) return;
      _commandResultsController.add(
        CommandResult(
          commandId: request.commandId,
          success: true,
          status: 'executing',
          message: 'Executing automation action: "${request.payload}"',
          timestamp: DateTime.now(),
        ),
      );
    });
    _activeTimers.add(executingTimer);

    // Step 3: "completed" or "failed"
    final shouldFail = forceCommandFailure ||
        request.payload.toLowerCase().contains('fail') ||
        request.payload.toLowerCase().contains('error');

    await Future.delayed(const Duration(milliseconds: 350));

    final finalResult = CommandResult(
      commandId: request.commandId,
      success: !shouldFail,
      status: shouldFail ? 'failed' : 'completed',
      message: shouldFail
          ? 'Execution failed on Windows host: simulated command error.'
          : 'Successfully executed: "${request.payload}"',
      timestamp: DateTime.now(),
      executionTimeMs: 280,
      errorDetails: shouldFail ? 'SIMULATED_EXECUTION_FAILURE' : null,
    );

    if (!_isDisposed) {
      _commandResultsController.add(finalResult);
    }

    return finalResult;
  }

  @override
  Future<void> uploadFile(
    File file, {
    required void Function(TransferProgress progress) onProgress,
  }) async {
    await _simulateStreamUpload(
      transferId: 'file_${DateTime.now().millisecondsSinceEpoch}',
      file: file,
      transferType: 'file',
      onProgress: onProgress,
    );
  }

  @override
  Future<void> uploadPhoto(
    File photo, {
    required void Function(TransferProgress progress) onProgress,
  }) async {
    await _simulateStreamUpload(
      transferId: 'photo_${DateTime.now().millisecondsSinceEpoch}',
      file: photo,
      transferType: 'photo',
      onProgress: onProgress,
    );
  }

  Future<void> _simulateStreamUpload({
    required String transferId,
    required File file,
    required String transferType,
    required void Function(TransferProgress progress) onProgress,
  }) async {
    int totalBytes = 1024 * 1024;
    try {
      if (file.existsSync()) {
        totalBytes = file.lengthSync();
      }
    } catch (_) {}

    final shouldFail = forceUploadFailure ||
        file.path.toLowerCase().contains('fail') ||
        file.path.toLowerCase().contains('error');

    // 0% waiting
    onProgress(
      TransferProgress(
        transferId: transferId,
        bytesTransferred: 0,
        totalBytes: totalBytes,
        status: TransferStatus.waiting,
      ),
    );

    final steps = [0.25, 0.5, 0.75, 1.0];
    for (int i = 0; i < steps.length; i++) {
      await Future.delayed(const Duration(milliseconds: 80));
      if (_isDisposed) return;

      final progressRatio = steps[i];
      final bytes = (totalBytes * progressRatio).round();

      if (shouldFail && i == 1) {
        onProgress(
          TransferProgress(
            transferId: transferId,
            bytesTransferred: bytes,
            totalBytes: totalBytes,
            status: TransferStatus.failed,
            errorMessage: 'Stream interrupted: simulated host connection drop',
          ),
        );
        return;
      }

      onProgress(
        TransferProgress(
          transferId: transferId,
          bytesTransferred: bytes,
          totalBytes: totalBytes,
          status: progressRatio == 1.0
              ? TransferStatus.completed
              : TransferStatus.uploading,
          speedBytesPerSecond: 256 * 1024,
        ),
      );
    }
  }

  @override
  Future<void> disconnect() async {
    for (final timer in _activeTimers) {
      timer.cancel();
    }
    _activeTimers.clear();
    _emitState(ConnectionState.disconnected);
  }

  /// Closes stream controllers and releases all resources.
  void dispose() {
    _isDisposed = true;
    for (final timer in _activeTimers) {
      timer.cancel();
    }
    _activeTimers.clear();
    _connectionStateController.close();
    _commandResultsController.close();
  }
}
