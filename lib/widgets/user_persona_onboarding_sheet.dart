import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/user_persona.dart';
import '../providers/profile_provider.dart';
import '../providers/themeprovider.dart';
import '../screens/web3/artist/artist_studio.dart';
import '../screens/web3/institution/institution_hub.dart';

class UserPersonaOnboardingSheet extends StatelessWidget {
  const UserPersonaOnboardingSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final accent = context.watch<ThemeProvider>().accentColor;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: scheme.onSurface.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.personaOnboardingTitle,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.commonSkipForNow,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: scheme.onSurface.withValues(alpha: 0.75)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              l10n.personaOnboardingSubtitle,
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.25,
                color: scheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 16),
            _PersonaTile(
              icon: Icons.explore_outlined,
              color: accent,
              title: l10n.personaOptionLoverTitle,
              subtitle: l10n.personaOptionLoverSubtitle,
              onTap: () => _select(context, UserPersona.lover),
            ),
            const SizedBox(height: 10),
            _PersonaTile(
              icon: Icons.palette_outlined,
              color: scheme.secondary,
              title: l10n.personaOptionCreatorTitle,
              subtitle: l10n.personaOptionCreatorSubtitle,
              onTap: () => _select(context, UserPersona.creator),
            ),
            const SizedBox(height: 10),
            _PersonaTile(
              icon: Icons.apartment_outlined,
              color: scheme.tertiary,
              title: l10n.personaOptionInstitutionTitle,
              subtitle: l10n.personaOptionInstitutionSubtitle,
              onTap: () => _select(context, UserPersona.institution),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _select(BuildContext context, UserPersona persona) async {
    final provider = context.read<ProfileProvider>();
    final navigator = Navigator.of(context);
    await provider.setUserPersona(persona);
    if (!context.mounted) return;
    navigator.pop();

    // For creator/institution, navigate to DAO review application surfaces
    if (persona == UserPersona.creator) {
      navigator.push(MaterialPageRoute(builder: (_) => const ArtistStudio()));
    } else if (persona == UserPersona.institution) {
      navigator.push(MaterialPageRoute(builder: (_) => const InstitutionHub()));
    }
  }
}

class _PersonaTile extends StatelessWidget {
  const _PersonaTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
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
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
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
            Icon(Icons.chevron_right, color: scheme.onSurface.withValues(alpha: 0.35)),
          ],
        ),
      ),
    );
  }
}
