import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../app/shell.dart';
import '../../../app/theme.dart';
import '../../../core/network/bridge_config_provider.dart';
import '../../../core/services/command_service.dart';
import '../../../core/services/connection_service.dart';
import '../../../core/storage/secure_storage_service.dart';

/// Command console Home Screen featuring real-time connection status block,
/// primary centered microphone control, last command telemetry, and quick action links.
class HomeScreen extends StatefulWidget {
  final bool autoConnectOnLaunch;

  const HomeScreen({
    super.key,
    this.autoConnectOnLaunch = true,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _checkedAutoConnect = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoConnectOnLaunch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkSilentReauth();
      });
    }
  }

  Future<void> _checkSilentReauth() async {
    if (_checkedAutoConnect || !mounted) return;
    _checkedAutoConnect = true;

    final connectionService = context.read<ConnectionService>();
    if (connectionService.currentState.isConnected) return;

    final secureStorage = context.read<SecureStorageService>();
    final configProvider = context.read<BridgeConfigProvider>();

    final token = await secureStorage.getToken();

    // Silent re-authentication is executed only when a token already exists (returning-user flow)
    if (token == null || token.isEmpty || !mounted) return;

    final result = await connectionService.silentReauthenticate(
      mode: configProvider.config.mode,
    );

    if (!mounted) return;

    // INVALID_TOKEN failure path: token was cleared by service, route user back to pairing
    if (result == StartupFlowResult.pairingRequired) {
      final palette = context.palette;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Session expired or invalid. Please re-pair your Windows device.',
            style: AppTypography.body.copyWith(color: Colors.white),
          ),
          backgroundColor: palette.errorRed,
          duration: const Duration(seconds: 3),
        ),
      );
      Navigator.pushNamed(
        context,
        AppRoutes.pairing,
        arguments: connectionService.activeDevice,
      );
    }
  }

  void _onRetryPressed() async {
    final connectionService = context.read<ConnectionService>();
    final configProvider = context.read<BridgeConfigProvider>();
    await connectionService.runStartupFlow(mode: configProvider.config.mode);
  }

  void _navigateToSection(int tabIndex, String routeName) {
    final shell = context.findAncestorStateOfType<AppShellState>();
    if (shell != null) {
      shell.setTab(tabIndex);
    } else {
      Navigator.pushNamed(context, routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final connectionService = context.watch<ConnectionService>();
    final commandService = context.watch<CommandService>();
    final state = connectionService.currentState;
    final isConnected = state.isConnected;
    final isTransitioning = state.isTransitioning;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(
          'WINDOWS REMOTE',
          style: AppTypography.sectionHeading.copyWith(
            color: palette.textPrimary,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 20),
            tooltip: 'Settings',
            onPressed: () => _navigateToSection(3, AppRoutes.settings),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: palette.border,
            height: 1.0,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Status Block: "WINDOWS / {device name} / ● Connected"
              _buildStatusBlock(connectionService, palette),

              // 2. Offline State Card (when disconnected) with [RETRY] button
              if (!isConnected && !isTransitioning) ...[
                const SizedBox(height: 12),
                _buildOfflineCard(connectionService, palette),
              ],

              const SizedBox(height: 18),

              // 3. Primary visual focus: Large centered microphone button
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildMicButton(context, isConnected, palette),
                    const SizedBox(height: 10),
                    Text(
                      'Tap to give a command',
                      key: const ValueKey('tap_to_command_caption'),
                      style: AppTypography.mutedMetadata.copyWith(
                        color: palette.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // 4. Divider
              const Divider(),
              const SizedBox(height: 14),

              // 5. "Last command" with its text and ✓/✕ status
              _buildLastCommandBlock(commandService, palette),

              const SizedBox(height: 14),

              // 6. Divider
              const Divider(),
              const SizedBox(height: 14),

              // 7. Row of quick links: COMMANDS / FILES / PHOTOS
              _buildQuickLinks(context, palette),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  /// Subtle real-time status block matching exact specification:
  /// "WINDOWS / {device name} / ● Connected" (small, subtle indicator; never a big banner;
  /// connecting = hollow circle, disconnected = red/gray dot).
  Widget _buildStatusBlock(
      ConnectionService connectionService, AppPalette palette) {
    final state = connectionService.currentState;
    final isConnected = state.isConnected;
    final isTransitioning = state.isTransitioning;
    final activeDevice = connectionService.activeDevice;
    final deviceName = activeDevice?.name ?? 'My Windows PC';

    final Widget dotWidget;
    final String statusText;
    final Color statusTextColor;

    if (isConnected) {
      dotWidget = Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: palette.accentGreen,
          shape: BoxShape.circle,
        ),
      );
      statusText = 'Connected';
      statusTextColor = palette.accentGreen;
    } else if (isTransitioning || connectionService.isReconnecting) {
      dotWidget = Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: palette.textMuted, width: 1.5),
        ),
      );
      statusText = connectionService.isReconnecting ? 'Reconnecting...' : 'Connecting...';
      statusTextColor = palette.textMuted;
    } else {
      dotWidget = Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: palette.errorRed,
          shape: BoxShape.circle,
        ),
      );
      statusText = 'Disconnected';
      statusTextColor = palette.textMuted;
    }

    return Container(
      key: const ValueKey('home_status_block'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: palette.border, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'WINDOWS / $deviceName / ',
                    style: AppTypography.monoConsole.copyWith(
                      color: palette.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  dotWidget,
                  const SizedBox(width: 6),
                  Text(
                    statusText,
                    style: AppTypography.monoConsole.copyWith(
                      color: statusTextColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (!isConnected && !isTransitioning)
            InkWell(
              key: const ValueKey('home_connect_link'),
              onTap: () => Navigator.pushNamed(context, AppRoutes.discovery),
              child: Text(
                'CONNECT',
                style: AppTypography.mutedMetadata.copyWith(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            )
          else if (isConnected) ...[
            InkWell(
              key: const ValueKey('home_disconnect_link'),
              onTap: () => connectionService.disconnect(),
              child: Text(
                'DISCONNECT',
                style: AppTypography.mutedMetadata.copyWith(
                  color: palette.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 10),
            InkWell(
              key: const ValueKey('home_unpair_link'),
              onTap: () async {
                await connectionService.unpair();
                if (mounted) {
                  Navigator.pushNamed(context, AppRoutes.discovery);
                }
              },
              child: Text(
                'UNPAIR',
                style: AppTypography.mutedMetadata.copyWith(
                  color: palette.errorRed,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Offline state card showing connection failure and [RETRY] button
  /// while keeping the rest of the application fully usable.
  Widget _buildOfflineCard(
      ConnectionService connectionService, AppPalette palette) {
    final activeDevice = connectionService.activeDevice;

    return Container(
      key: const ValueKey('offline_state_card'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: palette.border, width: 1),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_outlined,
            color: palette.textMuted,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BRIDGE OFFLINE',
                  style: AppTypography.sectionHeading.copyWith(
                    color: palette.textPrimary,
                    fontSize: 12,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  connectionService.errorMessage ??
                      (activeDevice != null
                          ? 'Cannot reach ${activeDevice.host}:${activeDevice.port}'
                          : 'Bridge host is disconnected or unreachable.'),
                  key: const ValueKey('home_offline_card_message'),
                  style: AppTypography.mutedMetadata.copyWith(
                    color: palette.textMuted,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            key: const ValueKey('offline_retry_btn'),
            onPressed: _onRetryPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.secondary,
              foregroundColor: palette.textPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              side: BorderSide(color: palette.border, width: 1),
              minimumSize: Size.zero,
            ),
            child: Text(
              'RETRY',
              style: AppTypography.sectionHeading.copyWith(
                color: palette.textPrimary,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Geometric, minimal microphone button as primary visual focus (zero glow, zero phone-call clichés).
  Widget _buildMicButton(
      BuildContext context, bool isConnected, AppPalette palette) {
    return InkWell(
      key: const ValueKey('mic_command_btn'),
      onTap: () {
        Navigator.pushNamed(context, AppRoutes.voice);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isConnected ? palette.textPrimary : palette.border,
            width: 1.5,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.mic_none_rounded,
            size: 40,
            color: isConnected ? palette.textPrimary : palette.textMuted,
          ),
        ),
      ),
    );
  }

  /// "Last command" section displaying message telemetry and ✓/✕ status indicator.
  Widget _buildLastCommandBlock(
      CommandService commandService, AppPalette palette) {
    final last = commandService.lastCommand;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'LAST COMMAND',
              style: AppTypography.mutedMetadata.copyWith(
                color: palette.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
            if (last != null)
              Text(
                '${last.timestamp.hour.toString().padLeft(2, '0')}:${last.timestamp.minute.toString().padLeft(2, '0')}:${last.timestamp.second.toString().padLeft(2, '0')}',
                style: AppTypography.monoConsole.copyWith(
                  color: palette.textMuted,
                  fontSize: 10,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          key: const ValueKey('last_command_block'),
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: palette.border, width: 1),
          ),
          child: last != null
              ? Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: (last.success
                                ? palette.accentGreen
                                : palette.errorRed)
                            .withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: last.success
                              ? palette.accentGreen
                              : palette.errorRed,
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          last.success ? '✓' : '✕',
                          style: TextStyle(
                            color: last.success
                                ? palette.accentGreen
                                : palette.errorRed,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        last.message,
                        style: AppTypography.monoConsole.copyWith(
                          color: palette.textPrimary,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      last.status.toUpperCase(),
                      style: AppTypography.mutedMetadata.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: last.success
                            ? palette.accentGreen
                            : palette.errorRed,
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Text(
                      '—',
                      style: AppTypography.monoConsole.copyWith(
                        color: palette.textMuted,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'No commands executed yet',
                      style: AppTypography.mutedMetadata.copyWith(
                        color: palette.textMuted,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  /// Quick link navigation tiles for COMMANDS, FILES, and PHOTOS.
  Widget _buildQuickLinks(BuildContext context, AppPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QUICK ACTIONS',
          style: AppTypography.mutedMetadata.copyWith(
            color: palette.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildQuickLinkTile(
              key: const ValueKey('quick_link_commands'),
              icon: Icons.terminal_outlined,
              label: 'COMMANDS',
              onTap: () => Navigator.pushNamed(context, AppRoutes.commands),
              palette: palette,
            ),
            const SizedBox(width: 10),
            _buildQuickLinkTile(
              key: const ValueKey('quick_link_files'),
              icon: Icons.folder_outlined,
              label: 'FILES',
              onTap: () => _navigateToSection(1, AppRoutes.files),
              palette: palette,
            ),
            const SizedBox(width: 10),
            _buildQuickLinkTile(
              key: const ValueKey('quick_link_photos'),
              icon: Icons.photo_library_outlined,
              label: 'PHOTOS',
              onTap: () => _navigateToSection(2, AppRoutes.photos),
              palette: palette,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickLinkTile({
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required AppPalette palette,
  }) {
    return Expanded(
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: palette.border, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: palette.textPrimary),
              const SizedBox(height: 6),
              Text(
                label,
                style: AppTypography.mutedMetadata.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: palette.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
