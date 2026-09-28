import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/config.dart';
import '../core/network/bridge_config_provider.dart';
import '../core/services/connection_service.dart';
import '../core/storage/secure_storage_service.dart';
import '../features/connection/screens/discovery_screen.dart';
import '../features/onboarding/screens/onboarding_screen.dart';
import 'routes.dart';
import 'shell.dart';
import 'theme.dart';

/// Startup Gate determining the initial landing view based on persistent pairing credentials.
///
/// Specification (Task 4 & Task 7):
/// - In [BridgeMode.mock], boots directly into AppShell for seamless automated widget testing.
/// - In live modes:
///   - If no credentials exist:
///     - First launch -> OnboardingScreen.
///     - Subsequent launch -> DiscoveryScreen.
///   - If credentials exist -> AppShell with silent reauth in background.
///     - If unreachable -> keep credentials, Home shows Offline card with RETRY.
///     - If token rejected -> clear credentials and route to DiscoveryScreen.
class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  bool _isLoading = true;
  Widget? _landingWidget;

  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _evaluateStartupDestination();
    }
  }

  Future<void> _evaluateStartupDestination() async {
    try {
      final configProvider = context.read<BridgeConfigProvider>();
      final secureStorage = context.read<SecureStorageService>();
      final connectionService = context.read<ConnectionService>();

    // 1. Mock mode boots directly into AppShell for widget tests
    if (configProvider.config.mode == BridgeMode.mock) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _landingWidget = const AppShell(initialIndex: 0);
        });
      }
      return;
    }

    // 2. Check for stored credentials in SecureStorage
    String? token;
    String? host;
    try {
      token = await secureStorage.getToken();
      host = await secureStorage.getHost();
    } catch (_) {}

    if (token != null && token.isNotEmpty && host != null && host.isNotEmpty) {
      // Credentials present -> boot into AppShell
      await connectionService.checkPairedState();
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _landingWidget = const AppShell(initialIndex: 0);
      });

      // Execute silent re-authentication in the background
      _executeSilentReauth(connectionService, configProvider.config.mode);
      return;
    }

    // 3. No credentials present -> check onboarding state
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _landingWidget = hasSeenOnboarding
            ? const DiscoveryScreen()
            : const OnboardingScreen();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _landingWidget = const DiscoveryScreen();
      });
    }
  } catch (_) {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _landingWidget = const OnboardingScreen();
      });
    }
  }
}

  Future<void> _executeSilentReauth(
    ConnectionService connectionService,
    BridgeMode mode,
  ) async {
    final result = await connectionService.silentReauthenticate(mode: mode);
    if (!mounted) return;

    if (result == StartupFlowResult.pairingRequired) {
      // Stored token was rejected by the bridge: navigate to discovery
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.discovery,
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _landingWidget == null) {
      final palette = context.palette;
      return Scaffold(
        backgroundColor: palette.background,
        body: const Center(),
      );
    }

    return _landingWidget!;
  }
}
