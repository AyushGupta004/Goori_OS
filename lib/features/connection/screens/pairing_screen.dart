import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/models.dart';
import '../../../core/network/bridge_config_provider.dart';
import '../../../core/services/connection_service.dart';

/// Screen for entering 6-digit pairing PIN displayed on the Windows host console.
class PairingScreen extends StatefulWidget {
  final WindowsDevice? targetDevice;

  const PairingScreen({
    super.key,
    this.targetDevice,
  });

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final _pinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  bool _isPaired = false;
  String? _pairingError;

  @override
  void initState() {
    super.initState();
    final serviceError = context.read<ConnectionService>().errorMessage;
    if (serviceError != null && serviceError.isNotEmpty) {
      if (serviceError.contains('INVALID_TOKEN') ||
          serviceError.contains('token rejected') ||
          serviceError.contains('rejected')) {
        _pairingError =
            'Session expired or invalid. Enter the 6-digit code shown on your Windows computer.';
      }
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _onPairPressed(WindowsDevice device) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _pairingError = null;
    });

    final config = context.read<BridgeConfigProvider>().config;
    final connectionService = context.read<ConnectionService>();
    final response = await connectionService.pair(
      device,
      _pinController.text.trim(),
      mode: config.mode,
    );

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    if (response.success) {
      final palette = context.palette;
      setState(() {
        _isPaired = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✓ Device paired',
            style: AppTypography.body.copyWith(color: palette.background),
          ),
          backgroundColor: palette.accentGreen,
          duration: const Duration(seconds: 2),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.home,
          (route) => false,
        );
      }
    } else {
      setState(() {
        _pairingError = response.errorMessage?.isNotEmpty == true
            ? response.errorMessage!
            : 'Invalid code. Check the 6-digit code shown on your Windows computer.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // Resolve device from direct widget property, modal route arguments, or active device in service
    final routeDevice =
        ModalRoute.of(context)?.settings.arguments as WindowsDevice?;
    final device = widget.targetDevice ??
        routeDevice ??
        context.read<ConnectionService>().activeDevice ??
        const WindowsDevice(
          id: 'mock_target',
          name: 'My Windows PC',
          host: '127.0.0.1',
          port: AppConstants.defaultHttpPort,
        );

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(
          'DEVICE PAIRING',
          style: AppTypography.sectionHeading.copyWith(
            color: palette.textPrimary,
            letterSpacing: 1.0,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: palette.border, height: 1.0),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Target Device Summary Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: palette.card,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: palette.border, width: 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: palette.secondary,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: palette.border, width: 1),
                        ),
                        child: Icon(
                          Icons.desktop_windows_outlined,
                          size: 18,
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              device.name,
                              style: AppTypography.sectionHeading.copyWith(
                                color: palette.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${device.host}:${device.port}',
                              style: AppTypography.monoConsole.copyWith(
                                color: palette.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'ENTER PAIRING PIN',
                  style: AppTypography.sectionHeading.copyWith(
                    color: palette.textPrimary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter the 6-digit code shown on your Windows computer',
                  style: AppTypography.mutedMetadata.copyWith(
                    color: palette.textMuted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                // PIN Input
                TextFormField(
                  key: const ValueKey('pairing_pin_input'),
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: AppTypography.largeBoldHeading.copyWith(
                    color: palette.textPrimary,
                    letterSpacing: 12.0,
                    fontSize: 26,
                  ),
                  decoration: const InputDecoration(
                    hintText: '000000',
                    counterText: '',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter 6-digit PIN';
                    }
                    if (val.trim().length != 6 ||
                        int.tryParse(val.trim()) == null) {
                      return 'PIN must be exactly 6 digits';
                    }
                    return null;
                  },
                ),
                if (_pairingError != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    key: const ValueKey('pairing_error_banner'),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: palette.card,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: palette.errorRed, width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: palette.errorRed,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _pairingError!,
                            style: AppTypography.mutedMetadata.copyWith(
                              color: palette.errorRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_isPaired) ...[
                  const SizedBox(height: 16),
                  Container(
                    key: const ValueKey('pairing_success_banner'),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: palette.card,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: palette.accentGreen, width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: palette.accentGreen,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '✓ Device paired',
                          style: AppTypography.body.copyWith(
                            color: palette.accentGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                ElevatedButton(
                  key: const ValueKey('pairing_submit_btn'),
                  onPressed: (_isSubmitting || _isPaired)
                      ? null
                      : () => _onPairPressed(device),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.textPrimary,
                    foregroundColor: palette.background,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isPaired
                      ? Text(
                          '✓ Device paired',
                          style: AppTypography.sectionHeading.copyWith(
                            color: palette.background,
                            letterSpacing: 1.0,
                          ),
                        )
                      : (_isSubmitting
                          ? Text(
                              'CONNECTING...',
                              style: AppTypography.sectionHeading.copyWith(
                                color: palette.background,
                                letterSpacing: 1.0,
                              ),
                            )
                          : Text(
                              'CONNECT',
                              style: AppTypography.sectionHeading.copyWith(
                                color: palette.background,
                                letterSpacing: 1.0,
                              ),
                            )),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
