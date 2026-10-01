import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../kubus_button.dart';

/// Flat, discovery-first introduction at the top of Home.
///
/// Replaces the former accent-gradient hero that led with wallet balances.
/// It answers "what can I discover here?" and offers one primary action
/// (the map) and one secondary action (community). No wallet, token or
/// status content belongs here; those live in their own infrastructure
/// surfaces. The structural notion label uses the Space Mono register; the
/// title and lede use the Sofia Sans content register.
class HomeDiscoveryIntro extends StatelessWidget {
  const HomeDiscoveryIntro({
    super.key,
    required this.onExploreMap,
    required this.onOpenCommunity,
    this.large = false,
  });

  final VoidCallback onExploreMap;
  final VoidCallback onOpenCommunity;

  /// Desktop composition: larger title and a wider reading measure.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    final textTheme = Theme.of(context).textTheme;
    final titleStyle =
        (large ? textTheme.headlineMedium : textTheme.headlineSmall)?.copyWith(
      color: roles.foreground,
      fontWeight: FontWeight.w700,
      height: 1.15,
    );

    return Padding(
      key: const Key('home_discovery_intro'),
      padding: const EdgeInsets.symmetric(vertical: KubusSpacing.sm),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: large ? 720 : 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.homeIntroNotion.toUpperCase(),
              style: KubusTextStyles.structuralLabel.copyWith(
                color: roles.foregroundMuted,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: KubusSpacing.sm),
            Semantics(
              header: true,
              child: Text(l10n.homeIntroTitle, style: titleStyle),
            ),
            const SizedBox(height: KubusSpacing.sm),
            Text(
              l10n.homeIntroLede,
              style: textTheme.bodyLarge?.copyWith(
                color: roles.foregroundMuted,
                height: 1.45,
              ),
            ),
            const SizedBox(height: KubusSpacing.md + KubusSpacing.xs),
            LayoutBuilder(
              builder: (context, constraints) {
                final primary = KubusButton(
                  key: const Key('home_intro_explore_map'),
                  onPressed: onExploreMap,
                  icon: Icons.explore_outlined,
                  label: l10n.homeIntroExploreMapAction,
                  isFullWidth: !large && constraints.maxWidth < 440,
                );
                final secondary = KubusButton(
                  key: const Key('home_intro_community'),
                  onPressed: onOpenCommunity,
                  icon: Icons.people_outline,
                  label: l10n.homeIntroCommunityAction,
                  variant: KubusButtonVariant.secondary,
                  isFullWidth: !large && constraints.maxWidth < 440,
                );
                // Phones stack two equal-width actions; wider layouts keep
                // them side by side at their natural width.
                return Wrap(
                  spacing: KubusSpacing.sm,
                  runSpacing: KubusSpacing.sm,
                  children: [primary, secondary],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
