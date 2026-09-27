import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../core/models/models.dart';

/// Card displaying a discovered or paired Windows AI Bridge host.
class DeviceCard extends StatelessWidget {
  final WindowsDevice device;
  final VoidCallback onConnect;
  final bool isConnecting;

  const DeviceCard({
    super.key,
    required this.device,
    required this.onConnect,
    this.isConnecting = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: palette.border, width: 1),
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
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              // Device info
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
                      'Windows AI Bridge',
                      style: AppTypography.mutedMetadata.copyWith(
                        color: palette.textMuted,
                      ),
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
          ),
        ],
      ),
    );
  }
}
