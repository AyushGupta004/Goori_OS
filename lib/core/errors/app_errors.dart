import 'dart:async';
import 'dart:io';

/// Centralized repository of user-facing friendly error messages.
///
/// Ensures raw exceptions (e.g. SocketException, FormatException, raw JSON/error codes)
/// never reach the user interface.
class AppErrors {
  // 1. Windows not found
  static const String windowsNotFound =
      "Couldn't connect to Windows. Make sure your phone and PC are connected to the same network.";

  // 2. Pairing failed
  static const String pairingFailed =
      'Failed to pair with your Windows computer. Please verify the connection and try again.';

  // 3. Invalid pairing code
  static const String invalidPairingCode =
      'Invalid 6-digit code. Please enter the code currently displayed on your Windows computer.';

  // 4. Token expired / rejected
  static const String tokenExpired =
      'Session expired or credentials rejected. Please pair your device again.';

  // 5. Authentication failed
  static const String authenticationFailed =
      'Authentication failed. Unable to verify device credentials with Windows Bridge.';

  // 6. Connection lost
  static const String connectionLost =
      'Connection to Windows PC was lost. Reconnecting...';

  // 7. Upload failed
  static const String uploadFailed =
      'File transfer failed. Please check your connection and try again.';

  // 8. Command failed
  static const String commandFailed =
      'Command execution failed. Make sure Windows AI Bridge is running on your PC.';

  // 9. Permission denied (mic / storage)
  static const String permissionDeniedMic =
      'Microphone access is required to use voice commands. Please allow permission in system settings.';

  static const String permissionDeniedStorage =
      'Storage access is required to transfer files. Please allow permission in system settings.';

  // 10. Protocol Version Mismatch
  static const String versionMismatch =
      'This Windows Bridge version is not compatible with this application';
}

/// Mapper translating technical exceptions and raw bridge error codes into
/// centralized, friendly messages.
class AppErrorMapper {
  /// Maps any exception, string, or error code into a user-friendly copy.
  static String map(dynamic error, {String? fallback}) {
    if (error == null) {
      return fallback ?? 'An unexpected error occurred. Please try again.';
    }

    if (error is SocketException) {
      return AppErrors.connectionLost;
    }

    if (error is TimeoutException) {
      return AppErrors.windowsNotFound;
    }

    final raw = error.toString().toLowerCase();

    // Protocol version mismatch
    if (raw.contains('incompatible') ||
        raw.contains('version mismatch') ||
        (raw.contains('protocol') && raw.contains('not compatible')) ||
        raw.contains('version is not compatible')) {
      return AppErrors.versionMismatch;
    }

    // Invalid pairing PIN
    if (raw.contains('invalid_pairing_code') ||
        raw.contains('invalid code') ||
        raw.contains('invalid pin') ||
        raw.contains('numeric digits')) {
      return AppErrors.invalidPairingCode;
    }

    // Pairing failure
    if (raw.contains('pairing_failed') ||
        raw.contains('pairing failed') ||
        raw.contains('pair error')) {
      return AppErrors.pairingFailed;
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
    if (raw.contains('device_not_found') ||
        raw.contains('not_found') ||
        raw.contains('no windows bridge hosts') ||
        raw.contains("couldn't connect to windows") ||
        raw.contains("couldn't find")) {
      return AppErrors.windowsNotFound;
    }

    // Connection lost / network drops
    if (raw.contains('not_connected') ||
        raw.contains('connection lost') ||
        raw.contains('disconnected') ||
        raw.contains('connection dropped') ||
        raw.contains('socketexception') ||
        raw.contains('connection refused') ||
        raw.contains('connection reset') ||
        raw.contains('broken pipe') ||
        raw.contains('network is unreachable')) {
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
        raw.contains('multipart')) {
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
