// Wallet-optional creator journey, proven against the HTTP contract the Flutter
// app actually speaks (a fake backend behind BackendApiService), not against
// widget fixtures that merely show a button.
import 'dart:convert';
import 'dart:typed_data';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/creator_workspace.dart';
import 'package:art_kubus/models/dao.dart';
import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/providers/artwork_drafts_provider.dart';
import 'package:art_kubus/providers/collab_provider.dart';
import 'package:art_kubus/providers/dao_provider.dart';
import 'package:art_kubus/providers/notification_provider.dart';
import 'package:art_kubus/providers/portfolio_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/providers/web3provider.dart';
import 'package:art_kubus/screens/web3/artist/artist_studio.dart';
import 'package:art_kubus/screens/web3/institution/institution_hub.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:art_kubus/services/solana_wallet_service.dart';
import 'package:art_kubus/utils/dao_role_verification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _json = {'content-type': 'application/json'};

class _TestSolanaWalletService extends SolanaWalletService {
  @override
  Future<double> getSplTokenBalance({
    required String owner,
    required String mint,
    int? expectedDecimals,
  }) async =>
      0;
}

/// A fake backend. `contract` toggles whether `/health` advertises the
/// wallet-optional creator contract, i.e. new backend vs. the previous one.
class _FakeBackend {
  _FakeBackend({this.contract = true, this.mine, this.accountReply});

  final bool contract;
  final Map<String, dynamic>? mine;
  final http.Response Function(http.Request request)? accountReply;
  final List<http.Request> requests = [];

  http.Client get client => MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        if (path == '/health') {
          return http.Response(
            jsonEncode({
              'status': 'ok',
              if (contract) 'contracts': {'walletOptionalCreator': 1},
            }),
            200,
            headers: _json,
          );
        }
        if (path == '/api/dao/reviews/mine') {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': mine ??
                  {
                    'capabilities': {'artist': false, 'institution': false},
                    'applications': {'artist': null, 'institution': null},
                    'reviews': <Object?>[],
                  },
            }),
            200,
            headers: _json,
          );
        }
        if (path == '/api/dao/reviews/account') {
          if (accountReply != null) return accountReply!(request);
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'id': 'review-account-1',
                'walletAddress': '',
                'portfolioUrl': body['portfolioUrl'],
                'medium': body['medium'],
                'statement': body['statement'],
                'status': 'pending',
                'role': body['role'],
                'isArtistApplication': body['role'] == 'artist',
                'isInstitutionApplication': body['role'] == 'institution',
                'submissionMode': 'account_session',
                'createdAt': DateTime.utc(2026, 10, 9).toIso8601String(),
                'metadata': {'role': body['role']},
              },
            }),
            201,
            headers: _json,
          );
        }
        if (path.startsWith('/api/dao/')) {
          return http.Response(jsonEncode({'data': <Object?>[]}), 200,
              headers: _json);
        }
        if (path == '/api/artworks' &&
            request.url.queryParameters['mine'] == 'true') {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': [
                {
                  'id': '11111111-1111-4111-8111-111111111111',
                  'title': 'Wall piece',
                  'description': 'A draft',
                  'imageUrl': '/uploads/a.png',
                  'isPublic': false,
                  'isActive': true,
                  'category': 'Street Art',
                  'createdAt': DateTime.utc(2026, 10, 9).toIso8601String(),
                },
              ],
            }),
            200,
            headers: _json,
          );
        }
        if (path == '/api/collections' &&
            request.url.queryParameters['mine'] == 'true') {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': [
                {
                  'id': '22222222-2222-4222-8222-222222222222',
                  'name': 'Walls',
                  'isPublic': false,
                  'artworkCount': 0,
                },
              ],
            }),
            200,
            headers: _json,
          );
        }
        return http.Response('', 404, headers: _json);
      });

  Iterable<http.Request> to(String path) =>
      requests.where((r) => r.url.path == path);
}

UserProfile _walletFreeUser({String displayName = 'Ana'}) => UserProfile(
      id: 'user-1',
      walletAddress: '',
      username: 'ana',
      displayName: displayName,
      bio: 'bio',
      avatar: '',
      preferences: ProfilePreferences(),
      createdAt: DateTime.utc(2026, 10, 9),
      updatedAt: DateTime.utc(2026, 10, 9),
    );

/// A token shaped like the backend's (header.payload.signature) so the app can
/// read the account id from it, as it does for real sessions.
String _jwt(String accountId) {
  String b64(Map<String, Object?> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${b64({'alg': 'HS256'})}.${b64({'id': accountId})}.sig';
}

void _use(_FakeBackend backend, {String? token}) {
  token ??= _jwt('account-a');
  final api = BackendApiService();
  api.setAuthTokenForTesting(token);
  api.setHttpClient(backend.client);
  api.resetWalletOptionalCreatorForTesting();
  addTearDown(() {
    api.resetWalletOptionalCreatorForTesting();
    api.setAuthTokenForTesting(null);
    api.setHttpClient(createPlatformHttpClient());
  });
}

Future<void> _pumpStudio(
  WidgetTester tester,
  UserProfile user, {
  Widget home = const ArtistStudio(),
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'Artist Studio_onboarding_completed': true,
    'Institution Hub_onboarding_completed': true,
  });
  await tester.binding.setSurfaceSize(const Size(420, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final theme = ThemeProvider();
  final profile = ProfileProvider()..setCurrentUser(user);
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
        ChangeNotifierProvider<NotificationProvider>(
            create: (_) => NotificationProvider()),
        ChangeNotifierProvider<PortfolioProvider>(
            create: (_) => PortfolioProvider()),
        ChangeNotifierProvider<WalletProvider>(
          create: (_) => WalletProvider(deferInit: true),
        ),
      ],
      child: MaterialApp(
        theme: theme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pumpAndSettle();
}

Uint8List _png() => base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    BackendApiService.disableHttpFailureDiagnosticsForTesting = true;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('stage resolution', () {
    CreatorWorkspaceStage stage({
      required bool accountApplications,
      String wallet = '',
      DAOReview? review,
      bool profile = true,
    }) =>
        resolveCreatorWorkspaceStage(
          workspace: CreatorWorkspace.artistStudio,
          hasAccountSession: true,
          hasUsableProfile: profile,
          walletAddress: wallet,
          review: review,
          profileGrantsRole: false,
          accountApplications: accountApplications,
        );

    test('a wallet is never a step once the backend authorises accounts', () {
      expect(stage(accountApplications: true), CreatorWorkspaceStage.apply);
      expect(stage(accountApplications: true, profile: false),
          CreatorWorkspaceStage.completeProfile);
    });

    test('against the previous backend the wallet step is kept', () {
      expect(stage(accountApplications: false),
          CreatorWorkspaceStage.linkWalletToApply);
    });

    test('with or without a wallet the answer is the same', () {
      expect(stage(accountApplications: true, wallet: 'w1'),
          stage(accountApplications: true, wallet: ''));
    });
  });

  group('backend contract discovery', () {
    test('parses only a numeric contract level of at least 1', () {
      bool parse(dynamic v) =>
          BackendApiService.parseWalletOptionalCreatorContract(v);
      expect(
          parse({
            'contracts': {'walletOptionalCreator': 1}
          }),
          isTrue);
      expect(
          parse({
            'contracts': {'walletOptionalCreator': 0}
          }),
          isFalse);
      expect(
          parse({
            'contracts': {'walletOptionalCreator': true}
          }),
          isFalse);
      expect(parse({'status': 'ok'}), isFalse);
      expect(parse('nope'), isFalse);
      expect(parse(null), isFalse);
    });

    test('a backend that does not advertise the contract keeps the wallet step',
        () async {
      _use(_FakeBackend(contract: false));
      final supported = await BackendApiService()
          .ensureWalletOptionalCreatorKnown(forceRefresh: true);
      expect(supported, isFalse);
      expect(BackendApiService().walletOptionalCreatorSupported, isFalse);
    });

    test('an unreachable backend is treated as unsupported, never as an error',
        () async {
      final api = BackendApiService();
      api.setHttpClient(MockClient((_) async => throw Exception('offline')));
      addTearDown(() => api.setHttpClient(createPlatformHttpClient()));
      expect(await api.ensureWalletOptionalCreatorKnown(forceRefresh: true),
          isFalse);
    });

    test('an advertising backend enables it', () async {
      _use(_FakeBackend());
      expect(
          await BackendApiService()
              .ensureWalletOptionalCreatorKnown(forceRefresh: true),
          isTrue);
      expect(BackendApiService().walletOptionalCreatorSupported, isTrue);
    });
  });

  group('wallet-free application', () {
    test('is an account request: no envelope, no signer, no wallet', () async {
      final backend = _FakeBackend();
      _use(backend);
      final provider =
          DAOProvider(solanaWalletService: _TestSolanaWalletService());

      final review = await provider.submitReview(
        portfolioUrl: 'example.org/me',
        medium: 'Mural',
        statement: 'I paint walls.',
        title: 'Application',
        metadata: const {'source': 'artist_studio'},
      );

      expect(review, isNotNull);
      expect(review!.status, 'pending');
      expect(review.walletAddress, isEmpty);
      final sent = backend.to('/api/dao/reviews/account').single;
      final body = jsonDecode(sent.body) as Map<String, dynamic>;
      expect(body['role'], 'artist');
      expect(body.containsKey('envelope'), isFalse);
      expect(body.containsKey('walletAddress'), isFalse);
      expect(body['portfolioUrl'], 'https://example.org/me');
      expect(backend.to('/api/dao/reviews'), isEmpty,
          reason: 'the signed legacy endpoint is not used');
      // The result is a pending application, not a granted role.
      expect(provider.myReviewFor(DaoRoleType.artist)?.id, 'review-account-1');
      expect(provider.hasServerCapability(DaoRoleType.artist), isFalse);
    });

    test('an institution applies independently of the artist role', () async {
      final backend = _FakeBackend();
      _use(backend);
      final provider =
          DAOProvider(solanaWalletService: _TestSolanaWalletService());

      await provider.submitInstitutionReview(
        organization: 'Galerija',
        contact: 'https://galerija.example',
        focus: 'Contemporary',
        mission: 'Shows',
      );

      final body =
          jsonDecode(backend.to('/api/dao/reviews/account').single.body)
              as Map<String, dynamic>;
      expect(body['role'], 'institution');
      expect(provider.myReviewFor(DaoRoleType.institution), isNotNull);
      expect(provider.myReviewFor(DaoRoleType.artist), isNull);
    });

    test(
        'a backend refusal surfaces its bounded error code, not a fake success',
        () async {
      _use(_FakeBackend(
        accountReply: (_) => http.Response(
          jsonEncode({
            'success': false,
            'error': 'Complete your profile before applying',
            'errorCode': 'PROFILE_INCOMPLETE',
          }),
          409,
          headers: _json,
        ),
      ));
      final provider =
          DAOProvider(solanaWalletService: _TestSolanaWalletService());

      final review = await provider.submitReview(
        portfolioUrl: 'https://example.org',
        medium: 'Mural',
        statement: 'x',
      );

      expect(review, isNull);
      expect(provider.lastApplicationErrorCode, 'PROFILE_INCOMPLETE');
      expect(provider.myReviewFor(DaoRoleType.artist), isNull);
    });

    test('against the previous backend no account request is attempted',
        () async {
      final backend = _FakeBackend(contract: false);
      _use(backend);
      final provider =
          DAOProvider(solanaWalletService: _TestSolanaWalletService());
      await provider.submitReview(
        portfolioUrl: 'https://example.org',
        medium: 'Mural',
        statement: 'x',
      );
      expect(backend.to('/api/dao/reviews/account'), isEmpty);
    });

    test('own applications and server capabilities load without a wallet',
        () async {
      _use(_FakeBackend(mine: {
        'capabilities': {'artist': false, 'institution': true},
        'applications': {'artist': null, 'institution': null},
        'reviews': [
          {
            'id': 'r-pending-artist',
            'walletAddress': '',
            'portfolioUrl': 'https://x',
            'medium': 'm',
            'statement': 's',
            'status': 'pending',
            'role': 'artist',
            'isArtistApplication': true,
            'isInstitutionApplication': false,
            'createdAt': DateTime.utc(2026, 10, 9).toIso8601String(),
            'metadata': {'role': 'artist'},
          },
        ],
      }));
      await BackendApiService()
          .ensureWalletOptionalCreatorKnown(forceRefresh: true);
      final provider =
          DAOProvider(solanaWalletService: _TestSolanaWalletService());
      await provider.loadMyApplications();

      expect(provider.myReviewFor(DaoRoleType.artist)?.status, 'pending');
      expect(provider.hasServerCapability(DaoRoleType.institution), isTrue);
      // Dual role: a pending artist review does not remove the institution.
      expect(provider.hasServerCapability(DaoRoleType.artist), isFalse);
    });
  });

  group('state never outlives its account', () {
    final grantedArtist = {
      'capabilities': {'artist': true, 'institution': false},
      'applications': {'artist': null, 'institution': null},
      'reviews': <Object?>[],
    };

    test('a second account does not inherit the first account\'s roles',
        () async {
      _use(_FakeBackend(mine: grantedArtist), token: _jwt('account-a'));
      await BackendApiService()
          .ensureWalletOptionalCreatorKnown(forceRefresh: true);
      final provider =
          DAOProvider(solanaWalletService: _TestSolanaWalletService());
      await provider.loadMyApplications();
      expect(provider.hasServerCapability(DaoRoleType.artist), isTrue);

      // Account B signs in; its status request fails.
      BackendApiService().setAuthTokenForTesting(_jwt('account-b'));
      BackendApiService().setHttpClient(MockClient((request) async {
        if (request.url.path == '/health') {
          return http.Response(
              jsonEncode({
                'contracts': {'walletOptionalCreator': 1}
              }),
              200,
              headers: _json);
        }
        return http.Response('boom', 500);
      }));

      // Even before B's status is read, A's role is not B's.
      expect(provider.hasServerCapability(DaoRoleType.artist), isFalse);
      await provider.loadMyApplications();
      expect(provider.hasServerCapability(DaoRoleType.artist), isFalse);
      expect(provider.myReviewFor(DaoRoleType.artist), isNull);
    });

    test('signing out drops the status', () async {
      _use(_FakeBackend(mine: grantedArtist));
      await BackendApiService()
          .ensureWalletOptionalCreatorKnown(forceRefresh: true);
      final provider =
          DAOProvider(solanaWalletService: _TestSolanaWalletService());
      await provider.loadMyApplications();
      expect(provider.hasServerCapability(DaoRoleType.artist), isTrue);

      BackendApiService().setAuthTokenForTesting(null);
      expect(provider.hasServerCapability(DaoRoleType.artist), isFalse);
      await provider.loadMyApplications();
      expect(provider.hasServerCapability(DaoRoleType.artist), isFalse);
    });

    test('the portfolio of one account is cleared when another signs in',
        () async {
      final backend = _FakeBackend();
      _use(backend, token: _jwt('account-a'));
      final portfolio = PortfolioProvider()
        ..setAccountScope(true, accountKey: 'account-a');
      await portfolio.refresh(force: true);
      expect(portfolio.artworks, isNotEmpty);

      portfolio.setAccountScope(true, accountKey: 'account-b');
      expect(portfolio.artworks, isEmpty,
          reason: 'A\'s private work is gone the moment B is current');
      portfolio.setAccountScope(false);
      expect(portfolio.artworks, isEmpty);
      expect(portfolio.collections, isEmpty);
    });

    test(
        'an account that later links a wallet still sees its account-owned work',
        () async {
      final backend = _FakeBackend();
      _use(backend, token: _jwt('account-a'));
      final portfolio = PortfolioProvider()
        ..setAccountScope(true, accountKey: 'account-a')
        ..setWalletAddress('LinkedWallet111111111111111111111111111111111');
      await portfolio.refresh(force: true);

      expect(portfolio.artworks.map((a) => a.title), ['Wall piece']);
      final listed = backend.to('/api/artworks').last.url.queryParameters;
      expect(listed['mine'], 'true');
      expect(listed.containsKey('wallet'), isFalse);
    });
  });

  group('Artist Studio without a wallet', () {
    testWidgets('a signed-in account with a name is offered the application',
        (tester) async {
      final backend = _FakeBackend();
      _use(backend);
      await BackendApiService()
          .ensureWalletOptionalCreatorKnown(forceRefresh: true);
      await _pumpStudio(tester, _walletFreeUser());
      final l10n =
          AppLocalizations.of(tester.element(find.byType(ArtistStudio)))!;

      expect(find.text(l10n.creatorWorkspaceLinkWalletCta), findsNothing);
      expect(find.text(l10n.creatorWorkspaceLinkWalletDetail), findsNothing);
      expect(find.text(l10n.artistStudioCtaApplyForDaoReview), findsWidgets);
      expect(backend.to('/api/dao/reviews/mine'), isNotEmpty,
          reason: 'status is read by account, not by wallet');
      // Regression: a provider notification must not retrigger the load
      // (didChangeDependencies fires for every watched provider).
      await tester.pump(const Duration(seconds: 2));
      expect(backend.to('/api/dao/reviews/mine').length, lessThanOrEqualTo(3));
    });

    testWidgets(
        'the previous backend still asks for a wallet at the application',
        (tester) async {
      _use(_FakeBackend(contract: false));
      await BackendApiService()
          .ensureWalletOptionalCreatorKnown(forceRefresh: true);
      await _pumpStudio(tester, _walletFreeUser());
      final l10n =
          AppLocalizations.of(tester.element(find.byType(ArtistStudio)))!;

      expect(find.text(l10n.creatorWorkspaceLinkWalletCta), findsWidgets);
    });

    testWidgets(
        'a server-granted capability opens the workspace without a wallet',
        (tester) async {
      _use(_FakeBackend(mine: {
        'capabilities': {'artist': true, 'institution': false},
        'applications': {'artist': null, 'institution': null},
        'reviews': <Object?>[],
      }));
      await BackendApiService()
          .ensureWalletOptionalCreatorKnown(forceRefresh: true);
      await _pumpStudio(tester, _walletFreeUser());
      final l10n =
          AppLocalizations.of(tester.element(find.byType(ArtistStudio)))!;

      expect(find.text(l10n.artistStudioLockedTitle), findsNothing);
      expect(find.text(l10n.creatorWorkspaceLinkWalletCta), findsNothing);
    });
  });

  group('Institution Hub without a wallet', () {
    testWidgets('a signed-in account with a name is offered the application',
        (tester) async {
      final backend = _FakeBackend();
      _use(backend);
      await BackendApiService()
          .ensureWalletOptionalCreatorKnown(forceRefresh: true);
      await _pumpStudio(tester, _walletFreeUser(),
          home: const InstitutionHub());
      final l10n =
          AppLocalizations.of(tester.element(find.byType(InstitutionHub)))!;

      expect(find.text(l10n.creatorWorkspaceLinkWalletCta), findsNothing);
      expect(find.text(l10n.creatorWorkspaceLinkWalletDetail), findsNothing);
      expect(backend.to('/api/dao/reviews/mine').length, lessThanOrEqualTo(3));
    });

    testWidgets('the previous backend still asks for a wallet', (tester) async {
      _use(_FakeBackend(contract: false));
      await BackendApiService()
          .ensureWalletOptionalCreatorKnown(forceRefresh: true);
      await _pumpStudio(tester, _walletFreeUser(),
          home: const InstitutionHub());
      final l10n =
          AppLocalizations.of(tester.element(find.byType(InstitutionHub)))!;
      expect(find.text(l10n.creatorWorkspaceLinkWalletCta), findsWidgets);
    });
  });

  group('wallet-free artwork and portfolio', () {
    test(
        'publishing a draft needs a session, not a wallet, and sends no wallet',
        () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      Map<String, dynamic>? sent;
      final backend = _FakeBackend();
      _use(backend);
      // Wrap the fake: capture upload and artwork creation.
      BackendApiService().setHttpClient(MockClient((request) async {
        if (request.url.path == '/api/upload') {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'relativeUrl': '/uploads/artworks/cover.png'},
            }),
            200,
            headers: _json,
          );
        }
        if (request.url.path == '/api/artworks') {
          sent = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'id': '33333333-3333-4333-8333-333333333333',
                'title': 'Wall piece',
                'description': 'Documented',
                'imageUrl': '/uploads/artworks/cover.png',
                'isPublic': true,
                'isActive': true,
                'category': 'General',
                'createdAt': DateTime.utc(2026, 10, 9).toIso8601String(),
              },
            }),
            201,
            headers: _json,
          );
        }
        return backend.client.get(request.url);
      }));
      await BackendApiService()
          .ensureWalletOptionalCreatorKnown(forceRefresh: true);

      final provider = ArtworkDraftsProvider();
      final draftId = provider.createDraft();
      provider.updateBasics(
        draftId: draftId,
        title: 'Wall piece',
        description: 'Documented',
      );
      provider.setCover(draftId: draftId, bytes: _png(), fileName: 'cover.png');

      final artwork = await provider.submitDraft(
        draftId: draftId,
        walletAddress: '',
        l10n: l10n,
      );

      expect(artwork, isNotNull);
      expect(sent, isNotNull);
      expect(sent!.containsKey('walletAddress'), isFalse);
      // Authorship is explicit: the submitter is never filled in as the artist.
      expect(sent!.containsKey('artistName'), isFalse);
    });

    test('an old backend still refuses to publish without a wallet', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final backend = _FakeBackend(contract: false);
      _use(backend);
      await BackendApiService()
          .ensureWalletOptionalCreatorKnown(forceRefresh: true);
      final provider = ArtworkDraftsProvider();
      final draftId = provider.createDraft();
      provider.updateBasics(
          draftId: draftId, title: 'Wall piece', description: 'Documented');
      provider.setCover(draftId: draftId, bytes: _png(), fileName: 'c.png');

      expect(
        await provider.submitDraft(
            draftId: draftId, walletAddress: '', l10n: l10n),
        isNull,
      );
      expect(backend.to('/api/artworks'), isEmpty);
      expect(backend.to('/api/upload'), isEmpty);
    });

    test('the portfolio loads by account when there is no wallet', () async {
      final backend = _FakeBackend();
      _use(backend);
      await BackendApiService()
          .ensureWalletOptionalCreatorKnown(forceRefresh: true);
      final portfolio = PortfolioProvider()..setAccountScope(true);
      await portfolio.refresh(force: true);

      expect(portfolio.artworks.map((a) => a.title), ['Wall piece']);
      expect(portfolio.collections.map((c) => c.name), ['Walls']);
      expect(backend.to('/api/artworks').first.url.queryParameters['mine'],
          'true');
      expect(backend.to('/api/artworks').first.url.queryParameters['wallet'],
          isNull);
    });

    test('without an account scope an empty wallet loads nothing', () async {
      final backend = _FakeBackend();
      _use(backend);
      final portfolio = PortfolioProvider();
      await portfolio.refresh(force: true);
      expect(portfolio.artworks, isEmpty);
      expect(backend.to('/api/artworks'), isEmpty);
    });
  });
}
