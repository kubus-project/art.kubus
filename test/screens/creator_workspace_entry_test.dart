import 'dart:convert';

import 'package:art_kubus/core/app_initializer_helper.dart';
import 'package:art_kubus/core/shell_routes.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/creator_workspace.dart';
import 'package:art_kubus/models/dao.dart';
import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/providers/collab_provider.dart';
import 'package:art_kubus/providers/dao_provider.dart';
import 'package:art_kubus/providers/portfolio_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/providers/web3provider.dart';
import 'package:art_kubus/screens/web3/artist/artist_studio.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/contextual_auth_gate.dart';
import 'package:art_kubus/services/onboarding_state_service.dart';
import 'package:art_kubus/services/solana_wallet_service.dart';
import 'package:art_kubus/utils/creator_workspace_navigation.dart';
import 'package:art_kubus/widgets/creator/creator_workspace_discovery_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestSolanaWalletService extends SolanaWalletService {
  @override
  Future<double> getSplTokenBalance({
    required String owner,
    required String mint,
    int? expectedDecimals,
  }) async =>
      0;
}

DAOReview _review(String status, String role) => DAOReview.fromJson({
      'id': 'review-1',
      'walletAddress': 'wallet-1',
      'portfolioUrl': 'https://example.com',
      'medium': 'painting',
      'statement': 'statement',
      'status': status,
      'createdAt': DateTime.utc(2026, 10, 9).toIso8601String(),
      'metadata': <String, dynamic>{'role': role},
    });

UserProfile _user({
  String walletAddress = 'wallet-1',
  String displayName = 'Ana',
  bool isArtist = false,
  bool isInstitution = false,
}) =>
    UserProfile(
      id: 'user-1',
      walletAddress: walletAddress,
      username: 'ana',
      displayName: displayName,
      bio: 'bio',
      avatar: '',
      isArtist: isArtist,
      isInstitution: isInstitution,
      preferences: ProfilePreferences(),
      createdAt: DateTime.utc(2026, 10, 9),
      updatedAt: DateTime.utc(2026, 10, 9),
    );

CreatorWorkspaceStage _stage({
  CreatorWorkspace workspace = CreatorWorkspace.artistStudio,
  bool session = true,
  bool profile = true,
  String wallet = 'wallet-1',
  DAOReview? review,
  bool grants = false,
}) =>
    resolveCreatorWorkspaceStage(
      workspace: workspace,
      hasAccountSession: session,
      hasUsableProfile: profile,
      walletAddress: wallet,
      review: review,
      profileGrantsRole: grants,
    );

void _configureApi({String? token, Map<String, dynamic>? review}) {
  final api = BackendApiService();
  api.setAuthTokenForTesting(token);
  api.setHttpClient(MockClient((request) async {
    const headers = {'content-type': 'application/json'};
    final path = request.url.path;
    if (path.startsWith('/api/dao/reviews/')) {
      return review == null
          ? http.Response('', 404, headers: headers)
          : http.Response(jsonEncode({'review': review}), 200,
              headers: headers);
    }
    if (path.startsWith('/api/dao/')) {
      return http.Response(jsonEncode({'data': <Object?>[]}), 200,
          headers: headers);
    }
    return http.Response('', 404, headers: headers);
  }));
}

Future<void> _pumpStudio(
  WidgetTester tester, {
  UserProfile? user,
  String? token,
  Map<String, dynamic>? review,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'Artist Studio_onboarding_completed': true,
  });
  _configureApi(token: token, review: review);
  addTearDown(() => BackendApiService().setAuthTokenForTesting(null));
  await tester.binding.setSurfaceSize(const Size(420, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final theme = ThemeProvider();
  final profile = ProfileProvider();
  if (user != null) profile.setCurrentUser(user);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: theme),
        ChangeNotifierProvider<ProfileProvider>.value(value: profile),
        ChangeNotifierProvider<DAOProvider>(
          create: (_) =>
              DAOProvider(solanaWalletService: _TestSolanaWalletService()),
        ),
        ChangeNotifierProvider<Web3Provider>(create: (_) => Web3Provider()),
        ChangeNotifierProvider<CollabProvider>(create: (_) => CollabProvider()),
        ChangeNotifierProvider<PortfolioProvider>(
          create: (_) => PortfolioProvider()..setWalletAddress('wallet-1'),
        ),
        ChangeNotifierProvider<WalletProvider>(
          create: (_) => WalletProvider(deferInit: true),
        ),
      ],
      child: MaterialApp(
        theme: theme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Scaffold(body: Text('route:${settings.name}')),
        ),
        home: const ArtistStudio(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('resolveCreatorWorkspaceStage', () {
    test('a visitor without an account discovers the workspace', () {
      expect(
          _stage(session: false, wallet: ''), CreatorWorkspaceStage.discover);
    });

    test('a signed-in account acquires profile, then wallet, then applies', () {
      expect(_stage(profile: false, wallet: ''),
          CreatorWorkspaceStage.completeProfile);
      expect(_stage(wallet: ''), CreatorWorkspaceStage.linkWalletToApply);
      expect(_stage(), CreatorWorkspaceStage.apply);
    });

    test('review states are reported as they are', () {
      expect(_stage(review: _review('pending', 'artist')),
          CreatorWorkspaceStage.pending);
      expect(_stage(review: _review('rejected', 'artist')),
          CreatorWorkspaceStage.rejected);
      expect(_stage(review: _review('approved', 'artist')),
          CreatorWorkspaceStage.open);
      expect(_stage(review: _review('pending', 'institution')),
          CreatorWorkspaceStage.otherRoleReview);
    });

    test('a server-granted role opens the workspace, so dual roles keep both',
        () {
      final institutionReview = _review('approved', 'institution');
      expect(
        _stage(
          workspace: CreatorWorkspace.artistStudio,
          review: institutionReview,
          grants: true,
        ),
        CreatorWorkspaceStage.open,
      );
      expect(
        _stage(
          workspace: CreatorWorkspace.institutionHub,
          review: institutionReview,
          grants: true,
        ),
        CreatorWorkspaceStage.open,
      );
    });

    test('an approved artist without a wallet session opens without a wallet',
        () {
      expect(_stage(wallet: '', grants: true), CreatorWorkspaceStage.open);
    });

    test('choosing a persona is not a role', () {
      // Nothing the viewer merely selected is an input: without a granted
      // flag or an approved review the workspace stays closed.
      expect(_stage(grants: false).isOpen, isFalse);
    });
  });

  group('CreatorWorkspaceNavigation.requirementsFor', () {
    test('account and profile come first, with no wallet', () {
      for (final stage in [
        CreatorWorkspaceStage.discover,
        CreatorWorkspaceStage.completeProfile,
      ]) {
        final requirements = CreatorWorkspaceNavigation.requirementsFor(stage)!;
        expect(requirements.requiresWallet, isFalse, reason: '$stage');
        expect(requirements.requiresProfile, isTrue, reason: '$stage');
      }
    });

    test('a wallet is requested only to sign the application', () {
      expect(
        CreatorWorkspaceNavigation.requirementsFor(
          CreatorWorkspaceStage.linkWalletToApply,
        )!
            .requiresWallet,
        isTrue,
      );
      for (final stage in [
        CreatorWorkspaceStage.apply,
        CreatorWorkspaceStage.pending,
        CreatorWorkspaceStage.rejected,
        CreatorWorkspaceStage.otherRoleReview,
        CreatorWorkspaceStage.open,
      ]) {
        expect(CreatorWorkspaceNavigation.requirementsFor(stage), isNull,
            reason: '$stage');
      }
    });
  });

  group('workspace URLs', () {
    test('are shell routes restored on cold start for guests and accounts', () {
      for (final workspace in CreatorWorkspace.values) {
        expect(ShellRoutes.builders.containsKey(workspace.route), isTrue);
        expect(
          ShellRoutes.shouldWrapInitialUri(Uri.parse(workspace.route)),
          isTrue,
        );
        expect(ShellRoutes.resolvePreferredShellRoute(workspace.route),
            workspace.route);
        for (final session in [true, false]) {
          expect(
            resolveColdStartEntry(
              preferredShellRoute: workspace.route,
              hasValidSession: session,
              hasLocalAccount: session,
            ).shellRoute,
            workspace.route,
            reason: 'session $session',
          );
        }
      }
      expect(CreatorWorkspace.fromRoute('/wallet'), isNull);
    });

    test('an interrupted journey remembers the workspace it started from',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'onboarding_pending_email_verification_v1': true,
      });
      final prefs = await SharedPreferences.getInstance();
      await OnboardingStateService.saveCapabilityScope(
        ProtectedActionRequirements.participant.storageValue,
        prefs: prefs,
        returnRoute: '/artist-studio',
      );
      expect(OnboardingStateService.capabilityReturnRouteSync(prefs),
          '/artist-studio');

      // Any other origin is not recorded: it is the screen the journey
      // opened above, never a route to restore on another device or tab.
      await OnboardingStateService.saveCapabilityScope(
        ProtectedActionRequirements.participant.storageValue,
        prefs: prefs,
        returnRoute: '/wallet',
      );
      expect(OnboardingStateService.capabilityReturnRouteSync(prefs), isNull);

      await OnboardingStateService.saveCapabilityScope(
        ProtectedActionRequirements.participant.storageValue,
        prefs: prefs,
        returnRoute: '/institution-hub',
      );
      await OnboardingStateService.clearCapabilityScope(prefs: prefs);
      expect(OnboardingStateService.capabilityReturnRouteSync(prefs), isNull);
    });
  });

  group('Artist Studio entry', () {
    testWidgets('a guest reads what the studio is for, with no wallet step',
        (tester) async {
      await _pumpStudio(tester);
      final l10n =
          AppLocalizations.of(tester.element(find.byType(ArtistStudio)))!;

      expect(find.byType(CreatorWorkspaceDiscoveryPanel), findsOneWidget);
      expect(find.text(l10n.artistStudioCtaConnectWalletToApply), findsNothing);
      expect(find.text(l10n.artistStudioLockedTitle), findsNothing);

      await tester.tap(find.byKey(
        const ValueKey<String>('creator_workspace_start_artistStudio'),
      ));
      await tester.pumpAndSettle();

      // The contextual account sheet, worded for the studio. Not a wallet.
      expect(find.text(l10n.creatorWorkspaceArtistGateTitle), findsOneWidget);
      expect(find.textContaining('route:'), findsNothing);

      await tester.tap(find.text(l10n.activationGateNotNow));
      await tester.pumpAndSettle();
      expect(find.byType(CreatorWorkspaceDiscoveryPanel), findsOneWidget,
          reason: 'dismissing leaves the visitor on the workspace');
    });

    testWidgets(
        'an account without a wallet gets an active step toward applying',
        (tester) async {
      await _pumpStudio(
        tester,
        user: _user(walletAddress: ''),
        token: 'test-token',
      );
      final l10n =
          AppLocalizations.of(tester.element(find.byType(ArtistStudio)))!;

      expect(find.byType(CreatorWorkspaceDiscoveryPanel), findsNothing);
      final cta = find.text(l10n.creatorWorkspaceLinkWalletCta);
      expect(cta, findsWidgets,
          reason: 'it used to be a disabled "Connect a wallet to apply"');

      await tester.tap(cta.first);
      await tester.pumpAndSettle();
      // The wallet step of the structured journey, returning to the studio.
      expect(find.text('route:/onboarding'), findsOneWidget);
    });

    testWidgets('a dual-role account keeps Artist Studio open', (tester) async {
      final review = <String, dynamic>{
        'id': 'review-1',
        'walletAddress': 'wallet-1',
        'portfolioUrl': 'https://example.com',
        'medium': 'museum',
        'statement': 'statement',
        'status': 'approved',
        'createdAt': DateTime.utc(2026, 10, 9).toIso8601String(),
        'metadata': <String, dynamic>{'role': 'institution'},
      };
      await _pumpStudio(
        tester,
        user: _user(isArtist: true, isInstitution: true),
        token: 'test-token',
        review: review,
      );
      final l10n =
          AppLocalizations.of(tester.element(find.byType(ArtistStudio)))!;

      expect(
          find.text(l10n.artistStudioInstitutionRoleActiveTitle), findsNothing);
      expect(find.text(l10n.artistStudioLockedTitle), findsNothing);
      expect(find.text(l10n.artistStudioTabGallery), findsOneWidget);
    });
  });
}
