import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Available application theme modes.
enum AppThemeMode {
  dark,
  light;

  String toJson() => name;

  static AppThemeMode fromString(String? value) {
    if (value == 'light') return AppThemeMode.light;
    return AppThemeMode.dark;
  }
}

/// Dynamic semantic color palette supporting both Black (OLED Dark) and White (Light) console themes.
class AppPalette {
  final Color background;
  final Color secondary;
  final Color card;
  final Color border;
  final Color textPrimary;
  final Color textMuted;
  final Color accentGreen;
  final Color errorRed;

  const AppPalette({
    required this.background,
    required this.secondary,
    required this.card,
    required this.border,
    required this.textPrimary,
    required this.textMuted,
    required this.accentGreen,
    required this.errorRed,
  });

  /// Deep OLED black console palette.
  static const dark = AppPalette(
    background: Color(0xFF050505),
    secondary: Color(0xFF0B0B0B),
    card: Color(0xFF111111),
    border: Color(0xFF222222),
    textPrimary: Color(0xFFFFFFFF),
    textMuted: Color(0xFF9A9A9A),
    accentGreen: Color(0xFF7CFF6B),
    errorRed: Color(0xFFFF3B30),
  );

  /// Clean, high-contrast white command-console palette.
  /// Uses #15803D for accentGreen to guarantee WCAG AA contrast (> 4.5:1) against white surfaces.
  static const light = AppPalette(
    background: Color(0xFFFFFFFF),
    secondary: Color(0xFFF4F4F5),
    card: Color(0xFFFAFAFA),
    border: Color(0xFFE4E4E7),
    textPrimary: Color(0xFF09090B),
    textMuted: Color(0xFF71717A),
    accentGreen: Color(0xFF15803D),
    errorRed: Color(0xFFDC2626),
  );

  /// Obtains the active [AppPalette] given the current [BuildContext].
  static AppPalette of(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return isLight ? light : dark;
  }
}

/// Convenience extension on [BuildContext] to access [AppPalette].
extension AppThemeContextExtension on BuildContext {
  AppPalette get palette => AppPalette.of(this);
}

/// Design tokens and semantic color palette strictly matching the Windows Remote specification.
/// Retained for static backward compatibility; use `context.palette` or `AppPalette.of(context)`
/// for theme-reactive colors.
class AppColors {
  AppColors._();

  /// Primary deep black canvas background (#050505).
  static const Color background = Color(0xFF050505);

  /// Secondary dark surface (#0B0B0B).
  static const Color secondary = Color(0xFF0B0B0B);

  /// Surface card fill color (#111111).
  static const Color card = Color(0xFF111111);

  /// Structural dividing border color (#222222).
  static const Color border = Color(0xFF222222);

  /// Primary text color (#FFFFFF).
  static const Color textPrimary = Color(0xFFFFFFFF);

  /// Muted metadata and placeholder text color (#9A9A9A).
  static const Color textMuted = Color(0xFF9A9A9A);

  /// Functional accent green (#7CFF6B) — reserved exclusively for success & connected states.
  static const Color accentGreen = Color(0xFF7CFF6B);

  /// Functional error red (#FF3B30) — reserved exclusively for errors and failures.
  static const Color errorRed = Color(0xFFFF3B30);

  /// Theme-reactive palette accessor.
  static AppPalette of(BuildContext context) => AppPalette.of(context);
}

/// Strict typography hierarchy using Inter clean sans-serif.
class AppTypography {
  AppTypography._();

  /// Large bold heading for top-level screen titles (24sp, bold).
  static TextStyle get largeBoldHeading => GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      );

  /// Section heading for grouping and component headers (16sp, semi-bold).
  static TextStyle get sectionHeading => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      );

  /// Standard body text for content, descriptions, and values (14sp, regular).
  static TextStyle get body => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.4,
      );

  /// Muted metadata for labels, timestamps, telemetry, and hints (12sp, regular).
  static TextStyle get mutedMetadata => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.2,
      );

  /// Monospace variant for command logs, device IDs, and tokens (12sp).
  static TextStyle get monoConsole => GoogleFonts.robotoMono(
        fontSize: 12,
        fontWeight: FontWeight.w500,
      );
}

/// Global theme definition for the Windows Remote application.
/// Provides a minimal command console / control tool aesthetic:
/// - Zero gradients
/// - Zero neon glow
/// - Zero bouncy animations
/// - Clean 1px industrial borders
class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    const palette = AppPalette.dark;
    final baseTextTheme = TextTheme(
      headlineLarge: AppTypography.largeBoldHeading.copyWith(color: palette.textPrimary),
      headlineMedium: AppTypography.largeBoldHeading.copyWith(fontSize: 20, color: palette.textPrimary),
      titleLarge: AppTypography.sectionHeading.copyWith(color: palette.textPrimary),
      titleMedium: AppTypography.sectionHeading.copyWith(fontSize: 14, color: palette.textPrimary),
      bodyLarge: AppTypography.body.copyWith(color: palette.textPrimary),
      bodyMedium: AppTypography.body.copyWith(color: palette.textPrimary),
      bodySmall: AppTypography.mutedMetadata.copyWith(color: palette.textMuted),
      labelLarge: AppTypography.sectionHeading.copyWith(fontSize: 14, color: palette.textPrimary),
      labelMedium: AppTypography.mutedMetadata.copyWith(color: palette.textMuted),
      labelSmall: AppTypography.mutedMetadata.copyWith(fontSize: 10, color: palette.textMuted),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.background,
      cardColor: palette.card,
      dividerColor: palette.border,
      fontFamily: GoogleFonts.inter().fontFamily,
      textTheme: baseTextTheme,
      colorScheme: ColorScheme.dark(
        primary: palette.textPrimary,
        onPrimary: palette.background,
        secondary: palette.secondary,
        onSecondary: palette.textPrimary,
        surface: palette.card,
        onSurface: palette.textPrimary,
        error: palette.errorRed,
        onError: palette.textPrimary,
        outline: palette.border,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppTypography.sectionHeading.copyWith(color: palette.textPrimary),
        iconTheme: IconThemeData(color: palette.textPrimary),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Color(0xFF050505),
          systemNavigationBarIconBrightness: Brightness.light,
          systemNavigationBarDividerColor: Color(0xFF222222),
        ),
      ),
      cardTheme: CardThemeData(
        color: palette.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: palette.border, width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: palette.border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.secondary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: AppTypography.mutedMetadata.copyWith(color: palette.textMuted),
        labelStyle: AppTypography.mutedMetadata.copyWith(color: palette.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: palette.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: palette.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: palette.textPrimary, width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: palette.errorRed, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: palette.errorRed, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.card,
          foregroundColor: palette.textPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: palette.border, width: 1),
            borderRadius: BorderRadius.circular(4),
          ),
          textStyle: AppTypography.sectionHeading.copyWith(fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          side: BorderSide(color: palette.border, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          textStyle: AppTypography.sectionHeading.copyWith(fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.textPrimary,
          textStyle: AppTypography.sectionHeading.copyWith(fontSize: 14),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.secondary,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: Color(0xFF222222), width: 1),
          borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: palette.border, width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
        titleTextStyle: AppTypography.sectionHeading.copyWith(color: palette.textPrimary),
        contentTextStyle: AppTypography.body.copyWith(color: palette.textPrimary),
      ),
    );
  }

  /// Clean, high-contrast light console theme counterpart.
  static ThemeData get lightTheme {
    const palette = AppPalette.light;
    final baseTextTheme = TextTheme(
      headlineLarge: AppTypography.largeBoldHeading.copyWith(color: palette.textPrimary),
      headlineMedium: AppTypography.largeBoldHeading.copyWith(fontSize: 20, color: palette.textPrimary),
      titleLarge: AppTypography.sectionHeading.copyWith(color: palette.textPrimary),
      titleMedium: AppTypography.sectionHeading.copyWith(fontSize: 14, color: palette.textPrimary),
      bodyLarge: AppTypography.body.copyWith(color: palette.textPrimary),
      bodyMedium: AppTypography.body.copyWith(color: palette.textPrimary),
      bodySmall: AppTypography.mutedMetadata.copyWith(color: palette.textMuted),
      labelLarge: AppTypography.sectionHeading.copyWith(fontSize: 14, color: palette.textPrimary),
      labelMedium: AppTypography.mutedMetadata.copyWith(color: palette.textMuted),
      labelSmall: AppTypography.mutedMetadata.copyWith(fontSize: 10, color: palette.textMuted),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.background,
      cardColor: palette.card,
      dividerColor: palette.border,
      fontFamily: GoogleFonts.inter().fontFamily,
      textTheme: baseTextTheme,
      colorScheme: ColorScheme.light(
        primary: palette.textPrimary,
        onPrimary: palette.background,
        secondary: palette.secondary,
        onSecondary: palette.textPrimary,
        surface: palette.card,
        onSurface: palette.textPrimary,
        error: palette.errorRed,
        onError: Colors.white,
        outline: palette.border,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppTypography.sectionHeading.copyWith(color: palette.textPrimary),
        iconTheme: IconThemeData(color: palette.textPrimary),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: Color(0xFFFFFFFF),
          systemNavigationBarIconBrightness: Brightness.dark,
          systemNavigationBarDividerColor: Color(0xFFE4E4E7),
        ),
      ),
      cardTheme: CardThemeData(
        color: palette.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: palette.border, width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: palette.border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.secondary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: AppTypography.mutedMetadata.copyWith(color: palette.textMuted),
        labelStyle: AppTypography.mutedMetadata.copyWith(color: palette.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: palette.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: palette.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: palette.textPrimary, width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: palette.errorRed, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: palette.errorRed, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.card,
          foregroundColor: palette.textPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: palette.border, width: 1),
            borderRadius: BorderRadius.circular(4),
          ),
          textStyle: AppTypography.sectionHeading.copyWith(fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          side: BorderSide(color: palette.border, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          textStyle: AppTypography.sectionHeading.copyWith(fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.textPrimary,
          textStyle: AppTypography.sectionHeading.copyWith(fontSize: 14),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.secondary,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: Color(0xFFE4E4E7), width: 1),
          borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: palette.border, width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
        titleTextStyle: AppTypography.sectionHeading.copyWith(color: palette.textPrimary),
        contentTextStyle: AppTypography.body.copyWith(color: palette.textPrimary),
      ),
    );
  }
}

