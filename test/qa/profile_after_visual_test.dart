import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/profile_fixtures.dart';
import '../support/profile_image_http_fixture.dart';
import '../support/profile_screen_harness.dart';
import '../support/qa_font_loader.dart';

/// Small, opt-in after-change profile captures written outside the repository.
/// Set KUBUS_PROFILE_QA_OUTPUT to the requested report directory.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('profile after captures across mobile and desktop layouts', (
    tester,
  ) async {
    if (Platform.environment['KUBUS_RUN_VISUAL_QA'] != '1') {
      markTestSkipped(
        'Set KUBUS_RUN_VISUAL_QA=1 to capture after screenshots.',
      );
      return;
    }
    final outputPath = Platform.environment['KUBUS_PROFILE_QA_OUTPUT'];
    if (outputPath == null || outputPath.trim().isEmpty) {
      fail('Set KUBUS_PROFILE_QA_OUTPUT to an external output directory.');
    }
    final outputDir = Directory(outputPath);
    outputDir.createSync(recursive: true);
    await QaFontLoader.ensureLoaded();

    const coverUrl = 'https://profile-fixture.invalid/wide.png';
    final user = ProfileFixtures.user(
      name: 'Ana Kovač Institute for Contemporary Muralism',
      username: ProfileFixtures.maxLengthUsername,
      isArtist: true,
      isVerified: true,
      coverImageUrl: coverUrl,
    );
    const scenes = <({
      String locale,
      ui.Brightness brightness,
      ProfileSurface surface,
      Size size,
      double textScale,
    })>[
      (
        locale: 'en',
        brightness: ui.Brightness.dark,
        surface: ProfileSurface.mobilePublic,
        size: Size(390, 852),
        textScale: 1,
      ),
      (
        locale: 'en',
        brightness: ui.Brightness.light,
        surface: ProfileSurface.mobileOwner,
        size: Size(390, 852),
        textScale: 1,
      ),
      (
        locale: 'sl',
        brightness: ui.Brightness.dark,
        surface: ProfileSurface.mobileOwner,
        size: Size(390, 852),
        textScale: 2,
      ),
      (
        locale: 'sl',
        brightness: ui.Brightness.light,
        surface: ProfileSurface.mobilePublic,
        size: Size(390, 852),
        textScale: 2,
      ),
      (
        locale: 'en',
        brightness: ui.Brightness.dark,
        surface: ProfileSurface.desktopPublic,
        size: Size(1440, 1000),
        textScale: 1,
      ),
      (
        locale: 'en',
        brightness: ui.Brightness.light,
        surface: ProfileSurface.desktopOwner,
        size: Size(1440, 1000),
        textScale: 1,
      ),
    ];

    for (final scene in scenes) {
      final fixture = ProfileImageHttpFixture();
      await tester.runAsync(fixture.prepare);
      final previousHttpClientProvider = debugNetworkImageHttpClientProvider;
      debugNetworkImageHttpClientProvider =
          () => fixture.createHttpClient(null);
      try {
        await pumpProfileSurface(
          tester,
          surface: scene.surface,
          user: user,
          size: scene.size,
          locale: Locale(scene.locale),
          brightness: scene.brightness == ui.Brightness.dark
              ? Brightness.dark
              : Brightness.light,
          textScale: scene.textScale,
          paintGround: true,
        );
        expect(fixture.requests, 1);
        final data = await tester.runAsync(() async {
          final root = tester.binding.rootElement!.renderObject!;
          final layer = root.debugLayer! as OffsetLayer;
          final image = await layer.toImage(root.paintBounds);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          return bytes!.buffer.asUint8List();
        });
        final name = 'profile-${scene.surface.name}-${scene.locale}-'
            '${scene.brightness.name}-${scene.size.width.toInt()}x'
            '${scene.size.height.toInt()}-scale${scene.textScale.toInt()}.png';
        File('${outputDir.path}/$name').writeAsBytesSync(data!);
        expectNoUnexpectedRenderErrors();
      } finally {
        debugNetworkImageHttpClientProvider = previousHttpClientProvider;
      }
    }
  });
}
