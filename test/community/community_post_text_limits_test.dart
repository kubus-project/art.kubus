import 'package:art_kubus/community/community_post_text_limits.dart';
import 'package:art_kubus/community/community_upload_feedback.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/l10n/app_localizations_en.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('post text policy', () {
    test('the canonical maximum is 2200 characters', () {
      expect(kCommunityPostMaxCharacters, 2200);
    });

    test('counts code points so accented Slovenian letters count once', () {
      expect(communityPostCharacterCount('čšž ČŠŽ'), 7);
      expect(communityPostCharacterCount('Dobrodošli'), 10);
    });

    test('counts an emoji as one character, not two UTF-16 units', () {
      expect('🎨'.length, 2);
      expect(communityPostCharacterCount('🎨'), 1);
      expect(communityPostCharacterCount('🎨🎨🎨'), 3);
    });

    test('accepts exactly 2200 characters and rejects 2201', () {
      expect(
        communityPostExceedsLimit('a' * kCommunityPostMaxCharacters),
        isFalse,
      );
      expect(
        communityPostExceedsLimit('a' * (kCommunityPostMaxCharacters + 1)),
        isTrue,
      );
    });

    test('applies the emoji boundary in code points', () {
      final atLimit = '🎨' * kCommunityPostMaxCharacters;
      expect(communityPostExceedsLimit(atLimit), isFalse);
      expect(communityPostExceedsLimit('$atLimit🎨'), isTrue);
    });

    test('trims surrounding whitespace before counting, as the backend does',
        () {
      final padded = '   ${'a' * kCommunityPostMaxCharacters}   ';
      expect(communityPostExceedsLimit(padded), isFalse);
    });
  });

  group('composer failure copy', () {
    final l10n = AppLocalizationsEn();

    test('names a short upload wait in seconds', () {
      expect(
        communityUploadRateLimitMessage(l10n, const Duration(seconds: 45)),
        'Upload limit reached. Try again in 45 seconds.',
      );
    });

    test('rounds a long upload wait up to minutes', () {
      expect(
        communityUploadRateLimitMessage(l10n, const Duration(seconds: 3000)),
        'Upload limit reached. Try again in about 50 minutes.',
      );
    });

    test('gives a neutral hint when the server gave no wait', () {
      expect(
        communityUploadRateLimitMessage(l10n, null),
        'Too many uploads right now. Wait a moment and try again.',
      );
    });

    test('a rate-limited publish uses the wait copy', () {
      final message = communityComposerFailureMessage(
        l10n,
        const UploadRateLimitedException(
          path: '/api/upload',
          retryAfter: Duration(seconds: 30),
        ),
      );
      expect(message, 'Upload limit reached. Try again in 30 seconds.');
    });

    test('a failed media publish says how many files remain', () {
      expect(
        communityComposerFailureMessage(
          l10n,
          StateError('boom'),
          unuploadedMediaCount: 2,
        ),
        '2 files could not be uploaded. Your draft is kept, so you can retry.',
      );
    });

    test(
        'committed post conflict asks for feed inspection, other conflicts do not',
        () {
      const gap = BackendApiRequestException(
          statusCode: 409,
          path: '/api/community/posts',
          body: '{"errorCode":"COMMUNITY_POST_ALREADY_COMMITTED"}');
      expect(communityPostAlreadyCommitted(gap), isTrue);
      expect(communityComposerFailureMessage(l10n, gap),
          l10n.communityComposerAlreadyCommitted);
      expect(
          communityPostAlreadyCommitted(const BackendApiRequestException(
              statusCode: 409,
              path: '/api/groups/g/posts',
              body: '{"error":"changed content"}')),
          isFalse);
    });

    test('new Slovenian feedback preserves its diacritics', () {
      final sl = lookupAppLocalizations(const Locale('sl'));
      expect(sl.communityComposerRateLimitedSeconds(45),
          'Objavljanje je za\u010dasno omejeno. Poskusite znova \u010dez 45 s. Osnutek je ohranjen.');
      expect(sl.communityComposerDiscardDraft,
          '\u017delite zavre\u010di ta osnutek?');
      expect(sl.communityComposerAlreadyCommitted,
          'Objava je morda \u017ee objavljena. Osnutek je ohranjen. Preden ga izbri\u0161ete ali za\u010dnete novo objavo, preverite vir objav.');
    });

    test('a create rate limit preserves the wait in both locales', () {
      const error = BackendApiRequestException(
        statusCode: 429,
        path: '/api/community/posts',
        retryAfter: Duration(seconds: 45),
      );
      for (final locale in ['en', 'sl']) {
        final localized = lookupAppLocalizations(Locale(locale));
        expect(communityComposerFailureMessage(localized, error),
            localized.communityComposerRateLimitedSeconds(45));
      }
    });

    test('other failures keep the supplied fallback', () {
      expect(
        communityComposerFailureMessage(
          l10n,
          StateError('boom'),
          fallback: 'Fallback copy',
        ),
        'Fallback copy',
      );
      expect(
        communityComposerFailureMessage(l10n, StateError('boom')),
        l10n.communityComposerCreatePostFailedToast,
      );
    });
  });

  test('the test harness resolves the generated English localizations', () {
    expect(
      lookupAppLocalizations(const Locale('en')).communityComposerMediaAddVideo,
      'Add video',
    );
  });
}
