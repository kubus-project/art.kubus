import 'dart:io';
import 'dart:convert';

/// Simple utility to fetch Material icon SVGs from the official
/// material-design-icons repository and compose editable marker SVGs.
///
/// Usage:
///   dart run tool/export_map_marker_vector_svgs.dart
//
/// This script is intentionally minimal and has no external package deps so
/// it can run with the Dart SDK that ships with Flutter. It attempts to
/// download the 24px production SVG for each icon and embeds the path data
/// into a marker-shaped SVG (rounded square + centered icon).

const _repoRawBase =
    'https://raw.githubusercontent.com/google/material-design-icons/main/';

final Map<String, List<String>> _iconSources = {
  // key -> list of candidate paths (first successful match wins)
  'artist_studio_palette': [
    'src/image/palette/materialicons/24px.svg',
  ],
  'community_people': [
    'src/social/people/materialicons/24px.svg',
  ],
  'governance_gavel': [
    // Try outlined variants and other governance icons
    'src/action/gavel/materialiconsoutlined/24px.svg',
    'src/action/gavel/materialiconssharp/24px.svg',
    'src/action/gavel/materialicons/24px.svg',
    'src/action/how_to_vote/materialicons/24px.svg',
    'src/action/how_to_vote/materialiconsoutlined/24px.svg',
    'src/action/how_to_vote/materialiconssharp/24px.svg',
  ],
  'institution_museum': [
    'src/maps/museum/materialicons/24px.svg',
  ],
};

void main(List<String> args) async {
  final outDir = Directory('assets/markers/svg/vector');
  outDir.createSync(recursive: true);

  for (final entry in _iconSources.entries) {
    final name = entry.key;
    final candidates = entry.value;
    var success = false;

    for (final relPath in candidates) {
      final url = '$_repoRawBase$relPath';
      stdout.writeln('Fetching $url');

      try {
        final svgText = await _httpGetUtf8(url);
        final paths = _extractPathData(svgText);
        if (paths.isEmpty) {
          stdout.writeln('  No usable paths found; trying next candidate...');
          continue;
        }

        final composed = _composeMarkerSvg(paths, name);
        final outFile = File('${outDir.path}/mk_${name}_vector.svg');
        outFile.writeAsStringSync(composed, flush: true);
        stdout.writeln('  ✓ Wrote ${outFile.path}');
        success = true;
        break;
      } catch (e) {
        stdout.writeln('  Failed: $e; trying next candidate...');
      }
    }

    if (!success) {
      stderr.writeln('✗ Could not generate vector for $name');
    }
  }

  stdout.writeln('Done. Vector SVGs are in assets/markers/svg/vector');
}

Future<String> _httpGetUtf8(String url) async {
  final uri = Uri.parse(url);
  final client = HttpClient();
  try {
    final request = await client.getUrl(uri);
    final response = await request.close();
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode} for $url');
    }
    return await utf8.decoder.bind(response).join();
  } finally {
    client.close(force: true);
  }
}

List<String> _extractPathData(String svgText) {
  // Very small, forgiving parser: capture all path d="..." attributes.
  final reg = RegExp(r'<path[^>]*d="([^"]+)"', multiLine: true);
  final allPaths = reg.allMatches(svgText).map((m) => m.group(1)!).toList(growable: false);

  // Filter out common background/viewBox rectangles that render as white squares:
  // - Paths that match the 24x24 viewBox boundary (M0 0... h24 v24 H0 Z variations)
  return allPaths.where((p) {
    final trimmed = p.replaceAll(RegExp(r'\s+'), ' ').toLowerCase().trim();
    // Skip empty, whitespace-only, or viewBox background paths
    if (trimmed.isEmpty) return false;
    if (trimmed == 'm0 0h24v24h0z' || trimmed == 'm0 0h24v24h0v0z') return false;
    // Also skip paths that are just the viewBox frame (start at origin, match 24x24)
    if (RegExp(r'^m0\s*0[^m]*[hv]\s*24[^m]*[hv]\s*24[^m]*[hv]\s*0').hasMatch(trimmed)) {
      return false;
    }
    return true;
  }).toList(growable: false);
}

String _composeMarkerSvg(List<String> paths, String name) {
  // Sizes mirrored from app tokens.
  const double viewW = 56.0;
  const double viewH = 56.0;
  const double squareSize = 46.0; // CubeMarkerTokens.staticSizeAtZoom15
  const double cornerRadius = 8.0;

  // icon target size is squareSize * 0.54 (same scale used by Paint code).
  final iconTargetPx = squareSize * 0.54;
  final sourceIconPx = 24.0; // material icon source is 24px
  final iconScale = iconTargetPx / sourceIconPx;

  // center translation (we will translate icon coordinates which are 24x24)
  final cx = viewW / 2.0;
  final cy = viewH / 2.0;

  final bgX = (viewW - squareSize) / 2.0;
  final bgY = (viewH - squareSize) / 2.0;

  final buffer = StringBuffer();
  buffer.writeln('<?xml version="1.0" encoding="utf-8"?>');
  buffer.writeln(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${viewW.toInt()} ${viewH.toInt()}" width="${viewW.toInt()}" height="${viewH.toInt()}">');

  // Background rounded square (marker body) — leave a placeholder color; the
  // designer can edit the fill in Illustrator easily.
  buffer.writeln(
      '<rect x="$bgX" y="$bgY" width="$squareSize" height="$squareSize" rx="$cornerRadius" ry="$cornerRadius" fill="#222222"/>');

  // Optional subtle outline
  buffer.writeln(
      '<rect x="$bgX" y="$bgY" width="$squareSize" height="$squareSize" rx="$cornerRadius" ry="$cornerRadius" fill="none" stroke="#000000" stroke-opacity="0.12" stroke-width="1.0"/>');

  // Icon group: translate to center, then scale, then translate -12,-12 to
  // account for 24x24 source origin so the icon centers correctly.
  buffer.writeln(
      '<g transform="translate($cx $cy) scale($iconScale) translate(-12 -12)" fill="#FFFFFF" fill-rule="evenodd">');
  for (final p in paths) {
    // ensure any double quotes inside d are escaped — unlikely but safe.
    final safe = p.replaceAll('"', '\\"');
    buffer.writeln('<path d="$safe"/>');
  }
  buffer.writeln('</g>');

  buffer.writeln('</svg>');
  return buffer.toString();
}
