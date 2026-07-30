import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/pending_action_intent.dart';
import '../../providers/artwork_provider.dart';
import '../../providers/pending_action_provider.dart';
import '../../providers/saved_items_provider.dart';
import '../../services/pending_action_executor.dart';
import '../../utils/activation_copy.dart';
import '../../utils/design_tokens.dart';
import '../glass_components.dart';
import '../kubus_snackbar.dart';

/// Watches for a restored [PendingActionIntent] and offers it back to the
/// visitor as an explicit confirmation.
///
/// Mounted once, above the navigator, so mobile and desktop share one
/// implementation and the confirmation follows the visitor to whichever entity
/// they were returned to. It never performs the action on its own — the
/// visitor has to press the confirm button, and the action then runs exactly
/// once.
class PendingActionContinuationHost extends StatefulWidget {
  const PendingActionContinuationHost({super.key, required this.child});

  final Widget child;

  /// Time allowed for the post-auth navigation to settle before the
  /// confirmation is presented, so the sheet opens over the restored entity
  /// rather than over the route transition.
  static const Duration settleDelay = Duration(milliseconds: 450);

  @override
  State<PendingActionContinuationHost> createState() =>
      _PendingActionContinuationHostState();
}

class _PendingActionContinuationHostState
    extends State<PendingActionContinuationHost> {
  bool _presenting = false;

  @override
  Widget build(BuildContext context) {
    // `watch` here is intentional: the host has no UI of its own, it just needs
    // to be rebuilt when an intent becomes ready so it can present the sheet.
    final provider = context.watch<PendingActionProvider>();
    if (provider.isAwaitingConfirmation && !_presenting) {
      _presenting = true;
      unawaited(_present(provider));
    }
    return widget.child;
  }

  Future<void> _present(PendingActionProvider provider) async {
    await Future<void>.delayed(PendingActionContinuationHost.settleDelay);
    if (!mounted || !provider.isAwaitingConfirmation) {
      _presenting = false;
      return;
    }

    final intent = provider.pending;
    if (intent == null) {
      _presenting = false;
      return;
    }

    provider.markConfirmationViewed();

    final confirmed = await showPendingActionConfirmationSheet(
      context,
      intent: intent,
    );
    if (!mounted) {
      _presenting = false;
      return;
    }

    if (!confirmed) {
      // Cancelling keeps the visitor exactly where they are, with public
      // browsing untouched.
      await provider.cancel();
      _presenting = false;
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final result = await provider.confirm(
      artworkProvider: context.read<ArtworkProvider>(),
      savedItemsProvider: context.read<SavedItemsProvider>(),
    );
    _presenting = false;
    if (!mounted) return;

    messenger.showKubusSnackBar(
      SnackBar(content: Text(_feedbackFor(l10n, intent, result))),
      tone: result.didSucceed
          ? KubusSnackBarTone.neutral
          : KubusSnackBarTone.error,
    );
  }

  String _feedbackFor(
    AppLocalizations l10n,
    PendingActionIntent intent,
    PendingActionExecutionResult result,
  ) {
    return switch (result.outcome) {
      PendingActionOutcome.completed ||
      PendingActionOutcome.entryRestored =>
        ActivationCopy.successToast(l10n, intent),
      PendingActionOutcome.targetUnavailable =>
        l10n.activationActionTargetUnavailableToast,
      PendingActionOutcome.unauthorized =>
        l10n.activationActionUnauthorizedToast,
      PendingActionOutcome.failed => l10n.activationActionFailedToast,
    };
  }
}

/// Asks the visitor to confirm the action they attempted before signing up.
///
/// Returns true only on an explicit confirmation; dismissing by tap-outside or
/// back both read as "not now".
Future<bool> showPendingActionConfirmationSheet(
  BuildContext context, {
  required PendingActionIntent intent,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: false,
    builder: (sheetContext) => _PendingActionConfirmationSheet(intent: intent),
  );
  return result ?? false;
}

class _PendingActionConfirmationSheet extends StatelessWidget {
  const _PendingActionConfirmationSheet({required this.intent});

  final PendingActionIntent intent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final media = MediaQuery.of(context);
    final isWide = media.size.width >= 720;
    final label = (intent.targetLabel ?? '').trim();

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(
        KubusSpacing.lg,
        KubusSpacing.md,
        KubusSpacing.lg,
        KubusSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: KubusSpacing.md),
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(KubusRadius.xs),
              ),
            ),
          ),
          Text(
            l10n.activationConfirmHeading,
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: KubusSpacing.xs),
          Semantics(
            header: true,
            child: Text(
              ActivationCopy.confirmationQuestion(l10n, intent),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(height: KubusSpacing.xs),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: KubusSpacing.lg),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(ActivationCopy.confirmationCta(l10n, intent)),
          ),
          const SizedBox(height: KubusSpacing.sm),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: scheme.onSurfaceVariant,
            ),
            child: Text(l10n.activationGateNotNow),
          ),
        ],
      ),
    );

    final panel = LiquidGlassPanel(
      margin: EdgeInsets.zero,
      showBorder: true,
      blurSigma: KubusGlassEffects.blurSigmaHeavy,
      fallbackMinOpacity: KubusGlassEffects.fallbackOpaqueOpacity,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(KubusRadius.xl),
      ),
      padding: EdgeInsets.zero,
      backgroundColor: scheme.surfaceContainerHighest.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.86 : 0.94,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.8),
        child: SingleChildScrollView(child: content),
      ),
    );

    if (isWide) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: KubusSizes.dialogWidthMd),
          child: SafeArea(top: false, child: panel),
        ),
      );
    }
    return SafeArea(top: false, child: panel);
  }
}
