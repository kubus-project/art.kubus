import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/export_map_marker_svgs.dart' as exporter;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final enabled = Platform.environment['KUBUS_EXPORT_MARKERS'] == '1';

  test(
    'exports map marker SVGs for marketing',
    () async {
      // `flutter test` runs with a minimal font set by default. Our marker
      // renderer paints Material icon glyphs via TextPainter; without fonts
      // loaded, those glyphs become tofu rectangles.
      await _ensureIconFontsLoaded();

      // Export into the canonical folder under assets/markers.
      await exporter.main(<String>[
        '--out-dir=assets/markers',
        '--pixel-ratio=4',
      ]);

      final svgDir = Directory('assets/markers/svg');
      expect(svgDir.existsSync(), isTrue);

      // Spot-check a few expected outputs.
      expect(
        File('assets/markers/svg/mk_artwork_subtle_l_std.svg').existsSync(),
        isTrue,
      );
      expect(
        File('assets/markers/svg/mk_streetArt_legendary_sel_d_pro.svg')
            .existsSync(),
        isTrue,
      );
      expect(
        File('assets/markers/svg/cl_event_99+_d.svg').existsSync(),
        isTrue,
      );

      // Verify manifest is parseable and non-empty.
      final manifestFile = File('assets/markers/manifest.json');
      expect(manifestFile.existsSync(), isTrue);
      final manifest = jsonDecode(await manifestFile.readAsString());
      expect(manifest, isA<Map<String, dynamic>>());
      expect((manifest as Map<String, dynamic>)['items'], isA<List<dynamic>>());
      expect(((manifest)['items'] as List).length, greaterThan(100));

      // Debug aid: write a sample PNG into build/ so we can quickly inspect
      // glyph rendering after export without decoding base64 by hand.
      final sampleSvg =
          await File('assets/markers/svg/mk_artwork_subtle_l_std.svg')
              .readAsString();
      final match = RegExp('href="data:image\\/png;base64,([^"]+)"')
          .firstMatch(sampleSvg);
      expect(match, isNotNull);
      final pngBytes = base64Decode(match!.group(1)!);
      final sampleDir = Directory('build/marker_export_samples');
      if (!sampleDir.existsSync()) {
        sampleDir.createSync(recursive: true);
      }
      await File('build/marker_export_samples/mk_artwork_subtle_l_std.png')
          .writeAsBytes(pngBytes, flush: true);
    },
    // Prevent side-effectful exports on normal `flutter test` runs.
    skip: enabled
        ? false
        : 'Set KUBUS_EXPORT_MARKERS=1 to enable the export test.',
  );
}

bool _iconFontsLoaded = false;

Future<void> _ensureIconFontsLoaded() async {
  if (_iconFontsLoaded) return;

  await _loadFontFamilyIfAvailable(
    family: 'MaterialIcons',
    required: true,
    assetCandidates: const <String>[
      // Package asset path (preferred when available).
      'packages/flutter/lib/src/material/fonts/MaterialIcons-Regular.otf',
      'packages/flutter/lib/src/material/fonts/MaterialIcons-Regular.ttf',
    ],
    fileCandidates: _flutterRootFileCandidates(
      relativePaths: const <String>[
        'bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
        'bin/cache/artifacts/material_fonts/MaterialIcons-Regular.ttf',
      ],
    ),
  );

  // Optional: used only as a fallback in some TextStyle stacks.
  await _loadFontFamilyIfAvailable(
    family: 'Material Symbols Outlined',
    required: false,
    assetCandidates: const <String>[
      'packages/flutter/lib/src/material/fonts/MaterialSymbolsOutlined.ttf',
      'packages/flutter/lib/src/material/fonts/MaterialSymbolsOutlined.otf',
    ],
    fileCandidates: _flutterRootFileCandidates(
      relativePaths: const <String>[
        'bin/cache/artifacts/material_fonts/MaterialSymbolsOutlined.ttf',
        'bin/cache/artifacts/material_fonts/MaterialSymbolsOutlined.otf',
      ],
    ),
  );

  _iconFontsLoaded = true;
}

List<String> _flutterRootFileCandidates({required List<String> relativePaths}) {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null || root.trim().isEmpty) return const <String>[];
  final normalizedRoot = root.replaceAll('\\', '/');
  return relativePaths
      .map((p) => '$normalizedRoot/${p.replaceAll('\\', '/')}')
      .toList(growable: false);
}

Future<void> _loadFontFamilyIfAvailable({
  required String family,
  required bool required,
  required List<String> assetCandidates,
  required List<String> fileCandidates,
}) async {
  Future<ByteData>? fontDataFuture;

  // Try as an asset first (works when Flutter exposes these in the test bundle).
  for (final assetPath in assetCandidates) {
    try {
      fontDataFuture = rootBundle.load(assetPath);
      // Verify it resolves now to avoid deferring a failure into FontLoader.load.
      await fontDataFuture;
      break;
    } catch (_) {
      fontDataFuture = null;
    }
  }

  // Fall back to reading from the local Flutter SDK if available.
  if (fontDataFuture == null) {
    for (final filePath in fileCandidates) {
      final file = File(filePath);
      if (!file.existsSync()) continue;
      final bytes = await file.readAsBytes();
      final data = ByteData.view(Uint8List.fromList(bytes).buffer);
      fontDataFuture = Future<ByteData>.value(data);
      break;
    }
  }

  if (fontDataFuture == null) {
    if (!required) return;
    throw StateError(
      'Required font family "$family" could not be loaded. Without it, '
      'IconData glyphs will render as tofu rectangles during export. '
      'Tried assets: ${assetCandidates.join(', ')} | '
      'Tried files: ${fileCandidates.join(', ')}',
    );
  }

  final loader = FontLoader(family)..addFont(fontDataFuture);
  await loader.load();
}
