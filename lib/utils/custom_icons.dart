import 'package:flutter/material.dart';

/// Custom icon definitions using Material Symbols fonts.
/// These icons are pulled from the Material Symbols Outlined font family.
///
/// IMPORTANT: pubspec.yaml bundles a SUBSET of the Material Symbols Outlined
/// font (assets/fonts/MaterialSymbolsOutlined-subset.ttf, ~4 KB) that contains
/// ONLY the codepoints listed below — the full variable font is ~10.4 MB and is
/// kept out of the build. When you add a new icon here, regenerate the subset
/// from the full source font and add the new codepoint, e.g.:
///
/// ```
/// python -m fontTools.subset \
///   "assets/fonts/MaterialSymbolsOutlined-VariableFont_FILL,GRAD,opsz,wght.ttf" \
///   --unicodes=EFCB,F345,NEW_CODEPOINT \
///   --output-file="assets/fonts/MaterialSymbolsOutlined-subset.ttf"
/// ```
///
/// Used codepoints: U+EFCB (wallArt), U+F345 (fragrance).
class CustomIcons {
  CustomIcons._(); // This class is not meant to be instantiated.

  // Material Symbols Outlined Font
  static const String _fontFamily = 'Material Symbols Outlined';

  /// Wall Art icon (exhibition marker) from Material Symbols Outlined
  /// Unicode codepoint: 0xEFCB
  static const IconData wallArt = IconData(
    0xEFCB,
    fontFamily: _fontFamily,
  );

  /// Fragrance icon (street/public art marker) from Material Symbols Outlined
  /// Unicode codepoint: 0xF345
  static const IconData fragrance = IconData(
    0xF345,
    fontFamily: _fontFamily,
  );
}
