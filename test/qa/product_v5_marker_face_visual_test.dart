import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:art_kubus/features/map/shared/map_screen_shared_helpers.dart';
import 'package:art_kubus/models/art_marker.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/utils/app_color_utils.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/art_marker_cube.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/qa_font_loader.dart';

/// Map marker face evidence (final 0.8.0 hardening): every category silhouette
/// at rest, selected, with a cover, and as homogeneous and mixed clusters, on a
/// light and a dark ground. The renderer is the production one; the "photo" is a
/// generated fixture.
///
/// ```
/// KUBUS_RUN_VISUAL_QA=1 QA_LABEL=after flutter test test/qa/product_v5_marker_face_visual_test.dart
/// ```
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  if (Platform.environment['KUBUS_RUN_VISUAL_QA'] != '1') {
    test('visual QA is opt-in', () {},
        skip: 'Set KUBUS_RUN_VISUAL_QA=1 to generate screenshot evidence.');
    return;
  }

  final label = Platform.environment['QA_LABEL'] ?? 'after';
  final outputDir = Directory('output/qa/final-hardening/$label');

  setUpAll(() async {
    await QaFontLoader.ensureLoaded();
    outputDir.createSync(recursive: true);
  });

  for (final brightness in Brightness.values) {
    testWidgets('marker sheet ${brightness.name}', (tester) async {
      tester.view.physicalSize = const Size(1000, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final isDark = brightness == Brightness.dark;
      final themes = ThemeProvider();
      final theme = isDark ? themes.darkTheme : themes.lightTheme;
      final scheme = theme.colorScheme;
      final roles = theme.extension<KubusColorRoles>()!;

      Color colorFor(ArtMarkerType type) => AppColorUtils.markerSubjectColor(
            markerType: type.name,
            metadata: null,
            scheme: scheme,
            roles: roles,
          );

      final rest = <ArtMarkerType, ui.Image>{};
      final selected = <ArtMarkerType, ui.Image>{};
      final cover = <ArtMarkerType, ui.Image>{};
      final clusters = <String, ui.Image>{};

      await tester.runAsync(() async {
        final photo = await _fixturePhoto();
        for (final type in ArtMarkerType.values) {
          final icon = KubusMapMarkerHelpers.resolveArtMarkerIcon(type);
          final shape = ArtMapMarkerShape.forType(type);
          final base = colorFor(type);
          Future<Uint8List> marker({bool glow = false}) =>
              ArtMarkerCubeIconRenderer.renderMarkerPng(
                baseColor: base,
                icon: icon,
                tier: ArtMarkerSignal.subtle,
                scheme: scheme,
                roles: roles,
                isDark: isDark,
                shape: shape,
                forceGlow: glow,
                pixelRatio: 3,
              );
          rest[type] = await decodeImageFromList(await marker());
          selected[type] = await decodeImageFromList(await marker(glow: true));
          cover[type] = await decodeImageFromList(
              await ArtMarkerCubeIconRenderer.renderCoverMarkerPng(
            cover: photo,
            baseColor: base,
            tier: ArtMarkerSignal.subtle,
            scheme: scheme,
            roles: roles,
            isDark: isDark,
            shape: shape,
            pixelRatio: 3,
          ));
        }

        ClusterCategoryBadge badge(ArtMarkerType type, int count) =>
            ClusterCategoryBadge(
              shape: ArtMapMarkerShape.forType(type),
              color: colorFor(type),
              count: count,
              icon: KubusMapMarkerHelpers.resolveArtMarkerIcon(type),
            );

        clusters['artwork x12'] = await decodeImageFromList(
            await ArtMarkerCubeIconRenderer.renderClusterPng(
          count: 12,
          baseColor: colorFor(ArtMarkerType.artwork),
          scheme: scheme,
          isDark: isDark,
          categories: [badge(ArtMarkerType.artwork, 12)],
          pixelRatio: 3,
        ));
        clusters['street art x4'] = await decodeImageFromList(
            await ArtMarkerCubeIconRenderer.renderClusterPng(
          count: 4,
          baseColor: colorFor(ArtMarkerType.streetArt),
          scheme: scheme,
          isDark: isDark,
          categories: [badge(ArtMarkerType.streetArt, 4)],
          pixelRatio: 3,
        ));
        clusters['institution x3'] = await decodeImageFromList(
            await ArtMarkerCubeIconRenderer.renderClusterPng(
          count: 3,
          baseColor: colorFor(ArtMarkerType.institution),
          scheme: scheme,
          isDark: isDark,
          categories: [badge(ArtMarkerType.institution, 3)],
          pixelRatio: 3,
        ));
        clusters['mixed x9'] = await decodeImageFromList(
            await ArtMarkerCubeIconRenderer.renderClusterPng(
          count: 9,
          baseColor: colorFor(ArtMarkerType.artwork),
          scheme: scheme,
          isDark: isDark,
          categories: [
            badge(ArtMarkerType.artwork, 5),
            badge(ArtMarkerType.streetArt, 3),
            badge(ArtMarkerType.institution, 1),
          ],
          pixelRatio: 3,
        ));
      });

      Widget cell(ui.Image? image) => SizedBox(
            width: 96,
            height: 124,
            child: image == null
                ? const SizedBox.shrink()
                : RawImage(image: image, fit: BoxFit.contain),
          );

      Widget row(String title, Map<ArtMarkerType, ui.Image> images) => Row(
            children: [
              SizedBox(
                width: 70,
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
              for (final type in ArtMarkerType.values) cell(images[type]),
            ],
          );

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: Scaffold(
            backgroundColor:
                isDark ? const Color(0xFF11161A) : const Color(0xFFE9E7E0),
            body: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ArtMarkerType.values.map((t) => t.name).join('   '),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                  row('rest', rest),
                  row('selected', selected),
                  row('cover', cover),
                  Row(
                    children: [
                      SizedBox(
                        width: 70,
                        child: Text(
                          'clusters',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                      for (final entry in clusters.entries) cell(entry.value),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      final boundary = tester.binding.rootElement!.renderObject!;
      final layer = boundary.debugLayer! as OffsetLayer;
      late final List<int> bytes;
      await tester.runAsync(() async {
        final image = await layer.toImage(boundary.paintBounds);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        bytes = data!.buffer.asUint8List();
        image.dispose();
      });
      File('${outputDir.path}/marker-sheet-${brightness.name}.png')
          .writeAsBytesSync(bytes);
    });
  }
}

/// A generated stand-in for artwork photography: a warm sky-to-ground gradient
/// with a few shapes, so a clipped cover is recognisable inside its silhouette.
Future<ui.Image> _fixturePhoto() async {
  const size = 240.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, size, size),
    Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        const Offset(0, size),
        const <Color>[Color(0xFFF2C58B), Color(0xFF9C4B3D), Color(0xFF2F2A3B)],
        const <double>[0, 0.55, 1],
      ),
  );
  canvas.drawCircle(
      const Offset(150, 80), 38, Paint()..color = const Color(0xFFFFF1D0));
  canvas.drawRect(
    const Rect.fromLTWH(30, 130, 70, 110),
    Paint()..color = const Color(0xFF1F1B2B),
  );
  canvas.drawRect(
    const Rect.fromLTWH(120, 150, 90, 90),
    Paint()..color = const Color(0xFF3A2F45),
  );
  final picture = recorder.endRecording();
  return picture.toImage(size.toInt(), size.toInt());
}
