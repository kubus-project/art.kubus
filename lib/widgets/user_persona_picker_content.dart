import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'inline_loading.dart';

import '../l10n/app_localizations.dart';
import '../models/user_persona.dart';
import '../utils/design_tokens.dart';

class UserPersonaPickerContent extends StatelessWidget {
  const UserPersonaPickerContent({
    super.key,
    required this.selectedPersona,
    required this.onSelect,
    this.enabled = true,
    this.loadingPersona,
    this.showChevron = true,
  });

  final UserPersona? selectedPersona;
  final Future<void> Function(UserPersona persona) onSelect;
  final bool enabled;
  final UserPersona? loadingPersona;
  final bool showChevron;

  Future<void> _handleSelect(UserPersona persona) async {
    if (!enabled) return;
    try {
      await onSelect(persona);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'UserPersonaPickerContent._handleSelect failed: $error\n$stackTrace',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        _PersonaTile(
          icon: Icons.explore_outlined,
          color: Theme.of(context).colorScheme.primary,
          title: l10n.personaOptionLoverTitle,
          subtitle: l10n.personaOptionLoverSubtitle,
          selected: selectedPersona == UserPersona.lover,
          enabled: enabled,
          loading: loadingPersona == UserPersona.lover,
          showChevron: showChevron,
          onTap: () => _handleSelect(UserPersona.lover),
        ),
        const SizedBox(height: KubusSpacing.sm + KubusSpacing.xxs),
        _PersonaTile(
          icon: Icons.palette_outlined,
          color: scheme.secondary,
          title: l10n.personaOptionCreatorTitle,
          subtitle: l10n.personaOptionCreatorSubtitle,
          selected: selectedPersona == UserPersona.creator,
          enabled: enabled,
          loading: loadingPersona == UserPersona.creator,
          showChevron: showChevron,
          onTap: () => _handleSelect(UserPersona.creator),
        ),
        const SizedBox(height: KubusSpacing.sm + KubusSpacing.xxs),
        _PersonaTile(
          icon: Icons.apartment_outlined,
          color: scheme.tertiary,
          title: l10n.personaOptionInstitutionTitle,
          subtitle: l10n.personaOptionInstitutionSubtitle,
          selected: selectedPersona == UserPersona.institution,
          enabled: enabled,
          loading: loadingPersona == UserPersona.institution,
          showChevron: showChevron,
          onTap: () => _handleSelect(UserPersona.institution),
        ),
      ],
    );
  }
}

class _PersonaTile extends StatelessWidget {
  const _PersonaTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.enabled,
    required this.loading,
    required this.showChevron,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final bool loading;
  final bool showChevron;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: enabled || loading ? 1 : 0.62,
      child: InkWell(
        onTap: enabled
            ? () async {
                await onTap();
              }
            : null,
        borderRadius: BorderRadius.circular(KubusRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(KubusChromeMetrics.compactCardPadding),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.16)
                : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(KubusRadius.lg),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.6)
                  : scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(KubusRadius.md),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: KubusSpacing.sm + KubusSpacing.xxs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: KubusTextStyles.sectionTitle.copyWith(
                        fontSize: KubusChromeMetrics.navLabel + 1,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: KubusSpacing.xs),
                    Text(
                      subtitle,
                      style: KubusTextStyles.sectionSubtitle.copyWith(
                        fontSize: KubusChromeMetrics.navMetaLabel + 0.5,
                        height: 1.2,
                        color: scheme.onSurface.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
              if (loading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: InlineLoading(tileSize: 4, color: color),
                )
              else if (selected)
                Icon(Icons.check_circle, color: color, size: 20)
              else if (showChevron)
                Icon(
                  Icons.chevron_right,
                  color: scheme.onSurface.withValues(alpha: 0.35),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
