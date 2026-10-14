import 'package:flutter/material.dart';

/// Renders authored kubus-family names with the shared wordmark emphasis.
///
/// This helper is for visible brand copy only. Keep URLs, package identifiers,
/// protocol values, signatures, and user-authored content as plain text.
class KubusFamilyBrandText extends StatelessWidget {
  const KubusFamilyBrandText(
    this.data, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.softWrap,
    this.textAlign,
    this.textDirection,
    this.semanticsLabel,
  });

  final String data;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final String? semanticsLabel;

  static final RegExp _brandToken = RegExp(
    RegExp.escape('kubus'),
    caseSensitive: false,
  );

  static bool containsBrandToken(String text) =>
      _brandToken.allMatches(text).any((match) => _isBrandWord(text, match));

  static TextSpan span(String text, {TextStyle? style}) {
    final children = <InlineSpan>[];
    var cursor = 0;
    for (final match in _brandToken.allMatches(text)) {
      final start = match.start;
      final end = match.end;
      if (!_isBrandWord(text, match)) continue;
      if (cursor < start) {
        children.add(TextSpan(text: text.substring(cursor, start)));
      }
      children.add(
        TextSpan(
          text: match.group(0),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
      cursor = end;
    }
    if (children.isEmpty) return TextSpan(text: text, style: style);
    if (cursor < text.length) {
      children.add(TextSpan(text: text.substring(cursor)));
    }
    return TextSpan(style: style, children: children);
  }

  static bool _isWordCharacter(String character) =>
      RegExp(r'[A-Za-z0-9_]').hasMatch(character);

  static bool _isBrandWord(String text, Match match) =>
      (match.start == 0 || !_isWordCharacter(text[match.start - 1])) &&
      (match.end == text.length || !_isWordCharacter(text[match.end]));

  @override
  Widget build(BuildContext context) => Text.rich(
        span(data, style: style),
        maxLines: maxLines,
        overflow: overflow,
        softWrap: softWrap,
        textAlign: textAlign,
        textDirection: textDirection,
        semanticsLabel: semanticsLabel,
      );
}
