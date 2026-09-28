import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/models/models.dart';
import '../../../core/network/config.dart';
import '../../../core/network/bridge_config_provider.dart';
import '../../../core/services/connection_service.dart';
import '../../../core/services/discovery_service.dart';
import '../widgets/device_card.dart';
import '../widgets/manual_connect_sheet.dart';
import '../widgets/scanning_indicator.dart';

/// Screen managing discovery of Windows AI automation bridge hosts on the LAN.
class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScanning();
    });
  }

  void _startScanning() {
    setState(() {
      _errorMessage = null;
    });
    final config = context.read<BridgeConfigProvider>().config;
    context.read<DiscoveryService>().startDiscovery(mode: config.mode);
  }

  void _onDeviceSelected(WindowsDevice device) {
    // Configure client immediately upon device selection
    final configProvider = context.read<BridgeConfigProvider>();
    final config = BridgeConfig(
      host: device.host,
      port: device.port,
      mode: configProvider.config.mode,
    );
    configProvider.client.configure(config);
    try {
      context.read<ConnectionService>().client.configure(config);
    } catch (_) {}

    // Navigate directly to pairing screen with the selected target device
    Navigator.pushNamed(
      context,
      AppRoutes.pairing,
      arguments: device,
    );
  }

  Future<void> _openManualConnect() async {
    final device = await ManualConnectSheet.show(context);
    if (device != null && mounted) {
      _onDeviceSelected(device);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final discoveryService = context.watch<DiscoveryService>();
    final devices = discoveryService.discoveredDevices;
    final isScanning = discoveryService.isScanning;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(
          'DEVICE DISCOVERY',
          style: AppTypography.sectionHeading.copyWith(
            color: palette.textPrimary,
            letterSpacing: 1.0,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Rescan',
            onPressed: isScanning ? null : _startScanning,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: palette.border, height: 1.0),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: _buildBody(
            isScanning: isScanning,
            devices: devices,
            palette: palette,
          ),
        ),
      ),
    );
  }

  Widget _buildBody({
    required bool isScanning,
    required List<WindowsDevice> devices,
    required AppPalette palette,
  }) {
    // 1. Error state
    if (_errorMessage != null) {
      return _buildErrorState(_errorMessage!, palette);
    }

    // 2. Loading state: scanning with no devices found yet
    if (isScanning && devices.isEmpty) {
      return _buildScanningState(palette);
    }

    // 3. Not-found state: scanning finished with 0 devices
    if (!isScanning && devices.isEmpty) {
      return _buildNotFoundState(palette);
    }

    // 4. Found state: devices discovered
    return _buildFoundState(devices: devices, isScanning: isScanning, palette: palette);
  }

  /// Loading state with scanning indicator and minimal copy
  Widget _buildScanningState(AppPalette palette) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ScanningIndicator(size: 64),
          const SizedBox(height: 24),
          Text(
            'Searching for Windows...',
            style: AppTypography.largeBoldHeading.copyWith(
              color: palette.textPrimary,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Scanning local subnet for Windows AI Bridge hosts',
            style: AppTypography.mutedMetadata.copyWith(color: palette.textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 36),
          TextButton(
            key: const ValueKey('connect_manually_btn'),
            onPressed: _openManualConnect,
            child: Text(
              'Connect manually',
              style: AppTypography.mutedMetadata.copyWith(
                color: palette.textPrimary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Not-found state with user-friendly guidance
  Widget _buildNotFoundState(AppPalette palette) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: palette.border, width: 1),
            ),
            child: Icon(
              Icons.devices_outlined,
              size: 24,
              color: palette.textMuted,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'NO WINDOWS HOSTS FOUND',
            style: AppTypography.sectionHeading.copyWith(
              color: palette.textPrimary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Couldn\'t connect to Windows. Make sure your phone and PC are connected to the same network and the Windows AI Bridge software is running.',
            style: AppTypography.mutedMetadata.copyWith(
              color: palette.textMuted,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            key: const ValueKey('retry_scan_btn'),
            onPressed: _startScanning,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(200, 44),
            ),
            child: const Text('SCAN AGAIN'),
          ),
          const SizedBox(height: 12),
          TextButton(
            key: const ValueKey('not_found_manual_connect_btn'),
            onPressed: _openManualConnect,
            child: Text(
              'Connect manually',
              style: AppTypography.mutedMetadata.copyWith(
                color: palette.textPrimary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Error state with retry actions
  Widget _buildErrorState(String message, AppPalette palette) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: palette.errorRed, width: 1),
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              size: 24,
              color: palette.errorRed,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'CONNECTION ERROR',
            style: AppTypography.sectionHeading.copyWith(
              color: palette.errorRed,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: AppTypography.mutedMetadata.copyWith(
              color: palette.textMuted,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: _startScanning,
            child: const Text('RETRY'),
          ),
        ],
      ),
    );
  }

  /// Found state with device list
  Widget _buildFoundState({
    required List<WindowsDevice> devices,
    required bool isScanning,
    required AppPalette palette,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'AVAILABLE WINDOWS BRIDGES (${devices.length})',
              style: AppTypography.mutedMetadata.copyWith(
                color: palette.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
            if (isScanning)
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: palette.accentGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'SCANNING',
                    style: AppTypography.mutedMetadata.copyWith(
                      color: palette.textMuted,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: ListView.separated(
            itemCount: devices.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final device = devices[index];
              return DeviceCard(
                device: device,
                onConnect: () => _onDeviceSelected(device),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: TextButton(
            key: const ValueKey('found_manual_connect_btn'),
            onPressed: _openManualConnect,
            child: Text(
              'Connect manually',
              style: AppTypography.mutedMetadata.copyWith(
                color: palette.textPrimary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
