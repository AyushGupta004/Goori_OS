import 'package:flutter/material.dart';
import '../features/connection/screens/discovery_screen.dart';
import '../features/connection/screens/home_screen.dart';
import '../features/connection/screens/pairing_screen.dart';
import '../features/onboarding/screens/onboarding_screen.dart';
import '../features/voice/screens/commands_screen.dart';
import '../features/voice/screens/voice_screen.dart';
import 'shell.dart';

/// Centralized named route identifiers and route generation for Windows Remote.
class AppRoutes {
  AppRoutes._();

  static const String home = '/';
  static const String onboarding = '/onboarding';
  static const String discovery = '/discovery';
  static const String pairing = '/pairing';
  static const String voice = '/voice';
  static const String commands = '/commands';
  static const String files = '/files';
  static const String photos = '/photos';
  static const String settings = '/settings';

  /// Map of all static named routes in the application.
  static Map<String, WidgetBuilder> get routes => {
        home: (context) => const AppShell(initialIndex: 0),
        onboarding: (context) => const OnboardingScreen(),
        discovery: (context) => const DiscoveryScreen(),
        pairing: (context) => const PairingScreen(),
        voice: (context) => const VoiceScreen(),
        commands: (context) => const CommandsScreen(),
        files: (context) => const AppShell(initialIndex: 1),
        photos: (context) => const AppShell(initialIndex: 2),
        settings: (context) => const AppShell(initialIndex: 3),
      };

  /// Route generator for dynamic or argument-based transitions.
  static Route<dynamic>? onGenerateRoute(RouteSettings routeSettings) {
    final builder = routes[routeSettings.name];
    if (builder != null) {
      return MaterialPageRoute<dynamic>(
        builder: builder,
        settings: routeSettings,
      );
    }
    return MaterialPageRoute<dynamic>(
      builder: (context) => const HomeScreen(),
      settings: routeSettings,
    );
  }
}
