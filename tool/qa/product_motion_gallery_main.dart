// PRODUCT motion acceptance gallery.
//
// Renders every layout of the PRODUCT tile family at fixed, known coordinates
// so `scripts/qa/product_motion_acceptance.mjs` can drive a real browser
// pointer over each one and measure the painted lift, float and shadow.
//
//   flutter build web --release -t tool/qa/product_motion_gallery_main.dart \
//     --output build/motion-gallery
//   node scripts/qa/product_motion_acceptance.mjs
//
// Query: ?theme=light|dark. Viewport: 1440x900. The case list below and
// `CASES` in the script must stay in step (same ids, same rectangles).
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/common/kubus_action_tile.dart';
import 'package:art_kubus/widgets/common/kubus_stat_card.dart';
import 'package:flutter/material.dart';

class _Case {
  const _Case(
      this.id, this.left, this.top, this.width, this.height, this.build);

  final String id;
  final double left;
  final double top;
  final double width;
  final double height;
  final Widget Function(Color accent) build;
}

void _noop() {}

final List<_Case> _cases = <_Case>[
  _Case(
    'action-stacked',
    40,
    60,
    300,
    140,
    (accent) => KubusActionTile(
      title: 'Analytics',
      icon: Icons.analytics_outlined,
      accent: accent,
      onTap: _noop,
    ),
  ),
  _Case(
    'action-inline',
    380,
    60,
    280,
    56,
    (accent) => KubusActionTile(
      title: 'Explore the map',
      icon: Icons.explore_outlined,
      accent: accent,
      onTap: _noop,
      layout: KubusActionTileLayout.inline,
    ),
  ),
  _Case(
    'action-compact',
    700,
    60,
    320,
    64,
    (accent) => KubusActionTile(
      title: 'Security',
      subtitle: 'Backup, recovery and sign-in',
      icon: Icons.shield_outlined,
      accent: accent,
      onTap: _noop,
      layout: KubusActionTileLayout.compact,
    ),
  ),
  _Case(
    'action-disabled',
    1060,
    60,
    320,
    64,
    (accent) => KubusActionTile(
      title: 'Locked',
      subtitle: 'Not available yet',
      icon: Icons.lock_outline,
      accent: accent,
      onTap: _noop,
      layout: KubusActionTileLayout.compact,
      enabled: false,
    ),
  ),
  _Case(
    'stat-centered',
    40,
    300,
    300,
    120,
    (accent) => KubusStatCard(
      title: 'Followers',
      value: '1,284',
      icon: Icons.people_outline,
      accent: accent,
      layout: KubusStatCardLayout.centered,
      minHeight: 88,
      titleMaxLines: 2,
    ),
  ),
  _Case(
    'stat-centered-tap',
    380,
    300,
    300,
    120,
    (accent) => KubusStatCard(
      title: 'Artworks',
      value: '42',
      icon: Icons.palette_outlined,
      accent: accent,
      layout: KubusStatCardLayout.centered,
      minHeight: 88,
      titleMaxLines: 2,
      onTap: _noop,
    ),
  ),
  _Case(
    'stat-standard',
    720,
    300,
    300,
    88,
    (accent) => KubusStatCard(
      title: 'Views',
      value: '9,310',
      icon: Icons.visibility_outlined,
      accent: accent,
    ),
  ),
  _Case(
    'stat-standard-tap',
    1060,
    300,
    300,
    88,
    (accent) => KubusStatCard(
      title: 'Collectors',
      value: '67',
      icon: Icons.groups_outlined,
      accent: accent,
      onTap: _noop,
    ),
  ),
  _Case(
    'stat-standard-expressive',
    40,
    540,
    300,
    88,
    (accent) => KubusStatCard(
      title: 'Exhibitions',
      value: '8',
      icon: Icons.museum_outlined,
      accent: accent,
      expressive: true,
    ),
  ),
];

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final dark = Uri.base.queryParameters['theme'] == 'dark';
  final theme = ThemeProvider();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme.lightTheme,
      darkTheme: theme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: Builder(
        builder: (context) {
          final roles = KubusColorRoles.of(context);
          return Scaffold(
            backgroundColor: roles.ground,
            body: Stack(
              children: [
                for (final c in _cases)
                  Positioned(
                    left: c.left,
                    top: c.top,
                    width: c.width,
                    height: c.height,
                    child: c.build(roles.active),
                  ),
              ],
            ),
          );
        },
      ),
    ),
  );
}
