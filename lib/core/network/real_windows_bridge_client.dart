import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../constants/app_constants.dart';
import '../errors/app_errors.dart';
import '../models/models.dart';
import 'config.dart';
import 'windows_bridge_client.dart';

/// Production-ready client implementing [WindowsBridgeClient] over real WebSocket and HTTP transports.
///
/// Implements the wire protocol:
/// - WebSocket: `ws://{host}:{port}/ws` (or `wss://`)
/// - Authentication: `{"type":"authenticate","token":"..."}` → `{"type":"auth_result","success":bool,"error":"..."?}`
/// - Command: `{"type":"command","request_id":"...","timestamp":...,"data":{"command":"..."}}`
/// - Command Result: `{"type":"command_result","request_id":"...","success":bool,"data":{...}}`
/// - Uploads: `POST /upload/file` and `POST /upload/photo` multipart with streamed chunks and Bearer auth.
class RealWindowsBridgeClient implements WindowsBridgeClient {
  final http.Client _httpClient;
  WebSocketChannel? _wsChannel;
  StreamSubscription<dynamic>? _wsSubscription;

  final StreamController<ConnectionState> _connectionStateController =
      StreamController<ConnectionState>.broadcast();

  final StreamController<CommandResult> _commandResultsController =
      StreamController<CommandResult>.broadcast();

  ConnectionState _currentState = ConnectionState.disconnected;
  BridgeConfig? _activeConfig;
  String? _authToken;

  /// Active authentication token for authenticated REST uploads.
  String? get authToken => _authToken;

  /// Sets or updates the active authentication token.
  void setAuthToken(String? token) {
    _authToken = token;
  }

  Completer<AuthenticationResponse>? _pendingAuthCompleter;
  final Map<String, Completer<CommandResult>> _pendingCommands = {};

  RealWindowsBridgeClient({
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  @override
  Stream<ConnectionState> get connectionState =>
      _connectionStateController.stream;

  @override
  ConnectionState get currentConnectionState => _currentState;

  @override
  Stream<CommandResult> get commandResults => _commandResultsController.stream;

  void _emitState(ConnectionState state) {
    _currentState = state;
    _connectionStateController.add(state);
  }

  @override
  void configure(BridgeConfig config) {
    _activeConfig = config;
  }

  @override
  Future<bool> checkHealth() async {
    if (_activeConfig == null) return false;
    try {
      final healthUri = Uri.parse('${_activeConfig!.httpBaseUrl}/health');
      final response = await _httpClient.get(healthUri).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[RealWindowsBridgeClient] Health check failed for ${_activeConfig?.httpBaseUrl}: $e');
      return false;
    }
  }

  @override
  Future<void> connect(BridgeConfig config) async {
    _activeConfig = config;
    _emitState(ConnectionState.connecting);

    try {
      final wsUri = Uri.parse(config.wsBaseUrl);
      _wsChannel = WebSocketChannel.connect(wsUri);
      await _wsChannel!.ready.timeout(const Duration(seconds: 5));

      _wsSubscription = _wsChannel!.stream.listen(
        _handleWebSocketMessage,
        onError: (error) {
          _emitState(ConnectionState.disconnected);
        },
        onDone: () {
          _emitState(ConnectionState.disconnected);
        },
      );

      _emitState(ConnectionState.connected);
    } catch (e) {
      _emitState(ConnectionState.disconnected);
      rethrow;
    }
  }

  void _handleWebSocketMessage(dynamic rawMessage) {
    try {
      final json = jsonDecode(rawMessage.toString()) as Map<String, dynamic>;
      final type = json['type'] as String?;

      switch (type) {
        case 'auth_result':
          final success = json['success'] as bool? ?? false;
          final error =
              json['error'] as String? ?? json['errorMessage'] as String?;
          final deviceId = json['device_id'] as String? ??
              json['deviceId'] as String? ??
              '';
          final version = json['version'] as String? ??
              json['protocolVersion'] as String? ??
              json['protocol_version'] as String? ??
              '1.0';

          if (success) {
            _emitState(ConnectionState.connected);
          } else {
            _emitState(ConnectionState.disconnected);
          }

          if (_pendingAuthCompleter != null &&
              !_pendingAuthCompleter!.isCompleted) {
            _pendingAuthCompleter!.complete(
              AuthenticationResponse(
                authenticated: success,
                deviceId: deviceId,
                serverVersion: version,
                protocolVersion: version,
                errorMessage: error,
              ),
            );
          }
          break;

        case 'command_result':
          final requestId = json['request_id'] as String? ??
              json['commandId'] as String? ??
              '';
          final data = json['data'] as Map<String, dynamic>? ?? json;
          final success = json['success'] as bool? ??
              (data['status'] == 'completed');

          final timestampVal = json['timestamp'];
          final ts = timestampVal is int
              ? DateTime.fromMillisecondsSinceEpoch(timestampVal)
              : DateTime.now();

          final executionMs = (data['execution_time_ms'] as num? ??
                  data['executionTimeMs'] as num? ??
                  json['execution_time_ms'] as num? ??
                  json['executionTimeMs'] as num?)
              ?.toInt();

          final result = CommandResult(
            commandId: requestId,
            success: success,
            status: data['status'] as String? ??
                json['status'] as String? ??
                (success ? 'completed' : 'failed'),
            message: data['message'] as String? ??
                json['message'] as String? ??
                '',
            timestamp: ts,
            executionTimeMs: executionMs,
            errorDetails: data['error'] as String? ??
                data['errorDetails'] as String? ??
                json['error'] as String? ??
                json['errorDetails'] as String?,
          );

          _commandResultsController.add(result);

          if (_pendingCommands.containsKey(requestId)) {
            _pendingCommands.remove(requestId)?.complete(result);
          }
          break;

        default:
          // Unhandled or auxiliary message type (e.g. status_update, pong)
          break;
      }
    } catch (_) {
      // Discard malformed bridge frame
    }
  }

  @override
  Future<PairingResponse> pair(String code) async {
    if (_activeConfig == null) {
      return PairingResponse(
        success: false,
        deviceId: '',
        failure: BridgeFailure.unreachable,
        errorMessage: AppErrorMapper.mapFailure(BridgeFailure.unreachable),
        protocolVersion: AppConstants.protocolVersion,
      );
    }

    // Step 1: Preflight health check (5s timeout)
    final isHealthy = await checkHealth();
    if (!isHealthy) {
      debugPrint(
        '[RealWindowsBridgeClient] Pre-pair health check failed for ${_activeConfig!.httpBaseUrl}',
      );
      return PairingResponse(
        success: false,
        deviceId: '',
        failure: BridgeFailure.unreachable,
        errorMessage: AppErrorMapper.mapFailure(
          BridgeFailure.unreachable,
          host: _activeConfig!.host,
        ),
        protocolVersion: _activeConfig!.protocolVersion,
      );
    }

    // Step 2: POST /pair (10s timeout)
    final endpoint = Uri.parse('${_activeConfig!.httpBaseUrl}/pair');
    try {
      final response = await _httpClient
          .post(
            endpoint,
            headers: {
              'Content-Type': 'application/json',
              'X-Protocol-Version': _activeConfig!.protocolVersion,
            },
            body: jsonEncode({
              'code': code.trim(),
              'protocolVersion': _activeConfig!.protocolVersion,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final pairing = PairingResponse.fromJson(body);
        if (pairing.success && pairing.sessionToken != null) {
          _authToken = pairing.sessionToken;
          return pairing;
        } else {
          final failure = _determineFailure(response.statusCode, response.body);
          return PairingResponse(
            success: false,
            deviceId: pairing.deviceId,
            failure: failure,
            errorMessage: AppErrorMapper.mapFailure(
              failure,
              host: _activeConfig!.host,
            ),
            protocolVersion: _activeConfig!.protocolVersion,
          );
        }
      } else {
        final failure = _determineFailure(response.statusCode, response.body);
        return PairingResponse(
          success: false,
          deviceId: '',
          failure: failure,
          errorMessage: AppErrorMapper.mapFailure(
            failure,
            host: _activeConfig!.host,
          ),
          protocolVersion: _activeConfig!.protocolVersion,
        );
      }
    } catch (e) {
      debugPrint('[RealWindowsBridgeClient] pair() exception: $e');
      final failure =
          (e is TimeoutException || e is SocketException || e is HttpException)
              ? BridgeFailure.unreachable
              : BridgeFailure.serverError;
      return PairingResponse(
        success: false,
        deviceId: '',
        failure: failure,
        errorMessage: AppErrorMapper.mapFailure(
          failure,
          host: _activeConfig?.host,
        ),
        protocolVersion:
            _activeConfig?.protocolVersion ?? AppConstants.protocolVersion,
      );
    }
  }

  BridgeFailure _determineFailure(int statusCode, String responseBody) {
    final lower = responseBody.toLowerCase();
    if (statusCode >= 500) {
      return BridgeFailure.serverError;
    }
    if (lower.contains('version') || lower.contains('incompatible')) {
      return BridgeFailure.versionMismatch;
    }
    if (lower.contains('expired')) {
      return BridgeFailure.expiredPin;
    }
    if (lower.contains('unreachable') || lower.contains('not_found')) {
      return BridgeFailure.unreachable;
    }
    return BridgeFailure.wrongPin;
  }

  @override
  Future<AuthenticationResponse> authenticate(String token) async {
    if (_wsChannel == null || _currentState != ConnectionState.connected) {
      return const AuthenticationResponse(
        authenticated: false,
        deviceId: '',
        serverVersion: '1.0',
        errorMessage: 'NOT_CONNECTED: Cannot authenticate without active WebSocket connection.',
      );
    }

    _authToken = token;
    _emitState(ConnectionState.authenticating);
    _pendingAuthCompleter = Completer<AuthenticationResponse>();

    final authMessage = {
      'type': 'authenticate',
      'token': token,
      'protocol_version':
          _activeConfig?.protocolVersion ?? AppConstants.protocolVersion,
    };

    _wsChannel!.sink.add(jsonEncode(authMessage));

    try {
      return await _pendingAuthCompleter!.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          _emitState(ConnectionState.disconnected);
          return const AuthenticationResponse(
            authenticated: false,
            deviceId: '',
            serverVersion: '1.0',
            errorMessage: 'AUTH_TIMEOUT: Windows Bridge did not respond to auth challenge.',
          );
        },
      );
    } catch (e) {
      _emitState(ConnectionState.disconnected);
      return AuthenticationResponse(
        authenticated: false,
        deviceId: '',
        serverVersion: '1.0',
        errorMessage: 'AUTH_ERROR: ${e.toString()}',
      );
    }
  }

  @override
  Future<CommandResult> sendCommand(CommandRequest request) async {
    if (_wsChannel == null || _currentState != ConnectionState.connected) {
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

    final completer = Completer<CommandResult>();
    _pendingCommands[request.commandId] = completer;

    final wireMessage = {
      'type': 'command',
      'request_id': request.commandId,
      'timestamp': request.timestamp.millisecondsSinceEpoch,
      'data': {
        'command': request.payload,
        'type': request.type,
        if (request.metadata != null) 'metadata': request.metadata,
      },
    };

    _wsChannel!.sink.add(jsonEncode(wireMessage));

    try {
      return await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          _pendingCommands.remove(request.commandId);
          final timeoutResult = CommandResult(
            commandId: request.commandId,
            success: false,
            status: 'timeout',
            message: 'Command timed out waiting for Windows host response.',
            timestamp: DateTime.now(),
            errorDetails: 'TIMEOUT',
          );
          _commandResultsController.add(timeoutResult);
          return timeoutResult;
        },
      );
    } catch (e) {
      _pendingCommands.remove(request.commandId);
      final errorResult = CommandResult(
        commandId: request.commandId,
        success: false,
        status: 'error',
        message: 'Transport error sending command: ${e.toString()}',
        timestamp: DateTime.now(),
        errorDetails: 'TRANSPORT_ERROR',
      );
      _commandResultsController.add(errorResult);
      return errorResult;
    }
  }

  @override
  Future<void> uploadFile(
    File file, {
    required void Function(TransferProgress progress) onProgress,
  }) async {
    await _streamMultipartUpload(
      endpointPath: '/upload/file',
      file: file,
      field: 'file',
      onProgress: onProgress,
    );
  }

  @override
  Future<void> uploadPhoto(
    File photo, {
    required void Function(TransferProgress progress) onProgress,
  }) async {
    await _streamMultipartUpload(
      endpointPath: '/upload/photo',
      file: photo,
      field: 'photo',
      onProgress: onProgress,
    );
  }

  /// Streams the file chunk-by-chunk using [http.MultipartRequest] without loading
  /// the full file contents into memory.
  Future<void> _streamMultipartUpload({
    required String endpointPath,
    required File file,
    required String field,
    required void Function(TransferProgress progress) onProgress,
  }) async {
    if (_activeConfig == null) {
      throw BridgeError(
        code: 'NOT_CONFIGURED',
        message: 'Bridge configuration not set.',
        timestamp: DateTime.now(),
      );
    }

    final transferId = 'tx_${DateTime.now().millisecondsSinceEpoch}';
    final totalBytes = await file.length();
    final uri = Uri.parse('${_activeConfig!.httpBaseUrl}$endpointPath');

    onProgress(
      TransferProgress(
        transferId: transferId,
        bytesTransferred: 0,
        totalBytes: totalBytes,
        status: TransferStatus.waiting,
      ),
    );

    int bytesSent = 0;
    final fileStream = file.openRead();

    // StreamTransformer intercepts stream chunks to track byte progress on the fly
    final progressStream = fileStream.transform(
      StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleData: (chunk, sink) {
          bytesSent += chunk.length;
          onProgress(
            TransferProgress(
              transferId: transferId,
              bytesTransferred: bytesSent,
              totalBytes: totalBytes,
              status: bytesSent >= totalBytes
                  ? TransferStatus.completed
                  : TransferStatus.uploading,
            ),
          );
          sink.add(chunk);
        },
        handleError: (error, stackTrace, sink) {
          debugPrint('[RealWindowsBridgeClient] Upload stream error: $error');
          onProgress(
            TransferProgress(
              transferId: transferId,
              bytesTransferred: bytesSent,
              totalBytes: totalBytes,
              status: TransferStatus.failed,
              errorMessage: AppErrorMapper.map(error, fallback: AppErrors.uploadFailed),
            ),
          );
          sink.addError(error, stackTrace);
        },
      ),
    );

    // Idle timeout: resets timer each time a chunk is emitted (not a total-duration cap)
    final idleProgressStream = progressStream.timeout(
      const Duration(seconds: 15),
      onTimeout: (sink) {
        debugPrint('[RealWindowsBridgeClient] Upload stream idle timeout (15s)');
        sink.addError(TimeoutException('Upload stalled: connection idle'));
      },
    );

    final request = http.MultipartRequest('POST', uri);
    if (_authToken != null) {
      request.headers['Authorization'] = 'Bearer $_authToken';
    }
    request.headers['X-Protocol-Version'] = _activeConfig!.protocolVersion;

    final fileName = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : 'upload.bin';

    request.files.add(
      http.MultipartFile(
        field,
        idleProgressStream,
        totalBytes,
        filename: fileName,
      ),
    );

    try {
      final streamedResponse = await _httpClient.send(request).timeout(const Duration(seconds: 15));
      if (streamedResponse.statusCode != 200 &&
          streamedResponse.statusCode != 201) {
        final responseBody = await streamedResponse.stream.bytesToString().timeout(const Duration(seconds: 10));
        debugPrint('[RealWindowsBridgeClient] Upload rejected HTTP ${streamedResponse.statusCode}: $responseBody');
        final friendlyMsg = AppErrorMapper.map(responseBody, fallback: AppErrors.uploadFailed);
        onProgress(
          TransferProgress(
            transferId: transferId,
            bytesTransferred: bytesSent,
            totalBytes: totalBytes,
            status: TransferStatus.failed,
            errorMessage: friendlyMsg,
          ),
        );
        throw BridgeError(
          code: 'UPLOAD_FAILED',
          message: friendlyMsg,
          details: responseBody,
          timestamp: DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint('[RealWindowsBridgeClient] Upload exception: $e');
      final friendlyMsg = AppErrorMapper.map(e, fallback: AppErrors.uploadFailed);
      onProgress(
        TransferProgress(
          transferId: transferId,
          bytesTransferred: bytesSent,
          totalBytes: totalBytes,
          status: TransferStatus.failed,
          errorMessage: friendlyMsg,
        ),
      );
      if (e is BridgeError) rethrow;
      throw BridgeError(
        code: 'UPLOAD_FAILED',
        message: friendlyMsg,
        timestamp: DateTime.now(),
      );
    }
  }

  @override
  Future<void> disconnect() async {
    await _wsSubscription?.cancel();
    _wsSubscription = null;
    await _wsChannel?.sink.close();
    _wsChannel = null;
    _emitState(ConnectionState.disconnected);

    for (final completer in _pendingCommands.values) {
      if (!completer.isCompleted) {
        completer.completeError(
          BridgeError(
            code: 'DISCONNECTED',
            message: 'Bridge client disconnected while command was in flight.',
            timestamp: DateTime.now(),
          ),
        );
      }
    }
    _pendingCommands.clear();
  }

  void dispose() {
    disconnect();
    _connectionStateController.close();
    _commandResultsController.close();
    _httpClient.close();
  }
}
