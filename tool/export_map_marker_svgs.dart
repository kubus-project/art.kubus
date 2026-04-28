import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:art_kubus/models/art_marker.dart';
import 'package:art_kubus/utils/app_color_utils.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/utils/map_marker_icon_ids.dart';
import 'package:art_kubus/widgets/art_marker_cube.dart';
import 'package:flutter/material.dart';

/// Exports all MapLibre marker/cluster images used by the app as standalone SVG
/// files (SVG wrappers embedding PNG image data).
///
/// Why embed PNG?
/// - The app renders marker icons to PNG at runtime via `dart:ui`.
/// - Many inner glyphs come from Material Icons fonts; converting those glyphs
///   to pure vector paths without font files is non-trivial.
/// - Embedding the rendered PNG preserves 1:1 visual parity with the app.
///
/// Output:
/// - `assets/markers/svg/*.svg`
/// - `assets/markers/manifest.json`
/// - `assets/markers/README.md`
///
/// Run (engine-backed; required for `dart:ui`):
///   # PowerShell
///   $env:KUBUS_EXPORT_MARKERS='1'; flutter test test/tools/export_map_marker_svgs_test.dart
///
/// Why not `flutter pub run`?
/// - `flutter pub run` executes on the standalone Dart VM (no `dart:ui`),
///   which makes the Flutter framework types like `Size`, `Offset`, etc.
///   appear missing at compile time.
///
/// Optional args:
///   --pixel-ratio=4
///   --out-dir=assets/markers
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  final options = _ExportOptions.parse(args);

  final outDir = Directory(options.outDir);
  final svgDir = Directory(p.join(outDir.path, 'svg'));

  if (!svgDir.existsSync()) {
    svgDir.createSync(recursive: true);
  }

  final schemeLight = ColorScheme.fromSeed(
    seedColor: KubusColors.accentTealLight,
    brightness: Brightness.light,
  );
  final schemeDark = ColorScheme.fromSeed(
    seedColor: KubusColors.accentTealDark,
    brightness: Brightness.dark,
  );

  final exportItems = <Map<String, Object?>>[];

  final markerTypes = ArtMarkerType.values;
  final tiers = ArtMarkerSignal.values;

  // Render all marker variants.
  for (final isDark in <bool>[false, true]) {
    final scheme = isDark ? schemeDark : schemeLight;
    final roles = isDark ? KubusColorRoles.dark : KubusColorRoles.light;

    for (final type in markerTypes) {
      final typeName = type.name;
      final baseColor = AppColorUtils.markerSubjectColor(
        markerType: typeName,
        metadata: null,
        scheme: scheme,
        roles: roles,
      );
      final icon = AppColorUtils.markerSubjectIcon(typeName);

      for (final tier in tiers) {
        for (final promoted in <bool>[false, true]) {
          final baseId = MapMarkerIconIds.markerBase(
            typeName: typeName,
            tierName: tier.name,
            isDark: isDark,
            promoted: promoted,
          );
          final selectedId = MapMarkerIconIds.markerSelected(
            typeName: typeName,
            tierName: tier.name,
            isDark: isDark,
            promoted: promoted,
          );

          // Base icon.
          await _writeMarkerSvg(
            svgDir: svgDir,
            iconId: baseId,
            bytes: await ArtMarkerCubeIconRenderer.renderMarkerPng(
              baseColor: baseColor,
              icon: icon,
              tier: tier,
              scheme: scheme,
              roles: roles,
              isDark: isDark,
              forceGlow: false,
              showPromotionStar: promoted,
              pixelRatio: options.pixelRatio,
            ),
            pixelRatio: options.pixelRatio,
          );
          exportItems.add(<String, Object?>{
            'kind': 'marker',
            'state': 'base',
            'iconId': baseId,
            'markerType': typeName,
            'tier': tier.name,
            'theme': isDark ? 'dark' : 'light',
            'promoted': promoted,
            'pixelRatio': options.pixelRatio,
            'logicalSize': <String, Object?>{'w': CubeMarkerTokens.pngWidth, 'h': CubeMarkerTokens.pngWidth},
          });

          // Selected icon (force glow).
          await _writeMarkerSvg(
            svgDir: svgDir,
            iconId: selectedId,
            bytes: await ArtMarkerCubeIconRenderer.renderMarkerPng(
              baseColor: baseColor,
              icon: icon,
              tier: tier,
              scheme: scheme,
              roles: roles,
              isDark: isDark,
              forceGlow: true,
              showPromotionStar: promoted,
              pixelRatio: options.pixelRatio,
            ),
            pixelRatio: options.pixelRatio,
          );
          exportItems.add(<String, Object?>{
            'kind': 'marker',
            'state': 'selected',
            'iconId': selectedId,
            'markerType': typeName,
            'tier': tier.name,
            'theme': isDark ? 'dark' : 'light',
            'promoted': promoted,
            'pixelRatio': options.pixelRatio,
            'logicalSize': <String, Object?>{'w': CubeMarkerTokens.pngWidth, 'h': CubeMarkerTokens.pngWidth},
          });
        }
      }
    }
  }

  // Render a representative set of cluster labels (the runtime can generate
  // many labels; these cover the main visual cases including 99+).
  const clusterCounts = <int>[2, 3, 4, 5, 10, 25, 99, 100];

  for (final isDark in <bool>[false, true]) {
    final scheme = isDark ? schemeDark : schemeLight;
    final roles = isDark ? KubusColorRoles.dark : KubusColorRoles.light;

    for (final type in markerTypes) {
      final typeName = type.name;
      final baseColor = AppColorUtils.markerSubjectColor(
        markerType: typeName,
        metadata: null,
        scheme: scheme,
        roles: roles,
      );

      for (final count in clusterCounts) {
        final label = count > 99 ? '99+' : '$count';
        final iconId = MapMarkerIconIds.cluster(
          typeName: typeName,
          label: label,
          isDark: isDark,
        );

        await _writeMarkerSvg(
          svgDir: svgDir,
          iconId: iconId,
          bytes: await ArtMarkerCubeIconRenderer.renderClusterPng(
            count: count,
            baseColor: baseColor,
            scheme: scheme,
            isDark: isDark,
            pixelRatio: options.pixelRatio,
            // Avoid google_fonts runtime fetching for headless/offline exports.
            // The app uses `KubusTextStyles.badgeCount` (Inter); for marketing
            // exports we accept the platform's default fallback font.
            labelStyleOverride: const TextStyle(
              fontSize: KubusSizes.badgeCountFontSize,
              fontWeight: FontWeight.w700,
            ),
          ),
          pixelRatio: options.pixelRatio,
        );

        exportItems.add(<String, Object?>{
          'kind': 'cluster',
          'iconId': iconId,
          'markerType': typeName,
          'count': count,
          'label': label,
          'theme': isDark ? 'dark' : 'light',
          'pixelRatio': options.pixelRatio,
          'logicalSize': <String, Object?>{'w': CubeMarkerTokens.pngWidth, 'h': CubeMarkerTokens.pngWidth},
        });
      }
    }
  }

  final manifestFile = File(p.join(outDir.path, 'manifest.json'));
  final encoder = const JsonEncoder.withIndent('  ');
  await manifestFile.writeAsString(
    '${encoder.convert(<String, Object?>{
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'pixelRatio': options.pixelRatio,
      'items': exportItems,
      'notes': <String>[
        'SVGs embed PNG image data rendered by ArtMarkerCubeIconRenderer for visual parity with the app.',
        'Cluster icons are exported for representative labels: 2,3,4,5,10,25,99,99+ (count=100). Runtime can generate more labels.',
      ],
    })}\n',
  );

  final readmeFile = File(p.join(outDir.path, 'README.md'));
  await readmeFile.writeAsString(_readmeText(pixelRatio: options.pixelRatio));

  stdout.writeln(
    'Exported ${exportItems.length} SVGs to ${svgDir.path} (pixelRatio=${options.pixelRatio}).',
  );
}

Future<void> _writeMarkerSvg({
  required Directory svgDir,
  required String iconId,
  required Uint8List bytes,
  required double pixelRatio,
}) async {
  final pngBase64 = base64Encode(bytes);

  final logicalW = CubeMarkerTokens.pngWidth;
  final logicalH = CubeMarkerTokens.pngWidth;
  final pxW = (logicalW * pixelRatio).round();
  final pxH = (logicalH * pixelRatio).round();

  final svg = _svgWithEmbeddedPng(
    width: pxW,
    height: pxH,
    pngBase64: pngBase64,
  );

  final file = File(p.join(svgDir.path, '$iconId.svg'));
  await file.writeAsString(svg);
}

String _svgWithEmbeddedPng({
  required int width,
  required int height,
  required String pngBase64,
}) {
  // Note: keep it minimal so tools like Figma import it cleanly, but include
  // SVG 1.1-compatible `xlink:href` for Adobe/Illustrator.
  final dataUri = 'data:image/png;base64,$pngBase64';
  return '<?xml version="1.0" encoding="UTF-8"?>\n'
      '<svg xmlns="http://www.w3.org/2000/svg" '
      'xmlns:xlink="http://www.w3.org/1999/xlink" '
      'width="$width" height="$height" viewBox="0 0 $width $height">\n'
      '  <image x="0" y="0" width="$width" height="$height" href="$dataUri" xlink:href="$dataUri" />\n'
      '</svg>\n';
}

String _readmeText({required double pixelRatio}) {
  return '''# Map marker SVG exports\n\nThis folder contains **SVG files for all map marker icons** used by the app.\n\n## What these are\n\nThe in-app map markers are rendered at runtime into PNGs via `ArtMarkerCubeIconRenderer` (`lib/widgets/art_marker_cube.dart`) and registered with MapLibre using `addImage(...)`.\n\nTo keep **pixel-perfect parity** with the app, the exported SVGs are *wrappers* that embed the rendered PNG image data (base64).\n\n## Where the files are\n\n- `assets/markers/svg/*.svg` — one SVG per MapLibre icon id (e.g. `mk_artwork_active_l_std.svg`)\n- `assets/markers/manifest.json` — machine-readable list of all exported icons\n\n## Naming\n\nThe filenames match the MapLibre image IDs generated by `MapMarkerIconIds` (`lib/utils/map_marker_icon_ids.dart`):\n\n- Marker icons:\n  - `mk_<type>_<tier>_<l|d>_<std|pro>.svg`\n  - `mk_<type>_<tier>_sel_<l|d>_<std|pro>.svg`\n- Cluster icons (representative set):\n  - `cl_<type>_<label>_<l|d>.svg`\n\n## Notes for designers\n\n- The exported icons are generated with `pixelRatio=$pixelRatio` to improve sharpness.\n- The SVGs embed PNG data URIs (not external links). For Adobe tools, the `<image>` tag includes both `href` and SVG 1.1 `xlink:href` for compatibility.\n- These are not “pure vector” icons (because the source-of-truth is a PNG renderer and inner glyphs come from icon fonts). If you want a fully vector-native design-system variant, we should introduce dedicated SVG sources for the marker body + icon glyphs and update the renderer to use them.\n''';
}

class _ExportOptions {
  const _ExportOptions({
    required this.outDir,
    required this.pixelRatio,
  });

  final String outDir;
  final double pixelRatio;

  static _ExportOptions parse(List<String> args) {
    var outDir = 'assets/markers';
    var pixelRatio = 4.0;

    for (final arg in args) {
      if (arg.startsWith('--out-dir=')) {
        outDir = arg.substring('--out-dir='.length).trim();
        continue;
      }
      if (arg.startsWith('--pixel-ratio=')) {
        final raw = arg.substring('--pixel-ratio='.length).trim();
        final parsed = double.tryParse(raw);
        if (parsed != null && parsed.isFinite && parsed > 0) {
          pixelRatio = parsed;
        }
      }
    }

    return _ExportOptions(outDir: outDir, pixelRatio: pixelRatio);
  }
}

/// Minimal path join helper (avoids bringing in extra deps in a tool script).
class p {
  static String join(String a, String b) {
    if (a.isEmpty) return b;
    if (b.isEmpty) return a;
    final sep = Platform.pathSeparator;
    final left = a.endsWith(sep) ? a.substring(0, a.length - 1) : a;
    final right = b.startsWith(sep) ? b.substring(1) : b;
    return '$left$sep$right';
  }
}
