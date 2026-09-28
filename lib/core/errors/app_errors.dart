import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

import '../models/pairing_response.dart';

/// Centralized repository of user-facing friendly error messages.
///
/// Ensures raw exceptions (e.g. SocketException, FormatException, raw JSON/error codes)
/// never reach the user interface.
class AppErrors {
  // 1. Unreachable / Windows not found
  static String unreachable([String? host]) => host != null && host.isNotEmpty
      ? "Can't reach your PC at $host. Make sure the Windows bridge is running and both devices are on the same Wi-Fi."
      : "Can't reach your PC. Make sure the Windows bridge is running and both devices are on the same Wi-Fi.";

  static const String windowsNotFound =
      "Couldn't connect to Windows. Make sure your phone and PC are connected to the same network.";

  // 2. Pairing & PIN errors
  static const String wrongPin =
      "That code isn't correct. Enter the code currently shown on your PC.";

  static const String expiredPin =
      "That code has expired. Enter the code currently shown on your PC.";

  static const String invalidPairingCode = wrongPin;

  static const String pairingFailed =
      'Failed to pair with your Windows computer. Please verify the connection and try again.';

  // 3. Server & version errors
  static const String serverError =
      'The Windows bridge encountered an error. Please try again.';

  static const String versionMismatch =
      'This Windows Bridge version is not compatible with this application';

  // 4. Session & auth
  static const String tokenExpired =
      'Session expired or credentials rejected. Please pair your device again.';

  static const String authenticationFailed =
      'Authentication failed. Unable to verify device credentials with Windows Bridge.';

  // 5. Connection state
  static const String connectionLost =
      'Connection to Windows PC was lost. Reconnecting...';

  static const String notConnected = 'Not connected to PC';

  // 6. Upload & commands
  static const String uploadFailed =
      'File transfer failed. Please check your connection and try again.';

  static const String commandFailed =
      'Command execution failed. Make sure Windows AI Bridge is running on your PC.';

  // 7. Permissions
  static const String permissionDeniedMic =
      'Microphone access is required to use voice commands. Please allow permission in system settings.';

  static const String permissionDeniedStorage =
      'Storage access is required to transfer files. Please allow permission in system settings.';

  // 8. Collapsible Troubleshooting Steps
  static const List<String> troubleshootingSteps = [
    'Windows bridge is running on your PC',
    'Windows Firewall allows ports 7890 and 7891',
    'Both devices are on the same Wi-Fi network',
    'Router client / AP isolation is turned off',
  ];
}

/// Mapper translating technical exceptions and raw bridge error codes into
/// centralized, friendly messages.
class AppErrorMapper {
  /// Maps a strongly typed [BridgeFailure] into friendly user copy.
  static String mapFailure(BridgeFailure failure, {String? host}) {
    switch (failure) {
      case BridgeFailure.unreachable:
        return AppErrors.unreachable(host);
      case BridgeFailure.wrongPin:
        return AppErrors.wrongPin;
      case BridgeFailure.expiredPin:
        return AppErrors.expiredPin;
      case BridgeFailure.versionMismatch:
        return AppErrors.versionMismatch;
      case BridgeFailure.serverError:
        return AppErrors.serverError;
      case BridgeFailure.unknown:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Maps any exception, string, or error code into a user-friendly copy.
  static String map(dynamic error, {String? host, String? fallback}) {
    if (error == null) {
      return fallback ?? 'An unexpected error occurred. Please try again.';
    }

    if (error is BridgeFailure) {
      return mapFailure(error, host: host);
    }

    // Log technical detail for diagnostics only
    debugPrint('[AppErrorMapper] Mapping technical error: $error');

    if (error is SocketException) {
      return AppErrors.unreachable(host);
    }

    if (error is TimeoutException) {
      return AppErrors.unreachable(host);
    }

    if (error is HttpException) {
      return AppErrors.unreachable(host);
    }

    final raw = error.toString().toLowerCase();

    // Protocol version mismatch
    if (raw.contains('incompatible') ||
        raw.contains('version mismatch') ||
        raw.contains('version_mismatch') ||
        (raw.contains('protocol') && raw.contains('not compatible')) ||
        raw.contains('version is not compatible')) {
      return AppErrors.versionMismatch;
    }

    // Invalid / wrong pairing PIN
    if (raw.contains('wrong_pin') ||
        raw.contains('wrong pin') ||
        raw.contains('invalid_pairing_code') ||
        raw.contains('invalid code') ||
        raw.contains('invalid pin') ||
        raw.contains('numeric digits') ||
        raw.contains('incorrect pin')) {
      return AppErrors.wrongPin;
    }

    // Expired PIN
    if (raw.contains('expired_pin') ||
        raw.contains('pin expired') ||
        raw.contains('code expired')) {
      return AppErrors.expiredPin;
    }

    // Pairing failure
    if (raw.contains('pairing_failed') ||
        raw.contains('pairing failed') ||
        raw.contains('pair error')) {
      return AppErrors.pairingFailed;
    }

    // Server error
    if (raw.contains('server_error') ||
        raw.contains('http 500') ||
        raw.contains('http 502') ||
        raw.contains('http 503') ||
        raw.contains('internal server error')) {
      return AppErrors.serverError;
    }

    // Token expired / rejected
    if (raw.contains('token_expired') ||
        raw.contains('invalid_token') ||
        raw.contains('stale token') ||
        raw.contains('token rejected') ||
        raw.contains('session expired')) {
      return AppErrors.tokenExpired;
    }

    // Authentication failure
    if (raw.contains('auth_failed') ||
        raw.contains('auth_error') ||
        raw.contains('auth_timeout') ||
        raw.contains('authentication failed') ||
        raw.contains('auth challenge') ||
        raw.contains('auth exception')) {
      return AppErrors.authenticationFailed;
    }

    // Device not found / discovery
    if (raw.contains('no windows bridge hosts') ||
        raw.contains("couldn't connect to windows")) {
      return AppErrors.windowsNotFound;
    }
    if (raw.contains('device_not_found') ||
        raw.contains('not_found') ||
        raw.contains("couldn't find")) {
      return AppErrors.unreachable(host);
    }

    // Connection lost / unreachable / network drops / not configured
    if (raw.contains('not_configured')) {
      return AppErrors.notConnected;
    }
    if (raw.contains('unreachable') ||
        raw.contains('errno 110') ||
        raw.contains('failed host lookup') ||
        raw.contains('network is unreachable')) {
      return AppErrors.unreachable(host);
    }
    if (raw.contains('not_connected') ||
        raw.contains('connection lost') ||
        raw.contains('disconnected') ||
        raw.contains('connection dropped') ||
        raw.contains('connection refused') ||
        raw.contains('errno 111') ||
        raw.contains('socketexception') ||
        raw.contains('connection reset') ||
        raw.contains('broken pipe')) {
      return AppErrors.connectionLost;
    }

    // Permission denied
    if (raw.contains('mic') && raw.contains('permission')) {
      return AppErrors.permissionDeniedMic;
    }
    if ((raw.contains('storage') || raw.contains('photo')) &&
        raw.contains('permission')) {
      return AppErrors.permissionDeniedStorage;
    }

    // Upload failed
    if (raw.contains('upload') ||
        raw.contains('transfer') ||
        raw.contains('multipart') ||
        raw.contains('stream interrupted')) {
      return AppErrors.uploadFailed;
    }

    // Command failed
    if (raw.contains('command') ||
        raw.contains('dispatch_error') ||
        raw.contains('simulated_execution_failure')) {
      return AppErrors.commandFailed;
    }

    return fallback ?? 'An unexpected error occurred. Please try again.';
  }
}
