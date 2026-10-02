import 'package:art_kubus/models/dao.dart';
import 'package:art_kubus/providers/dao_provider.dart';
import 'package:art_kubus/screens/web3/dao/governance_hub.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/product_surface_harness.dart';

class _FakeDao extends DAOProvider {
  _FakeDao({this.active = const <Proposal>[], this.failure});

  final List<Proposal> active;
  final Object? failure;

  @override
  List<Proposal> get proposals => active;

  @override
  List<Proposal> getActiveProposals() => active;

  @override
  List<DAOReview> get reviews => const <DAOReview>[];

  @override
  List<Delegate> get delegates => const <Delegate>[];

  @override
  bool get isLoading => false;

  @override
  Object? get loadError => failure;

  @override
  Future<void> refreshData({bool force = false}) async {}
}

Proposal _proposal() => Proposal(
      id: 'p-1',
      title: 'Open the winter mural fund',
      description: 'Allocate a small budget to restore two public murals.',
      type: ProposalType.community,
      status: ProposalStatus.voting,
      proposer: 'wallet-proposer',
      createdAt: DateTime.utc(2026, 9, 1),
      votingEndDate: DateTime.utc(2099, 1, 10),
      yesVotes: 30,
      noVotes: 10,
      quorumRequired: 0.1,
    );

Future<void> _pump(WidgetTester tester, DAOProvider dao) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'DAO_onboarding_completed': true,
    'Governance_onboarding_completed': true,
  });
  final prior = FlutterError.onError;
  final errors = await pumpProductSurface(
    tester,
    child: const GovernanceHub(),
    extraProviders: [ChangeNotifierProvider<DAOProvider>.value(value: dao)],
  );
  // Restore before expect(): the harness collects errors until teardown.
  FlutterError.onError = prior;
  expect(errors, isEmpty);
}

void main() {
  testWidgets('a network failure is not presented as "no proposals"',
      (tester) async {
    await _pump(
      tester,
      _FakeDao(failure: Exception('SocketException: Failed host lookup')),
    );
    expect(find.text("You're offline"), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('SocketException'), findsNothing);
  });

  testWidgets('an empty DAO shows the empty state, not an error',
      (tester) async {
    await _pump(tester, _FakeDao());
    expect(find.text('Retry'), findsNothing);
    expect(find.text('No active proposals'), findsWidgets);
  });

  testWidgets(
      'proposal card: title, status, timeline, quorum requirement, results; '
      'never an invented quorum status', (tester) async {
    await _pump(tester, _FakeDao(active: [_proposal()]));
    expect(find.text('Open the winter mural fund'), findsOneWidget);
    expect(find.text('VOTING OPEN'), findsOneWidget);
    expect(find.textContaining('Voting ends'), findsOneWidget);
    expect(find.text('Quorum required: 10% of voting power'), findsOneWidget);
    expect(find.text('Quorum reached'), findsNothing);
    expect(find.text('Quorum pending'), findsNothing);
    expect(find.textContaining('75.0% support'), findsOneWidget);
  });
}
