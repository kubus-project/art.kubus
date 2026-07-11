import 'package:flutter/material.dart';

/// A named, centrally defined contextual gradient.
///
/// Contextual color IS allowed in kubus (onboarding steps, wallet actions,
/// web3 hubs may each carry their own accent) — but every gradient must be
/// defined HERE, never inline in a widget. See the design spec
/// (docs/superpowers/specs/2026-07-10-ui-kit-token-enforcement-design.md).
@immutable
class KubusAccentGradient {
  const KubusAccentGradient({
    required this.debugName,
    required this.start,
    required this.end,
    required this.accent,
  });

  final String debugName;
  final Color start;
  final Color end;

  /// Light companion tone for icons/labels rendered on top of the gradient
  /// or on dark surfaces next to it.
  final Color accent;

  LinearGradient get linear => linearWith();

  LinearGradient linearWith({
    Alignment begin = Alignment.topLeft,
    Alignment end = Alignment.bottomRight,
  }) {
    return LinearGradient(begin: begin, end: end, colors: [start, this.end]);
  }
}

/// The curated contextual gradient set. Keep this list SHORT — a tight
/// palette is what makes the app read as professional. Add a new entry only
/// when no existing one fits, and never define gradient colors in widgets.
class KubusAccentGradients {
  KubusAccentGradients._();

  static const cyanBlue = KubusAccentGradient(
    debugName: 'cyanBlue',
    start: Color(0xFF06B6D4),
    end: Color(0xFF3B82F6),
    accent: Color(0xFF67E8F9),
  );

  static const skyCyan = KubusAccentGradient(
    debugName: 'skyCyan',
    start: Color(0xFF0EA5E9),
    end: Color(0xFF06B6D4),
    accent: Color(0xFF81D4FA),
  );

  static const emerald = KubusAccentGradient(
    debugName: 'emerald',
    start: Color(0xFF10B981),
    end: Color(0xFF059669),
    accent: Color(0xFFA7F3D0),
  );

  static const sunset = KubusAccentGradient(
    debugName: 'sunset',
    start: Color(0xFFF59E0B),
    end: Color(0xFFEF4444),
    accent: Color(0xFFFFE082),
  );

  static const indigo = KubusAccentGradient(
    debugName: 'indigo',
    start: Color(0xFF6366F1),
    end: Color(0xFF3B82F6),
    accent: Color(0xFFC7D2FE),
  );

  static const tealBlue = KubusAccentGradient(
    debugName: 'tealBlue',
    start: Color(0xFF0F766E),
    end: Color(0xFF2563EB),
    accent: Color(0xFF99F6E4),
  );

  static const violet = KubusAccentGradient(
    debugName: 'violet',
    start: Color(0xFF7C3AED),
    end: Color(0xFFA855F7),
    accent: Color(0xFFDDD6FE),
  );

  static const gold = KubusAccentGradient(
    debugName: 'gold',
    start: Color(0xFFFBBF24),
    end: Color(0xFFD97706),
    accent: Color(0xFFFDE68A),
  );

  static const List<KubusAccentGradient> all = [
    cyanBlue,
    skyCyan,
    emerald,
    sunset,
    indigo,
    tealBlue,
    violet,
    gold,
  ];
}
