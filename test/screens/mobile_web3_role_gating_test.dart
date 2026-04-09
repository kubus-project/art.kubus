import 'dart:convert';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/dao.dart';
import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/providers/collab_provider.dart';
import 'package:art_kubus/providers/dao_provider.dart';
import 'package:art_kubus/providers/exhibitions_provider.dart';
import 'package:art_kubus/providers/notification_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/providers/web3provider.dart';
import 'package:art_kubus/screens/web3/artist/artist_studio.dart';
import 'package:art_kubus/screens/web3/institution/institution_hub.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/solana_wallet_service.dart';
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
  }) async {
    return 0;
  }
}

Map<String, dynamic> _daoReviewJson({
  required String status,
  required String role,
}) {
  return <String, dynamic>{
    'id': 'review-1',
    'walletAddress': 'wallet-1',
    'portfolioUrl': 'https://example.com',
    'medium': 'painting',
    'statement': 'statement',
    'status': status,
    'createdAt': DateTime.utc(2026, 4, 9).toIso8601String(),
    'metadata': <String, dynamic>{'role': role},
  };
}

UserProfile _buildUser({
  bool isArtist = false,
  bool isInstitution = false,
  String? persona,
}) {
  return UserProfile(
    id: 'user-1',
    walletAddress: 'wallet-1',
    username: 'artist',
    displayName: 'Artist',
    bio: 'bio',
    avatar: '',
    isArtist: isArtist,
    isInstitution: isInstitution,
    preferences: ProfilePreferences(persona: persona),
    createdAt: DateTime.utc(2026, 4, 9),
    updatedAt: DateTime.utc(2026, 4, 9),
  );
}

void _configureBackendApi({Map<String, dynamic>? reviewJson}) {
  final api = BackendApiService();
  api.setAuthTokenForTesting('test-token');
  api.setHttpClient(
    MockClient((request) async {
      final path = request.url.path;
      final headers = const <String, String>{
        'content-type': 'application/json',
      };

      if (path == '/api/dao/proposals') {
        return http.Response(
            jsonEncode(<String, Object?>{'data': <Object?>[]}), 200,
            headers: headers);
      }
      if (path == '/api/dao/votes') {
        return http.Response(
            jsonEncode(<String, Object?>{'votes': <Object?>[]}), 200,
            headers: headers);
      }
      if (path == '/api/dao/delegates') {
        return http.Response(
            jsonEncode(<String, Object?>{'delegates': <Object?>[]}), 200,
            headers: headers);
      }
      if (path == '/api/dao/transactions') {
        return http.Response(
            jsonEncode(<String, Object?>{'data': <Object?>[]}), 200,
            headers: headers);
      }
      if (path == '/api/dao/reviews') {
        final payload =
            reviewJson == null ? <Object?>[] : <Object?>[reviewJson];
        return http.Response(
            jsonEncode(<String, Object?>{'reviews': payload}), 200,
            headers: headers);
      }
      if (path == '/api/dao/reviews/wallet-1') {
        if (reviewJson == null) {
          return http.Response('', 404, headers: headers);
        }
        return http.Response(
            jsonEncode(<String, Object?>{'review': reviewJson}), 200,
            headers: headers);
      }
      if (path == '/api/public/home-rails') {
        return http.Response(
            jsonEncode(<String, Object?>{'rails': <Object?>[]}), 200,
            headers: headers);
      }
      if (path == '/api/exhibitions') {
        return http.Response(
            jsonEncode(<String, Object?>{
              'data': <String, Object?>{'exhibitions': <Object?>[]},
            }),
            200,
            headers: headers);
      }

      return http.Response('', 404, headers: headers);
    }),
  );
}

Future<void> _pumpArtistStudio(
  WidgetTester tester, {
  required UserProfile user,
  Map<String, dynamic>? reviewJson,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'Artist Studio_onboarding_completed': true,
  });
  _configureBackendApi(reviewJson: reviewJson);
  await tester.binding.setSurfaceSize(const Size(900, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final themeProvider = ThemeProvider();
  final profileProvider = ProfileProvider()..setCurrentUser(user);
  final daoProvider =
      DAOProvider(solanaWalletService: _TestSolanaWalletService());

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ChangeNotifierProvider<ProfileProvider>.value(value: profileProvider),
        ChangeNotifierProvider<DAOProvider>.value(value: daoProvider),
        ChangeNotifierProvider<Web3Provider>(create: (_) => Web3Provider()),
        ChangeNotifierProvider<CollabProvider>(create: (_) => CollabProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) => MaterialApp(
          theme: theme.lightTheme,
          darkTheme: theme.darkTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ArtistStudio(),
        ),
      ),
    ),
  );

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
}

Future<void> _pumpInstitutionHub(
  WidgetTester tester, {
  required UserProfile user,
  Map<String, dynamic>? reviewJson,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'Institution Hub_onboarding_completed': true,
  });
  _configureBackendApi(reviewJson: reviewJson);
  await tester.binding.setSurfaceSize(const Size(900, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final themeProvider = ThemeProvider();
  final profileProvider = ProfileProvider()..setCurrentUser(user);
  final daoProvider =
      DAOProvider(solanaWalletService: _TestSolanaWalletService());

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ChangeNotifierProvider<ProfileProvider>.value(value: profileProvider),
        ChangeNotifierProvider<DAOProvider>.value(value: daoProvider),
        ChangeNotifierProvider<Web3Provider>(create: (_) => Web3Provider()),
        ChangeNotifierProvider<CollabProvider>(create: (_) => CollabProvider()),
        ChangeNotifierProvider<NotificationProvider>(
          create: (_) => NotificationProvider(),
        ),
        ChangeNotifierProvider<ExhibitionsProvider>(
          create: (_) => ExhibitionsProvider(),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) => MaterialApp(
          theme: theme.lightTheme,
          darkTheme: theme.darkTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const InstitutionHub(),
        ),
      ),
    ),
  );

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('artist promotion helper covers non-approved artist states', () {
    expect(
      resolveArtistPromotionUnavailableReason(
        walletAddress: '',
        review: null,
      ),
      'Connect an approved artist wallet to request profile promotion.',
    );

    expect(
      resolveArtistPromotionUnavailableReason(
        walletAddress: 'wallet-1',
        review: DAOReview.fromJson(
          _daoReviewJson(status: 'pending', role: 'artist'),
        ),
      ),
      'Profile promotion is available only for approved artist wallets.',
    );

    expect(
      resolveArtistPromotionUnavailableReason(
        walletAddress: 'wallet-1',
        review: DAOReview.fromJson(
          _daoReviewJson(status: 'rejected', role: 'artist'),
        ),
      ),
      'Profile promotion is available only for approved artist wallets.',
    );

    expect(
      resolveArtistPromotionUnavailableReason(
        walletAddress: 'wallet-1',
        review: null,
      ),
      'Profile promotion is available only for approved artist wallets.',
    );

    expect(
      resolveArtistPromotionUnavailableReason(
        walletAddress: 'wallet-1',
        review: DAOReview.fromJson(
          _daoReviewJson(status: 'pending', role: 'institution'),
        ),
      ),
      'Institution wallets cannot self-serve artist promotion. Use a dedicated artist wallet.',
    );
  });

  testWidgets('approved artists see both mobile promotion entry points',
      (tester) async {
    await _pumpArtistStudio(
      tester,
      user: _buildUser(isArtist: true, persona: 'creator'),
      reviewJson: _daoReviewJson(status: 'approved', role: 'artist'),
    );

    expect(find.byTooltip('Promote my profile'), findsOneWidget);
    expect(find.text('Promote my profile'), findsOneWidget);
  });

  testWidgets(
      'institution-pending wallets hide artist promotion actions and show warning on guarded flow',
      (tester) async {
    await _pumpArtistStudio(
      tester,
      user: _buildUser(isInstitution: true, persona: 'institution'),
      reviewJson: _daoReviewJson(status: 'pending', role: 'institution'),
    );

    expect(find.byTooltip('Promote my profile'), findsNothing);
    expect(find.text('Promote my profile'), findsNothing);

    final dynamic state = tester.state(find.byType(ArtistStudio));
    await state.debugOpenProfilePromotionFlow();
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Institution wallets cannot self-serve artist promotion. Use a dedicated artist wallet.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
      'institution hub header removes shortcut buttons but keeps tab navigation',
      (tester) async {
    await _pumpInstitutionHub(
      tester,
      user: _buildUser(isInstitution: true, persona: 'institution'),
      reviewJson: _daoReviewJson(status: 'approved', role: 'institution'),
    );

    expect(find.text('Create event'), findsNothing);
    expect(find.text('Events'), findsOneWidget);
    expect(find.text('Exhibitions'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);
    expect(find.text('Analytics'), findsOneWidget);
  });
}
