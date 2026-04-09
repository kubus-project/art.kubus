import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import '../../utils/media_url_resolver.dart';
import 'detail_shell_tokens.dart';

/// A shared header component for detail screens.
class DetailHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? coverUrl;
  final Color? accentColor;
  final double height;
  final Widget? leading;
  final List<Widget> actions;
  final Widget? bottomContent;
  final bool showGradientOverlay;
  final String? heroTag;
  final VoidCallback? onTap;

  const DetailHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.coverUrl,
    this.accentColor,
    this.height = 280,
    this.leading,
    this.actions = const [],
    this.bottomContent,
    this.showGradientOverlay = true,
    this.heroTag,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveAccent = accentColor ?? scheme.primary;

    return SliverAppBar(
      expandedHeight: height,
      pinned: true,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      leading: leading ??
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Container(
              padding: const EdgeInsets.all(KubusSpacing.sm),
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.arrow_back,
                size: KubusHeaderMetrics.actionIcon,
                color: scheme.onSurface,
              ),
            ),
          ),
      actions: actions
          .map((action) => Padding(
                padding: const EdgeInsets.only(right: 4),
                child: action,
              ))
          .toList(),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: EdgeInsets.zero,
        title: bottomContent != null
            ? null
            : Container(
                padding: const EdgeInsets.fromLTRB(
                  DetailSpacing.lg,
                  0,
                  DetailSpacing.lg,
                  DetailSpacing.lg,
                ),
                alignment: Alignment.bottomLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: KubusTextStyles.screenTitle.copyWith(
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KubusTextStyles.screenSubtitle.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
        background: GestureDetector(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildBackground(context, effectiveAccent),
              if (showGradientOverlay)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.2),
                          Colors.black.withValues(alpha: 0.6),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
              if (bottomContent != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(DetailSpacing.lg),
                    child: bottomContent,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackground(BuildContext context, Color accentColor) {
    final scheme = Theme.of(context).colorScheme;

    final gradientBackground = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: 0.4),
            accentColor.withValues(alpha: 0.2),
            scheme.surface,
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: KubusHeaderMetrics.actionHitArea + KubusSpacing.lg,
          color: scheme.onSurface.withValues(alpha: 0.2),
        ),
      ),
    );

    if (coverUrl == null || coverUrl!.isEmpty) {
      return gradientBackground;
    }

    final resolvedCoverUrl = MediaUrlResolver.resolveDisplayUrl(coverUrl) ??
        MediaUrlResolver.resolve(coverUrl) ??
        coverUrl!;

    final imageWidget = Image.network(
      resolvedCoverUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => gradientBackground,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Stack(
          fit: StackFit.expand,
          children: [
            gradientBackground,
            Center(
              child: SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: accentColor,
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (heroTag != null) {
      return Hero(tag: heroTag!, child: imageWidget);
    }
    return imageWidget;
  }
}

/// Represents a single action in [DetailActionsRow].
class DetailAction {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isActive;
  final Color? activeColor;

  const DetailAction({
    required this.label,
    this.icon,
    this.onPressed,
    this.isActive = false,
    this.activeColor,
  });
}

/// A row of action buttons with consistent styling.
class DetailActionsRow extends StatelessWidget {
  final List<DetailAction> actions;
  final MainAxisAlignment alignment;
  final double spacing;
  final bool expanded;

  const DetailActionsRow({
    super.key,
    required this.actions,
    this.alignment = MainAxisAlignment.start,
    this.spacing = DetailSpacing.sm,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    if (expanded) {
      return Row(
        children: actions
            .map((action) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: spacing / 2),
                    child: _buildActionButton(context, action),
                  ),
                ))
            .toList(),
      );
    }

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      alignment: WrapAlignment.start,
      children:
          actions.map((action) => _buildActionButton(context, action)).toList(),
    );
  }

  Widget _buildActionButton(BuildContext context, DetailAction action) {
    final scheme = Theme.of(context).colorScheme;
    final activeColor = action.activeColor ?? scheme.error;

    final buttonStyle = ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(
        horizontal: DetailSpacing.lg,
        vertical: DetailSpacing.md,
      ),
      backgroundColor: action.isActive
          ? activeColor.withValues(alpha: 0.12)
          : scheme.surfaceContainerHighest,
      foregroundColor: action.isActive ? activeColor : scheme.onSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KubusRadius.md),
        side: BorderSide(
          color: action.isActive
              ? activeColor.withValues(alpha: 0.3)
              : scheme.outline.withValues(alpha: 0.15),
        ),
      ),
    );

    if (action.icon != null) {
      return ElevatedButton.icon(
        onPressed: action.onPressed,
        icon: Icon(action.icon, size: 18),
        label: Text(
          action.label,
          style: KubusTextStyles.navMetaLabel.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        style: buttonStyle,
      );
    }

    return ElevatedButton(
      onPressed: action.onPressed,
      style: buttonStyle,
      child: Text(
        action.label,
        style: KubusTextStyles.navMetaLabel.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
