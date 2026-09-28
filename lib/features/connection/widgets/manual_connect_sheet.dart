import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/models.dart';
import '../../../core/network/config.dart';
import '../../../core/network/bridge_config_provider.dart';
import '../../../core/services/connection_service.dart';
import '../../../core/services/discovery_service.dart';

/// Modal bottom sheet allowing manual host IP and port configuration.
class ManualConnectSheet extends StatefulWidget {
  const ManualConnectSheet({super.key});

  /// Displays the manual connect sheet and returns the configured [WindowsDevice] if submitted.
  static Future<WindowsDevice?> show(BuildContext context) {
    final palette = AppPalette.of(context);
    return showModalBottomSheet<WindowsDevice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.secondary,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        side: BorderSide(color: palette.border, width: 1),
      ),
      builder: (_) => const ManualConnectSheet(),
    );
  }

  @override
  State<ManualConnectSheet> createState() => _ManualConnectSheetState();
}

class _ManualConnectSheetState extends State<ManualConnectSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _hostController;
  late final TextEditingController _portController;

  @override
  void initState() {
    super.initState();
    final currentConfig = context.read<BridgeConfigProvider>().config;
    _hostController = TextEditingController(text: currentConfig.host);
    _portController =
        TextEditingController(text: currentConfig.port.toString());
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _onConnectPressed() async {
    if (!_formKey.currentState!.validate()) return;

    final host = _hostController.text.trim();
    final port = int.parse(_portController.text.trim());

    final configProvider = context.read<BridgeConfigProvider>();
    final currentMode = configProvider.config.mode;

    // When connecting manually, ensure dev/production mode is active so RealWindowsBridgeClient is used
    final effectiveMode =
        (currentMode == BridgeMode.mock) ? BridgeMode.dev : currentMode;

    final updatedConfig = configProvider.config.copyWith(
      host: host,
      port: port,
      mode: effectiveMode,
    );

    await configProvider.updateConfig(updatedConfig);
    configProvider.client.configure(updatedConfig);
    if (mounted) {
      try {
        context.read<ConnectionService>().client.configure(updatedConfig);
      } catch (_) {}
    }

    // Register manual device in DiscoveryService
    if (mounted) {
      context.read<DiscoveryService>().addManualDevice(host, port);

      final device = WindowsDevice(
        id: 'manual_${host}_$port',
        name: 'Windows PC ($host)',
        host: host,
        port: port,
      );
      Navigator.pop(context, device);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: 24 + bottomInset,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'MANUAL BRIDGE CONNECTION',
                  style: AppTypography.sectionHeading.copyWith(
                    color: palette.textPrimary,
                    letterSpacing: 0.8,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 20, color: palette.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Enter the local IP address and port of your Windows AI automation host.',
              style: AppTypography.mutedMetadata.copyWith(color: palette.textMuted),
            ),
            const SizedBox(height: 20),
            // Host input
            Text(
              'HOST OR IP ADDRESS',
              style: AppTypography.mutedMetadata.copyWith(
                color: palette.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              key: const ValueKey('manual_host_input'),
              controller: _hostController,
              keyboardType: TextInputType.url,
              autocorrect: false,
              style: AppTypography.monoConsole.copyWith(
                color: palette.textPrimary,
                fontSize: 14,
              ),
              decoration: const InputDecoration(
                hintText: '192.168.1.100 or 127.0.0.1',
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Host address is required';
                }
                final cleaned = val.trim();
                if (cleaned.contains(' ') || cleaned.length < 3) {
                  return 'Enter a valid IP address or hostname';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Port input
            Text(
              'PORT',
              style: AppTypography.mutedMetadata.copyWith(
                color: palette.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              key: const ValueKey('manual_port_input'),
              controller: _portController,
              keyboardType: TextInputType.number,
              style: AppTypography.monoConsole.copyWith(
                color: palette.textPrimary,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: AppConstants.defaultHttpPort.toString(),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Port is required';
                }
                final portNum = int.tryParse(val.trim());
                if (portNum == null || portNum <= 0 || portNum > 65535) {
                  return 'Port must be between 1 and 65535';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            // Connect button
            ElevatedButton(
              key: const ValueKey('manual_connect_submit_btn'),
              onPressed: _onConnectPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.textPrimary,
                foregroundColor: palette.background,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: Text(
                'CONNECT',
                style: AppTypography.sectionHeading.copyWith(
                  color: palette.background,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
