import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../utils/design_tokens.dart';
import '../../utils/media_url_resolver.dart';
import 'detail_shell_tokens.dart';

/// A standard section container with header and content.
class DetailSection extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool collapsible;
  final bool initiallyExpanded;

  const DetailSection({
    super.key,
    required this.title,
    this.trailing,
    required this.child,
    this.padding,
    this.collapsible = false,
    this.initiallyExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (collapsible) {
      return _CollapsibleSection(
        title: title,
        trailing: trailing,
        padding: padding,
        initiallyExpanded: initiallyExpanded,
        child: child,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: KubusTextStyles.sectionTitle.copyWith(
                  color: scheme.onSurface,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        SizedBox(height: padding != null ? 0 : DetailSpacing.md),
        Padding(
          padding: padding ?? EdgeInsets.zero,
          child: child,
        ),
      ],
    );
  }
}

class _CollapsibleSection extends StatefulWidget {
  final String title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool initiallyExpanded;

  const _CollapsibleSection({
    required this.title,
    this.trailing,
    required this.child,
    this.padding,
    this.initiallyExpanded = true,
  });

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection>
    with SingleTickerProviderStateMixin {
  late bool _expanded;
  late AnimationController _controller;
  late Animation<double> _iconTurns;
  late Animation<double> _heightFactor;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _iconTurns = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _heightFactor =
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    if (_expanded) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _toggle,
          borderRadius: BorderRadius.circular(KubusRadius.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: KubusSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: KubusTextStyles.sectionTitle.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                if (widget.trailing != null) ...[
                  widget.trailing!,
                  const SizedBox(width: KubusSpacing.sm),
                ],
                RotationTransition(
                  turns: _iconTurns,
                  child: Icon(
                    Icons.expand_more,
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
        ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Align(
                alignment: Alignment.topCenter,
                heightFactor: _heightFactor.value,
                child: child,
              );
            },
            child: Padding(
              padding: widget.padding ?? EdgeInsets.zero,
              child: widget.child,
            ),
          ),
        ),
      ],
    );
  }
}

/// Data class for collaborator display.
class CollaboratorData {
  final String id;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final String? role;

  const CollaboratorData({
    required this.id,
    this.username,
    this.displayName,
    this.avatarUrl,
    this.role,
  });
}

/// A row/list of collaborators with avatars and names.
class CollaboratorsRow extends StatelessWidget {
  final List<CollaboratorData> collaborators;
  final int maxVisible;
  final VoidCallback? onViewAll;
  final void Function(CollaboratorData)? onTap;
  final double avatarSize;

  const CollaboratorsRow({
    super.key,
    required this.collaborators,
    this.maxVisible = 5,
    this.onViewAll,
    this.onTap,
    this.avatarSize = 40,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final visibleCount =
        collaborators.length > maxVisible ? maxVisible : collaborators.length;
    final remainingCount = collaborators.length - visibleCount;

    if (collaborators.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        SizedBox(
          width: visibleCount * (avatarSize * 0.75) + (avatarSize * 0.25),
          height: avatarSize,
          child: Stack(
            children: List.generate(visibleCount, (index) {
              final collab = collaborators[index];
              return Positioned(
                left: index * (avatarSize * 0.75),
                child: _buildAvatar(context, collab),
              );
            }),
          ),
        ),
        if (remainingCount > 0) ...[
          const SizedBox(width: 8),
          const SizedBox(width: KubusSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: KubusSpacing.sm,
              vertical: KubusSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(KubusRadius.md),
            ),
            child: Text(
              '+$remainingCount',
              style: KubusTextStyles.navMetaLabel.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
        if (onViewAll != null) ...[
          const Spacer(),
          TextButton(
            onPressed: onViewAll,
            child: Text(
              l10n.commonViewAll,
              style: KubusTextStyles.navMetaLabel.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAvatar(BuildContext context, CollaboratorData collab) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap != null ? () => onTap!(collab) : null,
      child: Container(
        width: avatarSize,
        height: avatarSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: scheme.surface,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipOval(
          child: collab.avatarUrl != null && collab.avatarUrl!.isNotEmpty
              ? Image.network(
                  MediaUrlResolver.resolveDisplayUrl(collab.avatarUrl) ??
                      MediaUrlResolver.resolve(collab.avatarUrl) ??
                      collab.avatarUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildInitials(context, collab),
                )
              : _buildInitials(context, collab),
        ),
      ),
    );
  }

  Widget _buildInitials(BuildContext context, CollaboratorData collab) {
    final scheme = Theme.of(context).colorScheme;
    final initials = _getInitials(collab.displayName ?? collab.username ?? '?');

    return Container(
      color: scheme.primaryContainer,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: KubusTypography.inter(
          fontSize: avatarSize * 0.4,
          fontWeight: FontWeight.w600,
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return '${parts[0].substring(0, 1)}${parts[1].substring(0, 1)}'
        .toUpperCase();
  }
}

/// A responsive two-pane layout for desktop detail screens.
class ResponsiveTwoPaneLayout extends StatelessWidget {
  final Widget mainContent;
  final Widget? sidePanel;
  final double sidePanelWidth;
  final double breakpoint;
  final EdgeInsetsGeometry? padding;

  const ResponsiveTwoPaneLayout({
    super.key,
    required this.mainContent,
    this.sidePanel,
    this.sidePanelWidth = 380,
    this.breakpoint = 900,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showTwoPane =
            constraints.maxWidth >= breakpoint && sidePanel != null;

        if (!showTwoPane) {
          return Padding(
            padding: padding ?? DetailSpacing.contentPaddingMobile,
            child: mainContent,
          );
        }

        return Padding(
          padding: padding ?? DetailSpacing.contentPaddingDesktop,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: mainContent),
              const SizedBox(width: DetailSpacing.xl),
              SizedBox(
                width: sidePanelWidth,
                child: sidePanel,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A stats card with icon, value, and label.
class DetailStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color? iconColor;
  final VoidCallback? onTap;

  const DetailStatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveIconColor = iconColor ?? scheme.primary;

    final content = Container(
      padding: const EdgeInsets.all(DetailSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(KubusRadius.lg),
        border: Border.all(
          color: scheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: effectiveIconColor),
          const SizedBox(height: KubusSpacing.sm),
          Text(
            value,
            style: KubusTextStyles.sheetTitle.copyWith(
              fontSize: KubusHeaderMetrics.screenTitle,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: KubusSpacing.xxs),
          Text(
            label,
            style: KubusTextStyles.navMetaLabel.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.6),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KubusRadius.lg),
        child: content,
      );
    }
    return content;
  }
}

/// A badge/chip for displaying status, rarity, etc.
class DetailBadge extends StatelessWidget {
  final String label;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;
  final double fontSize;

  const DetailBadge({
    super.key,
    required this.label,
    this.backgroundColor,
    this.textColor,
    this.icon,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bgColor = backgroundColor ?? scheme.primary;
    final fgColor = textColor ?? Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(KubusRadius.xl),
        boxShadow: [
          BoxShadow(
            color: bgColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fgColor),
            const SizedBox(width: 4),
          ],
          Text(
            label.toUpperCase(),
            style: KubusTextStyles.compactBadge.copyWith(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: fgColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// A card for displaying artwork in a list/grid.
class DetailArtworkCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final Color? accentColor;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool isCompact;

  const DetailArtworkCard({
    super.key,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.accentColor,
    this.onTap,
    this.trailing,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveAccent = accentColor ?? scheme.primary;
    final imageSize = isCompact ? 48.0 : 64.0;

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(KubusRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KubusRadius.md),
        child: Container(
          padding: EdgeInsets.all(isCompact ? 10 : 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(KubusRadius.md),
            border: Border.all(
              color: scheme.outline.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(KubusRadius.sm + KubusSpacing.xxs),
                child: Container(
                  width: imageSize,
                  height: imageSize,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        effectiveAccent.withValues(alpha: 0.2),
                        effectiveAccent.withValues(alpha: 0.1),
                      ],
                    ),
                  ),
                  child: imageUrl != null && imageUrl!.isNotEmpty
                      ? Image.network(
                          MediaUrlResolver.resolveDisplayUrl(imageUrl) ??
                              MediaUrlResolver.resolve(imageUrl) ??
                              imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _buildPlaceholder(context, effectiveAccent),
                        )
                      : _buildPlaceholder(context, effectiveAccent),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: isCompact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: KubusTextStyles.sectionTitle.copyWith(
                        fontSize: isCompact ? 14 : 15,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: KubusSpacing.xxs),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KubusTextStyles.navMetaLabel.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: KubusSpacing.sm),
                trailing!,
              ] else ...[
                const SizedBox(width: KubusSpacing.xs),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: scheme.onSurface.withValues(alpha: 0.4),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context, Color accentColor) {
    return Center(
      child: Icon(
        Icons.image_outlined,
        size: 24,
        color: accentColor.withValues(alpha: 0.5),
      ),
    );
  }
}
