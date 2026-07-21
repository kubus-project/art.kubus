import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:art_kubus/models/user.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/profile_fixtures.dart';
import '../support/profile_screen_harness.dart';
import '../support/qa_font_loader.dart';

/// Authenticated profile visual-QA matrix.
///
/// Renders the **real** profile screens against deterministic authenticated
/// fixtures and writes inspectable PNGs plus a machine-readable report to
/// `output/qa/profile-visual-matrix/`.
///
/// Deliberate properties:
/// * no production authentication is weakened — fixtures reach the screens only
///   through their supported `initialCriticalPackage` constructor seam and
///   `ProfileProvider.setCurrentUser`, and none of this code ships in `lib/`;
/// * fully deterministic — frozen timestamps, no network, no randomness;
/// * fails on any unexpected render error (see `pumpProfileSurface`);
/// * records the commit SHA, Flutter version and loaded font families so a
///   stale capture set can never be mistaken for a fresh one.
///
/// Run with:
/// ```
/// puro flutter test test/qa/profile_visual_matrix_test.dart
/// ```
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final outputDir = Directory('output/qa/profile-visual-matrix');
  final captures = <Map<String, Object?>>[];

  setUpAll(() async {
    await QaFontLoader.ensureLoaded();
    if (outputDir.existsSync()) outputDir.deleteSync(recursive: true);
    outputDir.createSync(recursive: true);
  });

  tearDownAll(() {
    final report = <String, Object?>{
      'generatedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'commit': _gitOutput(['rev-parse', 'HEAD']),
      'branch': _gitOutput(['rev-parse', '--abbrev-ref', 'HEAD']),
      'treeDirty': _gitOutput(['status', '--porcelain']).isNotEmpty,
      'flutterRoot': Platform.environment['FLUTTER_ROOT'],
      'fontFamiliesLoaded': QaFontLoader.loadedFamilies,
      'captureCount': captures.length,
      'captures': captures,
    };
    File('${outputDir.path}/report.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(report),
    );
  });

  Future<void> capture(
    WidgetTester tester, {
    required String name,
    required ProfileSurface surface,
    User? user,
    required Size size,
    Locale locale = const Locale('en'),
    Brightness brightness = Brightness.dark,
    double textScale = 1.0,
  }) async {
    await pumpProfileSurface(
      tester,
      surface: surface,
      user: user,
      size: size,
      locale: locale,
      brightness: brightness,
      textScale: textScale,
    );

    final image = await _captureRoot(tester);
    final file = File('${outputDir.path}/$name.png');
    file.writeAsBytesSync(image);

    captures.add(<String, Object?>{
      'name': name,
      'file': '$name.png',
      'surface': surface.name,
      'width': size.width,
      'height': size.height,
      'locale': locale.languageCode,
      'brightness': brightness.name,
      'textScale': textScale,
      'bytes': image.length,
    });
  }

  final artist = ProfileFixtures.user(isArtist: true, isVerified: true);
  final institution = ProfileFixtures.user(
    name: 'Muzej sodobne umetnosti Metelkova',
    username: 'msum_metelkova',
    isInstitution: true,
  );
  final combined = ProfileFixtures.user(
    isArtist: true,
    isInstitution: true,
    isVerified: true,
  );
  final longIdentity = ProfileFixtures.user(
    name: 'Ana Kovač Institute for Contemporary Muralism and Practice',
    username: ProfileFixtures.maxLengthUsername,
    isArtist: true,
    isVerified: true,
  );

  group('mobile public profile', () {
    for (final size in const [
      Size(320, 700),
      Size(360, 800),
      Size(390, 844),
      Size(412, 915),
    ]) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()}',
          (tester) async {
        await capture(
          tester,
          name: 'mobile-public-${size.width.toInt()}x${size.height.toInt()}',
          surface: ProfileSurface.mobilePublic,
          user: artist,
          size: size,
        );
      });
    }
  });

  group('desktop public profile', () {
    for (final size in const [
      Size(768, 1024),
      Size(1024, 768),
      Size(1200, 900),
      Size(1440, 1000),
    ]) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()}',
          (tester) async {
        await capture(
          tester,
          name: 'desktop-public-${size.width.toInt()}x${size.height.toInt()}',
          surface: ProfileSurface.desktopPublic,
          user: artist,
          size: size,
        );
      });
    }
  });

  group('community overlay', () {
    for (final entry in const <String, Size>{
      'narrow': Size(768, 900),
      'standard': Size(1024, 900),
      'wide': Size(1440, 900),
    }.entries) {
      testWidgets('${entry.key} overlay', (tester) async {
        await capture(
          tester,
          name: 'overlay-${entry.key}',
          surface: ProfileSurface.communityOverlay,
          user: longIdentity,
          size: entry.value,
        );
      });
    }
  });

  group('identity variants', () {
    final variants = <String, User>{
      'ordinary': ProfileFixtures.user(),
      'artist': artist,
      'institution': institution,
      'artist-institution': combined,
      'long-identity': longIdentity,
    };

    for (final entry in variants.entries) {
      testWidgets('mobile ${entry.key}', (tester) async {
        await capture(
          tester,
          name: 'variant-mobile-${entry.key}',
          surface: ProfileSurface.mobilePublic,
          user: entry.value,
          size: const Size(390, 844),
        );
      });

      testWidgets('overlay ${entry.key}', (tester) async {
        await capture(
          tester,
          name: 'variant-overlay-${entry.key}',
          surface: ProfileSurface.communityOverlay,
          user: entry.value,
          size: const Size(1024, 900),
        );
      });
    }

    testWidgets('owner profile', (tester) async {
      await capture(
        tester,
        name: 'variant-owner-mobile',
        surface: ProfileSurface.mobileOwner,
        user: artist,
        size: const Size(390, 844),
      );
    });

    testWidgets('owner profile desktop', (tester) async {
      await capture(
        tester,
        name: 'variant-owner-desktop',
        surface: ProfileSurface.desktopOwner,
        user: artist,
        size: const Size(1280, 1000),
      );
    });
  });

  group('theme and locale', () {
    for (final locale in const [Locale('en'), Locale('sl')]) {
      for (final brightness in Brightness.values) {
        testWidgets('${locale.languageCode}-${brightness.name}',
            (tester) async {
          await capture(
            tester,
            name: 'theme-${locale.languageCode}-${brightness.name}',
            surface: ProfileSurface.mobilePublic,
            user: longIdentity,
            size: const Size(390, 844),
            locale: locale,
            brightness: brightness,
          );
        });
      }
    }
  });

  group('accessibility text scale', () {
    for (final scale in const <double>[1.3, 1.6]) {
      testWidgets('mobile x$scale', (tester) async {
        await capture(
          tester,
          name: 'a11y-mobile-x${scale.toString().replaceAll('.', '_')}',
          surface: ProfileSurface.mobilePublic,
          user: longIdentity,
          size: const Size(390, 844),
          textScale: scale,
        );
      });

      testWidgets('overlay x$scale', (tester) async {
        await capture(
          tester,
          name: 'a11y-overlay-x${scale.toString().replaceAll('.', '_')}',
          surface: ProfileSurface.communityOverlay,
          user: longIdentity,
          size: const Size(1024, 900),
          textScale: scale,
        );
      });
    }
  });
}

/// Rasterizes the whole rendered surface to PNG bytes.
Future<List<int>> _captureRoot(WidgetTester tester) async {
  final boundary = tester.binding.rootElement!.renderObject!;
  final layer = boundary.debugLayer! as OffsetLayer;
  late final List<int> bytes;
  await tester.runAsync(() async {
    final image = await layer.toImage(boundary.paintBounds);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    bytes = data!.buffer.asUint8List();
    image.dispose();
  });
  return bytes;
}

String _gitOutput(List<String> args) {
  try {
    final result = Process.runSync('git', args);
    return (result.stdout as String).trim();
  } catch (_) {
    return '';
  }
}
