import 'package:flutter_test/flutter_test.dart';
import 'package:goori_os/core/models/models.dart';
import 'package:goori_os/core/network/network.dart';

/// Consumer demonstrating zero knowledge of Mock vs Real.
class AutomationConsumer {
  final WindowsBridgeClient client;
  AutomationConsumer(this.client);

  Future<CommandResult> runTask(String task) async {
    final req = CommandRequest(
      commandId: 'cmd_${DateTime.now().millisecondsSinceEpoch}',
      type: 'text',
      payload: task,
      timestamp: DateTime.now(),
    );
    return await client.sendCommand(req);
  }
}

void main() {
  test(
      'Demonstration: Swapping Mock <-> Real client via config only with zero consumer diff',
      () async {
    // 1. Initialize with Mock Config
    const mockConfig = BridgeConfig(
      host: '127.0.0.1',
      port: 7890,
      mode: BridgeMode.mock,
    );

    final mockClient = BridgeClientFactory.createClient(mockConfig);
    expect(mockClient, isA<MockWindowsBridgeClient>());

    await mockClient.connect(mockConfig);
    final mockPairing = await mockClient.pair('123456');
    expect(mockPairing.success, true);

    // Consumer instantiated with Mock client
    final mockConsumer = AutomationConsumer(mockClient);
    final result = await mockConsumer.runTask('Open Task Manager');
    expect(result.success, true);
    expect(result.status, 'completed');
    await mockClient.disconnect();

    // 2. Switch configuration to Real (Dev/Production)
    const realConfig = BridgeConfig(
      host: '192.168.1.188',
      port: 7890,
      mode: BridgeMode.dev,
    );

    final realClient = BridgeClientFactory.createClient(realConfig);
    expect(realClient, isA<RealWindowsBridgeClient>());

    // Exact same consumer instantiated with Real client — zero modifications needed!
    final realConsumer = AutomationConsumer(realClient);
    expect(realConsumer.client, isA<WindowsBridgeClient>());
    expect(realConsumer.client, isA<RealWindowsBridgeClient>());
  });
}
