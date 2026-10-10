import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/pending_action_intent.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/saved_items_provider.dart';
import 'package:art_kubus/services/pending_action_executor.dart';
import 'package:art_kubus/utils/activation_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PendingActionIntent _supportIntent({
  PendingActionType action = PendingActionType.supportContact,
  String targetId = 'new',
  String section = 'contact',
  String? ticketId,
}) =>
    PendingActionIntent.create(
      actionType: action,
      targetType: PendingActionTargetType.supportRequest,
      targetId: targetId,
      returnRoute: '/support',
      returnArguments: <String, String>{
        'section': section,
        if (ticketId != null) 'ticketId': ticketId,
      },
      sourceScreen: 'support_center',
      nowUtc: DateTime.utc(2026, 10, 10, 9),
    )!;

void main() {
  group('support pending actions', () {
    test('round-trip through storage with section and request id only', () {
      final intent = _supportIntent(
        action: PendingActionType.supportReply,
        targetId: 'ticket-9',
        section: 'requests',
        ticketId: 'ticket-9',
      );

      final restored = PendingActionIntent.decode(intent.encode());

      expect(restored, isNotNull);
      expect(restored!.actionType, PendingActionType.supportReply);
      expect(restored.targetType, PendingActionTargetType.supportRequest);
      expect(restored.targetId, 'ticket-9');
      expect(restored.returnRoute, '/support');
      expect(restored.returnArguments, <String, String>{
        'section': 'requests',
        'ticketId': 'ticket-9',
      });
      // No visitor text is representable in the stored intent.
      expect(intent.encode(), isNot(contains('subject')));
      expect(intent.encode(), isNot(contains('message')));
    });

    test('the new-request intent is valid with a placeholder target', () {
      expect(_supportIntent().isValid, isTrue);
    });

    test('unknown support action names do not decode', () {
      expect(PendingActionType.fromStorage('supportDelete'), isNull);
      expect(
        PendingActionType.fromStorage('supportContact'),
        PendingActionType.supportContact,
      );
    });

    test('restoring a support intent never runs a mutation', () async {
      final artwork = ArtworkProvider();
      final saved = SavedItemsProvider();
      for (final action in <PendingActionType>[
        PendingActionType.supportContact,
        PendingActionType.supportBug,
        PendingActionType.supportReply,
      ]) {
        final result = await const PendingActionExecutor().execute(
          intent: _supportIntent(action: action),
          artworkProvider: artwork,
          savedItemsProvider: saved,
        );
        // Lands on the Support screen; the visitor sends the draft themselves.
        expect(result.outcome, PendingActionOutcome.entryRestored,
            reason: '$action');
        expect(result.didSucceed, isTrue);
      }
    });

    test('confirmation and gate copy name the support action', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(
        ActivationCopy.confirmationQuestion(
          l10n,
          _supportIntent(action: PendingActionType.supportContact),
        ),
        'Continue your support request?',
      );
      expect(
        ActivationCopy.confirmationQuestion(
          l10n,
          _supportIntent(action: PendingActionType.supportBug),
        ),
        'Continue your bug report?',
      );
      expect(
        ActivationCopy.confirmationQuestion(
          l10n,
          _supportIntent(action: PendingActionType.supportReply),
        ),
        'Continue your reply?',
      );
      expect(
        ActivationCopy.confirmationCta(
          l10n,
          _supportIntent(action: PendingActionType.supportReply),
        ),
        l10n.activationConfirmContinueCta,
      );
      // The gate keeps the same generic line the Support sign-in prompt had.
      expect(
        ActivationCopy.gateTitle(
          l10n,
          actionType: PendingActionType.supportContact,
          targetType: PendingActionTargetType.supportRequest,
          fallbackActionLabel: 'send a support request',
        ),
        l10n.activationGateGenericTitle('send a support request'),
      );
    });
  });
}
