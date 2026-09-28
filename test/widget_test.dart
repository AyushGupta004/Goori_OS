import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goori_os/app/app.dart';
import 'package:goori_os/app/routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Windows Remote app smoke test renders blank themed home screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const WindowsRemoteApp(initialRoute: AppRoutes.home));
    await tester.pumpAndSettle();

    expect(find.text('WINDOWS REMOTE'), findsOneWidget);
    expect(find.text('Tap to give a command'), findsOneWidget);
    expect(find.text('HOME'), findsOneWidget);
    expect(find.byKey(const ValueKey('nav_files')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav_photos')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav_settings')), findsOneWidget);
  });

  testWidgets('Acceptance 1: Fresh install launches onboarding and never shows My Windows PC or 127.0.0.1',
      (WidgetTester tester) async {
    await tester.pumpWidget(const WindowsRemoteApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    // Verify lands on OnboardingScreen
    expect(find.text('WINDOWS REMOTE'), findsOneWidget);
    expect(find.text('FIND MY PC'), findsOneWidget);
    expect(find.text('My Windows PC'), findsNothing);
    expect(find.textContaining('127.0.0.1'), findsNothing);
  });
}
