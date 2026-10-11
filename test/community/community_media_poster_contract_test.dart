import 'dart:ui' show Size;

import 'package:art_kubus/community/community_interactions.dart';
import 'package:art_kubus/community/community_post_media.dart';
import 'package:art_kubus/community/community_video_poster_core.dart';
import 'package:flutter_test/flutter_test.dart';

const String _video = 'https://api.kubus.site/uploads/clip.mp4';
const String _poster = 'https://cdn.kubus.site/uploads/still.jpg';

/// The hinted form a video reference takes when [poster] is carried in it.
String _hinted(String video, String poster) =>
    '$video#kubus-media=video&kubus-poster=${Uri.encodeComponent(poster)}';

CommunityPost _post({List<String> mediaUrls = const [], String? imageUrl}) =>
    CommunityPost(
      id: 'post-poster-contract',
      authorName: 'Ana',
      content: 'Riverside wall.',
      timestamp: DateTime(2026, 10, 11, 9),
      mediaUrls: mediaUrls,
      imageUrl: imageUrl,
    );

void main() {
  group('poster hint: reading', () {
    test('a poster after the video hint is returned, decoded once', () {
      expect(communityMediaPosterReference(_hinted(_video, _poster)), _poster);
    });

    test('a video without a poster declares none', () {
      expect(
        communityMediaPosterReference('$_video#kubus-media=video'),
        isNull,
      );
      expect(communityMediaPosterReference(_video), isNull);
    });

    test('the poster is honoured only together with the video hint', () {
      final noVideoHint =
          '$_video#kubus-poster=${Uri.encodeComponent(_poster)}';
      expect(communityMediaPosterReference(noVideoHint), isNull);
    });

    test('a poster on an image reference is ignored', () {
      final imageWithPoster =
          'https://cdn.kubus.site/uploads/photo.jpg#kubus-poster=${Uri.encodeComponent(_poster)}';
      expect(communityMediaPosterReference(imageWithPoster), isNull);
      expect(communityMediaUrlIsVideo(imageWithPoster), isFalse);
    });

    test('a video reference with a poster is still a video', () {
      expect(communityMediaUrlIsVideo(_hinted(_video, _poster)), isTrue);
    });

    test('an .mp4 without any hint is a video and has no poster', () {
      expect(communityMediaUrlIsVideo(_video), isTrue);
      expect(communityMediaPosterReference(_video), isNull);
    });

    test('a double-encoded poster is not decoded twice and is refused', () {
      final twice = Uri.encodeComponent(Uri.encodeComponent(_poster));
      final url = '$_video#kubus-media=video&kubus-poster=$twice';
      expect(communityMediaPosterReference(url), isNull);
    });

    test('an encoded character inside the poster survives one decode', () {
      const poster = 'https://cdn.kubus.site/uploads/a%20b%2Bc.jpg';
      expect(communityMediaPosterReference(_hinted(_video, poster)), poster);
    });

    test('with duplicate poster keys, only the first counts', () {
      final first = Uri.encodeComponent(_poster);
      final second = Uri.encodeComponent('https://cdn.kubus.site/x/other.png');
      final url =
          '$_video#kubus-media=video&kubus-poster=$first&kubus-poster=$second';
      expect(communityMediaPosterReference(url), _poster);

      final invalidFirst = '$_video#kubus-media=video'
          '&kubus-poster=${Uri.encodeComponent(_video)}'
          '&kubus-poster=$first';
      expect(communityMediaPosterReference(invalidFirst), isNull);
    });

    test('unknown keys are ignored and do not hide the poster', () {
      final url = '$_video#kubus-media=video&kubus-other=1'
          '&kubus-poster=${Uri.encodeComponent(_poster)}&future=yes';
      expect(communityMediaPosterReference(url), _poster);
    });

    test('a malformed escape gives no poster', () {
      expect(
        communityMediaPosterReference(
          '$_video#kubus-media=video&kubus-poster=%E0%A4%A',
        ),
        isNull,
      );
    });

    test('the source URL drops every hint', () {
      expect(
        communityMediaVideoSourceUrl(_hinted(_video, _poster)),
        _video,
      );
      expect(communityMediaVideoSourceUrl(_video), _video);
    });
  });

  group('poster hint: accepted references', () {
    test('a public https image is accepted', () {
      expect(communityMediaPosterReferenceIsAccepted(_poster), isTrue);
      expect(
        communityMediaPosterReferenceIsAccepted(
          'https://cdn.kubus.site/a.JPEG',
        ),
        isTrue,
      );
      expect(
        communityMediaPosterReferenceIsAccepted(
            'https://img.example.org/p.webp'),
        isTrue,
      );
    });

    test('an upload path on this origin is accepted', () {
      expect(
        communityMediaPosterReferenceIsAccepted('/uploads/posters/still.png'),
        isTrue,
      );
    });

    test('an IPFS reference with a path is accepted', () {
      expect(
        communityMediaPosterReferenceIsAccepted(
            'ipfs://bafybeigdyrzt/still.jpg'),
        isTrue,
      );
      expect(
        communityMediaPosterReferenceIsAccepted('ipfs://QmTest123/a/b.png'),
        isTrue,
      );
    });

    test('the 2000-character cap is inclusive', () {
      const prefix = 'https://cdn.kubus.site/';
      final atLimit =
          '$prefix${'a' * (kCommunityMediaPosterMaxLength - prefix.length - 4)}.jpg';
      expect(atLimit.length, kCommunityMediaPosterMaxLength);
      expect(communityMediaPosterReferenceIsAccepted(atLimit), isTrue);
      final overCap =
          '$prefix${'a' * (kCommunityMediaPosterMaxLength - prefix.length - 3)}.jpg';
      expect(overCap.length, kCommunityMediaPosterMaxLength + 1);
      expect(
        communityMediaPosterReferenceIsAccepted(overCap),
        isFalse,
        reason: 'one character over the cap is refused',
      );
    });

    test('a poster hinted at the cap is read back in full', () {
      const prefix = 'https://cdn.kubus.site/';
      final atLimit =
          '$prefix${'a' * (kCommunityMediaPosterMaxLength - prefix.length - 4)}.jpg';
      expect(
        communityMediaPosterReference(_hinted(_video, atLimit)),
        atLimit,
      );
    });
  });

  group('poster hint: refused references', () {
    const refused = <String>[
      'https://cdn.kubus.site/uploads/clip.mp4',
      'https://cdn.kubus.site/still.gif',
      'https://cdn.kubus.site/still',
      'javascript:alert(1).jpg',
      'data:image/png;base64,AAAA.png',
      'blob:https://app.kubus.site/abc.jpg',
      'file:///etc/passwd.jpg',
      'http://cdn.kubus.site/still.jpg',
      'ftp://cdn.kubus.site/still.jpg',
      '//cdn.kubus.site/still.jpg',
      '/uploads/../secret.jpg',
      '/uploads/a.mp4',
      'https://localhost/still.jpg',
      'https://files.localhost/still.jpg',
      'https://printer.local/still.jpg',
      'https://10.0.0.5/still.jpg',
      'https://127.0.0.1/still.jpg',
      'https://192.168.1.20/still.jpg',
      'https://172.20.0.4/still.jpg',
      'https://169.254.169.254/still.jpg',
      'https://[::1]/still.jpg',
      'https://user:pw@cdn.kubus.site/still.jpg',
      'https://cdn.kubus.site/still.jpg#frag',
      'https://cdn.kubus.site/still .jpg',
      'https://cdn.kubus.site/still\u0007.jpg',
      'ipfs://bafy bad/still.jpg',
      'ipfs://bafy/../still.jpg',
    ];

    for (final reference in refused) {
      test('refuses ${reference.replaceAll('\u0007', '<BEL>')}', () {
        expect(communityMediaPosterReferenceIsAccepted(reference), isFalse);
        expect(
          communityMediaPosterReference(_hinted(_video, reference)),
          isNull,
        );
      });
    }

    test('refuses an empty poster', () {
      expect(communityMediaPosterReferenceIsAccepted(''), isFalse);
    });
  });

  group('building the reference for a post', () {
    test('an image is published exactly as uploaded', () {
      expect(
        communityMediaReferenceForPost(
          ' https://cdn.kubus.site/a.jpg ',
          isVideo: false,
          posterUrl: _poster,
        ),
        'https://cdn.kubus.site/a.jpg',
      );
    });

    test('a video with an extension and no poster is left as it is', () {
      expect(
        communityMediaReferenceForPost(_video, isVideo: true),
        _video,
      );
    });

    test('a video without an extension gets the video hint only', () {
      expect(
        communityMediaReferenceForPost(
          'ipfs://bafy/clip',
          isVideo: true,
        ),
        'ipfs://bafy/clip#kubus-media=video',
      );
    });

    test('a video with a poster carries the video hint and the poster', () {
      final built = communityMediaReferenceForPost(
        _video,
        isVideo: true,
        posterUrl: _poster,
      );
      expect(built, _hinted(_video, _poster));
      expect(communityMediaUrlIsVideo(built), isTrue);
      expect(communityMediaPosterReference(built), _poster);
      expect(communityMediaVideoSourceUrl(built), _video);
    });

    test('an .mp4 that is not yet hinted gets the poster hint too', () {
      final built = communityMediaReferenceForPost(
        _video,
        isVideo: true,
        posterUrl: _poster,
      );
      expect(built.startsWith('$_video#'), isTrue);
      expect(communityMediaPosterReference(built), _poster);
    });

    test('a refused poster leaves the video without a poster', () {
      final built = communityMediaReferenceForPost(
        'ipfs://bafy/clip',
        isVideo: true,
        posterUrl: 'https://cdn.kubus.site/still.gif',
      );
      expect(built, 'ipfs://bafy/clip#kubus-media=video');
      expect(communityMediaPosterReference(built), isNull);
    });

    test('an existing fragment is kept when there is no poster', () {
      expect(
        communityMediaReferenceForPost('ipfs://bafy/clip#v=1', isVideo: true),
        'ipfs://bafy/clip#v=1&kubus-media=video',
      );
    });
  });

  group('preview image for a post', () {
    test('a video-first post shows the poster of its first video', () {
      final post = _post(mediaUrls: [_hinted(_video, _poster)]);
      expect(communityPostPreviewImageUrl(post), _poster);
    });

    test('a video-first post without a poster falls back to its first image',
        () {
      final post = _post(
        mediaUrls: [
          _video,
          'https://cdn.kubus.site/second.jpg',
        ],
      );
      expect(
        communityPostPreviewImageUrl(post),
        'https://cdn.kubus.site/second.jpg',
      );
    });

    test('a video-only post without a poster has no still', () {
      expect(communityPostPreviewImageUrl(_post(mediaUrls: [_video])), isNull);
    });

    test('an image-first post shows its first image', () {
      final post = _post(
        mediaUrls: [
          'https://cdn.kubus.site/one.jpg',
          _hinted(_video, _poster),
        ],
      );
      expect(
        communityPostPreviewImageUrl(post),
        'https://cdn.kubus.site/one.jpg',
      );
    });

    test('a legacy imageUrl leads, and an empty post has no still', () {
      expect(
        communityPostPreviewImageUrl(
          _post(imageUrl: 'https://cdn.kubus.site/legacy.jpg'),
        ),
        'https://cdn.kubus.site/legacy.jpg',
      );
      expect(communityPostPreviewImageUrl(_post()), isNull);
    });
  });

  group('poster capture geometry', () {
    test('a frame is scaled to 720 on its longest side and keeps its shape',
        () {
      expect(
        communityVideoPosterSize(1920, 1080),
        const Size(720, 405),
      );
      expect(
        communityVideoPosterSize(1080, 1920),
        const Size(405, 720),
      );
    });

    test('a small frame is never upscaled', () {
      expect(communityVideoPosterSize(640, 360), const Size(640, 360));
    });

    test('a zero-sized frame gives no poster size', () {
      expect(communityVideoPosterSize(0, 360), Size.zero);
    });

    test('the seek point is a tenth of the clip, kept within 100 ms and 1 s',
        () {
      expect(
        communityVideoPosterSeekTarget(const Duration(seconds: 34)),
        const Duration(seconds: 1),
      );
      expect(
        communityVideoPosterSeekTarget(const Duration(seconds: 6)),
        const Duration(milliseconds: 600),
      );
      expect(
        communityVideoPosterSeekTarget(const Duration(milliseconds: 400)),
        const Duration(milliseconds: 100),
      );
      expect(
        communityVideoPosterSeekTarget(null),
        const Duration(milliseconds: 100),
      );
    });
  });
}
