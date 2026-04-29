# Kubus Design System Colors

This folder contains all official Kubus design system colors exported as SVG swatches.

## Files

- **color_*.svg** - Individual color swatches (one file per color)
- **palette_index.svg** - Complete color palette grid for reference
- **kubus_colors.csv** - Machine-readable color definitions with contrast ratios

## Total Colors: 49

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
