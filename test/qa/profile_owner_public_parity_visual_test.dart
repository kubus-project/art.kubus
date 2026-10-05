import 'dart:io';
import 'dart:ui' as ui;

import 'package:art_kubus/community/community_interactions.dart';
import 'package:art_kubus/models/user.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/profile_fixtures.dart';
import '../support/profile_screen_harness.dart';
import '../support/qa_font_loader.dart';

/// Whole-page captures of "My profile" next to the same profile viewed
/// publicly, so the shared information hierarchy can be inspected (identity,
/// work, activity, recognition, closing stats, then the owner's tools).
///
/// ```
/// KUBUS_RUN_VISUAL_QA=1 flutter test test/qa/profile_owner_public_parity_visual_test.dart
/// ```
///
/// Output: `output/qa/profile-parity/<surface>-<w>-<locale>-<scale>.png`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  if (Platform.environment['KUBUS_RUN_VISUAL_QA'] != '1') {
    test(
      'profile parity visual QA is opt-in',
      () {},
      skip: 'Set KUBUS_RUN_VISUAL_QA=1 to generate screenshot evidence.',
    );
    return;
  }

  final outputDir = Directory('output/qa/profile-parity');

  setUpAll(() async {
    await QaFontLoader.ensureLoaded();
    if (outputDir.existsSync()) outputDir.deleteSync(recursive: true);
    outputDir.createSync(recursive: true);
  });

  Future<void> capture(
    WidgetTester tester, {
    required String name,
    required ProfileSurface surface,
    required User user,
    required Size size,
    Locale locale = const Locale('en'),
    double textScale = 1.0,
    List<CommunityPost> posts = const <CommunityPost>[],
  }) async {
    await pumpProfileSurface(
      tester,
      surface: surface,
      user: user,
      size: size,
      locale: locale,
      brightness: Brightness.dark,
      textScale: textScale,
      posts: posts,
      paintGround: true,
    );
    final root = tester.binding.rootElement!.renderObject!;
    final layer = root.debugLayer! as OffsetLayer;
    late final List<int> bytes;
    await tester.runAsync(() async {
      final image = await layer.toImage(root.paintBounds);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      bytes = data!.buffer.asUint8List();
      image.dispose();
    });
    File('${outputDir.path}/$name.png').writeAsBytesSync(bytes);
    await tester.pump(const Duration(seconds: 2));
  }

  final artist = ProfileFixtures.user(isArtist: true, isVerified: true);
  final posts = ProfileFixtures.posts(
    authorId: artist.id,
    authorName: artist.name,
  );

  final scenes =
      <String, ({ProfileSurface owner, ProfileSurface public, Size size})>{
    '390': (
      owner: ProfileSurface.mobileOwner,
      public: ProfileSurface.mobilePublic,
      size: const Size(390, 3200),
    ),
    '1440': (
      owner: ProfileSurface.desktopOwner,
      public: ProfileSurface.desktopPublic,
      size: const Size(1440, 3000),
    ),
  };

  for (final scene in scenes.entries) {
    for (final locale in const [Locale('en'), Locale('sl')]) {
      for (final scale in scene.key == '390' ? const [1.0, 2.0] : const [1.0]) {
        final tag = '${scene.key}-${locale.languageCode}-${scale.toInt()}x';
        testWidgets('owner $tag', (tester) async {
          await capture(
            tester,
            name: 'owner-$tag',
            surface: scene.value.owner,
            user: artist,
            size: scene.value.size,
            locale: locale,
            textScale: scale,
            posts: posts,
          );
        });
        testWidgets('public $tag', (tester) async {
          await capture(
            tester,
            name: 'public-$tag',
            surface: scene.value.public,
            user: artist,
            size: scene.value.size,
            locale: locale,
            textScale: scale,
            posts: posts,
          );
        });
      }
    }
  }
}
