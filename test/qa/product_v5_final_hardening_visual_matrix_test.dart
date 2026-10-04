import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:art_kubus/models/kubus_node_models.dart';
import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/providers/kubus_node_provider.dart';
import 'package:art_kubus/screens/auth/forgot_password_screen.dart';
import 'package:art_kubus/screens/auth/register_screen.dart';
import 'package:art_kubus/screens/auth/reset_password_screen.dart';
import 'package:art_kubus/screens/auth/sign_in_screen.dart';
import 'package:art_kubus/screens/auth/verify_email_screen.dart';
import 'package:art_kubus/screens/home_screen.dart';
import 'package:art_kubus/screens/node/kubus_node_screen.dart';
import 'package:art_kubus/screens/node/my_nodes_screen.dart';
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
