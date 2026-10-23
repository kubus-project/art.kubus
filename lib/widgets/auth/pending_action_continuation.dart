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
  const PendingActionContinuationHost({
    super.key,
    required this.child,
    this.navigatorKey,
  });

  final Widget child;

  /// The app's navigator.
  ///
  /// This host is mounted in `MaterialApp.builder`, which sits *above* the
  /// Navigator, so its own context has no Navigator ancestor and cannot open a
  /// route-based sheet. The key gives us a context below the Navigator without
  /// having to duplicate this host into every screen.
  final GlobalKey<NavigatorState>? navigatorKey;

  /// Time allowed for the post-auth navigation to settle before the
  /// confirmation is presented, so the sheet opens over the restored entity
  /// rather than over the route transition.
  static const Duration settleDelay = Duration(milliseconds: 450);

  /// How many times a sheet that was removed from under the visitor is offered
  /// again before the host stops, leaving the action pending rather than
  /// discarded.
  static const int maxInterruptedOffers = 3;

  @override
  State<PendingActionContinuationHost> createState() =>
      _PendingActionContinuationHostState();
}

class _PendingActionContinuationHostState
    extends State<PendingActionContinuationHost> {
  bool _presenting = false;
  int _interruptedOffers = 0;
  String? _viewedIdentityKey;

  @override
  Widget build(BuildContext context) {
    // `watch` here is intentional: the host has no UI of its own, it just needs
    // to be rebuilt when an intent becomes ready so it can present the sheet.
    final provider = context.watch<PendingActionProvider>();
    if (!provider.isAwaitingConfirmation) {
      _interruptedOffers = 0;
    }
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

    final sheetContext = widget.navigatorKey?.currentContext ?? context;
    if (!sheetContext.mounted || Navigator.maybeOf(sheetContext) == null) {
      // No navigator to host the sheet (e.g. during a route swap). Leave the
      // intent pending so the next frame can offer it.
      _presenting = false;
      return;
    }

    // A re-offer after an interruption is the same view, not a second one.
    if (_viewedIdentityKey != intent.identityKey) {
      _viewedIdentityKey = intent.identityKey;
      provider.markConfirmationViewed();
    }

    // Captured before the await so no BuildContext is used across a gap.
    final l10n = AppLocalizations.of(sheetContext)!;
    final messenger = ScaffoldMessenger.of(sheetContext);
    final artworkProvider = context.read<ArtworkProvider>();
    final savedItemsProvider = context.read<SavedItemsProvider>();

    final decision = await _showConfirmation(sheetContext, intent: intent);
    if (!mounted) {
      _presenting = false;
      return;
    }

    if (decision == _ConfirmationDecision.interrupted) {
      // The route the sheet sat on was replaced while the visitor was still
      // reading it, e.g. post-authentication navigation finishing late. They
      // neither confirmed nor declined, so the action must survive and be
      // offered again over the screen that replaced it.
      _presenting = false;
      if (_interruptedOffers <
          PendingActionContinuationHost.maxInterruptedOffers) {
        _interruptedOffers += 1;
        setState(() {});
      }
      return;
    }

    if (decision == _ConfirmationDecision.declined) {
      // Cancelling keeps the visitor exactly where they are, with public
      // browsing untouched.
      await provider.cancel();
      _presenting = false;
      return;
    }

    final result = await provider.confirm(
      artworkProvider: artworkProvider,
      savedItemsProvider: savedItemsProvider,
    );
    _presenting = false;
    if (!mounted) return;

    // A restored entry point is its own feedback: the composer is already on
    // screen. A toast here would sit over the composer's send button and take
    // the visitor's first tap.
    if (result.outcome == PendingActionOutcome.entryRestored) return;
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

/// How the confirmation sheet ended.
enum _ConfirmationDecision {
  confirmed,
  declined,

  /// The sheet's route was removed (a route replacement) rather than closed by
  /// the visitor, so no decision was made.
  interrupted,
}

Future<_ConfirmationDecision> _showConfirmation(
  BuildContext context, {
  required PendingActionIntent intent,
}) async {
  // `PopScope` hears every pop the visitor can cause (buttons, the barrier,
  // back, drag) and none of the route removals that replace the screen
  // underneath, which is what tells the two kinds of `null` result apart.
  var closedByVisitor = false;
  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: false,
    builder: (sheetContext) => PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) closedByVisitor = true;
      },
      child: _PendingActionConfirmationSheet(intent: intent),
    ),
  );
  if (result == true) return _ConfirmationDecision.confirmed;
  if (result == false || closedByVisitor) return _ConfirmationDecision.declined;
  return _ConfirmationDecision.interrupted;
}

/// Asks the visitor to confirm the action they attempted before signing up.
///
/// Returns true only on an explicit confirmation; dismissing by tap-outside or
/// back both read as "not now".
Future<bool> showPendingActionConfirmationSheet(
  BuildContext context, {
  required PendingActionIntent intent,
}) async {
  final decision = await _showConfirmation(context, intent: intent);
  return decision == _ConfirmationDecision.confirmed;
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

    Widget panel({
      required BorderRadius radius,
      required double maxHeight,
    }) {
      // Opaque, as on the activation gate: the sheet sits over the screen the
      // visitor was on, and translucent glass let its content through the copy.
      return Material(
        color: scheme.surfaceContainerHighest,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: theme.brightness == Brightness.dark
                ? KubusColors.glassBorderDark
                : KubusColors.glassBorderLight,
            width: KubusSizes.hairline,
          ),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(child: content),
        ),
      );
    }

    if (isWide) {
      // Centred dialog on desktop, matching the activation surface: a
      // bottom-anchored panel sat flush against a short window's edge.
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(KubusSpacing.lg),
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: KubusSizes.dialogWidthMd),
            child: panel(
              radius: BorderRadius.circular(KubusRadius.xl),
              maxHeight: media.size.height - KubusSpacing.xxl,
            ),
          ),
        ),
      );
    }
    return SafeArea(
      top: false,
      child: panel(
        radius: const BorderRadius.vertical(
          top: Radius.circular(KubusRadius.xl),
        ),
        maxHeight: media.size.height * 0.8,
      ),
    );
  }
}
