import 'package:flutter/material.dart';

import '../../../utils/design_tokens.dart';
import '../analytics_presets.dart';

class AnalyticsHeader extends StatelessWidget {
  const AnalyticsHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.scopeLabel,
    required this.icon,
    required this.scopeBadge,
    required this.availablePresets,
    required this.activePreset,
    required this.onPresetSelected,
    required this.canExport,
    required this.onExport,
    required this.onShare,
  });

  final String title;
  final String subtitle;
  final String scopeLabel;
  final IconData icon;
  final String scopeBadge;
  final List<AnalyticsPreset> availablePresets;
  final AnalyticsPreset activePreset;
  final ValueChanged<AnalyticsPresetKind> onPresetSelected;
  final bool canExport;
  final VoidCallback onExport;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).width < 720;

    final titleBlock = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: compact ? 44 : 52,
          height: compact ? 44 : 52,
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(KubusRadius.md),
            border: Border.all(
              color: scheme.outline.withValues(alpha: 0.14),
            ),
          ),
          child: Icon(icon, color: scheme.onPrimaryContainer),
        ),
        const SizedBox(width: KubusSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: KubusSpacing.sm,
                runSpacing: KubusSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    title,
                    style: (compact
                            ? KubusTextStyles.mobileAppBarTitle
                            : KubusTextStyles.screenTitle)
                        .copyWith(color: scheme.onSurface),
                  ),
                  _HeaderBadge(label: scopeBadge),
                ],
              ),
              const SizedBox(height: KubusSpacing.xs),
              Text(
                subtitle,
                style: KubusTypography.inter(
                  fontSize: compact ? 12 : 14,
                  height: 1.35,
                  color: scheme.onSurface.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: KubusSpacing.xs),
              Text(
                scopeLabel,
                style: KubusTypography.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final actions = Wrap(
      spacing: KubusSpacing.sm,
      runSpacing: KubusSpacing.sm,
      children: [
        OutlinedButton.icon(
          onPressed: onShare,
          icon: const Icon(Icons.ios_share_outlined, size: 18),
          label: const Text('Share'),
        ),
        FilledButton.tonalIcon(
          onPressed: canExport ? onExport : null,
          icon: const Icon(Icons.download_outlined, size: 18),
          label: const Text('Export'),
        ),
      ],
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? KubusSpacing.md : KubusSpacing.xl,
        compact ? KubusSpacing.md : KubusSpacing.lg,
        compact ? KubusSpacing.md : KubusSpacing.xl,
        KubusSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (compact) ...[
            titleBlock,
            const SizedBox(height: KubusSpacing.md),
            actions,
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: titleBlock),
                const SizedBox(width: KubusSpacing.lg),
                actions,
              ],
            ),
          if (availablePresets.length > 1) ...[
            const SizedBox(height: KubusSpacing.md),
            Wrap(
              spacing: KubusSpacing.sm,
              runSpacing: KubusSpacing.sm,
              children: availablePresets.map((preset) {
                final selected = preset.kind == activePreset.kind;
                return ChoiceChip(
                  selected: selected,
                  avatar: Icon(preset.icon, size: 16),
                  label: Text(preset.scopeLabel),
                  onSelected: (_) {
                    if (!selected) onPresetSelected(preset.kind);
                  },
                );
              }).toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  const _HeaderBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KubusSpacing.sm,
        vertical: KubusSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(KubusRadius.sm),
      ),
      child: Text(
        label,
        style: KubusTypography.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: scheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
