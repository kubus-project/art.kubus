import 'package:flutter/material.dart';

import '../utils/design_tokens.dart';
import 'glass_components.dart';

class TopBarIcon extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final int? badgeCount;
  final Color? badgeColor;
  final double? size;

  const TopBarIcon({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.badgeCount,
    this.badgeColor,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 375;
    final containerSize = size ?? (isSmallScreen ? 40.0 : 44.0);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = KubusGlassStyle.resolve(
      context,
      surfaceType: KubusGlassSurfaceType.button,
      tintBase: scheme.surface,
    );
    final radius = BorderRadius.circular(KubusRadius.sm);

    Widget inner = IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      icon: icon,
      onPressed: onPressed,
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      inner = Tooltip(message: tooltip!, child: inner);
    }

    return SizedBox(
      width: containerSize + (KubusSpacing.sm * 1.5),
      height: containerSize + (KubusSpacing.sm * 1.5),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: KubusSpacing.xs,
            top: KubusSpacing.sm - KubusSpacing.xxs,
            child: Container(
              width: containerSize,
              height: containerSize,
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(
                  color: scheme.outline.withValues(alpha: 0.16),
                ),
              ),
              child: LiquidGlassPanel(
                padding: EdgeInsets.zero,
                margin: EdgeInsets.zero,
                borderRadius: radius,
                blurSigma: style.blurSigma,
                showBorder: false,
                backgroundColor: style.tintColor,
                fallbackMinOpacity: style.fallbackMinOpacity,
                child: Center(child: inner),
              ),
            ),
          ),
          if ((badgeCount ?? 0) > 0)
            Positioned(
              right: -KubusSpacing.xxs,
              top: KubusSpacing.xxs,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: KubusSpacing.xs,
                  vertical: KubusSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: badgeColor ?? theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(KubusRadius.xl),
                  border: Border.all(
                    color: theme.scaffoldBackgroundColor,
                    width: KubusSizes.hairline + 0.5,
                  ),
                ),
                constraints: const BoxConstraints(minWidth: 20, minHeight: 18),
                child: Center(
                  child: Text(
                    (badgeCount ?? 0) > 99 ? '99+' : '${badgeCount ?? 0}',
                    style: KubusTextStyles.badgeCount.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
