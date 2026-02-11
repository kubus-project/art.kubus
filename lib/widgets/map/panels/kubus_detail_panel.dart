import 'package:flutter/material.dart';

import '../../../utils/design_tokens.dart';
import '../../../utils/media_url_resolver.dart';
import '../../common/kubus_glass_icon_button.dart';
import '../../glass_components.dart';

enum DetailPanelKind {
  artwork,
  exhibition,
}

enum PanelPresentation {
  bottomSheet,
  sidePanel,
}

class KubusDetailPanel extends StatelessWidget {
  const KubusDetailPanel({
    super.key,
    required this.kind,
    required this.presentation,
    required this.header,
    required this.sections,
    this.margin = EdgeInsets.zero,
    this.borderRadius = 20,
    this.blurSigma = KubusGlassEffects.blurSigmaLight,
    this.expandContent = true,
    this.sectionSpacing = 0,
    this.backgroundAlphaDark = 0.20,
    this.backgroundAlphaLight = 0.14,
  });

  final DetailPanelKind kind;
  final PanelPresentation presentation;
  final Widget header;
  final List<Widget> sections;

  final EdgeInsetsGeometry margin;
  final double borderRadius;
  final double blurSigma;
  final bool expandContent;
  final double sectionSpacing;
  final double backgroundAlphaDark;
  final double backgroundAlphaLight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final panelBody = SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < sections.length; i++) ...[
            sections[i],
            if (sectionSpacing > 0 && i != sections.length - 1)
              SizedBox(height: sectionSpacing),
          ],
        ],
      ),
    );

    return LiquidGlassPanel(
      margin: margin,
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(borderRadius),
      blurSigma: blurSigma,
      backgroundColor: scheme.surface.withValues(
        alpha: isDark ? backgroundAlphaDark : backgroundAlphaLight,
      ),
      showBorder: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          if (expandContent) Expanded(child: panelBody) else panelBody,
        ],
      ),
    );
  }
}

class DetailHeader extends StatelessWidget {
  const DetailHeader({
    super.key,
    required this.accentColor,
    required this.closeTooltip,
    required this.onClose,
    this.imageUrl,
    this.height = 220,
    this.borderRadius = 20,
    this.badge,
    this.fallbackIcon = Icons.image_outlined,
    this.closeAccentColor,
    this.closeIconColor = KubusColors.textPrimaryDark,
  });

  final Color accentColor;
  final String closeTooltip;
  final VoidCallback onClose;
  final String? imageUrl;
  final double height;
  final double borderRadius;
  final Widget? badge;
  final IconData fallbackIcon;
  final Color? closeAccentColor;
  final Color closeIconColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resolvedImageUrl =
        MediaUrlResolver.resolveDisplayUrl(imageUrl) ?? imageUrl;
    final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1.0;
    final cacheHeight = (height * dpr).clamp(96.0, 1440.0).round();
    final fallbackIconColor =
        ThemeData.estimateBrightnessForColor(accentColor) == Brightness.dark
            ? KubusColors.textPrimaryDark.withValues(alpha: 0.78)
            : KubusColors.textPrimaryLight.withValues(alpha: 0.78);

    return ClipRRect(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(borderRadius),
      ),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (resolvedImageUrl != null && resolvedImageUrl.isNotEmpty)
              Image.network(
                resolvedImageUrl,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.low,
                cacheHeight: cacheHeight,
                errorBuilder: (_, __, ___) => _buildFallback(
                  icon: fallbackIcon,
                  accentColor: accentColor,
                  iconColor: fallbackIconColor,
                ),
              )
            else
              _buildFallback(
                icon: fallbackIcon,
                accentColor: accentColor,
                iconColor: fallbackIconColor,
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    scheme.shadow.withValues(alpha: 0.35),
                    scheme.shadow.withValues(alpha: 0.15),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: KubusGlassIconButton(
                icon: Icons.close,
                accentColor: closeAccentColor ?? accentColor,
                iconColor: closeIconColor,
                tooltip: closeTooltip,
                onPressed: onClose,
              ),
            ),
            if (badge != null)
              Positioned(
                top: 12,
                left: 12,
                child: badge!,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallback({
    required IconData icon,
    required Color accentColor,
    required Color iconColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor,
            accentColor.withValues(alpha: 0.7),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          color: iconColor,
          size: 40,
        ),
      ),
    );
  }
}

class DetailMetaRow extends StatelessWidget {
  const DetailMetaRow({
    super.key,
    required this.icon,
    required this.label,
    this.iconSize = 18,
    this.gap = 10,
    this.padding = const EdgeInsets.only(bottom: 8),
  });

  final IconData icon;
  final String label;
  final double iconSize;
  final double gap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Icon(
            icon,
            size: iconSize,
            color: scheme.onSurface.withValues(alpha: 0.7),
          ),
          SizedBox(width: gap),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    color: scheme.onSurface,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class DetailActionRow extends StatelessWidget {
  const DetailActionRow({
    super.key,
    required this.children,
    this.spacing = 10,
    this.runSpacing = 10,
  });

  final List<Widget> children;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      children: children,
    );
  }
}
