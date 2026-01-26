import 'dart:ui';

import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/utils/support_links.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Home-screen Support / Donate section.
///
/// Uses Kubus glass primitives and token-driven spacing to match the app's
/// liquid-glass design language.
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
        'Help us keep building art.kubus — every donation helps.';

    return LiquidGlassCard(
      padding: const EdgeInsets.all(KubusSpacing.lg),
      borderRadius: BorderRadius.circular(KubusRadius.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  gradient: KubusGradients.heroGradient,
                  borderRadius: BorderRadius.circular(KubusRadius.md),
                ),
                child: Icon(
                  Icons.volunteer_activism_outlined,
                  color: scheme.onPrimary,
                ),
              ),
              const SizedBox(width: KubusSpacing.md),
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

          const SizedBox(height: KubusSpacing.lg),

          Wrap(
            spacing: KubusSpacing.sm,
            runSpacing: KubusSpacing.sm,
            children: [
              _SupportLinkChip(
                label: l10n?.supportMethodKofi ?? 'Ko-fi',
                subtitle: l10n?.supportMethodKofiHint ?? 'Coffee-sized support',
                icon: Icons.local_cafe_outlined,
                gradient: KubusGradients.fromColors(
                  KubusColors.accentOrangeLight,
                  KubusColors.accentTealDark,
                ),
                url: SupportLinks.kofiUrl,
              ),
              _SupportLinkChip(
                label: l10n?.supportMethodPaypal ?? 'PayPal',
                subtitle: l10n?.supportMethodPaypalHint ?? 'Donate via PayPal',
                icon: Icons.payments_outlined,
                gradient: KubusGradients.fromColors(
                  KubusColors.primaryVariantDark,
                  KubusColors.primary,
                ),
                url: SupportLinks.paypalDonateUrl,
              ),
              _SupportLinkChip(
                label: l10n?.supportMethodGithubSponsors ?? 'GitHub Sponsors',
                subtitle: l10n?.supportMethodGithubSponsorsHint ??
                    'Support via GitHub',
                icon: Icons.code,
                gradient: KubusGradients.fromColors(
                  KubusColors.surfaceDark.withValues(alpha: 0.75),
                  KubusColors.primaryVariantDark,
                ),
                url: SupportLinks.githubSponsorsUrl,
              ),
            ],
          ),
        ],
      ),
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
        final isDark = theme.brightness == Brightness.dark;
        final maxHeight = MediaQuery.of(ctx).size.height * 0.80;

        final title = l10n?.supportDialogTitle ?? 'What your support enables';
        final subtitle = l10n?.supportDialogSubtitle ??
            'Three tiers — all meaningful. Thank you for helping us keep building.';

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: KubusSizes.dialogWidthMd,
            maxHeight: maxHeight,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(KubusRadius.xl),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: KubusGlassEffects.blurSigmaHeavy,
                sigmaY: KubusGlassEffects.blurSigmaHeavy,
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: KubusGradients.glass(theme.brightness),
                  borderRadius: BorderRadius.circular(KubusRadius.xl),
                  border: Border.all(
                    color: isDark
                        ? KubusColors.glassBorderDark
                        : KubusColors.glassBorderLight,
                    width: KubusSizes.hairline,
                  ),
                ),
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
                                    color:
                                        scheme.onSurface.withValues(alpha: 0.72),
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: MaterialLocalizations.of(ctx)
                                .closeButtonTooltip,
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
                        accent: KubusColors.primaryVariantDark,
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
            ),
          ),
        );
      },
    );
  }
}

class _SupportLinkChip extends StatelessWidget {
  const _SupportLinkChip({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.url,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final LinearGradient gradient;
  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      button: true,
      label: label,
      hint: subtitle,
      child: LiquidGlassPanel(
        padding: const EdgeInsets.symmetric(
          horizontal: KubusSpacing.md,
          vertical: KubusSpacing.sm + 2,
        ),
        borderRadius: BorderRadius.circular(KubusRadius.lg),
        onTap: () => _open(url),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 34,
              width: 34,
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(KubusRadius.sm),
              ),
              child: Icon(icon, size: 18, color: scheme.onPrimary),
            ),
            const SizedBox(width: KubusSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: KubusSpacing.xxs),
                  Text(
                    subtitle,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.72),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(String url) async {
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
      backgroundColor: (isDark ? KubusColors.surfaceDark : KubusColors.surfaceLight)
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
