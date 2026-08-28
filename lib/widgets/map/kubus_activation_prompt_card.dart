import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/activation_prompt_provider.dart';
import '../../utils/design_tokens.dart';
import '../glass_components.dart';

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
          child: LiquidGlassPanel(
            margin: const EdgeInsets.symmetric(horizontal: KubusSpacing.md),
            showBorder: true,
            blurSigma: KubusGlassEffects.blurSigmaHeavy,
            fallbackMinOpacity: KubusGlassEffects.fallbackOpaqueOpacity,
            borderRadius: BorderRadius.circular(KubusRadius.lg),
            padding: const EdgeInsets.fromLTRB(
              KubusSpacing.md,
              KubusSpacing.sm,
              KubusSpacing.sm,
              KubusSpacing.md,
            ),
            backgroundColor: scheme.surfaceContainerHighest.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.84 : 0.93,
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
                      // public; accepting the invitation starts the shared
                      // account step and returns here when complete.
                      await navigator.pushNamed(
                        '/onboarding',
                        arguments: const <String, Object?>{
                          'initialStepId': 'account',
                          'completionRoute': '/map',
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
