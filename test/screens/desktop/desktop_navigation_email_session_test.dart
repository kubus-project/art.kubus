import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/collab_provider.dart';
import 'package:art_kubus/providers/notification_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/screens/desktop/components/desktop_navigation.dart';
import 'package:art_kubus/services/backend_api_service.dart';

/// Serves one authenticated account at a time. The email session has no wallet.
class _EmailSessionApi implements ProfileBackendApi {
  Map<String, dynamic>? account;

  @override
  String get baseUrl => 'https://api.kubus.site';

  @override
  Future<Map<String, dynamic>> getMyProfile() async {
    final current = account;
    if (current == null) {
      return <String, dynamic>{'success': false, 'status': 401};
    }
    return Map<String, dynamic>.from(current);
  }

  @override
  Future<Map<String, dynamic>> registerWallet({
    required String walletAddress,
    String? username,
  }) async =>
      <String, dynamic>{'success': true};

  @override
  Future<Map<String, dynamic>> getProfileByWallet(String walletAddress) async =>
      <String, dynamic>{'success': false, 'status': 404};

  @override
  Future<Map<String, dynamic>> saveProfile(
          Map<String, dynamic> profileData) async =>
      Map<String, dynamic>.from(profileData);

  @override
  Future<Map<String, dynamic>> updateProfile(
    String walletAddress,
    Map<String, dynamic> updates,
  ) async =>
      <String, dynamic>{'success': true};

  @override
  Future<Map<String, dynamic>> uploadAvatarToProfile({
    required List<int> fileBytes,
    required String fileName,
    required String fileType,
    Map<String, String>? metadata,
  }) async =>
      <String, dynamic>{};

  @override
  Future<bool> verifyImageUrl(String url) async => true;

  @override
  Future<void> followUser(String walletAddress) async {}

  @override
  Future<void> unfollowUser(String walletAddress) async {}

  @override
  Future<bool> isFollowing(String walletAddress) async => false;

  @override
  Future<Map<String, dynamic>?> getDAOReview(
          {required String idOrWallet}) async =>
      null;
}

Map<String, dynamic> _aliceAccount() => <String, dynamic>{
      'id': 'user-a',
      'userId': 'user-a',
      'walletAddress': '',
      'username': 'alice',
      'displayName': 'Alice',
      'bio': '',
      'avatar': '',
      'createdAt': '2026-03-31T00:00:00.000Z',
      'updatedAt': '2026-03-31T00:00:00.000Z',
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpRail(WidgetTester tester, ProfileProvider profile) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AnimationController(
      vsync: tester,
      duration: Duration.zero,
      value: 1,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ProfileProvider>.value(value: profile),
          ChangeNotifierProvider(create: (_) => NotificationProvider()),
          ChangeNotifierProvider(create: (_) => CollabProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.centerLeft,
              child: DesktopNavigation(
                items: const <DesktopNavItem>[],
                activeAccent: Colors.teal,
                selectedIndex: 0,
                onItemSelected: (_) {},
                isExpanded: true,
                expandAnimation: controller,
                onToggleExpand: () {},
                onProfileTap: () {},
                onSettingsTap: () {},
                onNotificationsTap: () {},
                onWalletTap: () {},
                isProfileSelected: false,
                isNotificationsSelected: false,
                isSettingsSelected: false,
                isCollabInvitesSelected: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets(
      'an email session without a wallet shows the account, not Sign in',
      (tester) async {
    final api = _EmailSessionApi()..account = _aliceAccount();
    final profile = ProfileProvider(apiService: api);
    // The load awaits real I/O (SharedPreferences), so it runs outside fake
    // async; inside it the test would hang until the timeout.
    await tester.runAsync(() => profile.loadAuthenticatedProfile());

    await pumpRail(tester, profile);

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
  });

  testWidgets('a guest sees Sign in', (tester) async {
    final profile = ProfileProvider(apiService: _EmailSessionApi());

    await pumpRail(tester, profile);

    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('signing out brings Sign in back and drops the account',
      (tester) async {
    final api = _EmailSessionApi()..account = _aliceAccount();
    final profile = ProfileProvider(apiService: api);
    await tester.runAsync(() => profile.loadAuthenticatedProfile());
    await pumpRail(tester, profile);
    expect(find.text('Alice'), findsOneWidget);

    profile.signOut();
    await tester.pump();

    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Alice'), findsNothing);
  });
}
