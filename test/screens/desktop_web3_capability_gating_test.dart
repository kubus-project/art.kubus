import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/dao.dart';
import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/providers/dao_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/providers/web3provider.dart';
import 'package:art_kubus/screens/desktop/web3/desktop_governance_hub_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestWalletProvider extends WalletProvider {
  _TestWalletProvider(this._authority) : super(deferInit: true);

  WalletAuthoritySnapshot _authority;

  @override
  WalletAuthoritySnapshot get authority => _authority;

  @override
  String? get currentWalletAddress => _authority.walletAddress;

  void replaceAuthority(WalletAuthoritySnapshot authority) {
    _authority = authority;
    notifyListeners();
  }
}

class _TestDaoProvider extends DAOProvider {
  _TestDaoProvider({
    ProposalStatus proposalStatus = ProposalStatus.active,
    bool canModerateReviews = false,
  })  : _canModerateReviews = canModerateReviews,
        proposal = Proposal(
          id: 'proposal-1',
          title: 'Public governance proposal',
          description: 'Proposal body',
          type: ProposalType.governance,
          status: proposalStatus,
          proposer: 'wallet-proposer',
          createdAt: DateTime.utc(2026, 8, 1),
          votingEndDate: DateTime.utc(2026, 9, 1),
        ),
        review = DAOReview(
          id: 'review-1',
          walletAddress: 'wallet-applicant',
          portfolioUrl: 'https://example.com/portfolio',
          medium: 'painting',
          statement: 'Review statement',
          status: 'pending',
          createdAt: DateTime.utc(2026, 8, 1),
        );

  final Proposal proposal;
  final DAOReview review;
  final bool _canModerateReviews;

  @override
  bool get canModerateReviews => _canModerateReviews;

  @override
  List<Proposal> get proposals => <Proposal>[proposal];

  @override
  List<Proposal> getActiveProposals() => <Proposal>[proposal];

  @override
  Proposal? getProposalById(String id) => id == proposal.id ? proposal : null;

  @override
  List<Vote> get votes => const <Vote>[];

  @override
  List<Delegate> get delegates => const <Delegate>[];

  @override
  List<DAOTransaction> get transactions => const <DAOTransaction>[];

  @override
  List<DAOReview> get reviews => <DAOReview>[review];

  @override
  bool get isLoading => false;

  @override
  double? get treasuryOnChainBalance => 0;
}

WalletAuthoritySnapshot _authority({
  bool account = false,
  String? wallet,
  bool signer = false,
  String role = 'user',
}) {
  return WalletAuthoritySnapshot(
    state: !account
        ? WalletAuthorityState.signedOut
        : wallet == null
            ? WalletAuthorityState.accountShellOnly
            : signer
                ? WalletAuthorityState.localSignerReady
                : WalletAuthorityState.walletReadOnly,
    signerSource: signer ? WalletSignerSource.local : WalletSignerSource.none,
    accountSignedIn: account,
    signInMethod: account ? AuthSignInMethod.email : AuthSignInMethod.unknown,
    accountEmail: account ? 'member@example.com' : null,
    accountRole: role,
    walletAddress: wallet,
    hasLocalSigner: signer,
    hasExternalSigner: false,
    externalWalletConnected: false,
    externalWalletName: null,
    hasEncryptedBackup: false,
    encryptedBackupStatusKnown: true,
    hasPasskeyProtection: false,
    mnemonicBackupRequired: false,
    recoveryNeeded: false,
  );
}

UserProfile _profile() => UserProfile(
      id: 'user-1',
      walletAddress: 'wallet-member',
      username: 'member',
      displayName: 'Member',
      bio: '',
      avatar: '',
      createdAt: DateTime.utc(2026, 8, 1),
      updatedAt: DateTime.utc(2026, 8, 1),
    );

Future<void> _pumpGovernance(
  WidgetTester tester, {
  required ProfileProvider profile,
  required _TestWalletProvider wallet,
  _TestDaoProvider? dao,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'DAO Governance_onboarding_completed': true,
  });
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final theme = ThemeProvider();
  final web3 = Web3Provider()..bindWalletProvider(wallet);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: theme),
        ChangeNotifierProvider<ProfileProvider>.value(value: profile),
        ChangeNotifierProvider<WalletProvider>.value(value: wallet),
        ChangeNotifierProvider<Web3Provider>.value(value: web3),
        ChangeNotifierProvider<DAOProvider>.value(
          value: dao ?? _TestDaoProvider(),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routes: {
          '/wallet': (_) => const Scaffold(),
          '/connect-wallet': (_) => const Scaffold(),
        },
        home: const DesktopGovernanceHubScreen(),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('direct desktop route hides all governance mutations for guest',
      (tester) async {
    final profile = ProfileProvider();
    final wallet = _TestWalletProvider(_authority());
    await _pumpGovernance(tester, profile: profile, wallet: wallet);

    final context = tester.element(find.byType(DesktopGovernanceHubScreen));
    final l10n = AppLocalizations.of(context)!;
    expect(find.text(l10n.daoHubTabActiveProposals), findsOneWidget);
    expect(find.text(l10n.daoHubTabCreateProposal), findsNothing);
    expect(find.text(l10n.daoVoteYesButton), findsNothing);
    expect(find.text(l10n.daoVoteNoButton), findsNothing);
    expect(find.text(l10n.daoHubTabDelegation), findsNothing);
    expect(find.text(l10n.daoModerationApproveLabel), findsNothing);
    expect(find.text(l10n.daoModerationRejectLabel), findsNothing);
    expect(find.text(l10n.daoHubStatYourVotingPowerLabel), findsNothing);
  });

  testWidgets('account without signer shows participation state before forms',
      (tester) async {
    final profile = ProfileProvider()..setCurrentUser(_profile());
    final wallet = _TestWalletProvider(
      _authority(account: true, wallet: 'wallet-member'),
    );
    await _pumpGovernance(tester, profile: profile, wallet: wallet);

    final context = tester.element(find.byType(DesktopGovernanceHubScreen));
    final l10n = AppLocalizations.of(context)!;
    expect(find.text(l10n.walletActionReadOnlyReconnectToast), findsOneWidget);
    expect(find.text(l10n.daoHubTabCreateProposal), findsNothing);
    expect(find.text(l10n.daoVoteYesButton), findsNothing);
  });

  testWidgets('capabilities rebuild when signer is gained and lost',
      (tester) async {
    final profile = ProfileProvider()..setCurrentUser(_profile());
    final wallet = _TestWalletProvider(
      _authority(account: true, wallet: 'wallet-member'),
    );
    await _pumpGovernance(tester, profile: profile, wallet: wallet);

    final context = tester.element(find.byType(DesktopGovernanceHubScreen));
    final l10n = AppLocalizations.of(context)!;
    expect(find.text(l10n.daoHubTabCreateProposal), findsNothing);

    wallet.replaceAuthority(
      _authority(account: true, wallet: 'wallet-member', signer: true),
    );
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text(l10n.daoHubTabCreateProposal), findsWidgets);
    expect(find.text(l10n.daoVoteYesButton), findsOneWidget);

    wallet.replaceAuthority(
      _authority(account: true, wallet: 'wallet-member'),
    );
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text(l10n.daoHubTabCreateProposal), findsNothing);
    expect(find.text(l10n.daoVoteYesButton), findsNothing);
  });

  testWidgets('moderation controls require signer-ready moderator authority',
      (tester) async {
    final profile = ProfileProvider()..setCurrentUser(_profile());
    final wallet = _TestWalletProvider(
      _authority(
        account: true,
        wallet: 'wallet-member',
        signer: true,
        role: 'moderator',
      ),
    );
    await _pumpGovernance(tester, profile: profile, wallet: wallet);

    final context = tester.element(find.byType(DesktopGovernanceHubScreen));
    final l10n = AppLocalizations.of(context)!;
    expect(find.text(l10n.daoModerationApproveLabel), findsOneWidget);
    expect(find.text(l10n.daoModerationRejectLabel), findsOneWidget);
  });

  testWidgets('voting-phase proposals retain signer-ready voting actions',
      (tester) async {
    final profile = ProfileProvider()..setCurrentUser(_profile());
    final wallet = _TestWalletProvider(
      _authority(account: true, wallet: 'wallet-member', signer: true),
    );
    await _pumpGovernance(
      tester,
      profile: profile,
      wallet: wallet,
      dao: _TestDaoProvider(proposalStatus: ProposalStatus.voting),
    );

    final context = tester.element(find.byType(DesktopGovernanceHubScreen));
    final l10n = AppLocalizations.of(context)!;
    expect(find.text(l10n.daoVoteYesButton), findsOneWidget);
    expect(find.text(l10n.daoVoteNoButton), findsOneWidget);
  });

  testWidgets('server-derived reviewer authority enables moderation controls',
      (tester) async {
    final profile = ProfileProvider()..setCurrentUser(_profile());
    final wallet = _TestWalletProvider(
      _authority(account: true, wallet: 'wallet-member', signer: true),
    );
    await _pumpGovernance(
      tester,
      profile: profile,
      wallet: wallet,
      dao: _TestDaoProvider(canModerateReviews: true),
    );

    final context = tester.element(find.byType(DesktopGovernanceHubScreen));
    final l10n = AppLocalizations.of(context)!;
    expect(find.text(l10n.daoModerationApproveLabel), findsOneWidget);
    expect(find.text(l10n.daoModerationRejectLabel), findsOneWidget);
  });
}
