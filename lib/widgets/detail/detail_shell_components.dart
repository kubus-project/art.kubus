import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_localizations.dart';
import '../../utils/design_tokens.dart';
import '../glass_components.dart';

/// Design system spacing constants for detail screens
class DetailSpacing {
  const DetailSpacing._();

  static const double xs = KubusSpacing.xs;
  static const double sm = KubusSpacing.sm;
  static const double md = KubusSpacing.sm + KubusSpacing.xs;
  static const double lg = KubusSpacing.md;
  static const double xl = KubusSpacing.lg;
  static const double xxl = KubusSpacing.xl;

  /// Content padding for mobile screens
  static const EdgeInsets contentPaddingMobile = EdgeInsets.symmetric(
    horizontal: lg,
    vertical: lg,
  );

  /// Content padding for desktop screens
  static const EdgeInsets contentPaddingDesktop = EdgeInsets.symmetric(
    horizontal: xl,
    vertical: xl,
  );

  /// Section spacing
  static const double sectionGap = xl;
}

/// Design system typography styles
class DetailTypography {
  const DetailTypography._();

  /// Screen title (AppBar)
  static TextStyle screenTitle(BuildContext context) =>
      KubusTextStyles.detailScreenTitle.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
      );

  /// Section header (16px, bold)
  static TextStyle sectionTitle(BuildContext context) =>
      KubusTextStyles.detailSectionTitle.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
      );

  /// Card title (15px, semibold)
  static TextStyle cardTitle(BuildContext context) =>
      KubusTextStyles.detailCardTitle.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
      );

  /// Body text (14px)
  static TextStyle body(BuildContext context) => KubusTextStyles.detailBody
      .copyWith(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
      );

  /// Secondary/caption text (13px)
  static TextStyle caption(BuildContext context) =>
      KubusTextStyles.detailCaption.copyWith(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
      );

  /// Small label text (12px)
  static TextStyle label(BuildContext context) =>
      KubusTextStyles.detailLabel.copyWith(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
      );

  /// Button text
  static TextStyle button(BuildContext context) =>
      KubusTextStyles.detailButton;
}

/// Standard border radius values
class DetailRadius {
  const DetailRadius._();

  static const double xs = KubusRadius.xs + KubusSpacing.xxs;
  static const double sm = KubusRadius.sm;
  static const double md = KubusRadius.md;
  static const double lg = KubusRadius.lg;
  static const double xl = KubusRadius.lg + KubusSpacing.xs;
}

/// A unified card component for detail screens with consistent styling
class DetailCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final bool showBorder;
  final double borderRadius;
  final VoidCallback? onTap;

  const DetailCard({
    super.key,
    required this.child,
    this.padding,
    this.backgroundColor,
    this.showBorder = true,
    this.borderRadius = DetailRadius.md,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final radius = BorderRadius.circular(borderRadius);
    final glassTint = (backgroundColor ?? scheme.surface)
        .withValues(alpha: isDark ? 0.16 : 0.10);

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: showBorder
            ? Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35))
            : null,
      ),
      child: LiquidGlassPanel(
        padding: padding ?? const EdgeInsets.all(DetailSpacing.lg),
        margin: EdgeInsets.zero,
        borderRadius: radius,
        showBorder: false,
        backgroundColor: glassTint,
        onTap: onTap,
        child: child,
      ),
    );
  }
}

/// A section header with optional action button - unified design
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: DetailTypography.sectionTitle(context)),
        ),
        if (trailing != null) trailing!,
        if (onAction != null && trailing == null)
          TextButton.icon(
            onPressed: onAction,
            icon: Icon(actionIcon ?? Icons.arrow_forward, size: 16),
            label: Text(
              actionLabel ?? '',
              style: DetailTypography.button(context),
            ),
          ),
      ],
    );
  }
}

/// An info row with icon and label - used for metadata display
class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final TextStyle? labelStyle;
  final Color? iconColor;

  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.labelStyle,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: DetailSpacing.sm),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: iconColor ?? scheme.onSurface.withValues(alpha: 0.55),
          ),
          const SizedBox(width: DetailSpacing.sm),
          Expanded(
            child: Text(
              value != null ? '$label: $value' : label,
              style: labelStyle ?? DetailTypography.caption(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// A stat chip for displaying counts/metrics inline
class StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String? label;
  final Color? color;

  const StatChip({
    super.key,
    required this.icon,
    required this.value,
    this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveColor = color ?? scheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DetailSpacing.md,
        vertical: DetailSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(DetailRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: effectiveColor),
          const SizedBox(width: DetailSpacing.xs),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: effectiveColor,
            ),
          ),
          if (label != null) ...[
            const SizedBox(width: DetailSpacing.xs),
            Text(
              label!,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: effectiveColor.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A unified action button for detail screens with consistent styling
class DetailActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isActive;
  final Color? activeColor;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const DetailActionButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.isActive = false,
    this.activeColor,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final effectiveActiveColor = activeColor ?? scheme.primary;

    final isEnabled = onPressed != null;

    final bgColor = backgroundColor ??
        (isActive
            ? effectiveActiveColor.withValues(alpha: isDark ? 0.22 : 0.16)
            : scheme.surface.withValues(alpha: isDark ? 0.16 : 0.10));
    final fgColor =
        foregroundColor ?? (isActive ? effectiveActiveColor : scheme.onSurface);

    final radius = BorderRadius.circular(DetailRadius.md);

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: isActive
              ? effectiveActiveColor.withValues(alpha: 0.28)
              : scheme.outlineVariant.withValues(alpha: isEnabled ? 0.35 : 0.22),
        ),
      ),
      child: LiquidGlassPanel(
        padding: const EdgeInsets.symmetric(
          vertical: DetailSpacing.md,
          horizontal: DetailSpacing.lg,
        ),
        margin: EdgeInsets.zero,
        borderRadius: radius,
        showBorder: false,
        backgroundColor: bgColor,
        onTap: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: fgColor),
            const SizedBox(width: DetailSpacing.sm),
            Flexible(
              child: Text(
                label,
                style: DetailTypography.button(context).copyWith(color: fgColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A shared header component for detail screens (artwork, exhibition, collection, profile)
/// Supports cover image/gradient background with title overlay and primary actions.
class DetailHeader extends StatelessWidget {
  /// The title text displayed in the header
  final String title;

  /// Optional subtitle (e.g., artist name, date range)
  final String? subtitle;

  /// Cover image URL (nullable - will show gradient fallback)
  final String? coverUrl;

  /// Primary color for gradient fallback and accents
  final Color? accentColor;

  /// Height of the header (default: 280 for mobile, can be larger for desktop)
  final double height;

  /// Leading widget (typically back button) - if null, uses default back button
  final Widget? leading;

  /// Action widgets (share, favorite, edit, etc.)
  final List<Widget> actions;

  /// Optional child widget at the bottom (e.g., badges, stats row)
  final Widget? bottomContent;

  /// Whether to show the default gradient overlay for text readability
  final bool showGradientOverlay;

  /// Hero tag for cover image animation
  final String? heroTag;

  /// Callback when header is tapped (e.g., to view full image)
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
              padding: const EdgeInsets.all(8),
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
              child: Icon(Icons.arrow_back, size: 20, color: scheme.onSurface),
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
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
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
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
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
              // Background image or gradient
              _buildBackground(context, effectiveAccent),
              // Gradient overlay for readability
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
              // Bottom content overlay
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

    // Gradient fallback
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
          size: 64,
          color: scheme.onSurface.withValues(alpha: 0.2),
        ),
      ),
    );

    if (coverUrl == null || coverUrl!.isEmpty) {
      return gradientBackground;
    }

    final imageWidget = Image.network(
      coverUrl!,
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

/// A row of action buttons (like, comment, share, etc.) with consistent styling
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
    final isActive = action.isActive;
    final activeColor = action.activeColor ?? scheme.error;

    final buttonStyle = ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(
        horizontal: DetailSpacing.lg,
        vertical: DetailSpacing.md,
      ),
      backgroundColor: isActive
          ? activeColor.withValues(alpha: 0.12)
          : scheme.surfaceContainerHighest,
      foregroundColor: isActive ? activeColor : scheme.onSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isActive
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
          style: GoogleFonts.inter(
            fontSize: 13,
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
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Represents a single action in DetailActionsRow
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

/// A standard section container with header and content
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
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
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
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                if (widget.trailing != null) ...[
                  widget.trailing!,
                  const SizedBox(width: 8),
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

/// A row/list of collaborators with avatars and names
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
        // Overlapping avatars
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '+$remainingCount',
              style: GoogleFonts.inter(
                fontSize: 12,
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
              style: GoogleFonts.inter(
                fontSize: 13,
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
        style: GoogleFonts.inter(
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

/// Data class for collaborator display
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

/// A responsive two-pane layout for desktop detail screens
/// Shows main content on the left and info panel on the right
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

/// A stats card with icon, value, and label
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: effectiveIconColor),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
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
        borderRadius: BorderRadius.circular(16),
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
        borderRadius: BorderRadius.circular(20),
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
            style: GoogleFonts.inter(
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

/// A card for displaying artwork in a list/grid
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
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: EdgeInsets.all(isCompact ? 10 : 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: scheme.outline.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
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
                          imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _buildPlaceholder(context, effectiveAccent),
                        )
                      : _buildPlaceholder(context, effectiveAccent),
                ),
              ),
              const SizedBox(width: 12),
              // Title and subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: isCompact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: isCompact ? 14 : 15,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: scheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ] else ...[
                const SizedBox(width: 4),
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
