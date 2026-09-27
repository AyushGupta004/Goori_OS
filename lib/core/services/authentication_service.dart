import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../network/windows_bridge_client.dart';
import '../storage/secure_storage_service.dart';

/// Service orchestrating session authentication and credential invalidation.
class AuthenticationService extends ChangeNotifier {
  final WindowsBridgeClient client;
  final SecureStorageService secureStorage;

  bool _isAuthenticating = false;
  bool _isAuthenticated = false;
  String? _errorMessage;
  AuthenticationResponse? _lastResponse;

  AuthenticationService({
    required this.client,
    required this.secureStorage,
  });

  bool get isAuthenticating => _isAuthenticating;
  bool get isAuthenticated => _isAuthenticated;
  String? get errorMessage => _errorMessage;
  AuthenticationResponse? get lastResponse => _lastResponse;

  /// Authenticates using the credentials persisted in [SecureStorageService].
  Future<AuthenticationResponse> authenticateWithStoredToken() async {
    final token = await secureStorage.getToken();
    if (token == null || token.isEmpty) {
      const failure = AuthenticationResponse(
        authenticated: false,
        deviceId: '',
        serverVersion: '1.0',
        errorMessage: 'NO_TOKEN_STORED: Device must be paired before authenticating.',
      );
      _isAuthenticated = false;
      _errorMessage = failure.errorMessage;
      _lastResponse = failure;
      notifyListeners();
      return failure;
    }

    return await authenticate(token);
  }

  /// Authenticates explicitly with a given [token].
  Future<AuthenticationResponse> authenticate(String token) async {
    _isAuthenticating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await client.authenticate(token);
      _lastResponse = response;
      _isAuthenticated = response.authenticated;

      if (!response.authenticated) {
        _errorMessage = response.errorMessage ?? 'Authentication failed.';
      } else {
        _errorMessage = null;
      }

      _isAuthenticating = false;
      notifyListeners();
      return response;
    } catch (e) {
      final errResponse = AuthenticationResponse(
        authenticated: false,
        deviceId: '',
        serverVersion: '1.0',
        errorMessage: 'Auth exception: ${e.toString()}',
      );
      _isAuthenticated = false;
      _errorMessage = errResponse.errorMessage;
      _lastResponse = errResponse;
      _isAuthenticating = false;
      notifyListeners();
      return errResponse;
    }
  }

  /// Clears stored credentials from [SecureStorageService] and disconnects client.
  Future<void> logout() async {
    await secureStorage.deleteToken();
    _isAuthenticated = false;
    _errorMessage = null;
    _lastResponse = null;
    await client.disconnect();
    notifyListeners();
  }
}
