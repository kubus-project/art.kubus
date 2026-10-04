import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/utils/support_links.dart';
import 'package:art_kubus/widgets/common/kubus_action_tile.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Home-screen Support / Donate section.
///
/// A flat PRODUCT v5 surface placed after the cultural content on Home. The
/// tier dialog is a transient overlay and keeps its glass panel.
class SupportSectionCard extends StatelessWidget {
  const SupportSectionCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Localizations may be null during very early app initialization.
    final title = l10n?.supportSectionTitle ?? 'Support';
    final subtitle = l10n?.supportSectionSubtitle ??
        'Help us keep building art.kubus - every donation helps.';

    final roles = KubusColorRoles.of(context);
    // A closing section, not a card: the heading names it, the three ways to
    // give are destinations (compact tiles), and nothing is boxed twice.
    final links = <_SupportLink>[
      _SupportLink(
        label: l10n?.supportMethodKofi ?? 'Ko-fi',
        subtitle: l10n?.supportMethodKofiHint ?? 'Coffee-sized support',
        icon: Icons.local_cafe_outlined,
        url: SupportLinks.kofiUrl,
      ),
      _SupportLink(
        label: l10n?.supportMethodPaypal ?? 'PayPal',
        subtitle: l10n?.supportMethodPaypalHint ?? 'Donate via PayPal',
        icon: Icons.payments_outlined,
        url: SupportLinks.paypalDonateUrl,
      ),
      _SupportLink(
        label: l10n?.supportMethodGithubSponsors ?? 'GitHub Sponsors',
        subtitle: l10n?.supportMethodGithubSponsorsHint ?? 'Support via GitHub',
        icon: Icons.code,
        url: SupportLinks.githubSponsorsUrl,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: KubusSpacing.xs),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.72),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _openMoreInfo(context),
              child: Text(l10n?.supportSectionMoreInfo ?? 'More info'),
            ),
          ],
        ),
        const SizedBox(height: KubusSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = KubusSpacing.sm;
            final columns = constraints.maxWidth >= 760
                ? 3
                : constraints.maxWidth >= 520
                    ? 2
                    : 1;
            final width =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final link in links)
                  SizedBox(
                    width: width,
                    child: KubusActionTile(
                      title: link.label,
                      subtitle: link.subtitle,
                      icon: link.icon,
                      accent: roles.statAmber,
                      layout: KubusActionTileLayout.compact,
                      onTap: () => _openSupportLink(link.url),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  static Future<void> _openMoreInfo(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    if (AppConfig.enableHapticFeedback && !kIsWeb) {
      try {
        HapticFeedback.selectionClick();
      } catch (_) {}
    }

    await showKubusDialog<void>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final scheme = theme.colorScheme;
        final maxHeight = MediaQuery.of(ctx).size.height * 0.80;

        final title = l10n?.supportDialogTitle ?? 'What your support enables';
        final subtitle = l10n?.supportDialogSubtitle ??
            'Three tiers - all meaningful. Thank you for helping us keep building.';

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: KubusSizes.dialogWidthMd,
            maxHeight: maxHeight,
          ),
          child: LiquidGlassPanel(
            borderRadius: BorderRadius.circular(KubusRadius.xl),
            blurSigma: KubusGlassEffects.blurSigmaHeavy,
            padding: EdgeInsets.zero,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(KubusSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: KubusSpacing.xs),
                            Text(
                              subtitle,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurface.withValues(alpha: 0.72),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip:
                            MaterialLocalizations.of(ctx).closeButtonTooltip,
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: KubusSpacing.lg),
                  _TierCard(
                    amount: l10n?.supportTier5Amount ?? '€5',
                    body: l10n?.supportTier5Body ??
                        'Helps cover monthly infrastructure costs.',
                    accent: KubusColors.accentTealDark,
                  ),
                  const SizedBox(height: KubusSpacing.sm),
                  _TierCard(
                    amount: l10n?.supportTier15Amount ?? '€15',
                    body: l10n?.supportTier15Body ??
                        'Supports steady weekly improvements.',
                    accent: KubusColors.primary,
                  ),
                  const SizedBox(height: KubusSpacing.sm),
                  _TierCard(
                    amount: l10n?.supportTier50Amount ?? '€50',
                    body: l10n?.supportTier50Body ??
                        'Funds one focused development session (new feature / fixes / content updates).',
                    accent: KubusColors.accentOrangeLight,
                  ),
                  const SizedBox(height: KubusSpacing.lg),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text(l10n?.commonClose ?? 'Close'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SupportLink {
  const _SupportLink({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.url,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final String url;
}

Future<void> _openSupportLink(String url) async {
  if (AppConfig.enableHapticFeedback && !kIsWeb) {
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
  }

  final uri = Uri.tryParse(url);
  if (uri == null) return;

  try {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: SupportLinks.preferredLaunchMode);
    }
  } catch (_) {
    // Best-effort: do not throw on link open.
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({
    required this.amount,
    required this.body,
    required this.accent,
  });

  final String amount;
  final String body;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return LiquidGlassCard(
      padding: const EdgeInsets.all(KubusSpacing.md),
      borderRadius: BorderRadius.circular(KubusRadius.lg),
      backgroundColor:
          (isDark ? KubusColors.surfaceDark : KubusColors.surfaceLight)
              .withValues(alpha: isDark ? 0.28 : 0.60),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: KubusSpacing.xs,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(KubusRadius.xl),
            ),
          ),
          const SizedBox(width: KubusSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  amount,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: KubusSpacing.xs),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.78),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
