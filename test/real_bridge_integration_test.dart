import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:goori_os/core/constants/app_constants.dart';
import 'package:goori_os/core/models/models.dart';
import 'package:goori_os/core/network/config.dart';
import 'package:goori_os/core/network/real_windows_bridge_client.dart';
import 'package:http/http.dart' as http;

void main() {
  HttpOverrides.global = null;
  Process? backendProcess;
  const bridgeHost = '127.0.0.1';
  const bridgePort = 7890;

  setUpAll(() async {
    final client = http.Client();
    bool ready = false;
    try {
      final resp = await client.get(Uri.parse('http://$bridgeHost:$bridgePort/api/status'));
      if (resp.statusCode == 200) {
        ready = true;
      }
    } catch (_) {}

    if (!ready) {
      final possibleDirs = [
        r'c:\Users\Aayush\OneDrive\Desktop\web_app\Ai_voice',
        r'D:\web_app\Ai_voice',
      ];
      String? targetDir;
      for (final d in possibleDirs) {
        if (Directory(d).existsSync()) {
          targetDir = d;
          break;
        }
      }

      if (targetDir != null) {
        backendProcess = await Process.start(
          'python',
          ['-m', 'uvicorn', 'backend.main:app', '--host', bridgeHost, '--port', '$bridgePort'],
          workingDirectory: targetDir,
        );
      }

      for (int i = 0; i < 30; i++) {
        try {
          final resp = await client.get(Uri.parse('http://$bridgeHost:$bridgePort/api/status'));
          if (resp.statusCode == 200) {
            ready = true;
            break;
          }
        } catch (_) {}
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    client.close();

    if (!ready) {
      throw StateError('Companion Windows Bridge backend failed to start on port $bridgePort.');
    }
  });

  tearDownAll(() async {
    if (backendProcess != null) {
      backendProcess!.kill(ProcessSignal.sigterm);
      backendProcess!.kill(ProcessSignal.sigkill);
      await backendProcess!.exitCode;
    }
  });

  test('TASK 5: Full real-bridge integration test against companion Windows Bridge (Prompt A)', () async {
    final realClient = RealWindowsBridgeClient();
    const config = BridgeConfig(
      host: bridgeHost,
      port: bridgePort,
      mode: BridgeMode.dev,
    );

    await realClient.connect(config);

    // 1. Wrong 6-digit PIN rejected with clear error
    final wrongPinResponse = await realClient.pair('000000');
    expect(wrongPinResponse.success, isFalse);
    expect(wrongPinResponse.failure, equals(BridgeFailure.wrongPin));
    expect(
      wrongPinResponse.errorMessage,
      anyOf(contains('INVALID_PAIRING_CODE'), contains("That code isn't correct")),
    );

    // 2. Fetch active PIN from companion server status
    final statusResp = await http.get(Uri.parse('http://$bridgeHost:$bridgePort/pair/status'));
    expect(statusResp.statusCode, equals(200));
    final statusData = jsonDecode(statusResp.body) as Map<String, dynamic>;
    final correctPin = statusData['code'] as String?;
    expect(correctPin, isNotNull);
    expect(correctPin!.length, equals(6));

    // 3. Enter correct PIN -> pairing succeeds
    final correctPairResponse = await realClient.pair(correctPin);
    expect(correctPairResponse.success, isTrue);
    expect(correctPairResponse.sessionToken, isNotNull);
    expect(correctPairResponse.deviceId, isNotEmpty);
    final sessionToken = correctPairResponse.sessionToken!;

    // 4. Authenticate WebSocket connection with session token
    final authResp = await realClient.authenticate(sessionToken);
    expect(authResp.authenticated, isTrue);

    // 5. Send command (voice / typed) and confirm execution
    final commandRequest = CommandRequest(
      commandId: 'cmd-test-${DateTime.now().millisecondsSinceEpoch}',
      type: 'voice_transcript',
      payload: 'Open Notepad',
      timestamp: DateTime.now(),
    );
    final commandResult = await realClient.sendCommand(commandRequest);
    expect(commandResult.success, isTrue);
    expect(commandResult.status, equals('completed'));

    // 6. Upload a file and verify it lands in uploads/files/mobile/
    final tempDir = await Directory.systemTemp.createTemp('bridge_upload_test_');
    final testFile = File('${tempDir.path}/integration_doc.txt');
    await testFile.writeAsString('Hello from Goori_OS integration test!');

    final fileProgresses = <TransferProgress>[];
    await realClient.uploadFile(
      testFile,
      onProgress: (p) => fileProgresses.add(p),
    );
    expect(fileProgresses.any((p) => p.status == TransferStatus.completed), isTrue);

    // 7. Upload a photo and verify it lands in uploads/files/mobile/photos/
    final testPhoto = File('${tempDir.path}/integration_photo.jpg');
    await testPhoto.writeAsBytes(List.filled(1024, 0xFF));

    final photoProgresses = <TransferProgress>[];
    await realClient.uploadPhoto(
      testPhoto,
      onProgress: (p) => photoProgresses.add(p),
    );
    expect(photoProgresses.any((p) => p.status == TransferStatus.completed), isTrue);

    // 8. Confirm files appear in Nova OS Files app (/files endpoint)
    final filesResp = await http.get(Uri.parse('http://$bridgeHost:$bridgePort/files'));
    expect(filesResp.statusCode, equals(200));
    final filesData = jsonDecode(filesResp.body) as Map<String, dynamic>;
    final filesList = filesData['files'] as List<dynamic>;

    final hasUploadedFile = filesList.any((f) => f['name'] == 'integration_doc.txt');
    final hasUploadedPhoto = filesList.any((f) => f['name'] == 'integration_photo.jpg');

    expect(hasUploadedFile, isTrue);
    expect(hasUploadedPhoto, isTrue);

    // Disconnect cleanly
    await realClient.disconnect();
    await tempDir.delete(recursive: true);
  });
}
