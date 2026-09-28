import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';

/// Onboarding screen for first-launch initialization and setup instructions.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  Future<void> _completeOnboarding(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_seen_onboarding', true);
    } catch (_) {}

    if (context.mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.discovery);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(
          'WINDOWS REMOTE',
          style: AppTypography.sectionHeading.copyWith(
            color: palette.textPrimary,
            letterSpacing: 1.2,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: palette.border, height: 1.0),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Icon Box
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: palette.card,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: palette.border, width: 1.5),
                  ),
                  child: Icon(
                    Icons.desktop_windows_outlined,
                    size: 36,
                    color: palette.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'LOCAL AUTOMATION',
                style: AppTypography.largeBoldHeading.copyWith(
                  color: palette.textPrimary,
                  fontSize: 22,
                  letterSpacing: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Control your Windows PC directly over your local network. Send voice commands, stream files, and transmit photos without cloud intermediaries.',
                style: AppTypography.body.copyWith(
                  color: palette.textMuted,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              ElevatedButton(
                key: const ValueKey('get_started_btn'),
                onPressed: () => _completeOnboarding(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.textPrimary,
                  foregroundColor: palette.background,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: Text(
                  'FIND MY PC',
                  style: AppTypography.sectionHeading.copyWith(
                    color: palette.background,
                    fontSize: 14,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

