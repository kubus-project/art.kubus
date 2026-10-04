import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:art_kubus/models/kubus_node_models.dart';
import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/availability_operator_provider.dart';
import 'package:art_kubus/providers/collab_provider.dart';
import 'package:art_kubus/providers/portfolio_provider.dart';
import 'package:art_kubus/screens/art/artwork_edit_screen.dart';
import 'package:art_kubus/screens/desktop/web3/desktop_governance_hub_screen.dart';
import 'package:art_kubus/screens/web3/artist/artist_portfolio_screen.dart';
import 'package:art_kubus/screens/web3/dao/governance_hub.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/providers/kubus_node_provider.dart';
import 'package:art_kubus/screens/auth/forgot_password_screen.dart';
import 'package:art_kubus/screens/auth/register_screen.dart';
import 'package:art_kubus/screens/auth/reset_password_screen.dart';
import 'package:art_kubus/screens/auth/secure_account_screen.dart';
import 'package:art_kubus/services/post_auth_coordinator.dart';
import 'package:art_kubus/widgets/auth/auth_atmosphere.dart';
import 'package:art_kubus/widgets/auth_entry_shell.dart';
import 'package:art_kubus/widgets/auth/post_auth_loading_screen.dart';
import 'package:art_kubus/screens/auth/sign_in_screen.dart';
import 'package:art_kubus/screens/auth/verify_email_screen.dart';
import 'package:art_kubus/screens/home_screen.dart';
import 'package:art_kubus/screens/node/kubus_node_screen.dart';
import 'package:art_kubus/screens/node/my_nodes_screen.dart';
import 'package:art_kubus/screens/settings/availability_node_operator_screen.dart';
import 'package:art_kubus/services/socket_service.dart';
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

/// Final 0.8.0 UX hardening: whole-surface evidence for the screens the last
/// pass rebuilt. Fixtures only, no network, no production data.
///
/// ```
/// KUBUS_RUN_VISUAL_QA=1 QA_LABEL=after flutter test test/qa/product_v5_final_hardening_visual_matrix_test.dart
/// ```
///
/// `QA_ONLY=auth,node` limits the run to scenes whose name starts with one of
/// the prefixes (the output directory is then not wiped).
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
  final outputDir = Directory('output/qa/final-hardening/$label');
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

  Future<void> surface(
    WidgetTester tester,
    String name,
    Widget Function() build, {
    Size size = const Size(390, 844),
    Brightness brightness = Brightness.light,
    Locale locale = const Locale('en'),
    double textScale = 1,
    UserProfile? signedIn,
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

  const phone = Size(390, 844);
  const desktop = Size(1440, 900);
  final owner = qaOwner();

  // -------------------------------------------------- auth surfaces (0.8.1)
  // The sign-in security progress and Secure account: one atmosphere, one
  // panel. The progress is frozen on a stage so the capture is deterministic.
  for (final b in Brightness.values) {
    Widget progress({required bool framed}) => PostAuthLoadingContent(
          stage: PostAuthStage.syncingSavedItems,
          running: true,
          error: null,
          onRetry: null,
          onBackToSignIn: null,
          framed: framed,
        );
    for (final entry
        in <String, Size>{'phone': phone, 'desktop': desktop}.entries) {
      scene('auth-progress-fullscreen-${entry.key}-${b.name}', (tester) async {
        await surface(
          tester,
          'auth-progress-fullscreen-${entry.key}-${b.name}',
          () => Material(
            type: MaterialType.transparency,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const AuthAtmosphereForQa(),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: progress(framed: true),
                    ),
                  ),
                ),
              ],
            ),
          ),
          size: entry.value,
          brightness: b,
        );
      });
    }
    scene('auth-progress-shell-desktop-${b.name}', (tester) async {
      await surface(
        tester,
        'auth-progress-shell-desktop-${b.name}',
        () => AuthEntryShell(
          title: 'Sign in',
          subtitle: 'Welcome back',
          heroIcon: Icons.login_rounded,
          form: progress(framed: false),
        ),
        size: desktop,
        brightness: b,
      );
    });
    for (final entry
        in <String, Size>{'phone': phone, 'desktop': desktop}.entries) {
      scene('auth-secure-account-${entry.key}-${b.name}', (tester) async {
        BackendApiService().setAuthTokenForTesting('qa-token');
        BackendApiService().setHttpClient(MockClient((request) async {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'success': true,
              'data': <String, dynamic>{
                'hasEmail': false,
                'hasPassword': false,
                'emailVerified': false,
                'emailAuthEnabled': true,
              },
            }),
            200,
            headers: const <String, String>{
              'content-type': 'application/json',
            },
          );
        }));
        await surface(
          tester,
          'auth-secure-account-${entry.key}-${b.name}',
          () => const SecureAccountScreen(),
          size: entry.value,
          brightness: b,
        );
        BackendApiService().setAuthTokenForTesting(null);
      });
    }
  }

  // -------------------------------------------------------------------- auth
  for (final b in Brightness.values) {
    for (final entry in <String, Widget Function()>{
      'signin': () => const SignInScreen(),
      'register': () => const RegisterScreen(),
    }.entries) {
      scene('auth-${entry.key}-phone-${b.name}', (tester) async {
        await surface(tester, 'auth-${entry.key}-phone-${b.name}', entry.value,
            size: phone, brightness: b);
      });
      scene('auth-${entry.key}-desktop-${b.name}', (tester) async {
        await surface(
            tester, 'auth-${entry.key}-desktop-${b.name}', entry.value,
            size: desktop, brightness: b);
      });
    }
    for (final entry in <String, Widget Function()>{
      'forgot': () => const ForgotPasswordScreen(),
      'reset': () => const ResetPasswordScreen(token: 'qa'),
      'verify': () => const VerifyEmailScreen(email: 'qa@kubus.site'),
    }.entries) {
      scene('auth-${entry.key}-phone-${b.name}', (tester) async {
        await surface(tester, 'auth-${entry.key}-phone-${b.name}', entry.value,
            size: phone, brightness: b);
      });
    }
  }

  // -------------------------------------------------------------------- node
  scene('node-no-node', (tester) async {
    await surface(
      tester,
      'node-no-node-phone-light',
      () => const MyNodesScreen(),
      extraProviders: [_node(_QaNode())],
      signedIn: owner,
    );
  });
  scene('node-no-node-dark-sl', (tester) async {
    await surface(
      tester,
      'node-no-node-phone-dark-sl',
      () => const MyNodesScreen(),
      brightness: Brightness.dark,
      locale: const Locale('sl'),
      extraProviders: [_node(_QaNode())],
      signedIn: owner,
    );
  });
  scene('node-discovered', (tester) async {
    await surface(
      tester,
      'node-discovered-phone-light',
      () => const MyNodesScreen(),
      extraProviders: [
        _node(_QaNode(nodes: const [
          {'label': 'Studio tower', 'remoteAttachAvailable': true},
          {'label': 'Gallery archive', 'remoteAttachAvailable': false},
        ])),
      ],
      signedIn: owner,
    );
  });
  scene('node-lookup-failed', (tester) async {
    await surface(
      tester,
      'node-lookup-failed-phone-light',
      () => const MyNodesScreen(),
      extraProviders: [_node(_QaNode(discoveryFailure: 'offline'))],
      signedIn: owner,
    );
  });
  scene('node-home-unpaired', (tester) async {
    await surface(
      tester,
      'node-home-unpaired-desktop-light',
      () => const KubusNodeScreen(embedded: true),
      size: desktop,
      extraProviders: [_node(_QaNode())],
      signedIn: owner,
    );
  });
  scene('node-rail', (tester) async {
    await surface(
      tester,
      'node-capability-rail-wide-dark',
      () => Center(
        child: HomeWeb3CardStrip(
          isEffectivelyConnected: false,
          persona: null,
          isArtist: true,
          isInstitution: false,
          onOpenDao: () {},
          onOpenArtistStudio: () {},
          onOpenInstitutionHub: () {},
          onOpenMarketplace: () {},
          onOpenNode: () {},
          onShowWalletOnboarding: () {},
        ),
      ),
      size: const Size(900, 320),
      brightness: Brightness.dark,
      signedIn: owner,
    );
  });
  // ------------------------------------------------- 200 % text scale (a11y)
  // Node and account entry at twice the text size: no overflow, no clipped
  // title or action, nothing overlapping. `renderErrors` in the report is the
  // machine check; the images are the visual one.
  for (final b in Brightness.values) {
    for (final entry in <String, Widget Function()>{
      'signin': () => const SignInScreen(),
      'register': () => const RegisterScreen(),
      'forgot': () => const ForgotPasswordScreen(),
      'verify': () => const VerifyEmailScreen(email: 'qa@kubus.site'),
    }.entries) {
      scene('a11y200-auth-${entry.key}-${b.name}', (tester) async {
        await surface(
            tester, 'a11y200-auth-${entry.key}-phone-${b.name}', entry.value,
            size: phone, brightness: b, textScale: 2);
      });
    }
  }
  scene('a11y200-node-no-node', (tester) async {
    await surface(
      tester,
      'a11y200-node-no-node-phone-light',
      () => const MyNodesScreen(),
      textScale: 2,
      extraProviders: [_node(_QaNode())],
      signedIn: owner,
    );
  });
  scene('a11y200-node-discovered', (tester) async {
    await surface(
      tester,
      'a11y200-node-discovered-phone-dark',
      () => const MyNodesScreen(),
      brightness: Brightness.dark,
      textScale: 2,
      extraProviders: [
        _node(_QaNode(nodes: const [
          {'label': 'Studio tower', 'remoteAttachAvailable': true},
          {'label': 'Gallery archive', 'remoteAttachAvailable': false},
        ])),
      ],
      signedIn: owner,
    );
  });
  scene('a11y200-node-home-unpaired', (tester) async {
    await surface(
      tester,
      'a11y200-node-home-unpaired-phone-light',
      () => const KubusNodeScreen(embedded: true),
      textScale: 2,
      extraProviders: [_node(_QaNode())],
      signedIn: owner,
    );
  });
  scene('a11y200-node-advanced-recovery', (tester) async {
    await surface(
      tester,
      'a11y200-node-advanced-recovery-phone-light',
      () => const AvailabilityNodeOperatorScreen(),
      size: const Size(390, 2600),
      textScale: 2,
      extraProviders: [
        _node(_QaNode()),
        ChangeNotifierProvider<AvailabilityOperatorProvider>(
          create: (_) => AvailabilityOperatorProvider(),
        ),
      ],
      signedIn: owner,
    );
  });
  scene('a11y200-node-capability-entry', (tester) async {
    await surface(
      tester,
      'a11y200-node-capability-entry-phone-light',
      () => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: HomeWeb3CardStrip(
            isEffectivelyConnected: false,
            persona: null,
            isArtist: true,
            isInstitution: false,
            onOpenDao: () {},
            onOpenArtistStudio: () {},
            onOpenInstitutionHub: () {},
            onOpenMarketplace: () {},
            onOpenNode: () {},
            onShowWalletOnboarding: () {},
          ),
        ),
      ),
      size: const Size(390, 420),
      textScale: 2,
      signedIn: owner,
    );
  });
  // ------------------------------------------------------------------ studio
  PortfolioProvider portfolioWith(List<Artwork> artworks) {
    final api = BackendApiService();
    api.setAuthTokenForTesting('qa-token');
    api.setHttpClient(
      MockClient((request) async {
        Map<String, Object?> ok(Object data) =>
            <String, Object?>{'success': true, 'data': data};
        final body = switch (request.url.path) {
          '/api/artworks' => ok(artworks
              .map((a) => <String, Object?>{
                    'id': a.id,
                    'title': a.title,
                    'artist': a.artist,
                    'description': a.description,
                    'latitude': a.position.latitude,
                    'longitude': a.position.longitude,
                    'rewards': a.rewards,
                    'createdAt': a.createdAt.toIso8601String(),
                    'category': a.category,
                    'isPublic': a.isPublic,
                    'isActive': a.isActive,
                  })
              .toList(growable: false)),
          '/api/exhibitions' =>
            ok(<String, Object?>{'exhibitions': const <Object?>[]}),
          _ => ok(const <Object?>[]),
        };
        return http.Response(
          jsonEncode(body),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }),
    );
    return PortfolioProvider(api: api)..setWalletAddress('wallet-1');
  }

  Artwork studioArtwork(
    String id,
    String title,
    String category, {
    bool isPublic = true,
    bool isActive = true,
  }) =>
      Artwork(
        id: id,
        title: title,
        artist: 'Ana Kova\u010d',
        description: 'Painted on site, 2025.',
        position: const LatLng(46.05, 14.5),
        rewards: 5,
        createdAt: DateTime.utc(2026, 3, 17),
        category: category,
        isPublic: isPublic,
        isActive: isActive,
      );

  final mixedArtworks = <Artwork>[
    studioArtwork('a1', 'Riverside mural', 'Mural'),
    studioArtwork('a2', 'Tobacna doorway', 'Street art', isPublic: false),
    studioArtwork('a3', 'Metelkova wall study', 'Installation'),
    studioArtwork('a4', 'Night lines', 'Digital', isActive: false),
    studioArtwork('a5', 'Fountain, afternoon', 'Photography'),
    studioArtwork('a6', 'Rooftop sketch', 'Drawing', isPublic: false),
  ];

  for (final entry in <String, Size>{
    '390': const Size(390, 1600),
    '768': const Size(768, 1400),
    '1440': const Size(1440, 1100),
    '1920': const Size(1920, 1100),
  }.entries) {
    scene('studio-gallery-${entry.key}', (tester) async {
      await surface(
        tester,
        'studio-gallery-${entry.key}-light',
        () => const Material(
          type: MaterialType.transparency,
          child: ArtistPortfolioScreen(walletAddress: 'wallet-1'),
        ),
        size: entry.value,
        signedIn: qaOwner(isArtist: true),
        extraProviders: [
          ChangeNotifierProvider<PortfolioProvider>.value(
            value: portfolioWith(mixedArtworks),
          ),
        ],
      );
    });
  }
  scene('studio-gallery-empty', (tester) async {
    await surface(
      tester,
      'studio-gallery-empty-1440-dark',
      () => const Material(
        type: MaterialType.transparency,
        child: ArtistPortfolioScreen(walletAddress: 'wallet-1'),
      ),
      size: desktop,
      brightness: Brightness.dark,
      signedIn: qaOwner(isArtist: true),
      extraProviders: [
        ChangeNotifierProvider<PortfolioProvider>.value(
          value: portfolioWith(const <Artwork>[]),
        ),
      ],
    );
  });
  scene('studio-editor', (tester) async {
    final artworks = ArtworkProvider()..addOrUpdateArtwork(qaArtwork());
    await surface(
      tester,
      'studio-editor-1440-light',
      () => qaShellHost(const ArtworkEditScreen(
          artworkId: 'art-a', chrome: ArtworkEditChrome.workspace)),
      size: const Size(1440, 1000),
      signedIn: qaOwner(isArtist: true),
      extraProviders: [
        ChangeNotifierProvider<ArtworkProvider>.value(value: artworks),
        ChangeNotifierProvider<CollabProvider>(
          create: (_) => CollabProvider(api: QaFixtureCollabApi()),
        ),
      ],
    );
    Provider.of<CollabProvider>(
      tester.element(find.byType(ArtworkEditScreen)),
      listen: false,
    ).stopInvitePolling();
  });

  // --------------------------------------------------------------------- dao
  scene('dao-desktop', (tester) async {
    await surface(
      tester,
      'dao-desktop-1440-light',
      () => const DesktopGovernanceHubScreen(),
      size: const Size(1440, 1100),
      signedIn: qaOwner(),
    );
  });
  scene('dao-mobile', (tester) async {
    await surface(
      tester,
      'dao-mobile-390-dark',
      () => const GovernanceHub(),
      size: const Size(390, 1500),
      brightness: Brightness.dark,
      signedIn: qaOwner(),
    );
  });
}

SingleChildWidget _node(KubusNodeProvider provider) =>
    ChangeNotifierProvider<KubusNodeProvider>.value(value: provider);

class _QaNode extends KubusNodeProvider {
  _QaNode({this.nodes = const <Map<String, dynamic>>[], this.discoveryFailure});

  final List<Map<String, dynamic>> nodes;
  final String? discoveryFailure;

  @override
  List<Map<String, dynamic>> get ownedNodes => nodes;

  @override
  bool get loadingOwnedNodes => false;

  @override
  String? get discoveryError => discoveryFailure;

  @override
  KubusNodeConnectionState get state => KubusNodeConnectionState.unpaired;

  @override
  String? get error => null;

  @override
  Future<void> loadOwnedNodes() async {}
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

/// The production auth atmosphere, behind a QA-local name so the scene reads
/// as what the full-screen progress paints underneath its one panel.
class AuthAtmosphereForQa extends StatelessWidget {
  const AuthAtmosphereForQa({super.key});

  @override
  Widget build(BuildContext context) =>
      const AuthAtmosphere(child: SizedBox.expand());
}
