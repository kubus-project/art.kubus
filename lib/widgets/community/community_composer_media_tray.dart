import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../community/community_composer_media.dart';
import '../../community/community_upload_feedback.dart';
import '../../config/config.dart';
import '../../l10n/app_localizations.dart';
import '../inline_loading.dart';
import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';

/// Ordered thumbnails for the Community composer, shared by mobile and desktop.
///
/// Shows the running count, the add-photos and add-video actions, and a strip
/// of items that can be dragged, nudged with the move buttons, or removed.
/// Nothing is shown for an empty composer beyond its actions.
class CommunityComposerMediaTray extends StatelessWidget {
  const CommunityComposerMediaTray({
    super.key,
    required this.controller,
    required this.onAddPhotos,
    required this.onAddVideo,
    this.thumbnailSize = 96,
    this.showAddActions = true,
  });

  final CommunityComposerMediaController controller;
  final VoidCallback onAddPhotos;
  final VoidCallback onAddVideo;
  final double thumbnailSize;

  /// Hide the in-tray add buttons when the host already offers them.
  final bool showAddActions;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context)!;
        final scheme = Theme.of(context).colorScheme;
        final items = controller.items;
        final locked = controller.isLocked;
        final canAdd = !locked && !controller.isFull;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (controller.publishError != null) ...[
              Semantics(
                liveRegion: true,
                child: Text(
                  communityComposerFailureMessage(
                    l10n,
                    controller.publishError!,
                    unuploadedMediaCount: controller.hasFailedUploads
                        ? controller.unuploadedCount
                        : null,
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.error,
                      ),
                ),
              ),
              if (communityPostAlreadyCommitted(controller.publishError!))
                TextButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(AppConfig.appBaseUrl).resolve('/community'),
                    webOnlyWindowName: '_blank',
                  ),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(l10n.communityComposerCheckFeed),
                ),
              const SizedBox(height: KubusSpacing.xs),
            ],
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: KubusSpacing.xs,
              runSpacing: KubusSpacing.xs,
              children: [
                Text(
                  l10n.communityComposerMediaCount(
                    controller.length,
                    controller.maxItems,
                  ),
                  style: KubusTypography.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                if (showAddActions)
                  TextButton.icon(
                    onPressed: canAdd ? onAddPhotos : null,
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: Text(l10n.communityComposerMediaAddPhotos),
                  ),
                if (showAddActions)
                  TextButton.icon(
                    onPressed: canAdd ? onAddVideo : null,
                    icon: const Icon(Icons.videocam_outlined, size: 18),
                    label: Text(l10n.communityComposerMediaAddVideo),
                  ),
              ],
            ),
            if (controller.isFull)
              Padding(
                padding: const EdgeInsets.only(bottom: KubusSpacing.xs),
                child: Text(
                  l10n.communityComposerMediaLimitReached(controller.maxItems),
                  style: KubusTypography.inter(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (items.isNotEmpty)
              SizedBox(
                height: thumbnailSize,
                child: ReorderableListView.builder(
                  scrollDirection: Axis.horizontal,
                  buildDefaultDragHandles: false,
                  padding: EdgeInsets.zero,
                  itemCount: items.length,
                  onReorderItem: (from, to) {
                    if (locked) return;
                    controller.reorder(from, to);
                  },
                  proxyDecorator: (child, index, animation) =>
                      Material(color: Colors.transparent, child: child),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Padding(
                      key: ValueKey<String>(item.id),
                      padding: const EdgeInsets.only(right: KubusSpacing.sm),
                      child: ReorderableDelayedDragStartListener(
                        index: index,
                        child: _CommunityComposerMediaThumbnail(
                          item: item,
                          position: index + 1,
                          total: items.length,
                          size: thumbnailSize,
                          locked: locked,
                          canMoveEarlier: index > 0,
                          canMoveLater: index < items.length - 1,
                          onRemove: () => controller.remove(item.id),
                          onMoveEarlier: () => controller.moveBy(item.id, -1),
                          onMoveLater: () => controller.moveBy(item.id, 1),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CommunityComposerMediaThumbnail extends StatelessWidget {
  const _CommunityComposerMediaThumbnail({
    required this.item,
    required this.position,
    required this.total,
    required this.size,
    required this.locked,
    required this.canMoveEarlier,
    required this.canMoveLater,
    required this.onRemove,
    required this.onMoveEarlier,
    required this.onMoveLater,
  });

  final CommunityComposerMediaItem item;
  final int position;
  final int total;
  final double size;
  final bool locked;
  final bool canMoveEarlier;
  final bool canMoveLater;
  final VoidCallback onRemove;
  final VoidCallback onMoveEarlier;
  final VoidCallback onMoveLater;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final failed = item.status == CommunityComposerUploadStatus.failed;
    final uploading = item.status == CommunityComposerUploadStatus.uploading;
    final typeLabel = item.isVideo ? l10n.commonVideo : l10n.commonImage;
    final positionLabel = l10n.communityMediaCarouselPosition(position, total);

    return Semantics(
      container: true,
      label: '$typeLabel, $positionLabel',
      child: SizedBox(
        width: size,
        height: size,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(KubusRadius.md),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: failed ? KubusColors.error : Colors.transparent,
                width: failed ? 2 : 0,
              ),
              borderRadius: BorderRadius.circular(KubusRadius.md),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildPreview(context),
                if (uploading)
                  ColoredBox(
                    color: scheme.surface.withValues(alpha: 0.6),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: InlineLoading(
                          tileSize: 4,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  ),
                if (failed)
                  ColoredBox(
                    color: scheme.surface.withValues(alpha: 0.6),
                    child: Center(
                      child: Icon(
                        Icons.error_outline,
                        color: KubusColors.error,
                        size: 24,
                      ),
                    ),
                  ),
                Positioned(
                  top: KubusSpacing.xxs,
                  left: KubusSpacing.xxs,
                  child: _PositionBadge(label: '$position'),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: _TileIconButton(
                    tooltip: l10n.commonRemove,
                    icon: Icons.close,
                    onPressed: locked ? null : onRemove,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _TileIconButton(
                        tooltip: l10n.communityComposerMediaMoveEarlier,
                        icon: Icons.chevron_left,
                        onPressed:
                            locked || !canMoveEarlier ? null : onMoveEarlier,
                      ),
                      _TileIconButton(
                        tooltip: l10n.communityComposerMediaMoveLater,
                        icon: Icons.chevron_right,
                        onPressed: locked || !canMoveLater ? null : onMoveLater,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    final bytes = item.imageBytes;
    if (item.isImage && bytes != null) {
      return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
    }
    final typed = _buildTypedTile(context);
    if (item.isVideo) {
      return _ComposerVideoPreview(file: item.file, fallback: typed);
    }
    return typed;
  }

  Widget _buildTypedTile(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.primaryContainer.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(KubusSpacing.xxs),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              item.isVideo ? Icons.videocam_outlined : Icons.image_outlined,
              size: 28,
              color: scheme.primary,
            ),
            const SizedBox(height: KubusSpacing.xxs),
            Text(
              item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: KubusTypography.inter(
                fontSize: 11,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PositionBadge extends StatelessWidget {
  const _PositionBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Container(
        constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
        padding: const EdgeInsets.symmetric(horizontal: KubusSpacing.xs),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(KubusRadius.pill),
        ),
        child: Text(
          label,
          style: KubusTypography.inter(
            fontSize: KubusSizes.badgeCountFontSize,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _TileIconButton extends StatelessWidget {
  const _TileIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        minimumSize: const Size(30, 30),
        maximumSize: const Size(30, 30),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: scheme.surface.withValues(alpha: 0.85),
        foregroundColor: scheme.onSurface,
        disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.3),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
    );
  }
}

/// First frame of a picked video, shown paused and muted behind the tile
/// chrome. Falls back to the typed tile while the clip loads, and for good if it
/// cannot be decoded here (the upload still goes ahead; the server is the judge).
class _ComposerVideoPreview extends StatefulWidget {
  const _ComposerVideoPreview({required this.file, required this.fallback});

  final XFile file;
  final Widget fallback;

  @override
  State<_ComposerVideoPreview> createState() => _ComposerVideoPreviewState();
}

class _ComposerVideoPreviewState extends State<_ComposerVideoPreview> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    VideoPlayerController? controller;
    try {
      final path = widget.file.path;
      controller = kIsWeb
          ? VideoPlayerController.networkUrl(Uri.parse(path))
          : VideoPlayerController.file(File(path));
      await controller.initialize();
      await controller.setVolume(0);
      // A frame past the very first one avoids a black opening frame.
      await controller.seekTo(const Duration(milliseconds: 100));
    } catch (_) {
      await controller?.dispose();
      return;
    }
    if (_disposed) {
      await controller.dispose();
      return;
    }
    setState(() {
      _controller = controller;
      _ready = true;
    });
  }

  @override
  void dispose() {
    _disposed = true;
    final controller = _controller;
    _controller = null;
    if (controller != null) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (!_ready || controller == null || !controller.value.isInitialized) {
      return widget.fallback;
    }
    final roles = KubusColorRoles.of(context);
    final size = controller.value.size;
    return ExcludeSemantics(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRect(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: VideoPlayer(controller),
              ),
            ),
          ),
          Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: roles.surfaceOverlay,
                borderRadius: BorderRadius.circular(KubusRadius.control),
                border: Border.all(
                  color: roles.ruleStrong,
                  width: KubusSizes.hairline,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(KubusSpacing.xs),
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 18,
                  color: roles.active,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
