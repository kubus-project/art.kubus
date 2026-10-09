import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:art_kubus/models/creator_workspace.dart';
import 'package:art_kubus/models/user_persona.dart';
import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/providers/portfolio_provider.dart';
import 'package:art_kubus/screens/desktop/web3/desktop_artist_studio_screen.dart';
import 'package:art_kubus/screens/desktop/web3/desktop_institution_hub_screen.dart';
import 'package:art_kubus/screens/home_screen.dart';
import 'package:art_kubus/screens/web3/artist/artist_studio.dart';
import 'package:art_kubus/screens/web3/institution/institution_hub.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/socket_service.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/product_surface_harness.dart';
import '../support/product_v5_qa_fixtures.dart';
import '../support/qa_font_loader.dart';

/// 0.8.2 creator capabilities: screenshot evidence for discovery and every
/// account stage of Artist Studio and Institution Hub, mobile and desktop.
/// Fixtures only, no network, no production data.
///
/// ```
/// KUBUS_RUN_VISUAL_QA=1 flutter test test/qa/creator_capability_visual_matrix_test.dart
/// ```
///
/// `QA_ONLY=guest,artist` limits the run to scenes starting with a prefix.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  if (Platform.environment['KUBUS_RUN_VISUAL_QA'] != '1') {
    test('creator capability visual QA is opt-in', () {},
        skip: 'Set KUBUS_RUN_VISUAL_QA=1 to generate screenshot evidence.');
    return;
  }

  final only = (Platform.environment['QA_ONLY'] ?? '')
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  final outputDir = Directory('output/qa/creator-capabilities');
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
    });
  });

  tearDownAll(() {
    File('${outputDir.path}/report-${only.isEmpty ? 'all' : only.join('-')}.json')
        .writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'commit': _git(['rev-parse', 'HEAD']),
        'treeDirty': _git(['status', '--porcelain']).isNotEmpty,
        'fontFamiliesLoaded': QaFontLoader.loadedFamilies,
        'captureCount': captures.length,
        'captures': captures,
      }),
    );
  });

  Future<void> surface(
    WidgetTester tester,
    String name,
    Widget Function() build, {
    Size size = const Size(390, 844),
    Brightness brightness = Brightness.light,
    Locale locale = const Locale('en'),
    double textScale = 1,
    UserProfile? signedIn,
    bool session = false,
    Future<void> Function(WidgetTester tester)? before,
    List<SingleChildWidget> extraProviders = const <SingleChildWidget>[],
  }) async {
    BackendApiService().setAuthTokenForTesting(session ? 'qa-session' : null);
    addTearDown(() => BackendApiService().setAuthTokenForTesting(null));
    final prior = FlutterError.onError;
    final errors = await pumpProductSurface(
      tester,
      child: Builder(
        builder: (context) => ColoredBox(
          color: KubusColorRoles.of(context).ground,
          child: build(),
        ),
      ),
      extraProviders: <SingleChildWidget>[
        ChangeNotifierProvider<PortfolioProvider>(
          create: (_) => PortfolioProvider()
            ..setWalletAddress(signedIn?.walletAddress ?? ''),
        ),
        ...extraProviders,
      ],
      size: size,
      brightness: brightness,
      locale: locale,
      textScale: textScale,
      signedInProfile: signedIn,
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    if (before != null) await before(tester);
    final bytes = await _captureRoot(tester);
    File('${outputDir.path}/$name.png').writeAsBytesSync(bytes);
    captures.add(<String, Object?>{
      'name': name,
      'width': size.width,
      'height': size.height,
      'locale': locale.languageCode,
      'brightness': brightness.name,
      'textScale': textScale,
      'session': session,
      'renderErrors': errors.toSet().toList(),
    });
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    FlutterError.onError = prior;
  }

  void scene(String name, WidgetTesterCallback body) {
    if (only.isNotEmpty && !only.any(name.startsWith)) return;
    testWidgets(name, (tester) async {
      await body(tester);
      SocketService().disconnect();
      await tester.pump(const Duration(seconds: 25));
    }, timeout: const Timeout(Duration(seconds: 150)));
  }

  const narrow = Size(320, 640);
  const desktop = Size(1440, 900);
  final noWallet = qaOwner().copyWith(walletAddress: '');
  final lover = qaOwner();
  final artist = qaOwner(isArtist: true);
  final institution = qaOwner(isInstitution: true);
  final dual = qaOwner(isArtist: true, isInstitution: true);

  Widget strips({
    UserProfile? user,
    CreatorWorkspaceStage artistStage = CreatorWorkspaceStage.discover,
    CreatorWorkspaceStage institutionStage = CreatorWorkspaceStage.discover,
    bool wallet = false,
  }) {
    return Builder(
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsets.all(KubusSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HomeCreatorCardStrip(
              persona: user == null
                  ? null
                  : (user.isInstitution && !user.isArtist
                      ? UserPersona.institution
                      : UserPersona.creator),
              isArtist: user?.isArtist ?? false,
              isInstitution: user?.isInstitution ?? false,
              artistStage: artistStage,
              institutionStage: institutionStage,
              onOpenWorkspace: (_) {},
            ),
            const SizedBox(height: KubusSpacing.lg),
            HomeWeb3CardStrip(
              isEffectivelyConnected: wallet,
              onOpenDao: () {},
              onOpenMarketplace: () {},
              onOpenNode: () {},
              onOpenWallet: () {},
              onShowWalletOnboarding: () {},
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- guest
  for (final b in Brightness.values) {
    scene('guest-home-capabilities-phone-${b.name}', (tester) async {
      await surface(
          tester, 'guest-home-capabilities-phone-${b.name}', () => strips(),
          size: const Size(390, 420), brightness: b);
    });
    scene('guest-studio-phone-${b.name}', (tester) async {
      await surface(
          tester, 'guest-studio-phone-${b.name}', () => const ArtistStudio(),
          brightness: b);
    });
    scene('guest-hub-phone-${b.name}', (tester) async {
      await surface(
          tester, 'guest-hub-phone-${b.name}', () => const InstitutionHub(),
          brightness: b);
    });
    scene('guest-studio-desktop-${b.name}', (tester) async {
      await surface(tester, 'guest-studio-desktop-${b.name}',
          () => qaShellHost(const DesktopArtistStudioScreen()),
          size: desktop, brightness: b);
    });
    scene('guest-hub-desktop-${b.name}', (tester) async {
      await surface(tester, 'guest-hub-desktop-${b.name}',
          () => qaShellHost(const DesktopInstitutionHubScreen()),
          size: desktop, brightness: b);
    });
  }
  scene('guest-studio-phone-sl', (tester) async {
    await surface(tester, 'guest-studio-phone-sl', () => const ArtistStudio(),
        locale: const Locale('sl'));
  });
  scene('guest-home-capabilities-phone-sl', (tester) async {
    await surface(tester, 'guest-home-capabilities-phone-sl', () => strips(),
        size: const Size(390, 420), locale: const Locale('sl'));
  });
  scene('guest-studio-narrow-320', (tester) async {
    await surface(tester, 'guest-studio-narrow-320', () => const ArtistStudio(),
        size: narrow);
  });
  scene('guest-hub-narrow-320-a11y200', (tester) async {
    await surface(
        tester, 'guest-hub-narrow-320-a11y200', () => const InstitutionHub(),
        size: narrow, textScale: 2);
  });
  scene('guest-home-capabilities-narrow-320', (tester) async {
    await surface(tester, 'guest-home-capabilities-narrow-320', () => strips(),
        size: const Size(320, 420));
  });
  scene('guest-gate-studio-phone', (tester) async {
    await surface(
      tester,
      'guest-gate-studio-phone',
      () => const ArtistStudio(),
      before: (tester) async {
        await tester.tap(find.byKey(
          const ValueKey<String>('creator_workspace_start_artistStudio'),
        ));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
      },
    );
  });

  // --------------------------------------------------------- signed in
  scene('lover-home-capabilities-phone', (tester) async {
    await surface(
      tester,
      'lover-home-capabilities-phone',
      () => strips(
        user: lover,
        artistStage: CreatorWorkspaceStage.apply,
        institutionStage: CreatorWorkspaceStage.apply,
        wallet: true,
      ),
      size: const Size(390, 420),
      signedIn: lover,
      session: true,
    );
  });
  scene('nowallet-studio-phone', (tester) async {
    await surface(tester, 'nowallet-studio-phone', () => const ArtistStudio(),
        signedIn: noWallet, session: true);
  });
  scene('nowallet-hub-desktop', (tester) async {
    await surface(tester, 'nowallet-hub-desktop',
        () => qaShellHost(const DesktopInstitutionHubScreen()),
        size: desktop, signedIn: noWallet, session: true);
  });
  scene('lover-studio-apply-phone', (tester) async {
    await surface(
        tester, 'lover-studio-apply-phone', () => const ArtistStudio(),
        signedIn: lover, session: true);
  });
  scene('artist-home-capabilities-phone', (tester) async {
    await surface(
      tester,
      'artist-home-capabilities-phone',
      () => strips(
        user: artist,
        artistStage: CreatorWorkspaceStage.open,
        institutionStage: CreatorWorkspaceStage.apply,
        wallet: true,
      ),
      size: const Size(390, 420),
      signedIn: artist,
      session: true,
    );
  });
  scene('artist-studio-phone', (tester) async {
    await surface(tester, 'artist-studio-phone', () => const ArtistStudio(),
        signedIn: artist, session: true);
  });
  scene('artist-studio-desktop', (tester) async {
    await surface(tester, 'artist-studio-desktop',
        () => qaShellHost(const DesktopArtistStudioScreen()),
        size: desktop, signedIn: artist, session: true);
  });
  scene('institution-hub-phone', (tester) async {
    await surface(tester, 'institution-hub-phone', () => const InstitutionHub(),
        signedIn: institution, session: true);
  });
  scene('institution-hub-desktop', (tester) async {
    await surface(tester, 'institution-hub-desktop',
        () => qaShellHost(const DesktopInstitutionHubScreen()),
        size: desktop, signedIn: institution, session: true);
  });
  scene('dual-home-capabilities-phone', (tester) async {
    await surface(
      tester,
      'dual-home-capabilities-phone',
      () => strips(
        user: dual,
        artistStage: CreatorWorkspaceStage.open,
        institutionStage: CreatorWorkspaceStage.open,
        wallet: true,
      ),
      size: const Size(390, 420),
      signedIn: dual,
      session: true,
    );
  });
  scene('dual-studio-phone', (tester) async {
    await surface(tester, 'dual-studio-phone', () => const ArtistStudio(),
        signedIn: dual, session: true);
  });
  scene('dual-hub-phone', (tester) async {
    await surface(tester, 'dual-hub-phone', () => const InstitutionHub(),
        signedIn: dual, session: true);
  });
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
