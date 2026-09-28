import 'dart:async';
import 'dart:io';
import '../models/models.dart';
import 'config.dart';

/// Abstract service contract for all communication with the Windows AI automation host.
///
/// HARD CONSTRAINT:
/// UI and controllers NEVER touch WebSocket or HTTP directly. All network interaction
/// is routed exclusively through this client contract.
abstract class WindowsBridgeClient {
  /// Stream emitting changes to the bridge connection lifecycle.
  Stream<ConnectionState> get connectionState;

  /// Current instantaneous connection state.
  ConnectionState get currentConnectionState;

  /// Sets host/port/protocol configuration without opening sockets.
  void configure(BridgeConfig config);

  /// Performs a preflight health check probe against GET /health (5s).
  Future<HealthResult> checkHealth({Duration timeout = const Duration(seconds: 5)});

  /// Establishes communication transport with the bridge host using the provided [config].
  Future<void> connect(BridgeConfig config);

  /// Performs cryptographic pairing handshake using a 6-digit one-time PIN [code].
  Future<PairingResponse> pair(String code, {String? clientId});


  /// Authenticates an established session using a secure auth [token].
  Future<AuthenticationResponse> authenticate(String token);

  /// Submits a command request (voice transcript or text) for Windows AI execution.
  Future<CommandResult> sendCommand(CommandRequest request);

  /// Real-time stream of command lifecycle updates and execution results correlated by request_id.
  Stream<CommandResult> get commandResults;

  /// Streams a local file to the Windows host without loading the file fully into RAM.
  Future<void> uploadFile(
    File file, {
    required void Function(TransferProgress progress) onProgress,
  });

  /// Streams a photo to the Windows host without loading the file fully into RAM.
  Future<void> uploadPhoto(
    File photo, {
    required void Function(TransferProgress progress) onProgress,
  });

  /// Gracefully tears down the connection transport and resets state to disconnected.
  Future<void> disconnect();
}
