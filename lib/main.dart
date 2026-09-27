import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app/app.dart';
import 'app/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enforce system UI overlay style matching black-first console theme
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppPalette.dark.background,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: AppPalette.dark.border,
    ),
  );

  runApp(const WindowsRemoteApp());
}
