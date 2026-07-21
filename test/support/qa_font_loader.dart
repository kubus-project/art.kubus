import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads real text + icon fonts so QA captures show readable glyphs instead of
/// the `flutter test` placeholder boxes.
///
/// Fonts come from the pinned Flutter SDK's `material_fonts` artifact cache and
/// from the repository's checked-in Material Symbols subset, so no network
/// access is involved and every run is deterministic.
///
/// `GoogleFonts.inter(...)` resolves to family `Inter` at runtime; in a test
/// process the Google Fonts asset is unavailable, so Roboto is registered under
/// that family name too. Metrics differ slightly from shipped Inter, which is
/// noted in the QA report — layout structure, wrapping and clipping are still
/// faithfully represented.
class QaFontLoader {
  QaFontLoader._();

  static bool _loaded = false;

  /// Font families registered for a capture run, reported alongside the images.
  static final List<String> loadedFamilies = <String>[];

  static Future<void> ensureLoaded() async {
    if (_loaded) return;

    final robotoRegular = _sdkFont('roboto-regular.ttf');
    final robotoMedium = _sdkFont('roboto-medium.ttf');
    final robotoBold = _sdkFont('roboto-bold.ttf');

    if (robotoRegular != null) {
      // `google_fonts` resolves e.g. `GoogleFonts.inter(fontWeight: w600)` to
      // the family name `Inter_600` (weight 400 becomes `Inter_regular`), with
      // the bare family as a fallback. Register a real face under every one of
      // those names so no text falls back to the placeholder box font.
      for (final base in const ['Inter', 'Outfit']) {
        for (final variant in const [
          'regular',
          '100',
          '200',
          '300',
          '500',
          '600',
          '700',
          '800',
          '900',
        ]) {
          final weightFile = switch (variant) {
            '600' || '700' || '800' || '900' => robotoBold ?? robotoRegular,
            '500' => robotoMedium ?? robotoRegular,
            _ => robotoRegular,
          };
          final family = '${base}_$variant';
          await (FontLoader(family)..addFont(_bytes(weightFile))).load();
          loadedFamilies.add(family);
        }
        await (FontLoader(base)..addFont(_bytes(robotoRegular))).load();
        loadedFamilies.add(base);
      }

      await (FontLoader('Roboto')..addFont(_bytes(robotoRegular))).load();
      loadedFamilies.add('Roboto');
    }

    final materialIcons = _sdkFont('materialicons-regular.otf');
    if (materialIcons != null) {
      await (FontLoader('MaterialIcons')..addFont(_bytes(materialIcons)))
          .load();
      loadedFamilies.add('MaterialIcons');
    }

    const symbolsAsset = 'assets/fonts/MaterialSymbolsOutlined-subset.ttf';
    if (File(symbolsAsset).existsSync()) {
      await (FontLoader('Material Symbols Outlined')
            ..addFont(_bytes(File(symbolsAsset))))
          .load();
      loadedFamilies.add('Material Symbols Outlined');
    }

    _loaded = true;
  }

  static Future<ByteData> _bytes(File file) async {
    final bytes = await file.readAsBytes();
    return ByteData.view(Uint8List.fromList(bytes).buffer);
  }

  static File? _sdkFont(String name) {
    final root = Platform.environment['FLUTTER_ROOT'];
    if (root == null || root.trim().isEmpty) return null;
    final file = File(
      '${root.replaceAll('\\', '/')}/bin/cache/artifacts/material_fonts/$name',
    );
    return file.existsSync() ? file : null;
  }
}
