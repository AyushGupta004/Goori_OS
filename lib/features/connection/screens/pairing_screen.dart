import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/errors/app_errors.dart';
import '../../../core/models/models.dart';
import '../../../core/network/bridge_config_provider.dart';
import '../../../core/services/connection_service.dart';
import '../../../core/services/pairing_service.dart';

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
  bool _liveConnectionFailed = false;
  String? _pairingError;
  bool _isUnreachable = false;
  bool _troubleshootingExpanded = false;
  bool _detailsExpanded = false;
  HealthResult? _lastHealthResult;

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

  Future<void> _retryLiveConnection(WindowsDevice device) async {
    setState(() {
      _isSubmitting = true;
    });

    final config = context.read<BridgeConfigProvider>().config;
    final pairingService = context.read<PairingService>();
    final ok = await pairingService.retryLiveConnection(
      device: device,
      mode: config.mode,
    );

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    if (ok) {
      setState(() {
        _liveConnectionFailed = false;
        _isPaired = true;
      });
      final palette = context.palette;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✓ Connected to bridge',
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
      final palette = context.palette;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Live connection failed. Stored credentials kept.',
            style: AppTypography.body.copyWith(color: Colors.white),
          ),
          backgroundColor: palette.errorRed,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _onPairPressed(WindowsDevice device) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _pairingError = null;
      _isUnreachable = false;
      _liveConnectionFailed = false;
      _lastHealthResult = null;
    });

    final config = context.read<BridgeConfigProvider>().config;
    final connectionService = context.read<ConnectionService>();
    final pairingService = context.read<PairingService>();

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
      // Check if WebSocket live connection failed afterwards
      if (pairingService.liveConnectionFailed) {
        setState(() {
          _liveConnectionFailed = true;
        });
        return;
      }

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
      final health = pairingService.lastHealthResult;
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
        _isUnreachable = isUnreachable || health != null;
        _lastHealthResult = health;

        if (isWrongPin) {
          _pairingError = AppErrors.wrongPin;
          _pinController.clear();
        } else if (health != null && !health.ok) {
          _pairingError = health.friendlyHeadline;
        } else if (isUnreachable) {
          _pairingError = AppErrors.unreachable(device.host);
        } else {
          _pairingError = AppErrorMapper.map(
            response.errorMessage,
            host: device.host,
            fallback:
                'Pairing failed. Please verify the connection and try again.',
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final routeDevice =
        ModalRoute.of(context)?.settings.arguments as WindowsDevice?;
    final device = widget.targetDevice ??
        routeDevice ??
        context.read<ConnectionService>().activeDevice;

    // Never fabricate a mock device. If none passed, redirect to discovery.
    if (device == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, AppRoutes.discovery);
        }
      });
      return Scaffold(
        backgroundColor: palette.background,
        body: const Center(),
      );
    }

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
                                    device.name
                                        .toUpperCase()
                                        .contains('SIMULAT')) ...[
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

                // Live Connection Failed Banner (Task 1)
                if (_liveConnectionFailed) ...[
                  const SizedBox(height: 16),
                  Container(
                    key: const ValueKey('live_connection_failed_banner'),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: palette.card,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: palette.amberBadge.withValues(alpha: 0.8),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: palette.amberBadge,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Paired, but the live connection failed',
                                style: AppTypography.sectionHeading.copyWith(
                                  color: palette.textPrimary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your device credentials were saved successfully, but the real-time bridge socket could not connect. Tap RETRY to establish live connection.',
                          style: AppTypography.mutedMetadata.copyWith(
                            color: palette.textMuted,
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton(
                              key: const ValueKey('retry_live_connection_btn'),
                              onPressed: _isSubmitting
                                  ? null
                                  : () => _retryLiveConnection(device),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: palette.textPrimary,
                                foregroundColor: palette.background,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                              ),
                              child: Text(
                                _isSubmitting ? 'CONNECTING...' : 'RETRY',
                                style: AppTypography.sectionHeading.copyWith(
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                // Error Banner with Diagnosable Details (Task 2)
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
                                  fontWeight: FontWeight.w600,
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

                        // Diagnosable Details (Task 2)
                        if (_lastHealthResult != null) ...[
                          const SizedBox(height: 10),
                          InkWell(
                            key: const ValueKey('details_toggle_btn'),
                            onTap: () {
                              setState(() {
                                _detailsExpanded = !_detailsExpanded;
                              });
                            },
                            child: Row(
                              children: [
                                Icon(
                                  _detailsExpanded
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  size: 16,
                                  color: palette.textMuted,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Details',
                                  style: AppTypography.mutedMetadata.copyWith(
                                    color: palette.textMuted,
                                    decoration: TextDecoration.underline,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_detailsExpanded) ...[
                            const SizedBox(height: 8),
                            Container(
                              key: const ValueKey('diagnostics_details_box'),
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
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (_lastHealthResult!.details != null)
                                    Text(
                                      _lastHealthResult!.details!,
                                      style: AppTypography.monoConsole.copyWith(
                                        color: palette.textPrimary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  if (_lastHealthResult!.subnetHint != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      _lastHealthResult!.subnetHint!,
                                      style: AppTypography.mutedMetadata.copyWith(
                                        color: palette.amberBadge,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: OutlinedButton.icon(
                                      key: const ValueKey('copy_diagnostics_btn'),
                                      onPressed: () {
                                        Clipboard.setData(
                                          ClipboardData(
                                            text: _lastHealthResult!
                                                .toDiagnosticString(
                                              host: device.host,
                                              port: device.port,
                                            ),
                                          ),
                                        );
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: const Text(
                                              'Diagnostics copied to clipboard',
                                            ),
                                            duration:
                                                const Duration(seconds: 2),
                                            backgroundColor: palette.card,
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.copy, size: 13),
                                      label: const Text('Copy diagnostics'),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        textStyle:
                                            AppTypography.mutedMetadata.copyWith(
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],

                        // Troubleshooting checklist
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
