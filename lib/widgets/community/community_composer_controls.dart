import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../utils/app_animations.dart';
import '../../utils/community_screen_utils.dart';
import '../../utils/design_tokens.dart';

enum CommunityComposerCategorySelectorVariant {
  mobile,
  desktop,
}

class CommunityComposerCategoryOption {
  final String value;
  final String label;
  final IconData icon;
  final String? description;

  const CommunityComposerCategoryOption({
    required this.value,
    required this.label,
    required this.icon,
    this.description,
  });
}

List<CommunityComposerCategoryOption> buildCommunityComposerCategoryOptions({
  required AppLocalizations l10n,
  required CommunityComposerCategoryLabelVariant variant,
  bool includeDescriptions = false,
}) {
  return communityComposerCategorySpecs
      .map(
        (spec) => CommunityComposerCategoryOption(
          value: spec.value,
          label: communityComposerCategoryLabel(
            l10n,
            spec.key,
            variant: variant,
          ),
          icon: spec.icon,
          description: includeDescriptions
              ? communityComposerCategoryDescription(l10n, spec.key)
              : null,
        ),
      )
      .toList(growable: false);
}

class CommunityComposerCategorySelector extends StatelessWidget {
  const CommunityComposerCategorySelector({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.accentColor,
    required this.animationTheme,
    required this.variant,
    required this.onSelected,
  });

  final List<CommunityComposerCategoryOption> options;
  final String selectedValue;
  final Color accentColor;
  final AppAnimationTheme animationTheme;
  final CommunityComposerCategorySelectorVariant variant;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isMobile = variant == CommunityComposerCategorySelectorVariant.mobile;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.only(bottom: isMobile ? KubusSpacing.sm : 0),
      child: Row(
        children: options.map((option) {
          final selected = selectedValue == option.value;
          final chip = ChoiceChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  option.icon,
                  size: KubusHeaderMetrics.actionIcon - 4,
                  color: selected
                      ? accentColor
                      : scheme.onSurface
                          .withValues(alpha: isMobile ? 0.7 : 0.6),
                ),
                const SizedBox(width: KubusSpacing.xs + KubusSpacing.xxs),
                Text(option.label),
              ],
            ),
            selected: selected,
            showCheckmark: false,
            onSelected: (_) => onSelected(option.value),
            selectedColor:
                accentColor.withValues(alpha: isMobile ? 0.15 : 0.14),
            backgroundColor: scheme.surfaceContainerHighest.withValues(
              alpha: isMobile ? 1 : 0.5,
            ),
            side: BorderSide(
              color: isMobile
                  ? Colors.transparent
                  : selected
                      ? accentColor.withValues(alpha: 0.5)
                      : Colors.transparent,
            ),
            labelStyle: KubusTextStyles.navLabel.copyWith(
              fontSize: KubusChromeMetrics.navMetaLabel + 1,
              fontWeight: selected
                  ? FontWeight.w600
                  : (isMobile ? FontWeight.w400 : FontWeight.w500),
              color: selected
                  ? accentColor
                  : scheme.onSurface.withValues(alpha: 0.75),
            ),
          );

          return Padding(
            padding: EdgeInsets.only(
              right: isMobile
                  ? KubusSpacing.sm + KubusSpacing.xxs
                  : KubusSpacing.sm,
            ),
            child: isMobile
                ? AnimatedScale(
                    duration: animationTheme.short,
                    curve: animationTheme.emphasisCurve,
                    scale: selected ? 1 : 0.95,
                    child: AnimatedOpacity(
                      duration: animationTheme.short,
                      opacity: selected ? 1 : 0.85,
                      child: chip,
                    ),
                  )
                : chip,
          );
        }).toList(),
      ),
    );
  }
}

class CommunityComposerAttachmentCard extends StatelessWidget {
  const CommunityComposerAttachmentCard({
    super.key,
    required this.onTap,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.backgroundColor,
    required this.borderColor,
    required this.duration,
    required this.curve,
    this.borderRadius = KubusRadius.lg,
    this.padding = const EdgeInsets.all(KubusSpacing.md),
    this.titleMaxLines = 1,
    this.subtitleMaxLines = 2,
  });

  final VoidCallback onTap;
  final Widget leading;
  final String title;
  final String subtitle;
  final Widget trailing;
  final Color backgroundColor;
  final Color borderColor;
  final Duration duration;
  final Curve curve;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final int titleMaxLines;
  final int subtitleMaxLines;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: onTap,
        child: AnimatedContainer(
          duration: duration,
          curve: curve,
          padding: padding,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              leading,
              const SizedBox(width: KubusSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: KubusTextStyles.sectionTitle.copyWith(
                        fontSize: KubusChromeMetrics.navLabel + 1,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                      maxLines: titleMaxLines,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: KubusSpacing.xs),
                    Text(
                      subtitle,
                      style: KubusTextStyles.navMetaLabel.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                      maxLines: subtitleMaxLines,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: KubusSpacing.md),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}
