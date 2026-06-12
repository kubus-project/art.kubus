import 'package:flutter/material.dart';

/// Custom icon definitions using Material Symbols fonts.
/// These icons are pulled from the Material Symbols Outlined font family.
class CustomIcons {
  CustomIcons._(); // This class is not meant to be instantiated.

  // Material Symbols Outlined Font
  static const String _fontFamily = 'Material Symbols Outlined';

  /// Wall Art icon (exhibition marker) from Material Symbols Outlined
  /// Unicode codepoint: 0xE3F5
  static const IconData wallArt = IconData(
    0xE3F5,
    fontFamily: _fontFamily,
  );
}
