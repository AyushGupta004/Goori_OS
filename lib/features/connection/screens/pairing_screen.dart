import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_errors.dart';
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
  bool _isUnreachable = false;
  bool _troubleshootingExpanded = false;

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
      _isUnreachable = false;
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
      final isWrongPin = response.failure == BridgeFailure.wrongPin ||
          (response.errorMessage != null &&
              (response.errorMessage!.contains("isn't correct") ||
                  response.errorMessage!.contains('wrong') ||
                  response.errorMessage!.contains('invalid_pairing_code') ||
                  response.errorMessage!.contains('invalid code')));
      final isUnreachable = response.failure == BridgeFailure.unreachable ||
          (response.errorMessage != null &&
              (response.errorMessage!.contains("Can't reach") ||
                  response.errorMessage!.contains('unreachable')));

      setState(() {
        _isUnreachable = isUnreachable;
        if (isWrongPin) {
          _pairingError = AppErrors.wrongPin;
          _pinController.clear();
        } else if (isUnreachable) {
          _pairingError = AppErrors.unreachable(device.host);
        } else {
          _pairingError = AppErrorMapper.map(
            response.errorMessage,
            host: device.host,
            fallback: 'Pairing failed. Please verify the connection and try again.',
          );
        }
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
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    device.name,
                                    style: AppTypography.sectionHeading.copyWith(
                                      color: palette.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (device.id.startsWith('mock') ||
                                    device.name.toUpperCase().contains('SIMULAT')) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: palette.border,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Text(
                                      '(SIMULATED)',
                                      style: AppTypography.mutedMetadata.copyWith(
                                        color: palette.amberBadge,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
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
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: palette.card,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: palette.errorRed.withValues(alpha: 0.6),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                  fontSize: 12,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            if (_isUnreachable) ...[
                              const SizedBox(width: 8),
                              ElevatedButton(
                                key: const ValueKey('pairing_retry_btn'),
                                onPressed: _isSubmitting
                                    ? null
                                    : () => _onPairPressed(device),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: palette.secondary,
                                  foregroundColor: palette.textPrimary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  minimumSize: Size.zero,
                                  side: BorderSide(
                                    color: palette.border,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  'RETRY',
                                  style: AppTypography.mutedMetadata.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: palette.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (_isUnreachable) ...[
                          const SizedBox(height: 10),
                          InkWell(
                            key: const ValueKey('troubleshooting_toggle_btn'),
                            onTap: () {
                              setState(() {
                                _troubleshootingExpanded =
                                    !_troubleshootingExpanded;
                              });
                            },
                            child: Row(
                              children: [
                                Icon(
                                  _troubleshootingExpanded
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  size: 16,
                                  color: palette.textMuted,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Troubleshooting checklist',
                                  style: AppTypography.mutedMetadata.copyWith(
                                    color: palette.textMuted,
                                    decoration: TextDecoration.underline,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_troubleshootingExpanded) ...[
                            const SizedBox(height: 8),
                            Container(
                              key: const ValueKey('troubleshooting_list'),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: palette.secondary,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: palette.border,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: AppErrors.troubleshootingSteps
                                    .map(
                                      (step) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 4.0,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '• ',
                                              style: TextStyle(
                                                color: palette.textMuted,
                                                fontSize: 11,
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                step,
                                                style: AppTypography
                                                    .mutedMetadata
                                                    .copyWith(
                                                  color: palette.textPrimary,
                                                  fontSize: 11,
                                                  height: 1.3,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ],
                        ],
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
