import 'dart:io';

/// Export all Kubus design system colors as SVG color swatches.
/// Each swatch includes the color name, hex code, and a visual sample.
///
/// Usage:
///   dart run tool/export_kubus_colors_svgs.dart
///
/// Output: assets/design_system/colors/

const double _swatchWidth = 200.0;
const double _swatchHeight = 120.0;

class ColorDefinition {
  final String name;
  final String hex;
  final int argb;

  ColorDefinition({required this.name, required this.hex, required this.argb});

  int get r => (argb >> 16) & 0xFF;
  int get g => (argb >> 8) & 0xFF;
  int get b => argb & 0xFF;
  int get a => (argb >> 24) & 0xFF;
}

final List<ColorDefinition> _allColors = [
  // Brand Colors
  ColorDefinition(
    name: 'Primary',
    hex: '00838F',
    argb: 0xFF00838F,
  ),
  ColorDefinition(
    name: 'Primary Variant Light',
    hex: '0097A7',
    argb: 0xFF0097A7,
  ),
  ColorDefinition(
    name: 'Primary Variant Dark',
    hex: '00ACC1',
    argb: 0xFF00ACC1,
  ),

  // Glass & Overlay
  ColorDefinition(
    name: 'Glass Light',
    hex: 'FFFFFF',
    argb: 0x99FFFFFF,
  ),
  ColorDefinition(
    name: 'Glass Dark',
    hex: '1A1A1A',
    argb: 0xCC1A1A1A,
  ),
  ColorDefinition(
    name: 'Glass Border Light',
    hex: 'FFFFFF',
    argb: 0x40FFFFFF,
  ),
  ColorDefinition(
    name: 'Glass Border Dark',
    hex: '000000',
    argb: 0x40000000,
  ),

  // Secondary / Accents
  ColorDefinition(
    name: 'Secondary',
    hex: '00838F',
    argb: 0xCC00838F,
  ),

  // Extended Accents
  ColorDefinition(
    name: 'Accent Orange Dark',
    hex: 'FF9800',
    argb: 0xFFFF9800,
  ),
  ColorDefinition(
    name: 'Accent Orange Light',
    hex: 'FB8C00',
    argb: 0xFFFB8C00,
  ),
  ColorDefinition(
    name: 'Accent Teal Dark',
    hex: '4ECDC4',
    argb: 0xFF4ECDC4,
  ),
  ColorDefinition(
    name: 'Accent Teal Light',
    hex: '00897B',
    argb: 0xFF00897B,
  ),
  ColorDefinition(
    name: 'Achievement Gold Dark',
    hex: 'FFD700',
    argb: 0xFFFFD700,
  ),
  ColorDefinition(
    name: 'Achievement Gold Light',
    hex: 'FFC107',
    argb: 0xFFFFC107,
  ),
  ColorDefinition(
    name: 'Accent Blue',
    hex: '2979FF',
    argb: 0xFF2979FF,
  ),

  // Semantic Colors - Error/Red
  ColorDefinition(
    name: 'Error (Red 600)',
    hex: 'E53935',
    argb: 0xFFE53935,
  ),
  ColorDefinition(
    name: 'Error Dark (Coral Red)',
    hex: 'FF6B6B',
    argb: 0xFFFF6B6B,
  ),

  // Semantic Colors - Success/Green
  ColorDefinition(
    name: 'Success (Green 600)',
    hex: '43A047',
    argb: 0xFF43A047,
  ),
  ColorDefinition(
    name: 'Success Dark (Green 500)',
    hex: '4CAF50',
    argb: 0xFF4CAF50,
  ),

  // Semantic Colors - Warning/Amber
  ColorDefinition(
    name: 'Warning (Amber 700)',
    hex: 'FFA000',
    argb: 0xFFFFA000,
  ),
  ColorDefinition(
    name: 'Warning Dark (Amber 600)',
    hex: 'FFB300',
    argb: 0xFFFFB300,
  ),

  // Neutrals - Backgrounds
  ColorDefinition(
    name: 'Background Light',
    hex: 'F8F9FA',
    argb: 0xFFF8F9FA,
  ),
  ColorDefinition(
    name: 'Background Dark',
    hex: '0A0A0A',
    argb: 0xFF0A0A0A,
  ),

  // Neutrals - Surfaces
  ColorDefinition(
    name: 'Surface Light',
    hex: 'FFFFFF',
    argb: 0xFFFFFFFF,
  ),
  ColorDefinition(
    name: 'Surface Dark',
    hex: '1A1A1A',
    argb: 0xFF1A1A1A,
  ),

  // Neutrals - Outline
  ColorDefinition(
    name: 'Outline Light',
    hex: 'E0E0E0',
    argb: 0xFFE0E0E0,
  ),
  ColorDefinition(
    name: 'Outline Dark',
    hex: '424242',
    argb: 0xFF424242,
  ),

  // Text Colors
  ColorDefinition(
    name: 'Text Primary Light',
    hex: '000000',
    argb: 0xFF000000,
  ),
  ColorDefinition(
    name: 'Text Primary Dark',
    hex: 'FFFFFF',
    argb: 0xFFFFFFFF,
  ),
  ColorDefinition(
    name: 'Text Secondary Light',
    hex: '757575',
    argb: 0xFF757575,
  ),
  ColorDefinition(
    name: 'Text Secondary Dark',
    hex: 'B0B0B0',
    argb: 0xFFB0B0B0,
  ),

  // Stat Colors (for analytics/charts)
  ColorDefinition(
    name: 'Stat Teal',
    hex: '4ECDC4',
    argb: 0xFF4ECDC4,
  ),
  ColorDefinition(
    name: 'Stat Coral',
    hex: 'FF6B6B',
    argb: 0xFFFF6B6B,
  ),
  ColorDefinition(
    name: 'Stat Green',
    hex: '4CAF50',
    argb: 0xFF4CAF50,
  ),
  ColorDefinition(
    name: 'Stat Amber',
    hex: 'FFB300',
    argb: 0xFFFFB300,
  ),
  ColorDefinition(
    name: 'Stat Purple',
    hex: '00ACC1',
    argb: 0xFF00ACC1,
  ),
  ColorDefinition(
    name: 'Stat Blue',
    hex: '2979FF',
    argb: 0xFF2979FF,
  ),

  // Action Colors
  ColorDefinition(
    name: 'Like Action',
    hex: 'E53935',
    argb: 0xFFE53935,
  ),
  ColorDefinition(
    name: 'Positive Action',
    hex: '43A047',
    argb: 0xFF43A047,
  ),
  ColorDefinition(
    name: 'Negative Action',
    hex: 'E53935',
    argb: 0xFFE53935,
  ),
  ColorDefinition(
    name: 'Locked Feature',
    hex: 'FB8C00',
    argb: 0xFFFB8C00,
  ),

  // Web3 Hub Accents
  ColorDefinition(
    name: 'Artist Studio Red',
    hex: 'E53935',
    argb: 0xFFE53935,
  ),
  ColorDefinition(
    name: 'DAO Green',
    hex: '43A047',
    argb: 0xFF43A047,
  ),
  ColorDefinition(
    name: 'Institution Blue',
    hex: '2979FF',
    argb: 0xFF2979FF,
  ),
  ColorDefinition(
    name: 'Marketplace Orange',
    hex: 'FB8C00',
    argb: 0xFFFB8C00,
  ),

  // Gradient colors
  ColorDefinition(
    name: 'Dark Background Top',
    hex: '05070A',
    argb: 0xFF05070A,
  ),
  ColorDefinition(
    name: 'Dark Background Bottom',
    hex: '0B1D33',
    argb: 0xFF0B1D33,
  ),
  ColorDefinition(
    name: 'Auth Dark Top',
    hex: '05070A',
    argb: 0xFF05070A,
  ),
  ColorDefinition(
    name: 'Auth Dark Bottom',
    hex: '102A43',
    argb: 0xFF102A43,
  ),
];

void main() async {
  final outDir = Directory('assets/design_system/colors');
  outDir.createSync(recursive: true);

  // Generate individual color swatches
  for (final color in _allColors) {
    final svg = _generateColorSwatch(color);
    final filename = color.name
        .replaceAll(RegExp(r'[^a-z0-9]', caseSensitive: false), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .toLowerCase();
    final file = File('${outDir.path}/color_$filename.svg');
    file.writeAsStringSync(svg, flush: true);
  }

  // Generate a master palette index
  final index = _generatePaletteIndex(_allColors);
  File('${outDir.path}/palette_index.svg').writeAsStringSync(index, flush: true);

  // Generate a CSV export for reference
  final csv = _generateCsv(_allColors);
  File('${outDir.path}/kubus_colors.csv').writeAsStringSync(csv, flush: true);

  // Generate README
  final readme = _generateReadme(_allColors.length);
  File('${outDir.path}/README.md').writeAsStringSync(readme, flush: true);

  stdout.writeln('✓ Exported ${_allColors.length} colors to assets/design_system/colors');
  stdout.writeln('  - Individual swatches: color_*.svg');
  stdout.writeln('  - Master palette: palette_index.svg');
  stdout.writeln('  - CSV export: kubus_colors.csv');
}

String _generateColorSwatch(ColorDefinition color) {
  _isColorDark(color);

  return '''<?xml version="1.0" encoding="utf-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 120" width="200" height="120">
  <!-- Color swatch background -->
  <rect width="200" height="84" fill="#${color.hex}"/>
  <!-- Name and hex on white background -->
  <rect y="84" width="200" height="36" fill="#F5F5F5" stroke="#E0E0E0" stroke-width="1"/>
  <!-- Color name -->
  <text x="8" y="102" font-family="Arial, sans-serif" font-size="14" font-weight="600" fill="#000000" text-anchor="start">${color.name}</text>
  <!-- Hex code -->
  <text x="8" y="116" font-family="monospace" font-size="12" fill="#666666" text-anchor="start">#${color.hex}</text>
</svg>''';
}

String _generatePaletteIndex(List<ColorDefinition> colors) {
  const padding = 16.0;
  const cols = 5;
  final numRows = ((colors.length + cols - 1) / cols).ceil();
  final viewHeight = (numRows * _swatchHeight + (numRows + 1) * padding).toInt();
  final viewWidth = (cols * _swatchWidth + (cols + 1) * padding).toInt();

  final buffer = StringBuffer();
  buffer.writeln('<?xml version="1.0" encoding="utf-8"?>');
  buffer.writeln(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $viewWidth $viewHeight" width="$viewWidth" height="$viewHeight">');
  buffer.writeln('  <!-- Background -->');
  buffer.writeln('  <rect width="$viewWidth" height="$viewHeight" fill="#FFFFFF"/>');

  for (int i = 0; i < colors.length; i++) {
    final color = colors[i];
    final row = i ~/ cols;
    final col = i % cols;
    final x = (col * (_swatchWidth + padding) + padding).toInt();
    final y = (row * (_swatchHeight + padding) + padding).toInt();

    buffer.writeln('  <!-- ${color.name} -->');
    buffer.writeln('  <rect x="$x" y="$y" width="200" '
        'height="84" fill="#${color.hex}"/>');
    buffer.writeln('  <rect x="$x" y="${y + 84}" '
        'width="200" height="36" '
        'fill="#F5F5F5" stroke="#E0E0E0" stroke-width="1"/>');
    buffer.writeln('  <text x="${x + 8}" y="${y + 102}" '
        'font-family="Arial, sans-serif" font-size="14" font-weight="600" '
        'fill="#000000" text-anchor="start">${color.name}</text>');
    buffer.writeln('  <text x="${x + 8}" y="${y + 116}" '
        'font-family="monospace" font-size="12" fill="#666666" '
        'text-anchor="start">#${color.hex}</text>');
  }

  buffer.writeln('</svg>');
  return buffer.toString();
}

String _generateCsv(List<ColorDefinition> colors) {
  final buffer = StringBuffer('Name,Hex Code,ARGB,Light Contrast,Dark Contrast\n');
  final white = ColorDefinition(name: '', hex: 'FFFFFF', argb: 0xFFFFFFFF);
  final black = ColorDefinition(name: '', hex: '000000', argb: 0xFF000000);
  for (final color in colors) {
    final lightContrast = _getContrastRatio(color, white).toStringAsFixed(2);
    final darkContrast = _getContrastRatio(color, black).toStringAsFixed(2);
    buffer.writeln(
        '"${color.name}",#${color.hex},0x${color.argb.toRadixString(16).toUpperCase()},$lightContrast,$darkContrast');
  }
  return buffer.toString();
}

String _generateReadme(int colorCount) {
  return '''# Kubus Design System Colors

This folder contains all official Kubus design system colors exported as SVG swatches.

## Files

- **color_*.svg** - Individual color swatches (one file per color)
- **palette_index.svg** - Complete color palette grid for reference
- **kubus_colors.csv** - Machine-readable color definitions with contrast ratios

## Total Colors: $colorCount

### Categories

- **Brand Colors** - Primary cyan/teal family
- **Glass & Overlay** - Transparency and glass morphism variants
- **Semantic Colors** - Error (red), Success (green), Warning (amber)
- **Neutrals** - Backgrounds, surfaces, and outlines for light/dark modes
- **Text Colors** - Primary and secondary text for accessibility
- **Stat Colors** - Analytics and chart accent colors (teal, coral, green, amber, purple, blue)
- **Action Colors** - Like, positive, negative, and locked feature indicators
- **Web3 Hub Accents** - Specific colors for Artist Studio, DAO, Institutions, Marketplace

## Usage in Design Tools

1. Open individual `color_*.svg` files in Illustrator, Figma, or other design tools
2. Use the hex codes for web/mobile development
3. Reference `palette_index.svg` for a complete color overview
4. Import `kubus_colors.csv` into design tokens systems

## Accessibility Notes

All colors include WCAG contrast ratio calculations (see CSV). Use the contrast
ratios to ensure text readability when layering colors.

## Updating Colors

If you update colors in `lib/utils/design_tokens.dart` (KubusColors), regenerate
these SVGs:

```bash
dart run tool/export_kubus_colors_svgs.dart
```

---

Generated from `lib/utils/design_tokens.dart` and `lib/utils/kubus_color_roles.dart`.
''';
}

bool _isColorDark(ColorDefinition color) {
  final luminance = (0.299 * color.r + 0.587 * color.g + 0.114 * color.b) / 255;
  return luminance < 0.5;
}

double _getContrastRatio(ColorDefinition foreground, ColorDefinition background) {
  final fL = _relativeLuminance(foreground);
  final bL = _relativeLuminance(background);
  final lighter = fL > bL ? fL : bL;
  final darker = fL > bL ? bL : fL;
  return (lighter + 0.05) / (darker + 0.05);
}

double _relativeLuminance(ColorDefinition color) {
  final r = _linearize(color.r / 255.0);
  final g = _linearize(color.g / 255.0);
  final b = _linearize(color.b / 255.0);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double _linearize(double value) {
  if (value <= 0.03928) {
    return value / 12.92;
  }
  return _pow((value + 0.055) / 1.055, 2.4);
}

double _pow(double base, double exponent) {
  double result = 1.0;
  for (int i = 0; i < exponent.toInt(); i++) {
    result *= base;
  }
  return result;
}
