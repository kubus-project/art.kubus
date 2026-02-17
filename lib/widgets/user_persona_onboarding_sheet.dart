import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/user_persona.dart';
import '../providers/profile_provider.dart';
import '../screens/web3/artist/artist_studio.dart';
import '../screens/web3/institution/institution_hub.dart';
import 'user_persona_picker_content.dart';

class UserPersonaOnboardingSheet extends StatelessWidget {
  const UserPersonaOnboardingSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

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
            UserPersonaPickerContent(
              selectedPersona: null,
              onSelect: (persona) => _select(context, persona),
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
