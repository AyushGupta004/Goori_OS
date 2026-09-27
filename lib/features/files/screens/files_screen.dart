import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/models.dart';
import '../../../core/services/file_transfer_service.dart';
import '../services/file_picker_service.dart';

/// Screen managing file selection and real-time streaming upload to Windows Bridge.
/// Conforms to Task 8 requirements:
/// - "+ Select Files" with multi-select support
/// - Active Transfers list with filename, progress bar, percentage, and 5 states:
///   waiting / uploading / completed / failed / cancelled
/// - Live progress streaming & cancellation of in-flight transfers
/// - Permission requested strictly upon tapping "+ Select Files", never on screen load
class FilesScreen extends StatefulWidget {
  final FilePickerService? filePickerService;

  const FilesScreen({
    super.key,
    this.filePickerService,
  });

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  late FilePickerService _filePickerService;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _filePickerService =
        widget.filePickerService ?? NativeFilePickerService();
    // Storage permission is strictly NOT requested on screen load per spec
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.filePickerService == null) {
      try {
        _filePickerService = context.read<FilePickerService>();
      } catch (_) {}
    }
  }

  @override
  void didUpdateWidget(FilesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filePickerService != null &&
        widget.filePickerService != _filePickerService) {
      _filePickerService = widget.filePickerService!;
    }
  }

  Future<void> _onSelectFilesPressed() async {
    // 1. Request permission strictly when user taps "+ Select Files"
    final hasPermission = await _filePickerService.requestStoragePermission();
    if (!hasPermission) {
      setState(() {
        _permissionDenied = true;
      });
      return;
    }

    setState(() {
      _permissionDenied = false;
    });

    // 2. Open file picker with multi-select enabled
    final files = await _filePickerService.pickFiles(allowMultiple: true);
    if (files == null || files.isEmpty) return;

    if (!mounted) return;

    // 3. Queue and stream files through FileTransferService
    final transferService = context.read<FileTransferService>();
    // Non-blocking invocation so UI stays completely responsive
    for (final file in files) {
      transferService.uploadFile(file);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final transferService = context.watch<FileTransferService>();
    final transfers = transferService.transfers;
    final hasFinishedTransfers = transfers.any((t) => t.progress.isFinished);

    return Scaffold(
      key: const ValueKey('files_screen'),
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(
          'FILE STREAM',
          style: AppTypography.sectionHeading.copyWith(
            letterSpacing: 1.2,
            color: palette.textPrimary,
          ),
        ),
        actions: [
          if (hasFinishedTransfers)
            TextButton(
              key: const ValueKey('clear_completed_transfers_btn'),
              onPressed: () => transferService.clearCompleted(),
              child: Text(
                'CLEAR',
                style: AppTypography.mutedMetadata.copyWith(
                  color: palette.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          children: [
            // 1. Select Files Action Card
            _buildSelectFilesCard(palette),

            const SizedBox(height: 16),

            // 2. Permission Rationale Card (if denied after tapping Select Files)
            if (_permissionDenied) ...[
              _buildPermissionRationaleCard(palette),
              const SizedBox(height: 16),
            ],

            // 3. Active Transfers Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ACTIVE TRANSFERS',
                  style: AppTypography.mutedMetadata.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: palette.textMuted,
                  ),
                ),
                if (transfers.isNotEmpty)
                  Text(
                    '${transfers.length} TOTAL',
                    style: AppTypography.monoConsole.copyWith(
                      fontSize: 10,
                      color: palette.textMuted,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 10),

            // 4. Transfers List or Empty State
            if (transfers.isEmpty)
              _buildEmptyTransfersCard(palette)
            else
              ...transfers.map((task) => _buildTransferItem(task, transferService, palette)),
          ],
        ),
      ),
    );
  }

  /// Header container housing the prominent "+ Select Files" action button.
  Widget _buildSelectFilesCard(AppPalette palette) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: palette.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            key: const ValueKey('select_files_btn'),
            onPressed: _onSelectFilesPressed,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('+ Select Files'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Multi-select supported • Streams directly to Windows without RAM caching',
            style: AppTypography.mutedMetadata.copyWith(
              fontSize: 11,
              height: 1.3,
              color: palette.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Friendly permission rationale card displayed only when permission was denied on tap.
  Widget _buildPermissionRationaleCard(AppPalette palette) {
    return Container(
      key: const ValueKey('storage_permission_rationale_card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: palette.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.folder_off_outlined,
                color: palette.errorRed,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                'STORAGE PERMISSION REQUIRED',
                style: AppTypography.sectionHeading.copyWith(
                  fontSize: 12,
                  color: palette.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Storage permission is required to select and stream files to your Windows PC.',
            style: AppTypography.mutedMetadata.copyWith(
              fontSize: 12,
              height: 1.4,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            key: const ValueKey('grant_storage_permission_btn'),
            onPressed: _onSelectFilesPressed,
            child: const Text('GRANT PERMISSION'),
          ),
        ],
      ),
    );
  }

  /// Empty state placeholder when no files have been queued.
  Widget _buildEmptyTransfersCard(AppPalette palette) {
    return Container(
      key: const ValueKey('empty_transfers_card'),
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: palette.border, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_upload_outlined,
            size: 32,
            color: palette.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            'NO ACTIVE TRANSFERS',
            style: AppTypography.sectionHeading.copyWith(
              fontSize: 12,
              letterSpacing: 0.8,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap "+ Select Files" to stream files to Windows.',
            style: AppTypography.mutedMetadata.copyWith(
              fontSize: 11,
              color: palette.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Individual transfer card rendering filename, progress bar, percentage, and 5 states.
  Widget _buildTransferItem(
    FileTransferTask task,
    FileTransferService transferService,
    AppPalette palette,
  ) {
    final progress = task.progress;
    final status = progress.status;
    final isFinished = progress.isFinished;
    final isUploading = status == TransferStatus.uploading;
    final isCompleted = status == TransferStatus.completed;
    final isFailed = status == TransferStatus.failed;
    final isCancelled = status == TransferStatus.cancelled;
    final isWaiting = status == TransferStatus.waiting;

    // Status badge text & styling per TransferProgress model
    final String statusLabel;
    final Color statusColor;

    if (isCompleted) {
      statusLabel = '✓ COMPLETED';
      statusColor = palette.accentGreen;
    } else if (isFailed) {
      statusLabel = '✕ FAILED';
      statusColor = palette.errorRed;
    } else if (isCancelled) {
      statusLabel = 'CANCELLED';
      statusColor = palette.textMuted;
    } else if (isUploading) {
      statusLabel = 'UPLOADING ${progress.percentage}%';
      statusColor = palette.accentGreen;
    } else {
      statusLabel = 'WAITING';
      statusColor = palette.textMuted;
    }

    return Container(
      key: ValueKey('transfer_card_${task.transferId}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isCompleted
              ? palette.accentGreen.withValues(alpha: 0.3)
              : (isFailed
                  ? palette.errorRed.withValues(alpha: 0.3)
                  : palette.border),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Filename and Status Badge
          Row(
            children: [
              Icon(
                _getFileIcon(task.fileName),
                size: 18,
                color: palette.textPrimary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  task.fileName,
                  key: ValueKey('filename_${task.transferId}'),
                  style: AppTypography.monoConsole.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: palette.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(color: statusColor, width: 1),
                ),
                child: Text(
                  statusLabel,
                  key: ValueKey('status_${task.transferId}'),
                  style: AppTypography.mutedMetadata.copyWith(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Row 2: Progress bar (LinearProgressIndicator)
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              key: ValueKey('progress_bar_${task.transferId}'),
              value: isCompleted
                  ? 1.0
                  : (isWaiting ? 0.0 : progress.fraction),
              minHeight: 4,
              backgroundColor: palette.border,
              valueColor: AlwaysStoppedAnimation<Color>(
                isCompleted
                    ? palette.accentGreen
                    : (isFailed
                        ? palette.errorRed
                        : (isCancelled ? palette.textMuted : palette.accentGreen)),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Row 3: Transferred size, percentage, and Cancel action button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${task.formattedTransferredSize} / ${task.formattedTotalSize} (${progress.percentage}%)',
                key: ValueKey('progress_text_${task.transferId}'),
                style: AppTypography.monoConsole.copyWith(
                  fontSize: 11,
                  color: palette.textMuted,
                ),
              ),
              if (!isFinished)
                InkWell(
                  key: ValueKey('cancel_transfer_btn_${task.transferId}'),
                  onTap: () => transferService.cancelTransfer(task.transferId),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(
                      'CANCEL',
                      style: AppTypography.mutedMetadata.copyWith(
                        color: palette.errorRed,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // Error details if failed
          if (isFailed && progress.errorMessage != null) ...[
            const SizedBox(height: 6),
            Text(
              progress.errorMessage!,
              key: ValueKey('error_msg_${task.transferId}'),
              style: AppTypography.mutedMetadata.copyWith(
                color: palette.errorRed,
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getFileIcon(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
    if (lower.endsWith('.zip') || lower.endsWith('.rar') || lower.endsWith('.tar')) {
      return Icons.folder_zip_outlined;
    }
    if (lower.endsWith('.txt') || lower.endsWith('.md')) {
      return Icons.description_outlined;
    }
    if (lower.endsWith('.jpg') || lower.endsWith('.png') || lower.endsWith('.webp')) {
      return Icons.image_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }
}
