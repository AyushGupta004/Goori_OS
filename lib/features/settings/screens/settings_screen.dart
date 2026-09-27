import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/bridge_config_provider.dart';
import '../../../core/network/config.dart';
import '../../../core/services/command_history_service.dart';
import '../../../core/services/connection_service.dart';
import '../../../core/services/settings_service.dart';

/// Screen managing bridge connection telemetry, pairing lifecycle, command preferences,
/// appearance defaults, and application metadata.
/// Conforms to Task 10 requirements:
/// 1. Connection: shows device name, IP address, live connection status (read-only, from ConnectionService).
/// 2. Pairing: "Unpair Device" button -> confirms via dialog -> calls Task 5 unpair flow -> clears secure storage -> routes to discovery.
/// 3. Commands: "Auto-send commands" toggle, "Command history" toggle, and "Clear command history" action.
/// 4. Appearance: Dark theme shown as fixed default (no-op placeholder switch, not misleading).
/// 5. About: app version (from pubspec) and bridge protocol version (from BridgeConfig).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  /// Displays confirmation dialog prior to executing the unpair flow.
  Future<void> _confirmAndUnpair(BuildContext context) async {
    final palette = AppPalette.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: palette.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide(color: palette.border, width: 1),
          ),
          title: Text(
            'Unpair Windows PC?',
            style: AppTypography.sectionHeading.copyWith(
              color: palette.textPrimary,
              fontSize: 14,
            ),
          ),
          content: Text(
            'Are you sure you want to unpair from this Windows computer? You will need to re-enter a 6-digit code to connect again.',
            style: AppTypography.mutedMetadata.copyWith(
              fontSize: 12,
              color: palette.textPrimary,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              key: const ValueKey('cancel_unpair_dialog_btn'),
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'CANCEL',
                style: AppTypography.mutedMetadata.copyWith(
                  color: palette.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              key: const ValueKey('confirm_unpair_dialog_btn'),
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.errorRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: Text(
                'UNPAIR',
                style: AppTypography.sectionHeading.copyWith(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

    final connectionService = context.read<ConnectionService>();
    await connectionService.unpair();

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Device unpaired successfully',
          style: AppTypography.body.copyWith(color: palette.background),
        ),
        backgroundColor: palette.accentGreen,
        duration: const Duration(seconds: 2),
      ),
    );

    // Route to the discovery/pairing flow
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.discovery,
      (route) => false,
    );
  }

  /// Clears command history and shows brief feedback.
  Future<void> _clearCommandHistory(BuildContext context) async {
    final palette = AppPalette.of(context);
    final historyService = context.read<CommandHistoryService>();
    await historyService.clearHistory();

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Command history cleared',
          style: AppTypography.body.copyWith(color: palette.background),
        ),
        backgroundColor: palette.accentGreen,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final connectionService = context.watch<ConnectionService>();
    final configProvider = context.watch<BridgeConfigProvider>();
    final settingsService = context.watch<SettingsService>();
    final historyService = context.watch<CommandHistoryService>();

    final activeDevice = connectionService.activeDevice;
    final state = connectionService.currentState;
    final isConnected = state.isConnected;
    final isTransitioning = state.isTransitioning;

    final deviceName = activeDevice?.name ?? 'My Windows PC';
    final host = activeDevice?.host ?? configProvider.config.host;
    final port = activeDevice?.port ?? configProvider.config.port;

    return Scaffold(
      key: const ValueKey('settings_screen'),
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(
          'SETTINGS & CONFIG',
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
        child: ListView(
          key: const ValueKey('settings_list_view'),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          children: [
            // -----------------------------------------------------------------
            // SECTION 1: CONNECTION (Read-only device telemetry)
            // -----------------------------------------------------------------
            _buildSectionHeader('CONNECTION', palette),
            const SizedBox(height: 8),
            Container(
              key: const ValueKey('connection_section'),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: palette.card,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: palette.border, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTelemetryRow(
                    label: 'DEVICE NAME',
                    value: deviceName,
                    valueKey: 'settings_device_name',
                    palette: palette,
                  ),
                  const Divider(height: 20),
                  _buildTelemetryRow(
                    label: 'IP ADDRESS',
                    value: '$host:$port',
                    valueKey: 'settings_ip_address',
                    palette: palette,
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'STATUS',
                        style: AppTypography.mutedMetadata.copyWith(
                          color: palette.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      _buildLiveStatusBadge(isConnected, isTransitioning, palette),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // -----------------------------------------------------------------
            // SECTION 2: PAIRING (Unpair Device with Confirmation)
            // -----------------------------------------------------------------
            _buildSectionHeader('PAIRING', palette),
            const SizedBox(height: 8),
            Container(
              key: const ValueKey('pairing_section'),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: palette.card,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: palette.border, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 20,
                        color: palette.textPrimary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Device Authentication',
                              style: AppTypography.sectionHeading.copyWith(
                                color: palette.textPrimary,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Manage trusted pairing PIN and session security.',
                              style: AppTypography.mutedMetadata.copyWith(
                                color: palette.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    key: const ValueKey('unpair_device_btn'),
                    onPressed: () => _confirmAndUnpair(context),
                    icon: const Icon(Icons.link_off_rounded, size: 18),
                    label: const Text('UNPAIR DEVICE'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.errorRed,
                      side: BorderSide(color: palette.errorRed, width: 1),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // -----------------------------------------------------------------
            // SECTION 3: COMMANDS (Auto-send, History toggle & Clear action)
            // -----------------------------------------------------------------
            _buildSectionHeader('COMMANDS', palette),
            const SizedBox(height: 8),
            Container(
              key: const ValueKey('commands_section'),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: palette.card,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: palette.border, width: 1),
              ),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  children: [
                    // 1. Auto-send commands switch
                    SwitchListTile(
                      key: const ValueKey('auto_send_commands_switch'),
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: palette.accentGreen,
                      title: Text(
                        'Auto-send commands',
                        style: AppTypography.body.copyWith(
                          color: palette.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        settingsService.autoSend
                            ? 'Commands are dispatched immediately when speech recognition stops.'
                            : 'Review recognized command in review card prior to sending.',
                        style: AppTypography.mutedMetadata.copyWith(
                          color: palette.textMuted,
                          fontSize: 11,
                        ),
                      ),
                      value: settingsService.autoSend,
                      onChanged: (val) => settingsService.setAutoSend(val),
                    ),

                    const Divider(height: 1),

                    // 2. Command history switch
                    SwitchListTile(
                      key: const ValueKey('command_history_switch'),
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: palette.accentGreen,
                      title: Text(
                        'Command history',
                        style: AppTypography.body.copyWith(
                          color: palette.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        historyService.isEnabled
                            ? 'Executed commands are logged and viewable in Commands console.'
                            : 'Command logging is disabled; commands will not be saved.',
                        style: AppTypography.mutedMetadata.copyWith(
                          color: palette.textMuted,
                          fontSize: 11,
                        ),
                      ),
                      value: historyService.isEnabled,
                      onChanged: (val) {
                        settingsService.setCommandHistoryEnabled(val);
                        historyService.isEnabled = val;
                      },
                    ),

                    const Divider(height: 1),

                    // 3. Clear command history action
                    ListTile(
                      key: const ValueKey('clear_command_history_btn'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Clear command history',
                        style: AppTypography.body.copyWith(
                          color: palette.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Permanently remove all ${historyService.history.length} stored commands from device storage.',
                        style: AppTypography.mutedMetadata.copyWith(
                          color: palette.textMuted,
                          fontSize: 11,
                        ),
                      ),
                      trailing: Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: palette.errorRed,
                      ),
                      onTap: () => _clearCommandHistory(context),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // -----------------------------------------------------------------
            // SECTION 4: APPEARANCE (Black / White theme toggle)
            // -----------------------------------------------------------------
            _buildSectionHeader('APPEARANCE', palette),
            const SizedBox(height: 8),
            Container(
              key: const ValueKey('appearance_section'),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: palette.card,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: palette.border, width: 1),
              ),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  children: [
                    SwitchListTile(
                      key: const ValueKey('theme_mode_switch'),
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: palette.accentGreen,
                      title: Text(
                        'White theme',
                        style: AppTypography.body.copyWith(
                          color: palette.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        settingsService.themeMode == AppThemeMode.light
                            ? 'Light command console theme active.'
                            : 'Black OLED console theme active.',
                        style: AppTypography.mutedMetadata.copyWith(
                          color: palette.textMuted,
                          fontSize: 11,
                        ),
                      ),
                      value: settingsService.themeMode == AppThemeMode.light,
                      onChanged: (val) {
                        settingsService.setThemeMode(
                          val ? AppThemeMode.light : AppThemeMode.dark,
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    // Segmented control: "BLACK" / "WHITE"
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            key: const ValueKey('theme_black_btn'),
                            onPressed: () =>
                                settingsService.setThemeMode(AppThemeMode.dark),
                            style: OutlinedButton.styleFrom(
                              backgroundColor:
                                  settingsService.themeMode == AppThemeMode.dark
                                      ? palette.textPrimary
                                      : Colors.transparent,
                              foregroundColor:
                                  settingsService.themeMode == AppThemeMode.dark
                                      ? palette.background
                                      : palette.textPrimary,
                              side: BorderSide(
                                color: settingsService.themeMode ==
                                        AppThemeMode.dark
                                    ? palette.textPrimary
                                    : palette.border,
                                width: 1,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            child: Text(
                              'BLACK',
                              style: AppTypography.sectionHeading.copyWith(
                                fontSize: 11,
                                color: settingsService.themeMode ==
                                        AppThemeMode.dark
                                    ? palette.background
                                    : palette.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            key: const ValueKey('theme_white_btn'),
                            onPressed: () =>
                                settingsService.setThemeMode(AppThemeMode.light),
                            style: OutlinedButton.styleFrom(
                              backgroundColor:
                                  settingsService.themeMode == AppThemeMode.light
                                      ? palette.textPrimary
                                      : Colors.transparent,
                              foregroundColor:
                                  settingsService.themeMode == AppThemeMode.light
                                      ? palette.background
                                      : palette.textPrimary,
                              side: BorderSide(
                                color: settingsService.themeMode ==
                                        AppThemeMode.light
                                    ? palette.textPrimary
                                    : palette.border,
                                width: 1,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            child: Text(
                              'WHITE',
                              style: AppTypography.sectionHeading.copyWith(
                                fontSize: 11,
                                color: settingsService.themeMode ==
                                        AppThemeMode.light
                                    ? palette.background
                                    : palette.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // -----------------------------------------------------------------
            // SECTION 5: ABOUT (App version & Protocol version)
            // -----------------------------------------------------------------
            _buildSectionHeader('ABOUT', palette),
            const SizedBox(height: 8),
            Container(
              key: const ValueKey('about_section'),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: palette.card,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: palette.border, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTelemetryRow(
                    label: 'APPLICATION',
                    value: AppConstants.appName,
                    palette: palette,
                  ),
                  const Divider(height: 20),
                  _buildTelemetryRow(
                    label: 'APP VERSION',
                    value: AppConstants.appVersion,
                    valueKey: 'about_app_version',
                    palette: palette,
                  ),
                  const Divider(height: 20),
                  _buildTelemetryRow(
                    label: 'BRIDGE PROTOCOL',
                    value: configProvider.config.protocolVersion,
                    valueKey: 'about_protocol_version',
                    palette: palette,
                  ),
                  const Divider(height: 20),
                  InkWell(
                    key: const ValueKey('settings_client_mode_toggle'),
                    onTap: () {
                      final current = configProvider.config.mode;
                      final next = current == BridgeMode.mock
                          ? BridgeMode.dev
                          : (current == BridgeMode.dev
                              ? BridgeMode.production
                              : BridgeMode.mock);
                      configProvider.updateConfig(
                        configProvider.config.copyWith(mode: next),
                      );
                    },
                    child: _buildTelemetryRow(
                      label: 'CLIENT MODE (TAP TO CHANGE)',
                      value: configProvider.config.mode.name.toUpperCase(),
                      palette: palette,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, AppPalette palette) {
    return Text(
      title,
      style: AppTypography.mutedMetadata.copyWith(
        color: palette.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildTelemetryRow({
    required String label,
    required String value,
    String? valueKey,
    required AppPalette palette,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.mutedMetadata.copyWith(
            color: palette.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          key: valueKey != null ? ValueKey(valueKey) : null,
          style: AppTypography.monoConsole.copyWith(
            fontSize: 12,
            color: palette.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildLiveStatusBadge(
      bool isConnected, bool isTransitioning, AppPalette palette) {
    final Color color;
    final String label;

    if (isConnected) {
      color = palette.accentGreen;
      label = '● Connected';
    } else if (isTransitioning) {
      color = palette.textMuted;
      label = '○ Connecting...';
    } else {
      color = palette.errorRed;
      label = '● Disconnected';
    }

    return Container(
      key: const ValueKey('settings_connection_status'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style: AppTypography.monoConsole.copyWith(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
