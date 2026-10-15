import 'dart:typed_data';

import 'package:art_kubus/community/community_composer_media.dart';
import 'package:art_kubus/community/community_interactions.dart';
import 'package:art_kubus/community/community_post_media.dart';
import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

CommunityComposerPickedMedia _image(String name) =>
    CommunityComposerPickedMedia(
      file: XFile.fromData(
        Uint8List.fromList(<int>[1, 2, 3]),
        path: name,
        mimeType: 'image/jpeg',
      ),
      kind: CommunityComposerMediaKind.image,
      imageBytes: Uint8List.fromList(<int>[1, 2, 3]),
    );

CommunityPost _post({List<String> mediaUrls = const [], String? imageUrl}) =>
    CommunityPost(
      id: 'post-rollout',
      authorName: 'Ana Umetnica',
      content: 'A mural on the riverside wall.',
      timestamp: DateTime(2026, 10, 1, 12),
      mediaUrls: mediaUrls,
      imageUrl: imageUrl,
    );

final AppLocalizations _en = lookupAppLocalizations(const Locale('en'));
final AppLocalizations _sl = lookupAppLocalizations(const Locale('sl'));

void main() {
  group('rollout flag', () {
    test('AppConfig exposes the switch through isFeatureEnabled', () {
      expect(
        AppConfig.isFeatureEnabled('communityMultiMedia'),
        AppConfig.enableCommunityMultiMedia,
      );
    });

    test('enabled composers allow ten items and disabled composers allow one',
        () {
      expect(communityComposerMaxMediaItems(multiMediaEnabled: true), 10);
      expect(communityComposerMaxMediaItems(multiMediaEnabled: false), 1);
    });

    test('a disabled composer accepts one item and then reports itself full',
        () {
      final controller = CommunityComposerMediaController(
        maxItems: communityComposerMaxMediaItems(multiMediaEnabled: false),
      );

      expect(controller.add([_image('a.jpg'), _image('b.jpg')]), 1);
      expect(controller.isFull, isTrue);
    });

    test('a post with several stored URLs shows only its first when disabled',
        () {
      final post = _post(mediaUrls: const [
        '/uploads/1.jpg',
        '/uploads/2.mp4',
        '/uploads/3.jpg',
      ]);

      expect(
        communityPostMediaUrls(post, multiMediaEnabled: false),
        ['/uploads/1.jpg'],
      );
      expect(
        communityPostMediaUrls(post, multiMediaEnabled: true),
        ['/uploads/1.jpg', '/uploads/2.mp4', '/uploads/3.jpg'],
      );
    });

    test('a legacy single-image post is identical with the flag off', () {
      final post = _post(imageUrl: '/uploads/legacy.jpg');

      expect(communityPostMediaUrls(post, multiMediaEnabled: false),
          ['/uploads/legacy.jpg']);
      expect(communityPostMediaUrls(post, multiMediaEnabled: true),
          ['/uploads/legacy.jpg']);
    });
  });

  group('caption for media posts without typed text', () {
    test('image-only posts use the localized photo caption in English', () {
      expect(
        communityComposerMediaFallbackCaption(_en,
            hasImages: true, hasVideos: false),
        'Shared a photo',
      );
    });

    test('image-only posts use the localized photo caption in Slovenian', () {
      expect(
        communityComposerMediaFallbackCaption(_sl,
            hasImages: true, hasVideos: false),
        _sl.desktopCommunitySharedPhotoFallbackContent,
      );
      expect(_sl.desktopCommunitySharedPhotoFallbackContent,
          isNot('Shared a photo'));
    });

    test('mixed posts keep the photo caption, which the backend accepts', () {
      expect(
        communityComposerMediaFallbackCaption(_en,
            hasImages: true, hasVideos: true),
        communityComposerMediaFallbackCaption(_en,
            hasImages: true, hasVideos: false),
      );
    });

    test('video-only posts never get the photo caption, in either language',
        () {
      for (final l10n in [_en, _sl]) {
        final caption = communityComposerMediaFallbackCaption(l10n,
            hasImages: false, hasVideos: true);
        expect(caption, '🎥');
        expect(caption, isNot(l10n.desktopCommunitySharedPhotoFallbackContent));
      }
    });
  });
}
