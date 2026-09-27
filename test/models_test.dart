import 'package:flutter_test/flutter_test.dart';
import 'package:goori_os/core/constants/app_constants.dart';
import 'package:goori_os/core/models/models.dart';

void main() {
  group('Core Models Serialization and Validation', () {
    test('WindowsDevice serialization / deserialization', () {
      final device = WindowsDevice(
        id: 'win-pc-001',
        name: 'DESKTOP-AUTOMATION',
        host: '192.168.1.100',
        port: 7890,
        isPaired: true,
        lastSeen: DateTime.utc(2026, 9, 27, 12, 0, 0),
        osVersion: 'Windows 11 Pro',
        fingerprint: 'SHA256:abcd1234efgh5678',
      );

      final json = device.toJson();
      final fromJson = WindowsDevice.fromJson(json);

      expect(fromJson.id, 'win-pc-001');
      expect(fromJson.name, 'DESKTOP-AUTOMATION');
      expect(fromJson.host, '192.168.1.100');
      expect(fromJson.port, 7890);
      expect(fromJson.isPaired, true);
      expect(fromJson.osVersion, 'Windows 11 Pro');
      expect(fromJson.fingerprint, 'SHA256:abcd1234efgh5678');
      expect(fromJson, equals(device));
    });

    test('PairingResponse serialization / deserialization', () {
      final response = PairingResponse(
        success: true,
        deviceId: 'win-pc-001',
        sessionToken: 'sec-tok-xyz',
        refreshToken: 'ref-tok-abc',
        expiresAt: DateTime.utc(2026, 9, 28, 12, 0, 0),
        protocolVersion: '1.0',
      );

      final json = response.toJson();
      final fromJson = PairingResponse.fromJson(json);

      expect(fromJson.success, true);
      expect(fromJson.deviceId, 'win-pc-001');
      expect(fromJson.sessionToken, 'sec-tok-xyz');
      expect(fromJson.refreshToken, 'ref-tok-abc');
      expect(fromJson.protocolVersion, '1.0');
    });

    test('AuthenticationResponse serialization / deserialization', () {
      final auth = AuthenticationResponse(
        authenticated: true,
        deviceId: 'win-pc-001',
        serverVersion: '1.0.0',
        permissions: ['commands', 'file_transfer', 'voice_stream'],
      );

      final json = auth.toJson();
      final fromJson = AuthenticationResponse.fromJson(json);

      expect(fromJson.authenticated, true);
      expect(fromJson.deviceId, 'win-pc-001');
      expect(fromJson.permissions, contains('voice_stream'));
    });

    test('CommandRequest serialization / deserialization', () {
      final request = CommandRequest(
        commandId: 'cmd-999',
        type: 'voice_transcript',
        payload: 'open visual studio code',
        timestamp: DateTime.utc(2026, 9, 27, 12, 5, 0),
        metadata: {'confidence': '0.98'},
      );

      final json = request.toJson();
      final fromJson = CommandRequest.fromJson(json);

      expect(fromJson.commandId, 'cmd-999');
      expect(fromJson.type, 'voice_transcript');
      expect(fromJson.payload, 'open visual studio code');
      expect(fromJson.metadata?['confidence'], '0.98');
    });

    test('CommandResult serialization / deserialization', () {
      final result = CommandResult(
        commandId: 'cmd-999',
        success: true,
        status: 'executed',
        message: 'Opened Visual Studio Code',
        timestamp: DateTime.utc(2026, 9, 27, 12, 5, 2),
        executionTimeMs: 142,
      );

      final json = result.toJson();
      final fromJson = CommandResult.fromJson(json);

      expect(fromJson.commandId, 'cmd-999');
      expect(fromJson.success, true);
      expect(fromJson.status, 'executed');
      expect(fromJson.executionTimeMs, 142);
    });

    test('TransferRequest serialization / deserialization', () {
      final req = TransferRequest(
        transferId: 'tx-1234',
        fileName: 'snapshot.png',
        fileSizeBytes: 204800,
        mimeType: 'image/png',
        transferType: 'photo',
        timestamp: DateTime.utc(2026, 9, 27, 12, 10, 0),
      );

      final json = req.toJson();
      final fromJson = TransferRequest.fromJson(json);

      expect(fromJson.transferId, 'tx-1234');
      expect(fromJson.fileName, 'snapshot.png');
      expect(fromJson.fileSizeBytes, 204800);
      expect(fromJson.transferType, 'photo');
    });

    test('TransferProgress fractions and states', () {
      final progress = TransferProgress(
        transferId: 'tx-1234',
        bytesTransferred: 102400,
        totalBytes: 204800,
        status: TransferStatus.uploading,
        speedBytesPerSecond: 51200,
      );

      expect(progress.fraction, 0.5);
      expect(progress.percentage, 50);
      expect(progress.isUploading, true);
      expect(progress.isFinished, false);

      final json = progress.toJson();
      final fromJson = TransferProgress.fromJson(json);

      expect(fromJson.bytesTransferred, 102400);
      expect(fromJson.status, TransferStatus.uploading);
    });

    test('BridgeError serialization and Exception contract', () {
      final err = BridgeError(
        code: 'AUTH_FAILED',
        message: 'Invalid pairing token',
        details: 'Token expired 10 minutes ago',
        timestamp: DateTime.utc(2026, 9, 27, 12, 15, 0),
      );

      expect(err, isA<Exception>());
      final json = err.toJson();
      final fromJson = BridgeError.fromJson(json);

      expect(fromJson.code, 'AUTH_FAILED');
      expect(fromJson.message, 'Invalid pairing token');
      expect(fromJson.details, 'Token expired 10 minutes ago');
    });

    test('ConnectionState enum helpers and parsing', () {
      expect(ConnectionState.connected.isConnected, true);
      expect(ConnectionState.connecting.isTransitioning, true);
      expect(ConnectionState.authenticating.isTransitioning, true);
      expect(ConnectionState.disconnected.isConnected, false);

      expect(ConnectionState.fromString('connected'), ConnectionState.connected);
      expect(ConnectionState.fromString('authenticating'),
          ConnectionState.authenticating);
      expect(ConnectionState.fromString('invalid'), ConnectionState.disconnected);
    });

    test('TransferStatus enum parsing and serialization', () {
      expect(TransferStatus.fromString('uploading'), TransferStatus.uploading);
      expect(TransferStatus.fromString('completed'), TransferStatus.completed);
      expect(TransferStatus.fromString('unknown'), TransferStatus.failed);
      expect(TransferStatus.uploading.toJson(), 'uploading');
    });
  });
}
