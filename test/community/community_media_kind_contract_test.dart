import 'package:art_kubus/community/community_post_media.dart';
import 'package:flutter_test/flutter_test.dart';

/// How a stored Community media reference becomes "image" or "video".
///
/// The API stores `mediaUrls` as plain strings with no per-item type, so the
/// rule is deliberately conservative and never guesses:
///  * an explicit `kubus-media=video` fragment hint says video (it is how an
///    IPFS-only reference with no file extension is published);
///  * otherwise a recognised video extension on the path says video;
///  * everything else, including a bare CID or an extensionless gateway path,
///    is an image. It is not assumed to be a video either, and no request is
///    made to find out.
void main() {
  group('extensionless and IPFS references are not guessed', () {
    for (final url in <String>[
      'bafybeigdyrztq3fh6p2ksuv2fnkwcrmrd6y3v7qgz6mjwhdmeyxmksl6q4',
      'QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG',
      'ipfs://bafybeigdyrztq3fh6p2ksuv2fnkwcrmrd6y3v7qgz6mjwhdmeyxmksl6q4',
      'https://ipfs.io/ipfs/bafybeigdyrztq3fh6p2ksuv2fnkwcrmrd6y3v7qgz6mjwhdmeyxmksl6q4',
      'https://gateway.example/ipfs/bafybei/clip',
      'https://api.kubus.site/uploads/profiles/posts/photo-0.png',
      'https://example.test/view?file=clip.mp4',
      'https://example.test/path/clip.mp4.html',
      'https://example.test/uploads/image.jpg#kubus-aspect=1.5',
    ]) {
      test('$url is an image', () {
        expect(communityMediaUrlIsVideo(url), isFalse);
      });
    }
  });

  group('videos are recognised by hint or extension', () {
    for (final url in <String>[
      'https://example.test/uploads/clip.mp4',
      'https://example.test/uploads/CLIP.MP4',
      'https://example.test/uploads/clip.webm?token=abc',
      'ipfs://bafybei/clip.mov',
      'https://example.test/uploads/clip.m4v#kubus-aspect=0.5625',
      'ipfs://bafybei/clip#kubus-media=video',
      'https://gateway.example/ipfs/bafybei#kubus-media=video&kubus-aspect=0.5625',
      'bafybeigdyrztq3fh6p2ksuv2fnkwcrmrd6y3v7qgz6mjwhdmeyxmksl6q4#kubus-media=video',
    ]) {
      test('$url is a video', () {
        expect(communityMediaUrlIsVideo(url), isTrue);
      });
    }
  });

  group('hints never leak into playback, and geometry is optional', () {
    test('the video source URL drops every hint', () {
      expect(
        communityMediaVideoSourceUrl(
            'ipfs://bafybei/clip#kubus-media=video&kubus-aspect=0.5625'),
        'ipfs://bafybei/clip',
      );
    });

    test('a recorded aspect is read only for a video, and only if usable', () {
      expect(
          communityMediaVideoAspect('https://x.test/a.mp4#kubus-aspect=0.5625'),
          closeTo(0.5625, 1e-9));
      expect(communityMediaVideoAspect('https://x.test/a.mp4'), isNull);
      expect(communityMediaVideoAspect('https://x.test/a.mp4#kubus-aspect=0'),
          isNull);
      expect(communityMediaVideoAspect('https://x.test/a.mp4#kubus-aspect=-2'),
          isNull);
      expect(communityMediaVideoAspect('https://x.test/a.mp4#kubus-aspect=nan'),
          isNull);
      expect(communityMediaVideoAspect('https://x.test/a.mp4#kubus-aspect=abc'),
          isNull);
      // An image never carries a video geometry, whatever its fragment says.
      expect(
          communityMediaVideoAspect('https://x.test/a.jpg#kubus-aspect=0.5625'),
          isNull);
    });

    test('a poster counts only together with the video hint', () {
      const poster = 'https://x.test/still.jpg';
      final encoded = Uri.encodeComponent(poster);
      expect(
          communityMediaPosterReference(
              'ipfs://bafybei/clip#kubus-media=video&kubus-poster=$encoded'),
          poster);
      expect(
          communityMediaPosterReference(
              'ipfs://bafybei/clip#kubus-poster=$encoded'),
          isNull);
    });
  });
}
