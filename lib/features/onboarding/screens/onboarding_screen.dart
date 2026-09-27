import 'package:flutter/material.dart';
import '../../../app/theme.dart';

/// Onboarding screen stub for first-launch initialization and setup instructions.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(
          'INITIAL SETUP',
          style: AppTypography.sectionHeading.copyWith(
            color: palette.textPrimary,
          ),
        ),
      ),
      body: Center(
        child: Text(
          'Onboarding flow',
          style: AppTypography.mutedMetadata.copyWith(
            color: palette.textMuted,
          ),
        ),
      ),
    );
  }
}
