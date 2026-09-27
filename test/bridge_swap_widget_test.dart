import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goori_os/core/network/network.dart';
import 'package:provider/provider.dart';

/// Test widget consuming WindowsBridgeClient via Provider
class BridgeClientDemoWidget extends StatelessWidget {
  const BridgeClientDemoWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final configProvider = context.watch<BridgeConfigProvider>();
    final client = configProvider.client;
    final isMock = client is MockWindowsBridgeClient;

    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            Text('ACTIVE_CLIENT: ${isMock ? "MOCK" : "REAL"}'),
            Text('HOST: ${configProvider.config.host}'),
            Text('PORT: ${configProvider.config.port}'),
            ElevatedButton(
              key: const ValueKey('swap_to_real_btn'),
              onPressed: () {
                configProvider.updateConfig(
                  const BridgeConfig(
                    host: '192.168.1.100',
                    port: 8443,
                    mode: BridgeMode.production,
                  ),
                  persist: false,
                );
              },
              child: const Text('Switch to Real'),
            ),
            ElevatedButton(
              key: const ValueKey('swap_to_mock_btn'),
              onPressed: () {
                configProvider.updateConfig(
                  const BridgeConfig(
                    host: '127.0.0.1',
                    port: 7890,
                    mode: BridgeMode.mock,
                  ),
                  persist: false,
                );
              },
              child: const Text('Switch to Mock'),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  testWidgets(
      'Widget test proving Mock <-> Real client swap via config change only',
      (WidgetTester tester) async {
    final provider = BridgeConfigProvider(
      initialConfig: const BridgeConfig(
        host: '127.0.0.1',
        port: 7890,
        mode: BridgeMode.mock,
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const BridgeClientDemoWidget(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify initial client is Mock
    expect(find.text('ACTIVE_CLIENT: MOCK'), findsOneWidget);
    expect(find.text('HOST: 127.0.0.1'), findsOneWidget);
    expect(provider.client, isA<MockWindowsBridgeClient>());

    // Tap button to swap configuration to Real
    await tester.tap(find.byKey(const ValueKey('swap_to_real_btn')));
    await tester.pumpAndSettle();

    // Verify client seamlessly swapped to Real with ZERO change to widget/consumer
    expect(find.text('ACTIVE_CLIENT: REAL'), findsOneWidget);
    expect(find.text('HOST: 192.168.1.100'), findsOneWidget);
    expect(provider.client, isA<RealWindowsBridgeClient>());

    // Tap button to swap back to Mock
    await tester.tap(find.byKey(const ValueKey('swap_to_mock_btn')));
    await tester.pumpAndSettle();

    // Verify swapped back to Mock
    expect(find.text('ACTIVE_CLIENT: MOCK'), findsOneWidget);
    expect(find.text('HOST: 127.0.0.1'), findsOneWidget);
    expect(provider.client, isA<MockWindowsBridgeClient>());
  });
}
