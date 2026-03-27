import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/user_persona.dart';
import '../providers/profile_provider.dart';
import '../screens/web3/artist/artist_studio.dart';
import '../screens/web3/institution/institution_hub.dart';
import '../screens/desktop/desktop_shell_scope.dart';
import '../utils/design_tokens.dart';
import 'common/kubus_screen_header.dart';
import 'glass_components.dart';
import 'topbar_icon.dart';
import 'user_persona_picker_content.dart';

class UserPersonaOnboardingSheet extends StatelessWidget {
  const UserPersonaOnboardingSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: LiquidGlassPanel(
        padding: const EdgeInsets.fromLTRB(
          KubusSpacing.lg,
          KubusSpacing.sm + KubusSpacing.xs,
          KubusSpacing.lg,
          KubusSpacing.lg,
        ),
        margin: EdgeInsets.zero,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(KubusRadius.xl),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: KubusSpacing.md),
                decoration: BoxDecoration(
                  color: scheme.onSurface.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            KubusScreenHeaderBar(
              title: l10n.personaOnboardingTitle,
              subtitle: l10n.personaOnboardingSubtitle,
              compact: true,
              minHeight: 0,
              titleStyle: KubusTextStyles.sheetTitle,
              subtitleStyle: KubusTextStyles.sheetSubtitle.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.75),
              ),
              actions: [
                TopBarIcon(
                  tooltip: l10n.commonSkipForNow,
                  icon: Icon(
                    Icons.close,
                    color: scheme.onSurface,
                    size: KubusHeaderMetrics.actionIcon,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: KubusSpacing.md),
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
    final shellScope = DesktopShellScope.of(context);
    await provider.setUserPersona(persona);
    if (!context.mounted) return;
    navigator.pop();

    // For creator/institution, navigate to DAO review application surfaces
    if (persona == UserPersona.creator) {
      if (shellScope != null) {
        shellScope.pushSubScreen(
          title: 'Artist Studio',
          child: const ArtistStudio(embedded: true),
        );
        return;
      }
      navigator.push(MaterialPageRoute(builder: (_) => const ArtistStudio()));
    } else if (persona == UserPersona.institution) {
      if (shellScope != null) {
        shellScope.pushSubScreen(
          title: 'Institution Hub',
          child: const InstitutionHub(embedded: true),
        );
        return;
      }
      navigator.push(
        MaterialPageRoute(builder: (_) => const InstitutionHub()),
      );
    }
  }
}
