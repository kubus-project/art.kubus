import 'package:art_kubus/providers/support_center_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SupportCenterProvider interrupted draft', () {
    late SupportCenterProvider support;

    setUp(() {
      support = SupportCenterProvider(supportEnabled: true);
    });

    SupportDraft contact([String subject = 'Login help']) => SupportDraft(
          section: 'contact',
          fields: <String, String>{'subject': subject, 'message': 'Details'},
        );

    test('takes nothing when no draft was stashed', () {
      expect(
        support.takeDraft(section: 'contact', currentUserId: null),
        isNull,
      );
    });

    test('returns the draft once for the matching section, then clears it', () {
      support.stashDraft(contact());

      final first = support.takeDraft(section: 'contact', currentUserId: null);
      expect(first?.fields['subject'], 'Login help');
      expect(
        support.takeDraft(section: 'contact', currentUserId: null),
        isNull,
      );
    });

    test('keeps a draft that belongs to another section', () {
      support.stashDraft(contact());

      expect(support.takeDraft(section: 'bug', currentUserId: null), isNull);
      expect(
        support.takeDraft(section: 'contact', currentUserId: null)?.fields,
        containsPair('subject', 'Login help'),
      );
    });

    test('a reply draft is only restored for the same request', () {
      support.stashDraft(const SupportDraft(
        section: 'requests',
        fields: <String, String>{'reply': 'Still broken'},
        ticketId: 'ticket-1',
      ));

      expect(
        support.takeDraft(section: 'requests', ticketId: 'ticket-2'),
        isNull,
      );
      expect(
        support
            .takeDraft(section: 'requests', ticketId: 'ticket-1')
            ?.fields['reply'],
        'Still broken',
      );
    });

    test('a draft written by one account is dropped for another account', () {
      support.stashDraft(contact(), ownerUserId: 'user-a');

      expect(
        support.takeDraft(section: 'contact', currentUserId: 'user-b'),
        isNull,
      );
      // Dropped, not merely hidden: the same account finds nothing either.
      expect(
        support.takeDraft(section: 'contact', currentUserId: 'user-a'),
        isNull,
      );
    });

    test('a guest draft can be continued by the account that signs in', () {
      support.stashDraft(contact());

      expect(
        support
            .takeDraft(section: 'contact', currentUserId: 'user-b')
            ?.fields['subject'],
        'Login help',
      );
    });

    test('clearDraft drops the stash', () {
      support.stashDraft(contact());
      support.clearDraft();

      expect(
        support.takeDraft(section: 'contact', currentUserId: null),
        isNull,
      );
    });

    test('a newer stash replaces the earlier one', () {
      support.stashDraft(contact('first'));
      support.stashDraft(contact('second'));

      expect(
        support
            .takeDraft(section: 'contact', currentUserId: null)
            ?.fields['subject'],
        'second',
      );
    });
  });
}
