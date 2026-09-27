import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/models/command_history_item.dart';
import '../../../core/services/command_history_service.dart';

/// Screen displaying persistent local command execution history, newest first.
/// Reachable via Home's quick link: COMMANDS.
class CommandsScreen extends StatelessWidget {
  const CommandsScreen({super.key});

  String _formatTimestamp(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final historyService = context.watch<CommandHistoryService>();
    final history = historyService.history;

    return Scaffold(
      key: const ValueKey('commands_screen'),
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(
          'COMMANDS',
          style: AppTypography.sectionHeading.copyWith(
            color: palette.textPrimary,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          if (history.isNotEmpty)
            TextButton(
              key: const ValueKey('clear_history_btn'),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: palette.card,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                      side: BorderSide(color: palette.border, width: 1),
                    ),
                    title: Text(
                      'Clear History',
                      style: AppTypography.sectionHeading.copyWith(
                        color: palette.textPrimary,
                      ),
                    ),
                    content: Text(
                      'Clear all recorded command history entries?',
                      style: AppTypography.body.copyWith(
                        color: palette.textPrimary,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(
                          'CANCEL',
                          style: AppTypography.mutedMetadata.copyWith(
                            color: palette.textMuted,
                          ),
                        ),
                      ),
                      TextButton(
                        key: const ValueKey('confirm_clear_btn'),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(
                          'CLEAR',
                          style: AppTypography.mutedMetadata.copyWith(
                            color: palette.errorRed,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await historyService.clearHistory();
                }
              },
              child: Text(
                'CLEAR',
                style: AppTypography.mutedMetadata.copyWith(
                  color: palette.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          IconButton(
            key: const ValueKey('commands_voice_btn'),
            icon: Icon(Icons.mic_none_rounded, size: 20, color: palette.textPrimary),
            tooltip: 'Voice Command',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.voice),
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
        child: history.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: palette.card,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: palette.border, width: 1),
                        ),
                        child: Icon(
                          Icons.terminal_outlined,
                          size: 28,
                          color: palette.textMuted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'NO COMMANDS RECORDED',
                        style: AppTypography.sectionHeading.copyWith(
                          color: palette.textPrimary,
                          fontSize: 13,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Commands sent via voice or text will appear here with execution timestamps and status.',
                        style: AppTypography.mutedMetadata.copyWith(
                          color: palette.textMuted,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        key: const ValueKey('start_voice_command_btn'),
                        onPressed: () =>
                            Navigator.pushNamed(context, AppRoutes.voice),
                        icon: const Icon(Icons.mic_none_rounded, size: 16),
                        label: const Text('VOICE COMMAND'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: palette.card,
                          foregroundColor: palette.textPrimary,
                          side: BorderSide(color: palette.border, width: 1),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.separated(
                key: const ValueKey('command_history_list'),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: history.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = history[index];
                  return _buildCommandTile(item, index, palette);
                },
              ),
      ),
    );
  }

  Widget _buildCommandTile(
      CommandHistoryItem item, int index, AppPalette palette) {
    final isSuccess = item.success;

    return Container(
      key: ValueKey('command_item_$index'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: palette.border, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status indicator (✓ or ✕)
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: (isSuccess ? palette.accentGreen : palette.errorRed)
                  .withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: isSuccess ? palette.accentGreen : palette.errorRed,
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                isSuccess ? '✓' : '✕',
                style: TextStyle(
                  color: isSuccess ? palette.accentGreen : palette.errorRed,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Command text and details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.commandText,
                  style: AppTypography.monoConsole.copyWith(
                    color: palette.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      _formatTimestamp(item.timestamp),
                      style: AppTypography.mutedMetadata.copyWith(
                        color: palette.textMuted,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '•',
                      style: AppTypography.mutedMetadata.copyWith(
                        color: palette.textMuted,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item.status.toUpperCase(),
                      style: AppTypography.mutedMetadata.copyWith(
                        fontSize: 10,
                        color: isSuccess
                            ? palette.accentGreen
                            : palette.errorRed,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
