import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../core/models/models.dart';

/// Card displaying a discovered or paired Windows AI Bridge host.
class DeviceCard extends StatelessWidget {
  final WindowsDevice device;
  final VoidCallback onConnect;
  final VoidCallback? onRetry;
  final bool isConnecting;

  const DeviceCard({
    super.key,
    required this.device,
    required this.onConnect,
    this.onRetry,
    this.isConnecting = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isResponding = device.isResponding;

    final cardContent = Container(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isResponding
              ? palette.border
              : palette.errorRed.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Host icon box
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
                  color: isResponding ? palette.textPrimary : palette.textMuted,
                ),
              ),
              const SizedBox(width: 12),
              // Device info
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
                              color: isResponding
                                  ? palette.textPrimary
                                  : palette.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (device.id.startsWith('mock') ||
                            device.name.toUpperCase().contains('SIMULAT') ||
                            device.osVersion?.toUpperCase().contains('SIMULAT') ==
                                true) ...[
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
                      'Windows AI Bridge',
                      style: AppTypography.mutedMetadata.copyWith(
                        color: palette.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isResponding
                                ? palette.accentGreen
                                : palette.errorRed,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isResponding ? 'Online' : 'Not responding',
                          key: isResponding
                              ? null
                              : const ValueKey('device_not_responding_badge'),
                          style: AppTypography.mutedMetadata.copyWith(
                            color: isResponding
                                ? palette.textMuted
                                : palette.errorRed,
                            fontWeight: isResponding
                                ? FontWeight.normal
                                : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 10),
          // Network endpoint metadata
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'HOST',
                style: AppTypography.mutedMetadata.copyWith(
                  color: palette.textMuted,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
              Text(
                '${device.host}:${device.port}',
                style: AppTypography.monoConsole.copyWith(
                  color: palette.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Action button
          if (isResponding)
            ElevatedButton(
              key: ValueKey('connect_btn_${device.id}'),
              onPressed: isConnecting ? null : onConnect,
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.textPrimary,
                foregroundColor: palette.background,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: isConnecting
                  ? Text(
                      'CONNECTING...',
                      style: AppTypography.sectionHeading.copyWith(
                        color: palette.background,
                        fontSize: 13,
                        letterSpacing: 1.0,
                      ),
                    )
                  : Text(
                      'CONNECT',
                      style: AppTypography.sectionHeading.copyWith(
                        color: palette.background,
                        fontSize: 13,
                        letterSpacing: 1.0,
                      ),
                    ),
            )
          else
            OutlinedButton(
              key: ValueKey('retry_btn_${device.id}'),
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: palette.textPrimary,
                side: BorderSide(color: palette.border, width: 1),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: Text(
                'RETRY',
                style: AppTypography.sectionHeading.copyWith(
                  fontSize: 13,
                  letterSpacing: 1.0,
                ),
              ),
            ),
        ],
      ),
    );

    if (!isResponding) {
      return Opacity(
        opacity: 0.65,
        child: cardContent,
      );
    }
    return cardContent;
  }
}
