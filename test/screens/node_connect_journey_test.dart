import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/kubus_node_models.dart';
import 'package:art_kubus/providers/kubus_node_provider.dart';
import 'package:art_kubus/screens/node/my_nodes_screen.dart';
import 'package:art_kubus/widgets/kubus_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Node front door has **one** obvious way in.
///
/// It used to offer five controls that all meant roughly "connect" — Confirm,
/// Add Node, Retry, Pair locally, and a link straight into operator setup.
/// These tests pin the journey instead: one primary action, one quiet
/// alternative, a retry only where a retry means something, and states that
/// tell the truth about what the transport can actually do.
class _NodeState extends KubusNodeProvider {
  _NodeState({
    this.nodes = const <Map<String, dynamic>>[],
    this.loading = false,
    this.discoveryFailure,
  });

  final List<Map<String, dynamic>> nodes;
  final bool loading;
  final String? discoveryFailure;

  int loadCalls = 0;

  @override
  List<Map<String, dynamic>> get ownedNodes => nodes;

  @override
  bool get loadingOwnedNodes => loading;

  @override
  String? get discoveryError => discoveryFailure;

  @override
  KubusNodeConnectionState get state => KubusNodeConnectionState.unpaired;

  @override
  String? get error => null;

  @override
  Future<void> loadOwnedNodes() async {
    loadCalls += 1;
  }
}

Future<AppLocalizations> _pump(
  WidgetTester tester,
  KubusNodeProvider node, {
  Size size = const Size(390, 900),
}) async {
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ChangeNotifierProvider<KubusNodeProvider>.value(
      value: node,
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MyNodesScreen(),
      ),
    ),
  );
  await tester.pump();
  return AppLocalizations.of(tester.element(find.byType(MyNodesScreen)))!;
}

const _primary = ValueKey<String>('node_connect_primary_action');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('with no Node: what it is for, and exactly one primary action',
      (tester) async {
    final l10n = await _pump(tester, _NodeState());

    expect(find.text(l10n.kubusNodeNoNodeTitle), findsOneWidget);
    expect(find.text(l10n.kubusNodeEntrySubtitle), findsOneWidget);

    // One primary action, and it is the handoff.
    expect(find.byKey(_primary), findsOneWidget);
    expect(find.text(l10n.kubusNodeConnectAction), findsOneWidget);

    // No competing "connect". A retry means nothing when the lookup
    // succeeded and simply found nothing, so it is not offered.
    expect(find.text(l10n.commonRetry), findsNothing);
    expect(find.text(l10n.kubusMyNodesLocalPairing), findsNothing);
    expect(find.text(l10n.kubusNodeEntryConnectCta), findsNothing);

    // Operator internals are not pairing UX.
    expect(find.text(l10n.kubusNodeAdvancedOperatorSetup), findsNothing);
  });

  testWidgets('a reachable Node on the account offers a single Connect',
      (tester) async {
    final l10n = await _pump(
      tester,
      _NodeState(nodes: const [
        <String, dynamic>{
          'label': 'Studio tower',
          'remoteAttachAvailable': true,
        },
      ]),
    );

    expect(find.text('Studio tower'), findsOneWidget);
    expect(find.text(l10n.kubusNodeAvailable), findsOneWidget);

    final connect = find.widgetWithText(
      KubusButton,
      l10n.kubusNodeConfirmAction,
    );
    expect(connect, findsOneWidget);
    expect(tester.widget<KubusButton>(connect).onPressed, isNotNull);
  });

  testWidgets('an unreachable Node says so and does not offer a dead Connect',
      (tester) async {
    final l10n = await _pump(
      tester,
      _NodeState(nodes: const [
        <String, dynamic>{
          'label': 'Studio tower',
          'remoteAttachAvailable': false,
        },
      ]),
    );

    // Honest status: never a connected-looking row while the transport is
    // unavailable.
    expect(find.text(l10n.kubusNodeOffline), findsOneWidget);
    expect(find.text(l10n.kubusMyNodesUnavailable), findsOneWidget);

    final connect = find.widgetWithText(
      KubusButton,
      l10n.kubusNodeConfirmAction,
    );
    expect(tester.widget<KubusButton>(connect).onPressed, isNull);
  });

  testWidgets('a failed lookup is said as itself, with one retry',
      (tester) async {
    final node = _NodeState(discoveryFailure: 'offline');
    final l10n = await _pump(tester, node);

    // Not "this account has no Nodes": a failed lookup and an empty account
    // are different facts.
    expect(find.text(l10n.kubusMyNodesDiscoveryFailed), findsOneWidget);
    expect(find.text(l10n.kubusNodeNoNodeTitle), findsNothing);

    expect(find.text(l10n.commonRetry), findsOneWidget);
    await tester.tap(find.text(l10n.commonRetry));
    await tester.pump();
    expect(node.loadCalls, 1);

    // The front door is still the front door.
    expect(find.byKey(_primary), findsOneWidget);
  });

  testWidgets('while looking, one indicator and no competing controls',
      (tester) async {
    final l10n = await _pump(tester, _NodeState(loading: true));

    expect(find.text(l10n.kubusNodeNoNodeTitle), findsNothing);
    expect(find.text(l10n.kubusMyNodesDiscoveryFailed), findsNothing);
    expect(find.text(l10n.commonRetry), findsNothing);
  });

  testWidgets('normal pairing never asks for an operator token',
      (tester) async {
    final l10n = await _pump(tester, _NodeState());

    // The handoff is the whole normal path: the person is never asked to open
    // a shell, read a launcher token, or paste operator credentials.
    expect(find.text(l10n.kubusNodeConnectHandoffBody), findsOneWidget);
    for (final forbidden in const <String>[
      'NODE_GUI_TOKEN',
      'PowerShell',
      'operator token',
    ]) {
      expect(find.textContaining(forbidden), findsNothing,
          reason: '$forbidden must not appear in the normal pairing path');
    }
  });
}
