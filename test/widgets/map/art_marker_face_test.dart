import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:art_kubus/models/art_marker.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/utils/app_color_utils.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/art_marker_cube.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/qa_font_loader.dart';

/// The face of a map marker: a canonical silhouette per category, a restrained
/// tonal field, and a large glyph that is legible on every category colour.
///
/// The silhouette is the semantic category language, so it is asserted
/// explicitly; the face is asserted by what a reader of the map would actually
/// see (a field that is not flat, a glyph that clears contrast).
double _contrast(Color a, Color b) {
  final la = a.computeLuminance() + 0.05;
  final lb = b.computeLuminance() + 0.05;
  return la > lb ? la / lb : lb / la;
}

({ThemeData theme, ColorScheme scheme, KubusColorRoles roles}) _themeFor(
  bool isDark,
) {
  final themes = ThemeProvider();
  final theme = isDark ? themes.darkTheme : themes.lightTheme;
  return (
    theme: theme,
    scheme: theme.colorScheme,
    roles: theme.extension<KubusColorRoles>()!,
  );
}

Color _subject(ArtMarkerType type, bool isDark) {
  final t = _themeFor(isDark);
  return AppColorUtils.markerSubjectColor(
    markerType: type.name,
    metadata: null,
    scheme: t.scheme,
    roles: t.roles,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(const <String, Object>{}));

  group('canonical silhouettes are preserved', () {
    test('each category keeps its own shape', () {
      expect(
        {for (final t in ArtMarkerType.values) t: ArtMapMarkerShape.forType(t)},
        <ArtMarkerType, ArtMapMarkerShape>{
          ArtMarkerType.artwork: ArtMapMarkerShape.roundedSquare,
          ArtMarkerType.streetArt: ArtMapMarkerShape.diamond,
          ArtMarkerType.institution: ArtMapMarkerShape.arch,
          ArtMarkerType.event: ArtMapMarkerShape.pill,
          ArtMarkerType.exhibition: ArtMapMarkerShape.pill,
          ArtMarkerType.residency: ArtMapMarkerShape.hexagon,
          ArtMarkerType.drop: ArtMapMarkerShape.capsule,
          ArtMarkerType.experience: ArtMapMarkerShape.portalHex,
          ArtMarkerType.other: ArtMapMarkerShape.circle,
        },
      );
    });
  });

  group('the glyph is large and tuned to each silhouette', () {
    test('every shape lands in the 55-70% optical band of its em box', () {
      for (final shape in ArtMapMarkerShape.values) {
        final scale = ArtMarkerCubeIconRenderer.glyphScaleFor(shape);
        expect(scale, inInclusiveRange(0.48, 0.72), reason: shape.name);
      }
    });

    test('tight silhouettes get a smaller em box than roomy ones', () {
      double scale(ArtMapMarkerShape s) =>
          ArtMarkerCubeIconRenderer.glyphScaleFor(s);
      expect(scale(ArtMapMarkerShape.diamond),
          lessThan(scale(ArtMapMarkerShape.roundedSquare)));
      expect(scale(ArtMapMarkerShape.pill),
          lessThan(scale(ArtMapMarkerShape.circle)));
      expect(scale(ArtMapMarkerShape.capsule),
          lessThan(scale(ArtMapMarkerShape.hexagon)));
    });
  });

  group('glyph tint', () {
    for (final isDark in const [false, true]) {
      test(
          'clears contrast on every category colour (${isDark ? 'dark' : 'light'})',
          () {
        for (final type in ArtMarkerType.values) {
          final field = _subject(type, isDark);
          final tint = ArtMarkerCubeIconRenderer.glyphTintFor(
            field,
            isDark: isDark,
          );
          expect(_contrast(tint.to, field), greaterThanOrEqualTo(3.0),
              reason: '${type.name} weakest end');
          expect(_contrast(tint.from, field), greaterThanOrEqualTo(3.0),
              reason: '${type.name} strongest end');
        }
      });

      test(
          'is tonal, not a plain black or white ink (${isDark ? 'dark' : 'light'})',
          () {
        for (final type in ArtMarkerType.values) {
          final tint = ArtMarkerCubeIconRenderer.glyphTintFor(
            _subject(type, isDark),
            isDark: isDark,
          );
          expect(tint.from, isNot(const Color(0xFFFFFFFF)), reason: type.name);
          expect(tint.from, isNot(const Color(0xFF000000)), reason: type.name);
          expect(tint.from, isNot(tint.to), reason: '${type.name} has a range');
        }
      });
    }

    test('keeps the theme polarity where it is legible', () {
      // A deep colour on the light map takes a light glyph; on the dark map a
      // dark glyph — the existing preference.
      const deepTeal = Color(0xFF0B6E63);
      final light =
          ArtMarkerCubeIconRenderer.glyphTintFor(deepTeal, isDark: false);
      expect(light.from.computeLuminance(), greaterThan(0.6));
      const lightTeal = Color(0xFF5FD6C8);
      final dark =
          ArtMarkerCubeIconRenderer.glyphTintFor(lightTeal, isDark: true);
      expect(dark.from.computeLuminance(), lessThan(0.15));
    });

    test('flips polarity rather than shipping an illegible glyph', () {
      // A pale yellow cannot carry a white glyph.
      const paleYellow = Color(0xFFFFE066);
      final tint =
          ArtMarkerCubeIconRenderer.glyphTintFor(paleYellow, isDark: false);
      expect(tint.from.computeLuminance(), lessThan(0.2));
      expect(_contrast(tint.to, paleYellow), greaterThanOrEqualTo(3.0));
    });
  });

  group('expressive face glyph (theme independent)', () {
    test('clears contrast on every category colour in both themes', () {
      for (final isDark in const [false, true]) {
        for (final type in ArtMarkerType.values) {
          final field = _subject(type, isDark);
          final tint = ArtMarkerCubeIconRenderer.faceGlyphTintFor(field);
          expect(_contrast(tint.to, field), greaterThanOrEqualTo(3.0),
              reason: '${type.name} ${isDark ? 'dark' : 'light'}');
        }
      }
    });

    test('is made of the category colour, never plain black or white', () {
      for (final type in ArtMarkerType.values) {
        final tint = ArtMarkerCubeIconRenderer.faceGlyphTintFor(
          _subject(type, false),
        );
        for (final c in [tint.from, tint.to]) {
          expect(c, isNot(const Color(0xFFFFFFFF)), reason: type.name);
          expect(c, isNot(const Color(0xFF000000)), reason: type.name);
        }
        expect(tint.from, isNot(tint.to), reason: '${type.name} is tonal');
      }
    });

    test('does not flip with the map theme', () {
      const deepTeal = Color(0xFF0B6E63);
      expect(
        ArtMarkerCubeIconRenderer.faceGlyphTintFor(deepTeal).from,
        ArtMarkerCubeIconRenderer.faceGlyphTintFor(deepTeal).from,
      );
      // A deep colour takes a light glyph whatever the theme.
      expect(
        ArtMarkerCubeIconRenderer.faceGlyphTintFor(deepTeal)
            .from
            .computeLuminance(),
        greaterThan(0.5),
      );
    });
  });

  group('rendered marker face', () {
    Future<({int width, ByteData data})> decode(
      WidgetTester tester,
      Uint8List png,
    ) async {
      late ui.Image image;
      late ByteData data;
      await tester.runAsync(() async {
        image = await decodeImageFromList(png);
        data = (await image.toByteData())!;
      });
      return (width: image.width, data: data);
    }

    Color pixel(({int width, ByteData data}) img, int x, int y) {
      final i = (y * img.width + x) * 4;
      return Color.fromARGB(
        img.data.getUint8(i + 3),
        img.data.getUint8(i),
        img.data.getUint8(i + 1),
        img.data.getUint8(i + 2),
      );
    }

    testWidgets(
        'the body is a tonal field, lighter upper-left than lower-right',
        (tester) async {
      final t = _themeFor(false);
      late Uint8List png;
      await tester.runAsync(() async {
        png = await ArtMarkerCubeIconRenderer.renderMarkerPng(
          baseColor: _subject(ArtMarkerType.artwork, false),
          icon: Icons.auto_awesome,
          tier: ArtMarkerSignal.subtle,
          scheme: t.scheme,
          roles: t.roles,
          isDark: false,
          shape: ArtMapMarkerShape.roundedSquare,
          pixelRatio: 1,
        );
      });
      final img = await decode(tester, png);

      // Two body points well outside the glyph's own extent.
      const cx = ArtMarkerCubeIconRenderer.badgePngWidth / 2;
      const cy = ArtMarkerCubeIconRenderer.badgeBodyCenterY;
      final upperLeft = pixel(img, (cx - 17).round(), (cy - 15).round());
      final lowerRight = pixel(img, (cx + 17).round(), (cy + 15).round());

      expect(upperLeft.a, greaterThan(0.99), reason: 'inside the body');
      expect(lowerRight.a, greaterThan(0.99), reason: 'inside the body');
      expect(
        upperLeft.computeLuminance(),
        greaterThan(lowerRight.computeLuminance()),
        reason: 'a flat fill has no direction',
      );
      // Restrained: still recognisably the category colour.
      expect(
        (upperLeft.computeLuminance() - lowerRight.computeLuminance()).abs(),
        lessThan(0.25),
      );
    });

    testWidgets(
        'the glyph is a cropped ghost in the trailing corner, '
        'not a centred icon', (tester) async {
      final t = _themeFor(false);
      Future<({int width, ByteData data})> render(IconData icon) async {
        late Uint8List png;
        await tester.runAsync(() async {
          png = await ArtMarkerCubeIconRenderer.renderMarkerPng(
            baseColor: _subject(ArtMarkerType.artwork, false),
            icon: icon,
            tier: ArtMarkerSignal.subtle,
            scheme: t.scheme,
            roles: t.roles,
            isDark: false,
            shape: ArtMapMarkerShape.roundedSquare,
            pixelRatio: 1,
          );
        });
        return decode(tester, png);
      }

      await tester.runAsync(QaFontLoader.ensureLoaded);
      if (!QaFontLoader.loadedFamilies.contains('MaterialIcons')) {
        // The icon font comes from the local Flutter SDK cache; without it a
        // glyph paints no ink and there is nothing to locate.
        markTestSkipped('MaterialIcons font unavailable in this environment');
        return;
      }
      // A solid square glyph shows exactly where glyph ink lands.
      final withGlyph = await render(Icons.square);
      final without = await render(const IconData(0));
      const cx = ArtMarkerCubeIconRenderer.badgePngWidth / 2;
      const cy = ArtMarkerCubeIconRenderer.badgeBodyCenterY;
      double diff(int x, int y) {
        final a = pixel(withGlyph, x, y);
        final b = pixel(without, x, y);
        return (a.computeLuminance() - b.computeLuminance()).abs();
      }

      // Ink in the lower-right quadrant, the upper-left left to the field.
      expect(diff((cx + 12).round(), (cy + 12).round()), greaterThan(0.03));
      expect(diff((cx - 15).round(), (cy - 15).round()), lessThan(0.02));
    });

    testWidgets(
        'a mixed cluster renders without throwing and differs from a '
        'homogeneous one', (tester) async {
      final t = _themeFor(false);
      ClusterCategoryBadge badge(ArtMarkerType type, int count) =>
          ClusterCategoryBadge(
            shape: ArtMapMarkerShape.forType(type),
            color: _subject(type, false),
            count: count,
            icon: Icons.place,
          );
      late Uint8List single;
      late Uint8List mixed;
      await tester.runAsync(() async {
        single = await ArtMarkerCubeIconRenderer.renderClusterPng(
          count: 9,
          baseColor: _subject(ArtMarkerType.artwork, false),
          scheme: t.scheme,
          isDark: false,
          categories: [badge(ArtMarkerType.artwork, 9)],
          pixelRatio: 1,
        );
        mixed = await ArtMarkerCubeIconRenderer.renderClusterPng(
          count: 9,
          baseColor: _subject(ArtMarkerType.artwork, false),
          scheme: t.scheme,
          isDark: false,
          categories: [
            badge(ArtMarkerType.artwork, 5),
            badge(ArtMarkerType.streetArt, 3),
            badge(ArtMarkerType.institution, 1),
          ],
          pixelRatio: 1,
        );
      });
      expect(single, isNotEmpty);
      expect(mixed, isNotEmpty);
      expect(mixed, isNot(single));
    });

    for (final dominant in const [
      ArtMarkerType.artwork,
      ArtMarkerType.streetArt,
    ]) {
      testWidgets(
          'a mixed ${dominant.name} cluster fits its canvas: no body or pip '
          'is cut at an edge', (tester) async {
        final t = _themeFor(false);
        ClusterCategoryBadge badge(ArtMarkerType type, int count) =>
            ClusterCategoryBadge(
              shape: ArtMapMarkerShape.forType(type),
              color: _subject(type, false),
              count: count,
              icon: Icons.place,
            );
        final others = ArtMarkerType.values
            .where((type) => type != dominant)
            .take(3)
            .toList();
        late Uint8List png;
        await tester.runAsync(() async {
          png = await ArtMarkerCubeIconRenderer.renderClusterPng(
            count: 9,
            baseColor: _subject(dominant, false),
            scheme: t.scheme,
            isDark: false,
            categories: [
              badge(dominant, 6),
              for (final type in others) badge(type, 1),
            ],
            pixelRatio: 1,
          );
        });
        final img = await decode(tester, png);
        final height = img.data.lengthInBytes ~/ (img.width * 4);
        double edgeAlpha(int x) {
          var peak = 0.0;
          for (var y = 0; y < height; y++) {
            peak = math.max(peak, pixel(img, x, y).a);
          }
          return peak;
        }

        // Opaque shapes stop short of both side edges; only a soft shadow
        // may reach them.
        expect(edgeAlpha(0), lessThan(0.5), reason: 'left edge');
        expect(edgeAlpha(img.width - 1), lessThan(0.5), reason: 'right edge');
      });
    }
  });
}
