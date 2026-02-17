import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';
import '../models/user_persona.dart';

class UserPersonaPickerContent extends StatelessWidget {
  const UserPersonaPickerContent({
    super.key,
    required this.selectedPersona,
    required this.onSelect,
    this.showChevron = true,
  });

  final UserPersona? selectedPersona;
  final Future<void> Function(UserPersona persona) onSelect;
  final bool showChevron;

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
          showChevron: showChevron,
          onTap: () => unawaited(onSelect(UserPersona.lover)),
        ),
        const SizedBox(height: 10),
        _PersonaTile(
          icon: Icons.palette_outlined,
          color: scheme.secondary,
          title: l10n.personaOptionCreatorTitle,
          subtitle: l10n.personaOptionCreatorSubtitle,
          selected: selectedPersona == UserPersona.creator,
          showChevron: showChevron,
          onTap: () => unawaited(onSelect(UserPersona.creator)),
        ),
        const SizedBox(height: 10),
        _PersonaTile(
          icon: Icons.apartment_outlined,
          color: scheme.tertiary,
          title: l10n.personaOptionInstitutionTitle,
          subtitle: l10n.personaOptionInstitutionSubtitle,
          selected: selectedPersona == UserPersona.institution,
          showChevron: showChevron,
          onTap: () => unawaited(onSelect(UserPersona.institution)),
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
    required this.showChevron,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool selected;
  final bool showChevron;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.16)
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
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
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      height: 1.2,
                      color: scheme.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, color: color, size: 20)
            else if (showChevron)
              Icon(
                Icons.chevron_right,
                color: scheme.onSurface.withValues(alpha: 0.35),
              ),
          ],
        ),
      ),
    );
  }
}
