import 'dart:convert';

import 'package:art_kubus/providers/activation_prompt_provider.dart';
import 'package:art_kubus/providers/notification_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/services/account_identity.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/secure_storage_absent.dart';

// Walletless accounts: the session token carries only the canonical account
// id, so the wallet address is empty for both A and B. A wallet-keyed change
// check cannot tell these apart; only the account id can.
const _accountA = 'walletless-account-a';
const _accountB = 'walletless-account-b';

/// A session token for [accountId]. [refresh] changes the token itself without
/// changing the account, as a silent token refresh does.
String _token(String accountId, {int refresh = 0}) {
  final payload = jsonEncode({
    'id': accountId,
    'iat': refresh,
    'exp':
        DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
            1000,
  });
  return 'e30.${base64Url.encode(utf8.encode(payload)).replaceAll('=', '')}.synthetic';
}

/// Serves the signed-in account's own profile. Nothing else is needed here.
class _ProfileApi implements ProfileBackendApi {
  _ProfileApi(this.accountId);

  final String accountId;

  @override
  Future<Map<String, dynamic>> getMyProfile() async => {
        'success': true,
        'data': {
          'id': accountId,
          'user_id': accountId,
          'username': 'profile-of-$accountId',
          'wallet_address': '',
        },
      };

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  installEmptySecureStorage();
  TestWidgetsFlutterBinding.ensureInitialized();

  late BackendApiService api;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    api = BackendApiService();
    api.setAuthTokenForTesting(null);
    AccountIdentity.resetForTesting();
  });

  tearDown(() {
    api.setAuthTokenForTesting(null);
    AccountIdentity.resetForTesting();
  });

  group('walletless switch from account A to account B', () {
    test('notification unread counts of A are not readable as B', () async {
      await api.setAuthToken(_token(_accountA));
      final notifications = NotificationProvider();
      addTearDown(notifications.dispose);
      notifications.setAuthenticatedSessionForTesting(accountId: _accountA);
      notifications.handleUnreadSummaryForTesting({
        'data': {
          'notificationUnreadCount': 4,
          'messagesUnreadCount': 2,
          'totalUnreadCount': 6,
        },
      });
      expect(notifications.unreadCount, greaterThan(0));

      await api.setAuthToken(_token(_accountB));

      expect(notifications.unreadCount, 0);
    });

    test('the profile of A is not served as B', () async {
      await api.setAuthToken(_token(_accountA));
      final profile = ProfileProvider(apiService: _ProfileApi(_accountA));
      addTearDown(profile.dispose);
      await profile.loadAuthenticatedProfile();
      expect(profile.currentUser?.userId, _accountA);

      await api.setAuthToken(_token(_accountB));

      expect(profile.currentUser, isNull);
    });

    test('a pending activation prompt from A does not survive into B',
        () async {
      // Armed while signed out, then A signs in and the session moves to B.
      final prompt = ActivationPromptProvider(
        hasAuthSession: () => api.hasAuthSession,
      );
      addTearDown(prompt.dispose);
      for (var i = 0; i < ActivationPromptProvider.viewsBeforePrompt; i++) {
        await prompt.recordEntityView();
      }
      expect(prompt.shouldPrompt, isTrue);

      await api.setAuthToken(_token(_accountA));
      await api.setAuthToken(_token(_accountB));

      expect(prompt.entityViews, 0);
      expect(prompt.shouldPrompt, isFalse);
    });
  });

  group('same-account token refresh', () {
    test('keeps notification unread counts', () async {
      await api.setAuthToken(_token(_accountA));
      final notifications = NotificationProvider();
      addTearDown(notifications.dispose);
      notifications.setAuthenticatedSessionForTesting(accountId: _accountA);
      notifications.handleUnreadSummaryForTesting({
        'data': {
          'notificationUnreadCount': 4,
          'messagesUnreadCount': 2,
          'totalUnreadCount': 6,
        },
      });

      await api.setAuthToken(_token(_accountA, refresh: 1));

      expect(notifications.unreadCount, 4);
    });

    test('keeps the loaded profile', () async {
      await api.setAuthToken(_token(_accountA));
      final profile = ProfileProvider(apiService: _ProfileApi(_accountA));
      addTearDown(profile.dispose);
      await profile.loadAuthenticatedProfile();

      await api.setAuthToken(_token(_accountA, refresh: 1));

      expect(profile.currentUser?.userId, _accountA);
    });

    test('keeps the pending activation prompt state', () async {
      final prompt = ActivationPromptProvider(
        hasAuthSession: () => api.hasAuthSession,
      );
      addTearDown(prompt.dispose);
      for (var i = 0; i < ActivationPromptProvider.viewsBeforePrompt; i++) {
        await prompt.recordEntityView();
      }
      await api.setAuthToken(_token(_accountA));

      await api.setAuthToken(_token(_accountA, refresh: 1));

      expect(prompt.entityViews, ActivationPromptProvider.viewsBeforePrompt);
    });
  });
}
