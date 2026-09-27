import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goori_os/app/app.dart';

void main() {
  testWidgets('Windows Remote app smoke test renders blank themed home screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const WindowsRemoteApp());
    await tester.pumpAndSettle();

    expect(find.text('WINDOWS REMOTE'), findsOneWidget);
    expect(find.text('Tap to give a command'), findsOneWidget);
    expect(find.text('HOME'), findsOneWidget);
    expect(find.byKey(const ValueKey('nav_files')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav_photos')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav_settings')), findsOneWidget);
  });
}
