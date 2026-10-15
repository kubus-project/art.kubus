import 'package:art_kubus/community/community_post_media.dart';
import 'package:art_kubus/community/community_post_text_limits.dart';
import 'package:art_kubus/community/community_upload_feedback.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

BackendApiRequestException _rejected(String body, {int status = 400}) =>
    BackendApiRequestException(
      statusCode: status,
      path: '/api/community/posts',
      body: body,
    );

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final sl = lookupAppLocalizations(const Locale('sl'));

  group('video kind survives extensionless storage URLs', () {
    test('a video with a file extension is published untouched', () {
      expect(
        communityMediaReferenceForPost('/uploads/post-video/a.mp4',
            isVideo: true),
        '/uploads/post-video/a.mp4',
      );
    });

    test('an extensionless video reference carries an explicit hint', () {
      final stored = communityMediaReferenceForPost(
        'https://ipfs.io/ipfs/bafybeigdyrzt',
        isVideo: true,
      );
      expect(stored, 'https://ipfs.io/ipfs/bafybeigdyrzt#kubus-media=video');
      expect(communityMediaUrlIsVideo(stored), isTrue);
      expect(communityMediaUrlIsVideo('https://ipfs.io/ipfs/bafybeigdyrzt'),
          isFalse,
          reason: 'old stored references keep rendering as images');
    });

    test('an existing fragment is extended, not replaced', () {
      expect(
        communityMediaReferenceForPost('ipfs://bafy#t=2', isVideo: true),
        'ipfs://bafy#t=2&kubus-media=video',
      );
      expect(
        communityMediaUrlIsVideo('ipfs://bafy#t=2&kubus-media=video'),
        isTrue,
      );
      expect(communityMediaReferenceForPost('ipfs://bafy#', isVideo: true),
          'ipfs://bafy#kubus-media=video');
    });

    test('images are never hinted', () {
      expect(
        communityMediaReferenceForPost('https://ipfs.io/ipfs/bafy',
            isVideo: false),
        'https://ipfs.io/ipfs/bafy',
      );
    });

    test('the hinted reference still passes the backend reference rules', () {
      // Mirrors isAcceptedCommunityMediaReference: an absolute http(s) or ipfs://
      // reference, no whitespace, at most 2000 characters.
      for (final url in [
        'https://ipfs.io/ipfs/bafybeigdyrzt',
        'ipfs://bafybeigdyrzt',
        'https://api.kubus.site/uploads/x',
      ]) {
        final stored = communityMediaReferenceForPost(url, isVideo: true);
        expect(stored.contains(RegExp(r'\s')), isFalse);
        expect(stored.length, lessThanOrEqualTo(2000));
        expect(
          RegExp(r'^(https?://[^/\s]+|ipfs://[A-Za-z0-9]+)').hasMatch(stored),
          isTrue,
        );
      }
    });
  });

  group('caption limit', () {
    test('counts Unicode code points, so 2,200 fit and 2,201 do not', () {
      // Each emoji is two UTF-16 units but one code point.
      final exact =
          List<String>.filled(kCommunityPostMaxCharacters, '😀').join();
      expect(communityPostCharacterCount(exact), kCommunityPostMaxCharacters);
      expect(exact.length, kCommunityPostMaxCharacters * 2);
      expect(communityPostCharacterCount('${exact}x'),
          kCommunityPostMaxCharacters + 1);
    });
  });

  group('rejected publish feedback', () {
    test('names the server validation problem instead of a generic failure',
        () {
      final error = _rejected(
        '{"success":false,"error":"Validation failed","details":['
        '{"field":"content","message":"Content must be 1-1000 characters",'
        '"value":"x"}]}',
      );
      expect(communityValidationDetail(error),
          'Content must be 1-1000 characters');
      expect(
        communityComposerFailureMessage(en, error),
        'The server did not accept this post: Content must be 1-1000 '
        'characters. Your draft is kept.',
      );
      expect(
        communityComposerFailureMessage(sl, error),
        'Strežnik objave ni sprejel: Content must be 1-1000 characters. '
        'Osnutek je ohranjen.',
      );
    });

    test('lists distinct problems once each, at most three', () {
      final error = _rejected(
        '{"error":"Validation failed","details":['
        '{"message":"A"},{"message":"A"},{"message":"B"},{"message":"C"},'
        '{"message":"D"}]}',
      );
      expect(communityValidationDetail(error), 'A; B; C');
    });

    test('falls back to a plain error string, but not the generic summary', () {
      expect(
        communityValidationDetail(
            _rejected('{"error":"Media URLs must be an array of up to 10"}')),
        'Media URLs must be an array of up to 10',
      );
      expect(
          communityValidationDetail(
              _rejected('{"error":"Validation failed","details":[]}')),
          isNull);
    });

    test('other failures are not mistaken for validation', () {
      expect(communityValidationDetail(_rejected('{"error":"x"}', status: 500)),
          isNull);
      expect(communityValidationDetail(_rejected('not json')), isNull);
      expect(communityValidationDetail(StateError('boom')), isNull);
      expect(
        communityComposerFailureMessage(en, _rejected('', status: 500),
            fallback: 'Fallback copy'),
        'Fallback copy',
      );
    });

    test('a media upload failure keeps its file-count copy', () {
      expect(
        communityComposerFailureMessage(
          en,
          _rejected('{"details":[{"message":"File too large"}]}'),
          unuploadedMediaCount: 1,
        ),
        en.communityComposerMediaUploadFailed(1),
      );
    });
  });

  group('picker overflow feedback', () {
    test('says how many files were added when the pick exceeds the room', () {
      expect(
        communityComposerTrimmedMessage(en, added: 3, picked: 5, max: 10),
        'Added 3 of 5 files. A post holds up to 10 items.',
      );
      expect(
        communityComposerTrimmedMessage(sl, added: 3, picked: 5, max: 10),
        'Dodanih: 3 od 5 datotek. Objava vsebuje do 10 elementov.',
      );
    });

    test('is silent when everything fit', () {
      expect(communityComposerTrimmedMessage(en, added: 4, picked: 4, max: 10),
          isNull);
    });
  });
}
