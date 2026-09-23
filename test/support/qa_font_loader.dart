import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads real text + icon fonts so QA captures show readable glyphs instead of
/// the `flutter test` placeholder boxes.
///
/// Sofia Sans and Space Mono are loaded from the same checked-in local font
/// assets used by Flutter builds. Outfit remains a map-attribution compatibility
/// face and is represented by Roboto in tests because it is not PRODUCT text.
class QaFontLoader {
  QaFontLoader._();

  static bool _loaded = false;

  /// Font families registered for a capture run, reported alongside the images.
  static final List<String> loadedFamilies = <String>[];

  static Future<void> ensureLoaded() async {
    if (_loaded) return;

    final sofia =
        File('assets/fonts/product-v5/sofia-sans/SofiaSans-Variable.ttf');
    if (sofia.existsSync()) {
      await (FontLoader('Sofia Sans')..addFont(_bytes(sofia))).load();
      loadedFamilies.add('Sofia Sans');
    }

    final spaceMonoRegular =
        File('assets/fonts/product-v5/space-mono/SpaceMono-Regular.ttf');
    final spaceMonoBold =
        File('assets/fonts/product-v5/space-mono/SpaceMono-Bold.ttf');
    if (spaceMonoRegular.existsSync() && spaceMonoBold.existsSync()) {
      final loader = FontLoader('Space Mono')
        ..addFont(_bytes(spaceMonoRegular))
        ..addFont(_bytes(spaceMonoBold));
      await loader.load();
      loadedFamilies.add('Space Mono');
    }

    final robotoRegular = _sdkFont('roboto-regular.ttf');
    final robotoMedium = _sdkFont('roboto-medium.ttf');
    final robotoBold = _sdkFont('roboto-bold.ttf');

    if (robotoRegular != null) {
      // Outfit's one remaining helper is reserved for map attribution.
      for (final base in const ['Outfit']) {
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
