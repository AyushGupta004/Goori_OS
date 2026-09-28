import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_errors.dart';
import '../../../core/models/models.dart';
import '../../../core/services/connection_service.dart';
import '../../../core/services/photo_transfer_service.dart';
import '../../connection/screens/discovery_screen.dart';
import '../services/image_picker_service.dart';

/// Screen managing photo capture, gallery multi-selection, thumbnail grid preview,
/// and batch streaming to Windows AI Bridge.
/// Conforms to Task 9 requirements:
/// - [Camera] and [Gallery] buttons using image_picker; multi-select gallery & single camera capture
/// - Camera/photos permission requested strictly on first tap of each button, never on screen load
/// - Thumbnail grid with remove (✕) affordance per photo
/// - Memory-light thumbnail rendering (cacheWidth/cacheHeight: 256)
/// - [SEND TO PC] batch upload triggering PhotoTransferService.uploadPhoto() per photo
/// - Inline progress states (waiting/uploading/completed/failed) on each thumbnail
class PhotosScreen extends StatefulWidget {
  final ImagePickerService? imagePickerService;

  const PhotosScreen({
    super.key,
    this.imagePickerService,
  });

  @override
  State<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends State<PhotosScreen> {
  late ImagePickerService _imagePickerService;
  String? _permissionError;

  @override
  void initState() {
    super.initState();
    _imagePickerService =
        widget.imagePickerService ?? NativeImagePickerService();
    // Permissions are strictly NOT checked or requested on load per specification
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.imagePickerService == null) {
      try {
        _imagePickerService = context.read<ImagePickerService>();
      } catch (_) {}
    }
  }

  @override
  void didUpdateWidget(PhotosScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imagePickerService != null &&
        widget.imagePickerService != _imagePickerService) {
      _imagePickerService = widget.imagePickerService!;
    }
  }

  /// Handles Camera button tap: requests camera permission on first tap, then captures single photo.
  Future<void> _onCameraPressed() async {
    final hasPermission = await _imagePickerService.requestCameraPermission();
    if (!hasPermission) {
      setState(() {
        _permissionError =
            'Camera permission is required to capture photos for transfer to your Windows PC.';
      });
      return;
    }

    setState(() {
      _permissionError = null;
    });

    final photo = await _imagePickerService.capturePhotoFromCamera();
    if (photo == null || !mounted) return;

    final photoService = context.read<PhotoTransferService>();
    photoService.addPhoto(photo);
  }

  /// Handles Gallery button tap: requests photos permission on first tap, then multi-selects photos.
  Future<void> _onGalleryPressed() async {
    final hasPermission = await _imagePickerService.requestPhotosPermission();
    if (!hasPermission) {
      setState(() {
        _permissionError =
            'Photos permission is required to select photos for transfer to your Windows PC.';
      });
      return;
    }

    setState(() {
      _permissionError = null;
    });

    final photos = await _imagePickerService.pickMultiImageFromGallery();
    if (photos == null || photos.isEmpty || !mounted) return;

    final photoService = context.read<PhotoTransferService>();
    photoService.addPhotos(photos);
  }

  /// Dispatches all staged photos to the Windows bridge.
  Future<void> _onSendToPCPressed() async {
    final photoService = context.read<PhotoTransferService>();
    await photoService.sendAllToPC();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final connection = context.watch<ConnectionService>();
    final isAuthenticated = connection.isAuthenticated;
    final photoService = context.watch<PhotoTransferService>();
    final photos = photoService.photos;
    final isUploading = photoService.isUploading;
    final hasFinishedPhotos = photos.any((p) => p.isFinished);

    return Scaffold(
      key: const ValueKey('photos_screen'),
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(
          'PHOTO TRANSMIT',
          style: AppTypography.sectionHeading.copyWith(
            letterSpacing: 1.2,
            color: palette.textPrimary,
          ),
        ),
        actions: [
          if (hasFinishedPhotos)
            TextButton(
              key: const ValueKey('clear_completed_photos_btn'),
              onPressed: isUploading ? null : () => photoService.clearCompleted(),
              child: Text(
                'CLEAR',
                style: AppTypography.mutedMetadata.copyWith(
                  color: isUploading
                      ? palette.textMuted.withValues(alpha: 0.3)
                      : palette.textMuted,
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
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                children: [
                  // 0. Disconnected Strip (if not authenticated)
                  if (!isAuthenticated) ...[
                    _buildNotConnectedStrip(palette),
                  ],

                  // 1. Action Row: [Camera] / [Gallery] Buttons
                  _buildSourceButtons(isUploading, isAuthenticated, palette),

                  const SizedBox(height: 14),

                  // 2. Permission Rationale Card (if denied after tapping Camera or Gallery)
                  if (_permissionError != null) ...[
                    _buildPermissionRationaleCard(palette),
                    const SizedBox(height: 14),
                  ],

                  // 3. Header & Count
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'STAGED PHOTOS',
                        style: AppTypography.mutedMetadata.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                          color: palette.textMuted,
                        ),
                      ),
                      if (photos.isNotEmpty)
                        Text(
                          '${photos.length} TOTAL',
                          style: AppTypography.monoConsole.copyWith(
                            fontSize: 10,
                            color: palette.textMuted,
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // 4. Thumbnail Grid or Empty State
                  if (photos.isEmpty)
                    _buildEmptyPhotosCard(palette)
                  else
                    _buildThumbnailGrid(photos, photoService, isAuthenticated, palette),
                ],
              ),
            ),
            // 5. Pinned [SEND TO PC] Action Footer
            if (photos.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                decoration: BoxDecoration(
                  color: palette.background,
                  border: Border(
                    top: BorderSide(color: palette.border, width: 1.0),
                  ),
                ),
                child: _buildSendToPCButton(photoService, isAuthenticated, isUploading, palette),
              ),
          ],
        ),
      ),
    );
  }

  /// Subtle inline strip showing disconnection status with CONNECT action.
  Widget _buildNotConnectedStrip(AppPalette palette) {
    return Container(
      key: const ValueKey('photos_not_connected_strip'),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: palette.border, width: 1),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 18,
            color: palette.textMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Not connected to PC',
              style: AppTypography.mutedMetadata.copyWith(
                color: palette.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          InkWell(
            key: const ValueKey('photos_connect_btn'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DiscoveryScreen(),
                ),
              );
            },
            child: Text(
              'CONNECT',
              style: AppTypography.mutedMetadata.copyWith(
                color: palette.textPrimary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// [Camera] and [Gallery] action buttons.
  Widget _buildSourceButtons(bool isUploading, bool isAuthenticated, AppPalette palette) {
    final canPick = isAuthenticated && !isUploading;
    return Container(
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
              Expanded(
                child: ElevatedButton.icon(
                  key: const ValueKey('camera_btn'),
                  onPressed: canPick ? _onCameraPressed : null,
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: const Text('Camera'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.secondary,
                    foregroundColor: palette.textPrimary,
                    side: BorderSide(color: palette.border, width: 1),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  key: const ValueKey('gallery_btn'),
                  onPressed: canPick ? _onGalleryPressed : null,
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Gallery'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Multi-select gallery • Direct camera snap • Memory-light resized preview',
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

  /// Friendly permission rationale card displayed only after user tap if permission denied.
  Widget _buildPermissionRationaleCard(AppPalette palette) {
    return Container(
      key: const ValueKey('photo_permission_rationale_card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: palette.errorRed.withValues(alpha: 0.5), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.no_photography_outlined,
                color: palette.errorRed,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                'PERMISSION REQUIRED',
                style: AppTypography.sectionHeading.copyWith(
                  fontSize: 12,
                  color: palette.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _permissionError ?? 'Permission is required to proceed.',
            style: AppTypography.mutedMetadata.copyWith(
              fontSize: 12,
              height: 1.4,
              color: palette.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  /// Empty state card displayed when no photos have been staged.
  Widget _buildEmptyPhotosCard(AppPalette palette) {
    return Container(
      key: const ValueKey('empty_photos_card'),
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: palette.border, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.photo_outlined,
            size: 36,
            color: palette.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            'NO PHOTOS STAGED',
            style: AppTypography.sectionHeading.copyWith(
              fontSize: 12,
              letterSpacing: 0.8,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Use Camera or Gallery above to select photos to stream to Windows.',
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

  /// Grid of staged photos featuring memory-light thumbnail previews,
  /// remove (✕) affordance per photo, and inline progress states.
  Widget _buildThumbnailGrid(
    List<PhotoTransferItem> photos,
    PhotoTransferService photoService,
    bool isAuthenticated,
    AppPalette palette,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final item = photos[index];
        return _buildThumbnailCard(item, photoService, isAuthenticated, palette);
      },
    );
  }

  /// Individual photo card displaying memory-light thumbnail, remove ✕ button,
  /// and inline progress state (waiting/uploading/completed/failed).
  Widget _buildThumbnailCard(
    PhotoTransferItem item,
    PhotoTransferService photoService,
    bool isAuthenticated,
    AppPalette palette,
  ) {
    final progress = item.progress;
    final status = progress.status;
    final isCompleted = status == TransferStatus.completed;
    final isFailed = status == TransferStatus.failed;
    final isUploading = status == TransferStatus.uploading;
    final isWaiting = status == TransferStatus.waiting;

    final String statusLabel;
    final Color statusColor;

    if (isCompleted) {
      statusLabel = '✓ COMPLETED';
      statusColor = palette.accentGreen;
    } else if (isFailed) {
      statusLabel = '✕ FAILED';
      statusColor = palette.errorRed;
    } else if (isUploading) {
      statusLabel = 'UPLOADING ${progress.percentage}%';
      statusColor = palette.accentGreen;
    } else {
      statusLabel = 'WAITING';
      statusColor = palette.textMuted;
    }

    return InkWell(
      key: ValueKey('photo_tile_inkwell_${item.id}'),
      onTap: (isFailed && isAuthenticated && !isUploading)
          ? () => photoService.retryPhoto(item.id)
          : null,
      child: Container(
        key: ValueKey('photo_card_${item.id}'),
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Thumbnail Preview with Remove (✕) Affordance
            Expanded(
              child: Stack(
                children: [
                  // Memory-light thumbnail rendering (cacheWidth & cacheHeight: 256)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                      child: Image.file(
                        item.file,
                        cacheWidth: 256,
                        cacheHeight: 256,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: palette.secondary,
                            child: Center(
                              child: Icon(
                                Icons.image_outlined,
                                size: 32,
                                color: palette.textMuted.withValues(alpha: 0.6),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // Top-right Remove (✕) Button Affordance
                  if (!isUploading)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: InkWell(
                        key: ValueKey('remove_photo_btn_${item.id}'),
                        onTap: () => photoService.removePhoto(item.id),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            shape: BoxShape.circle,
                            border: Border.all(color: palette.border, width: 1),
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                  // Status Overlay on Thumbnail
                  Positioned(
                    bottom: 6,
                    left: 6,
                    right: 6,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(color: statusColor, width: 1),
                          ),
                          child: Text(
                            statusLabel,
                            key: ValueKey('photo_status_${item.id}'),
                            style: AppTypography.mutedMetadata.copyWith(
                              color: statusColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (isFailed)
                          InkWell(
                            key: ValueKey('retry_photo_btn_${item.id}'),
                            onTap: (isAuthenticated && !isUploading)
                                ? () => photoService.retryPhoto(item.id)
                                : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(2),
                                border: Border.all(color: palette.accentGreen, width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.refresh, size: 10, color: palette.accentGreen),
                                  const SizedBox(width: 2),
                                  Text(
                                    'RETRY',
                                    style: AppTypography.mutedMetadata.copyWith(
                                      color: palette.accentGreen,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 2. Linear Progress Bar
            ClipRRect(
              child: LinearProgressIndicator(
                key: ValueKey('photo_progress_bar_${item.id}'),
                value: isCompleted
                    ? 1.0
                    : (isWaiting ? 0.0 : progress.fraction),
                minHeight: 3,
                backgroundColor: palette.border,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isCompleted
                      ? palette.accentGreen
                      : (isFailed ? palette.errorRed : palette.accentGreen),
                ),
              ),
            ),

            // 3. Filename & Size Caption
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item.fileName,
                      key: ValueKey('photo_filename_${item.id}'),
                      style: AppTypography.monoConsole.copyWith(
                        fontSize: 10,
                        color: palette.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    item.formattedTotalSize,
                    style: AppTypography.monoConsole.copyWith(
                      fontSize: 9,
                      color: palette.textMuted,
                    ),
                  ),
                ],
              ),
            ),

            // 4. Mapped friendly error message if failed
            if (isFailed && progress.errorMessage != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0).copyWith(bottom: 6.0),
                child: Text(
                  AppErrorMapper.map(progress.errorMessage, fallback: AppErrors.uploadFailed),
                  key: ValueKey('photo_error_${item.id}'),
                  style: AppTypography.mutedMetadata.copyWith(
                    color: palette.errorRed,
                    fontSize: 9,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// [SEND TO PC] primary action button.
  Widget _buildSendToPCButton(
    PhotoTransferService photoService,
    bool isAuthenticated,
    bool isUploading,
    AppPalette palette,
  ) {
    final hasUploadable = photoService.hasUploadablePhotos;
    final onlyFailedRemain =
        !photoService.hasPendingPhotos && photoService.hasFailedPhotos;
    final canSend = isAuthenticated && hasUploadable && !isUploading;

    final String buttonLabel;
    if (isUploading) {
      buttonLabel = 'STREAMING TO WINDOWS...';
    } else if (onlyFailedRemain) {
      buttonLabel = 'RETRY FAILED (${photoService.failedCount})';
    } else {
      final count = photoService.waitingCount + photoService.failedCount;
      buttonLabel = 'SEND TO PC ($count)';
    }

    return ElevatedButton.icon(
      key: const ValueKey('send_to_pc_btn'),
      onPressed: canSend ? _onSendToPCPressed : null,
      icon: isUploading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(palette.textPrimary),
              ),
            )
          : const Icon(Icons.send_rounded, size: 18),
      label: Text(
        buttonLabel,
        style: AppTypography.sectionHeading.copyWith(
          letterSpacing: 0.8,
          fontSize: 12,
        ),
      ),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }
}
