import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/user_persona.dart';
import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/providers/locale_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/screens/auth/sign_in_screen.dart';
import 'package:art_kubus/screens/onboarding/onboarding_flow_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:art_kubus/widgets/auth_title_row.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:art_kubus/widgets/kubus_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildTestApp({
  required Widget child,
  required Locale locale,
  double viewInsetsBottom = 0,
  Size size = const Size(390, 844),
  ThemeData? theme,
  ThemeData? darkTheme,
  ThemeMode themeMode = ThemeMode.system,
  ProfileProvider? profileProvider,
}) {
  final resolvedProfileProvider = profileProvider ?? ProfileProvider();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
      ChangeNotifierProvider<ProfileProvider>.value(
          value: resolvedProfileProvider),
      ChangeNotifierProvider<WalletProvider>(
        create: (_) => WalletProvider(deferInit: true),
      ),
    ],
    child: MaterialApp(
      theme: theme ?? ThemeData.light(useMaterial3: true),
      darkTheme: darkTheme ?? ThemeData.dark(useMaterial3: true),
      themeMode: themeMode,
      routes: <String, WidgetBuilder>{
        '/main': (_) => const Scaffold(body: Text('Main shell')),
      },
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          viewInsets: EdgeInsets.only(bottom: viewInsetsBottom),
        ),
        child: child,
      ),
    ),
  );
}

Future<void> _pumpOnboardingReady(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 4),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 120));
    final hasLoading =
        find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
    if (!hasLoading) {
      return;
    }
  }
  await tester.pump(const Duration(milliseconds: 120));
}

void _installBackendMock(
  Future<http.Response> Function(http.Request request) handler,
) {
  BackendApiService().setHttpClient(MockClient(handler));
}

String _buildJwt({
  required String email,
  String? walletAddress,
}) {
  final payload = base64Url
      .encode(
        utf8.encode(
          jsonEncode(<String, Object>{
            'email': email,
            if (walletAddress != null) 'walletAddress': walletAddress,
            'sub': 'test',
          }),
        ),
      )
      .replaceAll('=', '');
  return 'e30.$payload.';
}

Map<String, dynamic> _profileJson({
  required String walletAddress,
  String username = 'role_user',
  String displayName = 'Role User',
  String? persona,
}) {
  return <String, dynamic>{
    'id': 'profile_$walletAddress',
    'walletAddress': walletAddress,
    'username': username,
    'displayName': displayName,
    'bio': '',
    'avatar': '',
    'preferences': <String, dynamic>{
      if (persona != null) 'persona': persona,
    },
    'createdAt': DateTime(2026, 3, 16).toIso8601String(),
    'updatedAt': DateTime(2026, 3, 16).toIso8601String(),
  };
}

/// Fake [ProfileProvider] that avoids real network/upload work so we can assert
/// the onboarding avatar flush + hydration logic in isolation.
class _FakeAvatarProfileProvider extends ProfileProvider {
  _FakeAvatarProfileProvider(UserProfile user) {
    setCurrentUser(user);
  }

  String uploadResult = 'https://cdn.example/onboarding-avatar.png';

  /// When non-null, [loadAuthenticatedProfile] rewrites the avatar to this
  /// value (use '' to simulate a backend reload that briefly drops the avatar).
  String? reloadAvatar;
  int reloadCount = 0;

  @override
  Future<String> uploadAvatarBytes({
    required List<int> fileBytes,
    required String fileName,
    required String walletAddress,
    String? mimeType,
  }) async =>
      uploadResult;

  @override
  Future<bool> saveProfile({
    required String walletAddress,
    String? username,
    String? displayName,
    String? bio,
    String? avatar,
    String? coverImage,
    Map<String, String>? social,
    List<String>? fieldOfWork,
    int? yearsActive,
    bool? isArtist,
    bool? isInstitution,
    ProfilePreferences? preferences,
    bool reloadStats = true,
  }) async {
    final current = currentUser;
    if (current != null && avatar != null) {
      setCurrentUser(current.copyWith(avatar: avatar));
    }
    return true;
  }

  @override
  Future<void> loadAuthenticatedProfile() async {
    reloadCount += 1;
    final current = currentUser;
    final next = reloadAvatar;
    if (current != null && next != null) {
      setCurrentUser(current.copyWith(avatar: next));
    }
  }
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 4),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 120));
    if (finder.evaluate().isNotEmpty) return;
  }
}

Future<void> _pumpUntilCondition(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 4),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 120));
    if (condition()) return;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setAuthTokenForTesting(null);
    _installBackendMock((_) async => http.Response(
          jsonEncode(<String, dynamic>{'success': false}),
          404,
          headers: <String, String>{'content-type': 'application/json'},
        ));
  });

  tearDown(() {
    final api = BackendApiService();
    api.setAuthTokenForTesting(null);
    api.setHttpClient(createPlatformHttpClient());
  });

  testWidgets('onboarding starts at unified welcome phase', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingFlowScreen(),
        locale: const Locale('en'),
      ),
    );
    await _pumpOnboardingReady(tester);

    expect(find.byType(PageView), findsNothing);
    expect(find.text('art.kubus is an open art platform.'), findsOneWidget);
    expect(find.text('Create an account'), findsWidgets);
    expect(find.text('Discover art'), findsWidgets);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('welcome screen shows both branch buttons on page',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingFlowScreen(),
        locale: const Locale('en'),
      ),
    );
    await _pumpOnboardingReady(tester);

    final createAccountButton = find.text('Create an account');
    final discoverArtButton = find.text('Discover art');
    expect(createAccountButton, findsWidgets);
    expect(discoverArtButton, findsWidgets);
    expect(find.text('art.kubus is an open art platform.'), findsOneWidget);
  });

  testWidgets('guest branch: discover art → permissions → done',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingFlowScreen(),
        locale: const Locale('en'),
      ),
    );
    await _pumpOnboardingReady(tester);

    // Tap "Discover art" to enter guest branch
    await tester.tap(find.widgetWithText(KubusOutlineButton, 'Discover art'));
    await tester.pumpAndSettle();

    // Should show permissions step
    expect(find.text('Choose what to enable'), findsOneWidget);
    expect(find.text('Location'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
  });

  testWidgets('account branch: create account shows auth panel',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingFlowScreen(),
        locale: const Locale('en'),
      ),
    );
    await _pumpOnboardingReady(tester);

    // Tap "Create an account" to enter account branch
    await tester.tap(find.widgetWithText(KubusButton, 'Create an account'));
    await tester.pumpAndSettle();

    // Should show account step with auth panel
    expect(find.text('Create your profile first'), findsOneWidget);
  });

  testWidgets(
      'incomplete wallet backup does not add a mandatory wallet backup step',
      (tester) async {
    // Wallet backup is recommended, not required: even when the recovery phrase
    // is flagged as not yet backed up, the account flow must not insert a
    // walletBackupIntro / walletBackup gate.
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    const walletAddress = '4Nd1m5sP3v1bE7c9Q2w6z8YkLmNoPrStUvWxYzABcDeF';
    SharedPreferences.setMockInitialValues(<String, Object>{
      'wallet_address': walletAddress,
      '${PreferenceKeys.walletMnemonicBackupRequiredV1Prefix}:$walletAddress':
          true,
    });

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingFlowScreen(initialStepId: 'profile'),
        locale: const Locale('en'),
        size: const Size(390, 1200),
      ),
    );
    await _pumpOnboardingReady(tester);

    final state = tester.state(find.byType(OnboardingFlowScreen)) as dynamic;
    final List<String> stepIds = List<String>.from(state.debugStepIds);

    expect(stepIds, isNot(contains('walletBackupIntro')));
    expect(stepIds, isNot(contains('walletBackup')));
    // The user is never parked on a backup step.
    expect(state.debugCurrentStepId, isNot('walletBackupIntro'));
    expect(state.debugCurrentStepId, isNot('walletBackup'));

    final l10n = AppLocalizations.of(
      tester.element(find.byType(OnboardingFlowScreen)),
    )!;
    expect(find.text(l10n.onboardingFlowWalletBackupIntroTitle), findsNothing);
  });

  testWidgets(
      'routing to legacy walletBackupIntro id does not trap the user on a backup gate',
      (tester) async {
    // Older builds (and AuthOnboardingService resume) may still hand us a
    // walletBackupIntro/walletBackup initial step id. The flow must migrate
    // forward to a real step instead of blocking on a backup gate.
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    const walletAddress = '4Nd1m5sP3v1bE7c9Q2w6z8YkLmNoPrStUvWxYzABcDeF';
    SharedPreferences.setMockInitialValues(<String, Object>{
      'wallet_address': walletAddress,
      '${PreferenceKeys.walletMnemonicBackupRequiredV1Prefix}:$walletAddress':
          true,
    });

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingFlowScreen(initialStepId: 'walletBackupIntro'),
        locale: const Locale('en'),
        size: const Size(390, 1200),
      ),
    );
    await _pumpOnboardingReady(tester);

    expect(tester.takeException(), isNull);
    final state = tester.state(find.byType(OnboardingFlowScreen)) as dynamic;
    expect(state.debugStepIds, isNot(contains('walletBackupIntro')));
    expect(state.debugCurrentStepId, isNot('walletBackupIntro'));
    expect(state.debugCurrentStepId, isNot('walletBackup'));
  });

  testWidgets(
      'staged onboarding avatar is flushed and pinned before reaching main shell',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    const wallet = '0xavataronboarding';
    final provider = _FakeAvatarProfileProvider(
      UserProfile(
        id: 'profile_avatar',
        walletAddress: wallet,
        username: 'avatar_user',
        displayName: 'Avatar User',
        bio: '',
        avatar: '',
        createdAt: DateTime(2026, 3, 16),
        updatedAt: DateTime(2026, 3, 16),
      ),
    );

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingFlowScreen(initialStepId: 'profile'),
        locale: const Locale('en'),
        size: const Size(390, 1200),
        profileProvider: provider,
      ),
    );
    await _pumpOnboardingReady(tester);

    final state = tester.state(find.byType(OnboardingFlowScreen)) as dynamic;

    await state.debugStageAvatar(
      bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
      fileName: 'avatar.png',
      mimeType: 'image/png',
    );

    final uploaded = await state.debugFlushPendingAvatarUpload() as String?;
    expect(uploaded, provider.uploadResult);
    // Flush pins the resolved avatar onto the in-memory profile + local draft.
    expect(provider.currentUser?.avatar, provider.uploadResult);
    expect(state.debugLocalProfileDraftAvatar, provider.uploadResult);

    // Simulate a backend reload that briefly returns no avatar right after the
    // upload: hydration must keep the uploaded URL so the shell shows it now.
    provider.reloadAvatar = '';
    await state.debugEnsureAvatarHydratedForMainShell(uploaded);
    expect(provider.reloadCount, greaterThanOrEqualTo(1));
    expect(provider.currentUser?.avatar, provider.uploadResult);
  });

  testWidgets('avatar hydration keeps a fresh reloaded avatar from the backend',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    const wallet = '0xavatarreload';
    final provider = _FakeAvatarProfileProvider(
      UserProfile(
        id: 'profile_avatar_reload',
        walletAddress: wallet,
        username: 'avatar_reload',
        displayName: 'Avatar Reload',
        bio: '',
        avatar: '',
        createdAt: DateTime(2026, 3, 16),
        updatedAt: DateTime(2026, 3, 16),
      ),
    );

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingFlowScreen(initialStepId: 'profile'),
        locale: const Locale('en'),
        size: const Size(390, 1200),
        profileProvider: provider,
      ),
    );
    await _pumpOnboardingReady(tester);

    final state = tester.state(find.byType(OnboardingFlowScreen)) as dynamic;

    const reloaded = 'https://cdn.example/reloaded-avatar.png';
    provider.reloadAvatar = reloaded;
    await state.debugEnsureAvatarHydratedForMainShell(
      'https://cdn.example/uploaded-avatar.png',
    );
    // A valid reloaded avatar wins; the uploaded fallback does not clobber it.
    expect(provider.currentUser?.avatar, reloaded);
  });

  testWidgets(
      'verification manual check keeps onboarding on verify step while pending',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1024));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    SharedPreferences.setMockInitialValues(<String, Object>{
      'onboarding_verification_email_v3': 'pending@example.com',
    });

    _installBackendMock((request) async {
      if (request.url.path == '/api/auth/email-status') {
        return http.Response(
          jsonEncode(<String, dynamic>{'success': true, 'verified': false}),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode(<String, dynamic>{'success': true}),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingFlowScreen(initialStepId: 'verifyEmail'),
        locale: const Locale('en'),
        size: const Size(390, 1024),
      ),
    );
    await _pumpOnboardingReady(tester);
    expect(find.text('I verified / Continue'), findsWidgets);

    await tester.tap(find.text('I verified / Continue').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));

    expect(
        find.text('After verifying, return here to sign in.'), findsOneWidget);
    expect(find.text('Choose what to enable'), findsNothing);
    expect(
      find.ancestor(
        of: find.text('After verifying, return here to sign in.'),
        matching: find.byType(LiquidGlassPanel),
      ),
      findsWidgets,
    );
  });

  testWidgets('verified email completes only verifyEmail and advances to role',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1024));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    const email = 'verified-role@example.com';
    SharedPreferences.setMockInitialValues(<String, Object>{
      'onboarding_verification_email_v3': email,
    });
    BackendApiService().setAuthTokenForTesting(_buildJwt(email: email));

    var statusChecks = 0;
    _installBackendMock((request) async {
      if (request.url.path == '/api/auth/email-status') {
        statusChecks += 1;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'success': true,
            'verified': true,
          }),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode(<String, dynamic>{'success': true}),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingFlowScreen(initialStepId: 'verifyEmail'),
        locale: const Locale('en'),
        size: const Size(390, 1024),
      ),
    );
    await _pumpOnboardingReady(tester);
    await _pumpUntilFound(tester, find.text('I verified / Continue'));

    await tester.tap(find.text('I verified / Continue').last);
    await _pumpUntilFound(tester, find.text('Pick your role'));
    expect(statusChecks, greaterThanOrEqualTo(1));

    expect(find.text('Pick your role'), findsOneWidget);
    expect(find.text('Create your profile'), findsNothing);
    expect(find.text('Choose what to enable'), findsNothing);
    expect(find.text("You're all set"), findsNothing);

    final prefs = await SharedPreferences.getInstance();
    final completed =
        prefs.getStringList('onboarding_completed_steps_v2') ?? const [];
    expect(completed, contains('account'));
    expect(completed, contains('verifyEmail'));
    expect(completed, isNot(contains('role')));
    expect(completed, isNot(contains('profile')));
    expect(completed, isNot(contains('done')));
  });

  testWidgets('verification confirm does not sync stale profile draft',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1024));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    const email = 'draft-sync@example.com';
    final profileProvider = ProfileProvider()
      ..setCurrentUser(UserProfile(
        id: 'profile_draft_sync',
        walletAddress: '0xdraftsync',
        username: 'draft_sync',
        displayName: 'Draft Sync',
        bio: '',
        avatar: '',
        createdAt: DateTime(2026, 3, 16),
        updatedAt: DateTime(2026, 3, 16),
      ));
    SharedPreferences.setMockInitialValues(<String, Object>{
      'onboarding_verification_email_v3': email,
      'onboarding_profile_draft_v3': jsonEncode(<String, String>{
        'displayName': 'Stale Draft',
        'username': 'stale_draft',
      }),
    });
    BackendApiService().setAuthTokenForTesting(_buildJwt(email: email));

    var statusChecks = 0;
    var profileSaves = 0;
    _installBackendMock((request) async {
      if (request.url.path == '/api/auth/email-status') {
        statusChecks += 1;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'success': true,
            'verified': true,
          }),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }
      if (request.method == 'POST' && request.url.path == '/api/profiles') {
        profileSaves += 1;
      }
      return http.Response(
        jsonEncode(<String, dynamic>{'success': true}),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingFlowScreen(initialStepId: 'verifyEmail'),
        locale: const Locale('en'),
        size: const Size(390, 1024),
        profileProvider: profileProvider,
      ),
    );
    await _pumpOnboardingReady(tester);
    await _pumpUntilFound(tester, find.text('I verified / Continue'));

    await tester.tap(find.text('I verified / Continue').last);
    await _pumpUntilFound(tester, find.text('Pick your role'));
    expect(statusChecks, greaterThanOrEqualTo(1));

    expect(find.text('Pick your role'), findsOneWidget);
    expect(profileSaves, 0);
  });

  testWidgets('primary action on role does not skip or defer role',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1024));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingFlowScreen(initialStepId: 'role'),
        locale: const Locale('en'),
        size: const Size(390, 1024),
      ),
    );
    await _pumpOnboardingReady(tester);
    expect(find.text('Pick your role'), findsOneWidget);

    final state = tester.state(find.byType(OnboardingFlowScreen)) as dynamic;
    await state.debugTriggerPrimaryAction();
    await tester.pump();

    expect(state.debugCurrentStepId, 'role');
    expect(state.debugCompletedStepIds, isNot(contains('role')));
    expect(state.debugCompletedStepIds, isNot(contains('profile')));
    expect(
      find.text('Choose how you want to use art.kubus before continuing.'),
      findsOneWidget,
    );
  });

  testWidgets('role selection saves persona and advances to profile',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    const wallet = '0xrolesuccess';
    BackendApiService().setAuthTokenForTesting(
      _buildJwt(email: 'role-success@example.com', walletAddress: wallet),
    );
    final profileProvider = ProfileProvider()
      ..setCurrentUser(UserProfile(
        id: 'profile_role_success',
        walletAddress: wallet,
        username: 'role_success',
        displayName: 'Role Success',
        bio: '',
        avatar: '',
        createdAt: DateTime(2026, 3, 16),
        updatedAt: DateTime(2026, 3, 16),
      ));

    final saveCompleter = Completer<void>();
    var personaSaves = 0;
    _installBackendMock((request) async {
      if (request.method == 'POST' && request.url.path == '/api/profiles') {
        personaSaves += 1;
        await saveCompleter.future;
        return http.Response(
          jsonEncode(_profileJson(
            walletAddress: wallet,
            username: 'role_success',
            displayName: 'Role Success',
            persona: 'lover',
          )),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/api/profiles/$wallet') {
        return http.Response(
          jsonEncode(_profileJson(
            walletAddress: wallet,
            username: 'role_success',
            displayName: 'Role Success',
            persona: 'lover',
          )),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode(<String, dynamic>{'success': true}),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingFlowScreen(initialStepId: 'role'),
        locale: const Locale('en'),
        size: const Size(390, 1200),
        profileProvider: profileProvider,
      ),
    );
    await _pumpOnboardingReady(tester);

    await tester.tap(find.text('Art lover'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsWidgets);
    await _pumpUntilCondition(tester, () => personaSaves == 1);

    saveCompleter.complete();
    await _pumpUntilFound(tester, find.text('Create your profile'));

    final state = tester.state(find.byType(OnboardingFlowScreen)) as dynamic;
    expect(state.debugCurrentStepId, 'profile');
    expect(state.debugCompletedStepIds, contains('role'));
  });

  testWidgets('role selection backend failure stays retryable on role',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    const wallet = '0xrolefailure';
    BackendApiService().setAuthTokenForTesting(
      _buildJwt(email: 'role-failure@example.com', walletAddress: wallet),
    );
    final profileProvider = ProfileProvider()
      ..setCurrentUser(UserProfile(
        id: 'profile_role_failure',
        walletAddress: wallet,
        username: 'role_failure',
        displayName: 'Role Failure',
        bio: '',
        avatar: '',
        createdAt: DateTime(2026, 3, 16),
        updatedAt: DateTime(2026, 3, 16),
      ));

    var personaSaves = 0;
    _installBackendMock((request) async {
      if (request.method == 'POST' && request.url.path == '/api/profiles') {
        personaSaves += 1;
        return http.Response(
          jsonEncode(<String, dynamic>{'error': 'save failed'}),
          400,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode(_profileJson(walletAddress: wallet)),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingFlowScreen(initialStepId: 'role'),
        locale: const Locale('en'),
        size: const Size(390, 1200),
        profileProvider: profileProvider,
      ),
    );
    await _pumpOnboardingReady(tester);

    await tester.tap(find.text('Art lover'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 8));

    final state = tester.state(find.byType(OnboardingFlowScreen)) as dynamic;
    expect(personaSaves, greaterThanOrEqualTo(1));
    expect(state.debugCurrentStepId, 'role');
    expect(state.debugCompletedStepIds, isNot(contains('role')));
    expect(
      find.text('We could not save your role. Please try again.'),
      findsOneWidget,
    );

    final attemptsAfterFirstTap = personaSaves;
    await tester.tap(find.text('Art lover'));
    await tester.pump(const Duration(seconds: 8));
    expect(personaSaves, greaterThan(attemptsAfterFirstTap));
  });

  testWidgets('primary action on role persists existing local selection',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    SharedPreferences.setMockInitialValues(<String, Object>{
      'onboarding_persona_draft_v3': UserPersona.lover.storageValue,
    });

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingFlowScreen(initialStepId: 'role'),
        locale: const Locale('en'),
        size: const Size(390, 1200),
      ),
    );
    await _pumpOnboardingReady(tester);

    final state = tester.state(find.byType(OnboardingFlowScreen)) as dynamic;
    await state.debugTriggerPrimaryAction();
    await _pumpUntilFound(tester, find.text('Create your profile'));

    expect(state.debugCurrentStepId, 'profile');
    expect(state.debugCompletedStepIds, contains('role'));
  });

  testWidgets('verification confirm resets loading state after failure',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1024));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    const email = 'confirm-fails@example.com';
    SharedPreferences.setMockInitialValues(<String, Object>{
      'onboarding_verification_email_v3': email,
    });

    var statusChecks = 0;
    final confirmStatusReady = Completer<void>();
    _installBackendMock((request) async {
      if (request.url.path == '/api/auth/email-status') {
        statusChecks += 1;
        await confirmStatusReady.future;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'success': true,
            'verified': true,
          }),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode(<String, dynamic>{'success': true}),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingFlowScreen(initialStepId: 'verifyEmail'),
        locale: const Locale('en'),
        size: const Size(390, 1024),
      ),
    );
    await _pumpOnboardingReady(tester);
    await _pumpUntilFound(tester, find.text('I verified / Continue'));

    final state = tester.state(find.byType(OnboardingFlowScreen)) as dynamic;
    final action = state.debugTriggerPrimaryAction() as Future<void>;
    await tester.pump();

    expect(state.debugVerificationConfirmInFlight, isTrue);

    confirmStatusReady.complete();
    await action;
    await tester.pump();

    expect(statusChecks, greaterThanOrEqualTo(1));
    expect(state.debugVerificationConfirmInFlight, isFalse);
    expect(find.text('Pick your role'), findsNothing);
    expect(find.text('Sign in to finish'), findsOneWidget);
  });

  testWidgets(
      'verification auto-check on app resume shows finish sign-in prompt after verify',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1024));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    SharedPreferences.setMockInitialValues(<String, Object>{
      'onboarding_verification_email_v3': 'resume-check@example.com',
    });

    var statusChecks = 0;
    _installBackendMock((request) async {
      if (request.url.path == '/api/auth/email-status') {
        statusChecks += 1;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'success': true,
            'verified': statusChecks >= 2,
          }),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode(<String, dynamic>{'success': true}),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingFlowScreen(initialStepId: 'verifyEmail'),
        locale: const Locale('en'),
        size: const Size(390, 1024),
      ),
    );
    await _pumpOnboardingReady(tester);
    expect(find.text('I verified / Continue'), findsWidgets);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpUntilFound(tester, find.text('Sign in to finish'));

    expect(statusChecks, greaterThanOrEqualTo(2));
    expect(find.text('Sign in to finish'), findsOneWidget);
    expect(find.text('Choose what to enable'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('verified email with active session advances to role',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1024));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    const email = 'captured-login@example.com';
    final token = _buildJwt(email: email);
    SharedPreferences.setMockInitialValues(<String, Object>{
      'onboarding_verification_email_v3': email,
      'jwt_token': token,
    });

    BackendApiService().setAuthTokenForTesting(token);
    _installBackendMock((request) async {
      if (request.url.path == '/api/auth/email-status') {
        return http.Response(
          jsonEncode(<String, dynamic>{'success': true, 'verified': true}),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/api/profiles/me') {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'success': true,
            'data': <String, dynamic>{
              ..._profileJson(
                walletAddress: '',
                username: 'captured_backend',
                displayName: 'Captured Backend',
              ),
              'userId': 'user-captured',
              'requiresWalletSetup': true,
            },
          }),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode(<String, dynamic>{'success': true}),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingFlowScreen(initialStepId: 'verifyEmail'),
        locale: const Locale('en'),
        size: const Size(390, 1024),
      ),
    );
    await _pumpOnboardingReady(tester);

    final state = tester.state(find.byType(OnboardingFlowScreen)) as dynamic;
    var actionCompleted = false;
    unawaited(
      (state.debugTriggerPrimaryAction() as Future<void>).whenComplete(
        () => actionCompleted = true,
      ),
    );
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (!actionCompleted && DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(actionCompleted, isTrue);
    await _pumpUntilFound(tester, find.text('Pick your role'));

    expect(state.debugVerificationConfirmInFlight, isFalse);
    expect(state.debugCurrentStepId, 'role');
    expect(state.debugCompletedStepIds, contains('verifyEmail'));
    expect(state.debugCompletedStepIds, isNot(contains('role')));
  });

  testWidgets('stale provider persona cannot skip role after verification',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1024));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    const email = 'stale-persona@example.com';
    final token = _buildJwt(email: email);
    final profileProvider = ProfileProvider()
      ..setCurrentUser(UserProfile(
        id: 'profile_old',
        walletAddress: '0xoldsessionwallet',
        username: 'old_user',
        displayName: 'Old User',
        bio: '',
        avatar: '',
        preferences: ProfilePreferences(persona: 'creator'),
        createdAt: DateTime(2026, 3, 16),
        updatedAt: DateTime(2026, 3, 16),
      ));
    SharedPreferences.setMockInitialValues(<String, Object>{
      'onboarding_verification_email_v3': email,
      'jwt_token': token,
    });
    BackendApiService().setAuthTokenForTesting(token);

    _installBackendMock((request) async {
      if (request.url.path == '/api/auth/email-status') {
        return http.Response(
          jsonEncode(<String, dynamic>{'success': true, 'verified': true}),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/api/profiles/me') {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'success': true,
            'data': <String, dynamic>{
              ..._profileJson(walletAddress: ''),
              'userId': 'user-stale-persona',
              'requiresWalletSetup': true,
            },
          }),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode(<String, dynamic>{'success': true}),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingFlowScreen(initialStepId: 'verifyEmail'),
        locale: const Locale('en'),
        size: const Size(390, 1024),
        profileProvider: profileProvider,
      ),
    );
    await _pumpOnboardingReady(tester);

    final state = tester.state(find.byType(OnboardingFlowScreen)) as dynamic;
    var actionCompleted = false;
    unawaited(
      (state.debugTriggerPrimaryAction() as Future<void>).whenComplete(
        () => actionCompleted = true,
      ),
    );
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (!actionCompleted && DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(actionCompleted, isTrue);
    await _pumpUntilFound(tester, find.text('Pick your role'));

    expect(state.debugCurrentStepId, 'role');
    expect(state.debugCompletedStepIds, contains('verifyEmail'));
    expect(state.debugCompletedStepIds, isNot(contains('role')));
    expect(find.text('Create your profile'), findsNothing);
  });

  testWidgets('email registration username is preserved for profile step',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    const wallet = '0xusernameprofile';
    final profileProvider = ProfileProvider()
      ..setCurrentUser(UserProfile(
        id: 'profile_username',
        walletAddress: wallet,
        username: 'provider_username',
        displayName: 'Provider Name',
        bio: '',
        avatar: '',
        createdAt: DateTime(2026, 3, 16),
        updatedAt: DateTime(2026, 3, 16),
      ));

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingFlowScreen(initialStepId: 'account'),
        locale: const Locale('en'),
        size: const Size(390, 1200),
        profileProvider: profileProvider,
      ),
    );
    await _pumpOnboardingReady(tester);

    final state = tester.state(find.byType(OnboardingFlowScreen)) as dynamic;
    await state.debugCaptureEmailRegistration(
      email: 'username@example.com',
      typedUsername: 'typed_username',
      backendUsername: 'backend_username',
      displayName: 'Backend Name',
      walletAddress: wallet,
    );
    expect(state.debugLocalProfileDraftUsername, 'backend_username');

    SharedPreferences.setMockInitialValues(<String, Object>{
      'onboarding_profile_draft_v3': jsonEncode(<String, String>{
        'username': 'backend_username',
        'displayName': 'Backend Name',
      }),
    });
    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingFlowScreen(initialStepId: 'profile'),
        locale: const Locale('en'),
        size: const Size(390, 1200),
        profileProvider: profileProvider,
      ),
    );
    await _pumpOnboardingReady(tester);

    final resumedState =
        tester.state(find.byType(OnboardingFlowScreen)) as dynamic;
    expect(resumedState.debugLocalProfileDraftUsername, 'backend_username');
    expect(resumedState.debugLocalProfileDraftDisplayName, 'Backend Name');
  });

  testWidgets('role step shows persona picker without DAO fields',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1700));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    _installBackendMock((request) async {
      return http.Response(
        jsonEncode(<String, dynamic>{'success': true}),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingFlowScreen(initialStepId: 'role'),
        locale: const Locale('en'),
        size: const Size(390, 1700),
      ),
    );
    await _pumpOnboardingReady(tester);

    expect(find.text('Pick your role'), findsOneWidget);
    // DAO application fields should NOT appear in onboarding
    expect(find.text('Apply for DAO review'), findsNothing);
    // No text fields for portfolio URL, medium, statement
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('dao review step opens inside account onboarding branch',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1700));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    final profileProvider = ProfileProvider()
      ..setCurrentUser(UserProfile(
        id: 'profile_creator',
        walletAddress: '0xcreator',
        username: 'creator_user',
        displayName: 'Creator User',
        bio: 'Artist bio',
        avatar: '',
        preferences: ProfilePreferences(persona: 'creator'),
        createdAt: DateTime(2026, 3, 16),
        updatedAt: DateTime(2026, 3, 16),
      ));

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingFlowScreen(initialStepId: 'daoReview'),
        locale: const Locale('en'),
        size: const Size(390, 1700),
        profileProvider: profileProvider,
      ),
    );
    await _pumpOnboardingReady(tester);

    expect(find.text('Governance review'), findsOneWidget);
    expect(
        find.text(
            'Submit your practice for community governance review before account setup is completed.'),
        findsOneWidget);
  });

  testWidgets('onboarding header action icons follow theme contrast rules',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingFlowScreen(initialStepId: 'account'),
        locale: const Locale('en'),
        themeMode: ThemeMode.light,
      ),
    );
    await _pumpOnboardingReady(tester);

    final lightLanguageIcon =
        tester.widget<Icon>(find.byIcon(Icons.language).first);
    final lightThemeIcon =
        tester.widget<Icon>(find.byIcon(Icons.brightness_6_outlined).first);
    expect(lightLanguageIcon.color, equals(Colors.black));
    expect(lightThemeIcon.color, equals(Colors.black));

    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingFlowScreen(initialStepId: 'account'),
        locale: const Locale('en'),
        themeMode: ThemeMode.dark,
      ),
    );
    await _pumpOnboardingReady(tester);

    final darkLanguageIcon =
        tester.widget<Icon>(find.byIcon(Icons.language).first);
    final darkThemeIcon =
        tester.widget<Icon>(find.byIcon(Icons.brightness_6_outlined).first);
    expect(darkLanguageIcon.color, equals(Colors.white));
    expect(darkThemeIcon.color, equals(Colors.white));
  });

  testWidgets('onboarding header keeps enlarged auth title footprint',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingFlowScreen(),
        locale: const Locale('en'),
      ),
    );
    await _pumpOnboardingReady(tester);

    // Enter account branch to get the header with AuthTitleRow
    await tester.tap(find.widgetWithText(KubusButton, 'Create an account'));
    await tester.pumpAndSettle();

    final titleSize = tester.getSize(find.byType(AuthTitleRow).first);
    expect(titleSize.height, greaterThanOrEqualTo(48));
    expect(titleSize.width, greaterThan(280));
  });

  testWidgets('onboarding remains stable on small mobile heights',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingFlowScreen(),
        locale: const Locale('en'),
        size: const Size(360, 640),
      ),
    );
    await _pumpOnboardingReady(tester);
    expect(tester.takeException(), isNull);

    // Unified welcome screen should render without overflow on small heights
    expect(find.text('Create an account'), findsWidgets);
    expect(find.text('Discover art'), findsWidgets);
  });

  testWidgets(
      'sign-in mobile layout has no page scroll and clears keyboard inset gap',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildTestApp(
        child: const SignInScreen(),
        locale: const Locale('en'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.byType(ListView), findsNothing);
    expect(find.byType(CustomScrollView), findsNothing);

    await tester.pumpWidget(
      _buildTestApp(
        child: const SignInScreen(),
        locale: const Locale('en'),
        viewInsetsBottom: 320,
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    final AnimatedPadding openPadding =
        tester.widget(find.byType(AnimatedPadding).first);
    expect(
        openPadding.padding.resolve(TextDirection.ltr).bottom, greaterThan(0));

    await tester.pumpWidget(
      _buildTestApp(
        child: const SignInScreen(),
        locale: const Locale('en'),
        viewInsetsBottom: 0,
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    final AnimatedPadding closedPadding =
        tester.widget(find.byType(AnimatedPadding).first);
    expect(closedPadding.padding.resolve(TextDirection.ltr).bottom, equals(0));
  });

  testWidgets('onboarding keyboard inset animation resets to zero after close',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingFlowScreen(initialStepId: 'account'),
        locale: const Locale('en'),
        viewInsetsBottom: 280,
        size: const Size(390, 1200),
      ),
    );
    await _pumpOnboardingReady(tester);
    await tester.pump(const Duration(milliseconds: 250));
    final AnimatedPadding openPadding =
        tester.widget(find.byType(AnimatedPadding).first);
    expect(openPadding.padding.resolve(TextDirection.ltr).bottom, equals(280));

    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingFlowScreen(initialStepId: 'account'),
        locale: const Locale('en'),
        viewInsetsBottom: 0,
        size: const Size(390, 1200),
      ),
    );
    await _pumpOnboardingReady(tester);
    await tester.pump(const Duration(milliseconds: 250));
    final AnimatedPadding closedPadding =
        tester.widget(find.byType(AnimatedPadding).first);
    expect(closedPadding.padding.resolve(TextDirection.ltr).bottom, equals(0));
  });
}
