import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/l10n/app_localizations_en.dart';
import 'package:art_kubus/l10n/app_localizations_sl.dart';
import 'package:art_kubus/services/push_notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final AppLocalizations en = AppLocalizationsEn();
  final AppLocalizations sl = AppLocalizationsSl();

  ({String title, String body}) community(
    AppLocalizations l10n,
    String type, {
    String? actorName = 'Ana',
    String? comment,
  }) =>
      PushNotificationService.communityInteractionCopy(
        l10n,
        type: type,
        actorName: actorName,
        comment: comment,
      );

  group('community interaction copy (en)', () {
    test('like names the actor and uses post as the noun', () {
      final copy = community(en, 'like');
      expect(copy.title, 'New like');
      expect(copy.body, 'Ana liked your post');
    });

    test('comment without text does not render a bare fallback label', () {
      final copy = community(en, 'comment', comment: '   ');
      expect(copy.title, 'New comment');
      expect(copy.body, 'Ana commented on your post');
      expect(copy.body, isNot(startsWith('Ana: commented')));
    });

    test('comment with text shows the preview', () {
      final copy = community(en, 'comment', comment: 'Lovely work');
      expect(copy.body, 'Ana: Lovely work');
    });

    test('comment preview is truncated to 60 characters', () {
      final long = 'a' * 80;
      final copy = community(en, 'comment', comment: long);
      expect(copy.body, 'Ana: ${'a' * 60}...');
    });

    test('share, repost and mention use localized copy', () {
      expect(community(en, 'share').body, 'Ana shared your post');
      expect(community(en, 'repost').title, 'New repost');
      expect(community(en, 'repost').body, 'Ana reposted your post');
      expect(community(en, 'mention').title, 'You were mentioned');
      expect(community(en, 'mention').body, 'Ana mentioned you in a post');
    });

    test('unknown types use the generic activity copy', () {
      final copy = community(en, 'unknown-type');
      expect(copy.title, 'New activity');
      expect(copy.body, 'Ana interacted with your post');
    });

    test('missing actor uses the localized Someone fallback', () {
      final copy = community(en, 'like', actorName: '  ');
      expect(copy.body, 'Someone liked your post');
    });
  });

  group('community interaction copy (sl)', () {
    test('every type has Slovenian copy without emoji titles', () {
      for (final type in [
        'like',
        'comment',
        'share',
        'repost',
        'mention',
        'other',
      ]) {
        final copy = community(sl, type, comment: 'Lep');
        expect(copy.title, isNotEmpty, reason: type);
        expect(copy.body, contains('Ana'), reason: type);
        expect(
          copy.title,
          isNot(matches(RegExp(r'[\u{1F300}-\u{1FAFF}]', unicode: true))),
          reason: type,
        );
        expect(copy.title, isNot(contains('❤')), reason: type);
      }
    });

    test('like, comment and repost copy is Slovenian', () {
      final like = community(sl, 'like');
      expect(like.title, 'Nov všeček');
      expect(like.body, 'Ana: všeček za vašo objavo');

      final comment = community(sl, 'comment', comment: 'Lep');
      expect(comment.title, 'Nov komentar');
      expect(comment.body, 'Ana: Lep');

      final commentNoText = community(sl, 'comment');
      expect(commentNoText.body, 'Ana: nov komentar na vašo objavo');

      final repost = community(sl, 'repost');
      expect(repost.title, 'Nova ponovna objava');
      expect(repost.body, 'Ana: ponovna objava vaše objave');
    });

    test('missing actor uses the Slovenian Someone fallback', () {
      final copy = community(sl, 'repost', actorName: null);
      expect(copy.body, 'Nekdo: ponovna objava vaše objave');
    });
  });

  group('follower copy', () {
    test('en and sl name the follower and avoid the hardcoded emoji title', () {
      final enCopy = PushNotificationService.followerNotificationCopy(
        en,
        userName: 'Ana',
      );
      expect(enCopy.title, 'New follower');
      expect(enCopy.body, 'Ana started following you');

      final slCopy = PushNotificationService.followerNotificationCopy(
        sl,
        userName: 'Ana',
      );
      expect(slCopy.title, 'Nov sledilec');
      expect(slCopy.body, 'Ana: zdaj vam sledi');
    });

    test('missing follower name uses the localized fallback', () {
      final copy = PushNotificationService.followerNotificationCopy(
        sl,
        userName: '',
      );
      expect(copy.body, 'Nekdo: zdaj vam sledi');
    });
  });
}
