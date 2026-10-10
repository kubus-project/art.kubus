import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/onboarding_completion_navigation.dart';
import '../../models/protected_action_requirements.dart';
import '../../providers/activation_prompt_provider.dart';
import '../../utils/design_tokens.dart';
import 'kubus_map_chrome.dart';

/// Non-blocking invitation to create an account, shown after a visitor has
/// demonstrated interest.
///
/// Renders nothing until [ActivationPromptProvider] arms it. It is a card, not
/// a modal: the map stays fully interactive underneath, and callers position it
/// so it never covers map attribution or the primary controls.
class KubusActivationPromptCard extends StatefulWidget {
  const KubusActivationPromptCard({super.key, this.maxWidth = 420});

  final double maxWidth;

  @override
  State<KubusActivationPromptCard> createState() =>
      _KubusActivationPromptCardState();
}

class _KubusActivationPromptCardState extends State<KubusActivationPromptCard> {
  bool _reported = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ActivationPromptProvider>();
    if (!provider.shouldPrompt) {
      _reported = false;
      return const SizedBox.shrink();
    }

    if (!_reported) {
      _reported = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) provider.markPresented();
      });
    }

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      container: true,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: widget.maxWidth),
          // One flat chrome surface (no blur, single hairline) like the other
          // map clusters; the prompt is not a glass sheet over the map.
          child: buildKubusMapChromeSurface(
            context: context,
            margin: const EdgeInsets.symmetric(horizontal: KubusSpacing.md),
            borderRadius: BorderRadius.circular(KubusRadius.surface),
            padding: const EdgeInsets.fromLTRB(
              KubusSpacing.md,
              KubusSpacing.sm,
              KubusSpacing.sm,
              KubusSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: KubusSpacing.sm),
                        child: Text(
                          l10n.activationPromptTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: provider.dismiss,
                      icon: const Icon(Icons.close, size: 20),
                      tooltip: l10n.activationPromptDismiss,
                      color: scheme.onSurfaceVariant,
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: KubusSpacing.sm),
                  child: Text(
                    l10n.activationPromptBody,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: KubusSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      await provider.accept();
                      // This is proactive account acquisition, not a legacy
                      // standalone registration detour. Map browsing remains
                      // public; accepting the invitation creates an account
                      // (and verifies its email) and nothing else: no role,
                      // profile, wallet or permissions. Completion pops back to
                      // the map the visitor was exploring.
                      await navigator.pushNamed(
                        '/onboarding',
                        arguments: <String, Object?>{
                          'initialStepId': 'account',
                          'completionRoute': '/map',
                          'requirements': ProtectedActionRequirements
                              .accountOnly.storageValue,
                          'completionNavigation': OnboardingCompletionNavigation
                              .returnToOrigin.storageValue,
                        },
                      );
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: Text(l10n.activationPromptCta),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
