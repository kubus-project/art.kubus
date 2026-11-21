import 'package:art_kubus/models/dao.dart';
import 'package:art_kubus/providers/dao_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/screens/web3/dao/governance_hub.dart';
import 'package:art_kubus/services/encrypted_wallet_backup_service.dart';
import 'package:art_kubus/widgets/common/kubus_action_tile.dart';
import 'package:art_kubus/widgets/kubus_button.dart';
import 'package:art_kubus/widgets/dashboard/kubus_dashboard_chrome.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/common/kubus_stat_card.dart';
import 'package:art_kubus/widgets/dao/dao_metric_strip.dart';
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

/// Wallet state is seeded through the provider's test hooks; deferInit keeps
/// the real wallet bootstrap (secure storage, network) out of the test.
class _GovernanceWallet extends WalletProvider {
  _GovernanceWallet() : super(deferInit: true);
}

EncryptedWalletBackupDefinition _governanceBackup() {
  return EncryptedWalletBackupDefinition(
    walletAddress: 'wallet123',
    version: 1,
    kdfName: 'argon2id',
    kdfParams: const <String, dynamic>{'iterations': 1},
    salt: 'salt',
    wrappedDekNonce: 'wrappedNonce',
    wrappedDekCiphertext: 'wrappedCipher',
    mnemonicNonce: 'mnemonicNonce',
    mnemonicCiphertext: 'mnemonicCipher',
    passkeys: const <WalletBackupPasskeyDefinition>[],
  );
}

Future<void> _pumpWithWallet(
  WidgetTester tester,
  WalletProvider wallet, {
  Locale locale = const Locale('en'),
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'DAO_onboarding_completed': true,
    'Governance_onboarding_completed': true,
  });
  final prior = FlutterError.onError;
  final errors = await pumpProductSurface(
    tester,
    child: const GovernanceHub(),
    locale: locale,
    extraProviders: [
      ChangeNotifierProvider<DAOProvider>.value(value: _FakeDao()),
      ChangeNotifierProvider<WalletProvider>.value(value: wallet),
    ],
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

  testWidgets('header metrics use the expressive DAO stat language',
      (tester) async {
    await _pump(tester, _FakeDao(active: [_proposal()]));
    expect(find.byType(DaoMetricStrip), findsOneWidget);
    final cards = tester
        .widgetList<KubusStatCard>(
          find.descendant(
            of: find.byType(DaoMetricStrip),
            matching: find.byType(KubusStatCard),
          ),
        )
        .toList();
    expect(cards, isNotEmpty);
    final context = tester.element(find.byType(DaoMetricStrip));
    final daoAccent = KubusColorRoles.of(context).web3DaoAccent;
    for (final card in cards) {
      expect(card.icon, isNotNull, reason: '${card.title} needs a glyph');
      expect(card.expressive, isTrue, reason: card.title);
      expect(card.layout, KubusStatCardLayout.centered);
      expect(card.accent, daoAccent, reason: card.title);
      expect(card.minHeight, greaterThanOrEqualTo(96),
          reason: 'not a 64 px utility row');
    }
  });

  group('governance does not print its tabs a second time', () {
    const tabDuplicates = <String>[
      'dao_destination_treasury',
      'dao_destination_delegation',
      'dao_destination_voting_history',
      'dao_destination_create_proposal',
    ];

    testWidgets(
        'with proposals, no tile merely repeats a tab; proposals stay '
        'content and the numbers stay metrics', (tester) async {
      await _pump(tester, _FakeDao(active: [_proposal()]));

      for (final key in tabDuplicates) {
        expect(find.byKey(ValueKey<String>(key)), findsNothing, reason: key);
      }
      expect(find.byType(KubusActionTile), findsNothing);

      // A proposal is content, not a shortcut.
      expect(find.text('Open the winter mural fund'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('Open the winter mural fund'),
          matching: find.byType(KubusActionTile),
        ),
        findsNothing,
      );

      // The header numbers stay metrics.
      expect(find.byType(KubusStatCard), findsWidgets);
    });

    testWidgets('an empty list offers no signing task without the capability',
        (tester) async {
      await _pump(tester, _FakeDao());

      expect(find.text('No active proposals'), findsWidgets);
      for (final key in tabDuplicates) {
        expect(find.byKey(ValueKey<String>(key)), findsNothing, reason: key);
      }
      // The create-proposal task is gated exactly as its tab is: with no
      // wallet the tab is absent, so the task is too.
      expect(
        find.byKey(const ValueKey<String>('dao_task_create_proposal')),
        findsNothing,
      );
      final createTab = find
          .descendant(
            of: find.byType(KubusDashboardTabs),
            matching: find.text('Create proposal'),
          )
          .evaluate()
          .isNotEmpty;
      expect(createTab, isFalse);
    });
  });

  group('participation action follows the wallet identity state', () {
    testWidgets('a walletless account is offered a connect, never a restore',
        (tester) async {
      final wallet = _GovernanceWallet()
        ..seedAccountSessionForTesting(
          email: 'walletless@example.com',
          backendProfile: const <String, dynamic>{},
        )
        ..setCurrentWalletAddressForTesting(null);

      await _pumpWithWallet(tester, wallet);

      expect(
        find.text(
          'Your account is signed in without a wallet. Connect one to continue with this action.',
        ),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(KubusButton, 'Connect wallet'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(KubusButton, 'Restore wallet'),
        findsNothing,
      );
    });

    testWidgets(
        'a read-only wallet with no proven backup is offered a reconnect',
        (tester) async {
      final wallet = _GovernanceWallet()
        ..seedAccountSessionForTesting(
          email: 'readonly@example.com',
          backendProfile: const <String, dynamic>{},
        )
        ..setCurrentWalletAddressForTesting('wallet123');

      await _pumpWithWallet(tester, wallet);

      expect(
        find.widgetWithText(KubusButton, 'Reconnect'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(KubusButton, 'Restore wallet'),
        findsNothing,
      );
    });

    testWidgets(
        'a wallet with a proven backup and no local key is offered restore',
        (tester) async {
      final wallet = _GovernanceWallet()
        ..seedAccountSessionForTesting(
          email: 'restorable@example.com',
          backendProfile: const <String, dynamic>{},
        )
        ..setCurrentWalletAddressForTesting('wallet123')
        ..setEncryptedWalletBackupDefinitionForTesting(_governanceBackup());

      await _pumpWithWallet(tester, wallet);

      expect(
        find.widgetWithText(KubusButton, 'Restore wallet'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(KubusButton, 'Reconnect'),
        findsNothing,
      );
    });

    testWidgets('a walletless account reads the connect copy in Slovenian',
        (tester) async {
      final wallet = _GovernanceWallet()
        ..seedAccountSessionForTesting(
          email: 'walletless@example.com',
          backendProfile: const <String, dynamic>{},
        )
        ..setCurrentWalletAddressForTesting(null);

      await _pumpWithWallet(tester, wallet, locale: const Locale('sl'));

      expect(
        find.widgetWithText(KubusButton, 'Poveži denarnico'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(KubusButton, 'Obnovi denarnico'),
        findsNothing,
      );
    });

    testWidgets(
        'an account whose wallet link is still settling is not told to connect one',
        (tester) async {
      final wallet = _GovernanceWallet()
        ..seedAccountSessionForTesting(
          email: 'settling@example.com',
          backendProfile: const <String, dynamic>{},
        );

      await _pumpWithWallet(tester, wallet);

      expect(find.text('Checking wallet status…'), findsOneWidget);
      expect(
        find.text(
          'Your account is signed in without a wallet. Connect one to continue with this action.',
        ),
        findsNothing,
      );
      expect(
        find.widgetWithText(KubusButton, 'Connect wallet'),
        findsNothing,
      );

      // The link settles without a wallet: only now is connecting offered.
      wallet.setCurrentWalletAddressForTesting(null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Checking wallet status…'), findsNothing);
      expect(
        find.widgetWithText(KubusButton, 'Connect wallet'),
        findsOneWidget,
      );
    });
  });
}
