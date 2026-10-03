import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/providers/platform_provider.dart';
import 'package:art_kubus/screens/community/community_screen.dart';
import 'package:art_kubus/screens/desktop/desktop_home_screen.dart';
import 'package:art_kubus/screens/desktop/desktop_settings_screen.dart';
import 'package:art_kubus/screens/home_screen.dart';
import 'package:art_kubus/screens/season0/season0_screen.dart';
import 'package:art_kubus/screens/settings_screen.dart';
import 'package:art_kubus/screens/web3/artist/artist_studio_create_screen.dart';
import 'package:art_kubus/screens/web3/wallet/connectwallet_screen.dart';
import 'package:art_kubus/screens/web3/wallet/wallet_home.dart';
import 'package:art_kubus/services/share/share_types.dart';
import 'package:art_kubus/services/socket_service.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/common/kubus_action_tile.dart';
import 'package:art_kubus/widgets/common/kubus_stat_card.dart';
import 'package:art_kubus/widgets/share/share_sheet.dart';
import 'package:art_kubus/widgets/support/support_section.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/product_surface_harness.dart';
import '../support/product_v5_qa_fixtures.dart';
import '../support/qa_font_loader.dart';

/// Tile-system visual matrix (0.8.0 visual hardening): every destination
/// surface that moved onto the shared action tile, plus the hover evidence.
///
/// ```
/// KUBUS_RUN_VISUAL_QA=1 QA_LABEL=after flutter test test/qa/product_v5_tile_system_visual_matrix_test.dart
/// ```
///
/// `QA_ONLY=settings,hover` limits the run to scenes whose name starts with
/// one of the prefixes (the output directory is then not wiped). Fixtures
/// only: no network, no production data.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  if (Platform.environment['KUBUS_RUN_VISUAL_QA'] != '1') {
    test('visual QA matrix is opt-in', () {},
        skip: 'Set KUBUS_RUN_VISUAL_QA=1 to generate screenshot evidence.');
    return;
  }

  final label = Platform.environment['QA_LABEL'] ?? 'after';
  final only = (Platform.environment['QA_ONLY'] ?? '')
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  final outputDir = Directory('output/qa/product-v5-tiles/$label');
  final captures = <Map<String, Object?>>[];

  setUpAll(() async {
    await QaFontLoader.ensureLoaded();
    if (only.isEmpty && outputDir.existsSync()) {
      outputDir.deleteSync(recursive: true);
    }
    outputDir.createSync(recursive: true);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'Artist Studio_onboarding_completed': true,
      'Institution Hub_onboarding_completed': true,
      'DAO_onboarding_completed': true,
      'Marketplace_onboarding_completed': true,
    });
  });

  tearDownAll(() {
    File('${outputDir.path}/report-${only.isEmpty ? 'all' : only.join('-')}.json')
        .writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'label': label,
        'commit': _git(['rev-parse', 'HEAD']),
        'treeDirty': _git(['status', '--porcelain']).isNotEmpty,
        'fontFamiliesLoaded': QaFontLoader.loadedFamilies,
        'captureCount': captures.length,
        'captures': captures,
      }),
    );
  });

  Future<void> capture(
    WidgetTester tester,
    String name,
    Size size,
    Brightness brightness,
    Locale locale,
    double textScale,
    List<String> errors,
  ) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    final bytes = await _captureRoot(tester);
    File('${outputDir.path}/$name.png').writeAsBytesSync(bytes);
    captures.add(<String, Object?>{
      'name': name,
      'width': size.width,
      'height': size.height,
      'locale': locale.languageCode,
      'brightness': brightness.name,
      'textScale': textScale,
      'renderErrors': errors.toSet().toList(),
    });
  }

  Future<void> surface(
    WidgetTester tester,
    String name,
    Widget Function() build, {
    Size size = _mobile,
    Brightness brightness = Brightness.light,
    Locale locale = const Locale('en'),
    double textScale = 1,
    UserProfile? signedIn,
    Future<void> Function(WidgetTester tester)? interact,
    List<SingleChildWidget> extraProviders = const <SingleChildWidget>[],
  }) async {
    final prior = FlutterError.onError;
    final errors = await pumpProductSurface(
      tester,
      child: Builder(
        builder: (context) => ColoredBox(
          color: KubusColorRoles.of(context).ground,
          child: build(),
        ),
      ),
      extraProviders: extraProviders,
      size: size,
      brightness: brightness,
      locale: locale,
      textScale: textScale,
      signedInProfile: signedIn,
    );
    if (interact != null) {
      try {
        await interact(tester);
      } catch (error) {
        errors.add('interaction: $error');
      }
    }
    await capture(tester, name, size, brightness, locale, textScale, errors);
    // Fake time only: outlasts the socket connect timeout and the
    // secure-storage reads so no timer survives the scene.
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    FlutterError.onError = prior;
  }

  void scene(String name, WidgetTesterCallback body) {
    if (only.isNotEmpty && !only.any(name.startsWith)) return;
    testWidgets(name, (tester) async {
      // The test binding draws shadows without blur; the hover evidence
      // needs the real soft shadow. The binding checks it is restored.
      debugDisableShadows = false;
      try {
        await body(tester);
        SocketService().disconnect();
        await tester.pump(const Duration(seconds: 25));
      } finally {
        debugDisableShadows = true;
      }
    }, timeout: const Timeout(Duration(seconds: 150)));
  }

  final owner = qaOwner();
  final artist = qaOwner(isArtist: true);
  const desktop = Size(1440, 1000);

  // ----------------------------------------------------------------- hover
  // Before/after pairs for each tile kind, in both themes, plus reduced
  // motion. The sheet is the same in every pair so the only difference
  // between the two captures is the hover itself.
  for (final b in Brightness.values) {
    for (final reduced in const [false, true]) {
      scene('hover-${b.name}${reduced ? '-reduced' : ''}', (tester) async {
        final name = 'hover-${b.name}${reduced ? '-reduced' : ''}';
        final prior = FlutterError.onError;
        final errors = await pumpProductSurface(
          tester,
          child: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: ColoredBox(
                color: KubusColorRoles.of(context).ground,
                child: const _HoverSheet(),
              ),
            ),
          ),
          size: const Size(900, 760),
          brightness: b,
          signedInProfile: owner,
        );
        final gesture =
            await tester.createGesture(kind: PointerDeviceKind.mouse);
        await gesture.addPointer(location: const Offset(1, 1));
        addTearDown(gesture.removePointer);
        await capture(tester, '$name-rest', const Size(900, 760), b,
            const Locale('en'), 1, errors);
        for (final target in _HoverSheet.targets) {
          await gesture.moveTo(tester.getCenter(find.byKey(target.key)));
          await tester.pumpAndSettle();
          await capture(tester, '$name-${target.name}', const Size(900, 760), b,
              const Locale('en'), 1, errors);
        }
        await gesture.moveTo(const Offset(899, 759));
        await tester.pumpAndSettle();
        FlutterError.onError = prior;
      });
    }
  }

  // ------------------------------------------------------------- components
  for (final b in Brightness.values) {
    scene('components-${b.name}', (tester) async {
      await surface(
        tester,
        'components-390-${b.name}-en',
        () => const _TileSheet(),
        size: const Size(390, 1500),
        brightness: b,
        signedIn: owner,
      );
    });
  }
  scene('components-320-sl-x2', (tester) async {
    await surface(
      tester,
      'components-320-dark-sl-x2',
      () => const _TileSheet(),
      size: const Size(320, 2600),
      brightness: Brightness.dark,
      locale: const Locale('sl'),
      textScale: 2,
      signedIn: owner,
    );
  });
  scene('components-1440', (tester) async {
    await surface(
      tester,
      'components-1440-light-en',
      () => const _TileSheet(),
      size: const Size(1440, 900),
      signedIn: owner,
    );
  });

  // ---------------------------------------------------------------- settings
  for (final w in const [320.0, 390.0]) {
    scene('settings-${w.toInt()}', (tester) async {
      await surface(
        tester,
        'settings-mobile-${w.toInt()}-light-en',
        () => const SettingsScreen(),
        size: Size(w, 2600),
        signedIn: owner,
        extraProviders: [qaEmailPreferences(), _platform()],
      );
    });
  }
  scene('settings-390-dark-sl', (tester) async {
    await surface(
      tester,
      'settings-mobile-390-dark-sl',
      () => const SettingsScreen(),
      size: const Size(390, 2600),
      brightness: Brightness.dark,
      locale: const Locale('sl'),
      signedIn: owner,
      extraProviders: [qaEmailPreferences(), _platform()],
    );
  });
  scene('settings-390-x2', (tester) async {
    await surface(
      tester,
      'settings-mobile-390-light-en-x2',
      () => const SettingsScreen(),
      size: const Size(390, 4200),
      textScale: 2,
      signedIn: owner,
      extraProviders: [qaEmailPreferences(), _platform()],
    );
  });
  for (final section in const ['Security settings', 'About', 'Danger zone']) {
    scene('settings-desktop-${section.toLowerCase().replaceAll(' ', '-')}',
        (tester) async {
      await surface(
        tester,
        'settings-desktop-1440-dark-en-${section.toLowerCase().replaceAll(' ', '-')}',
        () => qaShellHost(const DesktopSettingsScreen(embeddedInShell: true)),
        size: desktop,
        brightness: Brightness.dark,
        signedIn: owner,
        extraProviders: [qaEmailPreferences(), _platform()],
        interact: (tester) async {
          await tester.tap(find.text(section).first);
          await tester.pump(const Duration(milliseconds: 400));
        },
      );
    });
  }

  scene('settings-768-x13', (tester) async {
    await surface(
      tester,
      'settings-mobile-768-light-en-x13',
      () => const SettingsScreen(),
      size: const Size(768, 3000),
      textScale: 1.3,
      signedIn: owner,
      extraProviders: [qaEmailPreferences(), _platform()],
    );
  });
  scene('home-desktop-1920', (tester) async {
    await surface(
      tester,
      'home-desktop-1920-dark-en',
      () => qaShellHost(const DesktopHomeScreen()),
      size: const Size(1920, 2200),
      brightness: Brightness.dark,
      signedIn: artist,
    );
  });
  scene('home-768', (tester) async {
    await surface(
      tester,
      'home-mobile-768-light-en-x13',
      () => const HomeScreen(),
      size: const Size(768, 2400),
      textScale: 1.3,
      signedIn: artist,
    );
  });

  // ----------------------------------------------------------------- season 0
  for (final w in const [320.0, 390.0]) {
    scene('season0-${w.toInt()}', (tester) async {
      await surface(
        tester,
        'season0-${w.toInt()}-light-en',
        () => const Season0Screen(),
        size: Size(w, 900),
        signedIn: owner,
      );
    });
  }
  scene('season0-390-dark-sl', (tester) async {
    await surface(
      tester,
      'season0-390-dark-sl',
      () => const Season0Screen(),
      size: const Size(390, 900),
      brightness: Brightness.dark,
      locale: const Locale('sl'),
      signedIn: owner,
    );
  });

  // -------------------------------------------------------- studio create tab
  scene('studio-create-390', (tester) async {
    await surface(
      tester,
      'studio-create-390-light-en',
      () => const Scaffold(body: ArtistStudioCreateScreen()),
      signedIn: artist,
    );
  });
  scene('studio-create-320-dark-sl', (tester) async {
    await surface(
      tester,
      'studio-create-320-dark-sl',
      () => const Scaffold(body: ArtistStudioCreateScreen()),
      size: const Size(320, 900),
      brightness: Brightness.dark,
      locale: const Locale('sl'),
      signedIn: artist,
    );
  });

  // -------------------------------------------------------------------- home
  for (final w in const [320.0, 390.0]) {
    scene('home-${w.toInt()}', (tester) async {
      await surface(
        tester,
        'home-mobile-${w.toInt()}-light-en',
        () => const HomeScreen(),
        size: Size(w, 2400),
        signedIn: artist,
      );
    });
  }
  scene('home-390-dark-sl', (tester) async {
    await surface(
      tester,
      'home-mobile-390-dark-sl',
      () => const HomeScreen(),
      size: const Size(390, 2400),
      brightness: Brightness.dark,
      locale: const Locale('sl'),
      signedIn: artist,
    );
  });
  scene('home-desktop', (tester) async {
    await surface(
      tester,
      'home-desktop-1440-light-en',
      () => qaShellHost(const DesktopHomeScreen()),
      size: const Size(1440, 2200),
      signedIn: artist,
    );
  });

  // ------------------------------------------------------- wallet and entry
  scene('wallet-390', (tester) async {
    await surface(
      tester,
      'wallet-mobile-390-light-en',
      () => const WalletHome(),
      size: const Size(390, 1500),
      signedIn: artist,
      extraProviders: [qaWalletProvider()],
    );
  });
  scene('connect-wallet-390', (tester) async {
    await surface(
      tester,
      'connect-wallet-390-light-en',
      () => const ConnectWallet(),
      size: const Size(390, 1000),
    );
  });
  scene('connect-wallet-390-dark', (tester) async {
    await surface(
      tester,
      'connect-wallet-390-dark-sl',
      () => const ConnectWallet(),
      size: const Size(390, 1000),
      brightness: Brightness.dark,
      locale: const Locale('sl'),
    );
  });

  // --------------------------------------------------------------- community
  scene('community-390', (tester) async {
    await surface(
      tester,
      'community-mobile-390-light-en',
      () => const CommunityScreen(),
      size: const Size(390, 1100),
      signedIn: owner,
    );
  });

  // ---------------------------------------------------- support and sharing
  scene('support-390', (tester) async {
    await surface(
      tester,
      'support-390-light-en',
      () => const Padding(
        padding: EdgeInsets.all(KubusSpacing.md),
        child: SingleChildScrollView(child: SupportSectionCard()),
      ),
      size: const Size(390, 700),
    );
  });
  scene('support-1440-dark', (tester) async {
    await surface(
      tester,
      'support-1440-dark-en',
      () => const Padding(
        padding: EdgeInsets.all(KubusSpacing.xl),
        child: SingleChildScrollView(child: SupportSectionCard()),
      ),
      size: const Size(1440, 500),
      brightness: Brightness.dark,
    );
  });
  scene('share-390', (tester) async {
    await surface(
      tester,
      'share-sheet-390-light-en',
      () => Align(
        alignment: Alignment.bottomCenter,
        child: ShareSheet(
          target: const ShareTarget(
            type: ShareEntityType.artwork,
            shareId: 'a',
            title: 'Artwork',
          ),
          onActionSelected: (_) async {},
        ),
      ),
      size: const Size(390, 700),
    );
  });
}

const Size _mobile = Size(390, 844);

SingleChildWidget _platform() => ChangeNotifierProvider<PlatformProvider>.value(
      value: PlatformProvider(),
    );

class _HoverTarget {
  const _HoverTarget(this.name, this.key);
  final String name;
  final Key key;
}

/// One of each tile kind with room around it, so the lift, the shadow and the
/// glyph drift are visible in a screenshot.
class _HoverSheet extends StatelessWidget {
  const _HoverSheet();

  static const targets = <_HoverTarget>[
    _HoverTarget('stacked', ValueKey<String>('hover_stacked')),
    _HoverTarget('inline', ValueKey<String>('hover_inline')),
    _HoverTarget('compact', ValueKey<String>('hover_compact')),
    _HoverTarget('stat', ValueKey<String>('hover_stat')),
  ];

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    return Padding(
      padding: const EdgeInsets.all(KubusSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 260,
                height: 140,
                child: KubusActionTile(
                  key: targets[0].key,
                  title: 'Analytics',
                  icon: Icons.analytics_outlined,
                  accent: roles.statTeal,
                  onTap: () {},
                ),
              ),
              const SizedBox(width: KubusSpacing.xl),
              KubusActionTile(
                key: targets[1].key,
                title: 'Artist Studio',
                icon: Icons.palette_outlined,
                accent: roles.web3ArtistStudioAccent,
                layout: KubusActionTileLayout.inline,
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: KubusSpacing.xl),
          SizedBox(
            width: 420,
            child: KubusActionTile(
              key: targets[2].key,
              title: 'Security',
              subtitle: 'PIN, backup and sign-in methods',
              icon: Icons.shield_outlined,
              accent: roles.active,
              layout: KubusActionTileLayout.compact,
              onTap: () {},
            ),
          ),
          const SizedBox(height: KubusSpacing.xl),
          SizedBox(
            width: 220,
            height: 120,
            child: KubusStatCard(
              key: targets[3].key,
              title: 'Followers',
              value: '1,284',
              icon: Icons.people_outline,
              accent: roles.statBlue,
              layout: KubusStatCardLayout.centered,
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }
}

/// Every layout of the action tile (with and without subtitle and status) and
/// both stat tiles, so the primitives are reviewed without a screen around
/// them.
class _TileSheet extends StatelessWidget {
  const _TileSheet();

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(KubusSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(builder: (context, constraints) {
            final columns = narrow ? 2 : 4;
            final width =
                (constraints.maxWidth - KubusSpacing.sm * (columns - 1)) /
                    columns;
            Widget cell(Widget tile) => SizedBox(width: width, child: tile);
            return Wrap(
              spacing: KubusSpacing.sm,
              runSpacing: KubusSpacing.sm,
              children: [
                cell(KubusActionTile(
                  title: 'Artist Studio',
                  subtitle: 'Create and publish',
                  icon: Icons.palette_outlined,
                  accent: roles.web3ArtistStudioAccent,
                  onTap: () {},
                )),
                cell(KubusActionTile(
                  title: 'Marketplace',
                  icon: Icons.storefront_outlined,
                  accent: roles.web3MarketplaceAccent,
                  onTap: () {},
                )),
                cell(KubusActionTile(
                  title: 'Governance',
                  icon: Icons.how_to_vote_outlined,
                  accent: roles.web3DaoAccent,
                  status: Icon(Icons.lock_outline,
                      size: 14, color: roles.lockedFeature),
                  onTap: () {},
                )),
                cell(KubusActionTile(
                  title: 'Institution Hub with a long name',
                  icon: Icons.account_balance_outlined,
                  accent: roles.web3InstitutionAccent,
                  onTap: () {},
                )),
              ],
            );
          }),
          const SizedBox(height: KubusSpacing.lg),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                KubusActionTile(
                  title: 'Map',
                  icon: Icons.map_outlined,
                  accent: roles.statTeal,
                  layout: KubusActionTileLayout.inline,
                  onTap: () {},
                ),
                const SizedBox(width: KubusSpacing.sm),
                KubusActionTile(
                  title: 'Achievements',
                  icon: Icons.emoji_events_outlined,
                  accent: roles.statAmber,
                  layout: KubusActionTileLayout.inline,
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: KubusSpacing.lg),
          for (final t in <(String, String?, IconData, Color, bool, bool)>[
            (
              'Security',
              'PIN, backup and sign-in methods',
              Icons.shield,
              roles.active,
              false,
              false
            ),
            (
              'Secure your account',
              'Add e-mail and a password to recover access',
              Icons.lock_outline,
              roles.active,
              false,
              true
            ),
            (
              'Privacy settings',
              'Data: enabled, ads: disabled',
              Icons.privacy_tip,
              roles.active,
              false,
              false
            ),
            (
              'Delete account',
              'Permanently remove your account and data',
              Icons.delete_forever,
              roles.destructive,
              false,
              false
            ),
            (
              'Send',
              'Restore wallet access to send',
              Icons.arrow_upward,
              roles.statAmber,
              true,
              false
            ),
            ('Settings', null, Icons.settings, roles.active, false, false),
          ]) ...[
            KubusActionTile(
              title: t.$1,
              subtitle: t.$2,
              icon: t.$3,
              accent: t.$4,
              enabled: !t.$5,
              layout: KubusActionTileLayout.compact,
              status: t.$6
                  ? Text('VERIFIED',
                      style: KubusTextStyles.compactBadge
                          .copyWith(color: roles.success))
                  : null,
              onTap: () {},
            ),
            const SizedBox(height: KubusSpacing.sm),
          ],
          const SizedBox(height: KubusSpacing.md),
          Builder(builder: (context) {
            final extent = KubusStatCard.centeredExtent(context);
            final width = (MediaQuery.sizeOf(context).width -
                    KubusSpacing.lg * 2 -
                    KubusSpacing.sm) /
                2;
            return Wrap(
              spacing: KubusSpacing.sm,
              runSpacing: KubusSpacing.sm,
              children: [
                SizedBox(
                  width: width,
                  height: extent,
                  child: KubusStatCard(
                    title: 'Followers',
                    value: '1,284',
                    icon: Icons.people_outline,
                    accent: roles.statBlue,
                    layout: KubusStatCardLayout.centered,
                    onTap: () {},
                  ),
                ),
                SizedBox(
                  width: width,
                  height: extent,
                  child: KubusStatCard(
                    title: 'Artworks',
                    value: '42',
                    icon: Icons.image_outlined,
                    accent: roles.statTeal,
                    layout: KubusStatCardLayout.centered,
                    onTap: () {},
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: KubusSpacing.md),
          KubusStatCard(
            title: 'Votes cast',
            value: '17',
            icon: Icons.how_to_vote_outlined,
            accent: roles.web3DaoAccent,
          ),
        ],
      ),
    );
  }
}

Future<List<int>> _captureRoot(WidgetTester tester) async {
  final boundary = tester.binding.rootElement!.renderObject!;
  final layer = boundary.debugLayer! as OffsetLayer;
  late final List<int> bytes;
  await tester.runAsync(() async {
    final image = await layer.toImage(boundary.paintBounds);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    bytes = data!.buffer.asUint8List();
    image.dispose();
  });
  return bytes;
}

String _git(List<String> args) {
  try {
    final result = Process.runSync('git', args);
    return (result.stdout as String).trim();
  } catch (_) {
    return '';
  }
}
