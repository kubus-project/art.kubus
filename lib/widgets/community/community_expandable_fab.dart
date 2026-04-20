import 'package:flutter/material.dart';

import '../../utils/app_animations.dart';
import '../../utils/design_tokens.dart';

enum CommunityExpandableFabVariant {
  mobile,
  desktop,
}

class CommunityFabOption {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const CommunityFabOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

class CommunityExpandableFab extends StatelessWidget {
  const CommunityExpandableFab({
    super.key,
    required this.isExpanded,
    required this.accentColor,
    required this.scheme,
    required this.animationTheme,
    required this.mainIcon,
    required this.mainLabel,
    required this.closeLabel,
    required this.mainHeroTag,
    required this.optionHeroTagPrefix,
    required this.options,
    required this.variant,
    required this.onExpandedChanged,
  });

  final bool isExpanded;
  final Color accentColor;
  final ColorScheme scheme;
  final AppAnimationTheme animationTheme;
  final IconData mainIcon;
  final String mainLabel;
  final String closeLabel;
  final String mainHeroTag;
  final String optionHeroTagPrefix;
  final List<CommunityFabOption> options;
  final CommunityExpandableFabVariant variant;
  final ValueChanged<bool> onExpandedChanged;

  @override
  Widget build(BuildContext context) {
    final isMobile = variant == CommunityExpandableFabVariant.mobile;

    TextStyle labelStyle() {
      if (isMobile) {
        return KubusTypography.textTheme.labelMedium!.copyWith(
          fontWeight: FontWeight.w600,
        );
      }
      return KubusTypography.textTheme.labelMedium!.copyWith(
        fontWeight: FontWeight.w600,
      );
    }

    TextStyle optionStyle() {
      if (isMobile) {
        return KubusTypography.textTheme.labelMedium!.copyWith(
          fontWeight: FontWeight.w500,
          color: scheme.onSurface,
        );
      }
      return KubusTextStyles.navMetaLabel.copyWith(
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedSize(
          duration: animationTheme.medium,
          curve: animationTheme.emphasisCurve,
          child: isExpanded
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ...options.asMap().entries.map((entry) {
                      final index = entry.key;
                      final option = entry.value;
                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: Duration(
                          milliseconds: animationTheme.medium.inMilliseconds +
                              (index * 50),
                        ),
                        curve: animationTheme.emphasisCurve,
                        builder: (context, value, child) {
                          return Transform.translate(
                            offset:
                                Offset(0, (isMobile ? 20 : 16) * (1 - value)),
                            child: Opacity(opacity: value, child: child),
                          );
                        },
                        child: Padding(
                          padding: EdgeInsets.only(bottom: isMobile ? 12 : 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: KubusSpacing.sm + KubusSpacing.xs,
                                  vertical: KubusSpacing.sm,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.surface,
                                  borderRadius: isMobile
                                      ? KubusRadius.circular(KubusRadius.sm)
                                      : BorderRadius.circular(
                                          KubusRadius.sm + KubusSpacing.xxs),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                          alpha: isMobile ? 0.1 : 0.08),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(option.label, style: optionStyle()),
                              ),
                              SizedBox(width: isMobile ? 12 : 10),
                              FloatingActionButton.small(
                                heroTag: '$optionHeroTagPrefix${option.label}',
                                onPressed: () {
                                  onExpandedChanged(false);
                                  option.onTap();
                                },
                                backgroundColor: accentColor,
                                foregroundColor: scheme.onPrimary,
                                child: Icon(
                                  option.icon,
                                  size: 20,
                                  color: scheme.onPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    SizedBox(height: isMobile ? 4 : 8),
                  ],
                )
              : const SizedBox.shrink(),
        ),
        FloatingActionButton.extended(
          heroTag: mainHeroTag,
          onPressed: () => onExpandedChanged(!isExpanded),
          backgroundColor:
              isExpanded ? scheme.surfaceContainerHighest : accentColor,
          foregroundColor: isExpanded ? scheme.onSurface : scheme.onPrimary,
          icon: AnimatedRotation(
            turns: isExpanded ? 0.125 : 0,
            duration: animationTheme.short,
            child: Icon(isExpanded ? Icons.close : mainIcon),
          ),
          label: AnimatedSwitcher(
            duration: animationTheme.short,
            child: Text(
              isExpanded ? closeLabel : mainLabel,
              key: ValueKey(isExpanded),
              style: labelStyle(),
            ),
          ),
        ),
      ],
    );
  }
}
