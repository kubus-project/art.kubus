import 'package:art_kubus/models/user.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/settings_service.dart';
import 'package:art_kubus/services/socket_service.dart';
import 'package:art_kubus/services/user_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// Everything a sign-out must leave behind on this device, and everything it
/// must keep. Account data (email, verification, status, privacy mirrors) goes;
/// the wallet, its identity and its recovery material stay.
const List<String> _accountScopedKeys = <String>[
  'jwt_token',
  'secure_account_email',
  'secure_account_email_verified_v1',
  'secure_account_status_cache_v1',
  'secure_account_status_cache_ts_v1',
  'private_profile',
  'allow_messages',
  'show_activity_status',
  'show_achievements',
  'showAchievements',
  'share_last_visited_location',
  'show_collection',
];

const MethodChannel _secureStorageChannel =
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

Map<String, String> _installSecureStorage() {
  final values = <String, String>{'cached_mnemonic': 'alpha beta gamma'};
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_secureStorageChannel, (call) async {
    final args = (call.arguments as Map?) ?? const {};
    final key = args['key'] as String?;
    switch (call.method) {
      case 'read':
        return values[key];
      case 'write':
        values[key!] = args['value'] as String;
        return null;
      case 'delete':
        values.remove(key);
        return null;
    }
    return null;
  });
  return values;
}

void _uninstallSecureStorage() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_secureStorageChannel, null);
}

Map<String, Object> _signedInPrefs() => <String, Object>{
      'jwt_token': 'pre-signout.jwt',
      'wallet_address': 'WalletAddr111',
      'has_wallet': true,
      'secure_account_email': 'person@example.com',
      'secure_account_email_verified_v1': true,
      'secure_account_status_cache_v1':
          '{"hasEmail":true,"hasPassword":true,"email":"person@example.com"}',
      'secure_account_status_cache_ts_v1': 1700000000000,
      'private_profile': true,
      'allow_messages': false,
      'show_activity_status': false,
      'show_achievements': false,
      'showAchievements': false,
      'share_last_visited_location': true,
      'show_collection': false,
    };

class _Wallet extends WalletProvider {
  _Wallet() : super(deferInit: true);

  @override
  Future<bool> hasPin() async => false;

  @override
  Future<bool> hasPinOrThrow() async => false;

  @override
  Future<bool> canUseBiometrics() async => false;
}

Map<String, dynamic> _securityBody({
  required String email,
  required bool verified,
}) =>
    <String, dynamic>{
      'success': true,
      'data': <String, dynamic>{
        'securityStatus': <String, dynamic>{
          'hasEmail': true,
          'hasPassword': true,
          'email': email,
          'emailVerified': verified,
          'emailAuthEnabled': true,
        },
      },
    };

User _user(String id) => User(
      id: id,
      name: 'Name $id',
      username: id,
      bio: '',
      followersCount: 1,
      followingCount: 1,
      postsCount: 1,
      isFollowing: false,
      isVerified: false,
      isArtist: false,
      isInstitution: false,
      isArtistSpecified: false,
      isInstitutionSpecified: false,
      isVerifiedSpecified: false,
      joinedDate: 'Joined recently',
      profileImageUrl: null,
    );

Future<void> _settleWrites() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('sign-out removes account-scoped local data', () {
    late Map<String, String> secureValues;

    setUp(() {
      SharedPreferences.setMockInitialValues(_signedInPrefs());
      secureValues = _installSecureStorage();
    });

    tearDown(_uninstallSecureStorage);

    test('SettingsService.logout keeps the wallet, its identity and its phrase',
        () async {
      final wallet = _Wallet();
      wallet.setCurrentWalletAddressForTesting('WalletAddr111');
      wallet.seedAccountSessionForTesting(
        email: 'person@example.com',
        backendProfile: <String, dynamic>{'id': 'user-person'},
        collectionsCount: 4,
        achievementsUnlocked: 7,
      );

      await SettingsService.logout(
        walletProvider: wallet,
        backendApi: BackendApiService(),
        preserveWallet: true,
      );

      final prefs = await SharedPreferences.getInstance();
      for (final key in _accountScopedKeys) {
        expect(prefs.get(key), isNull, reason: '$key survived sign-out');
      }
      expect(prefs.getString('wallet_address'), 'WalletAddr111');
      expect(prefs.getBool('has_wallet'), isTrue);
      expect(secureValues['cached_mnemonic'], 'alpha beta gamma');
      expect(wallet.accountSignedIn, isFalse);
      expect(wallet.currentWalletAddress, 'WalletAddr111');
    });

    test('clearAuth ends the session epoch and removes the account status',
        () async {
      final api = BackendApiService();
      final before = api.authSessionEpoch;

      await api.clearAuth();

      expect(api.authSessionEpoch, before + 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('secure_account_email'), isNull);
      expect(prefs.getBool('secure_account_email_verified_v1'), isNull);
      expect(prefs.getString('secure_account_status_cache_v1'), isNull);
      expect(prefs.getInt('secure_account_status_cache_ts_v1'), isNull);
      expect(prefs.getString('wallet_address'), 'WalletAddr111');
      expect(prefs.getBool('has_wallet'), isTrue);
    });
  });

  group('a response for a session that ended is discarded', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      _installSecureStorage();
    });

    tearDown(_uninstallSecureStorage);

    test('a security status fetched before sign-out does not write the email',
        () async {
      final api = BackendApiService();
      final requestEpoch = api.authSessionEpoch;
      await api.clearAuth(); // Sign-out lands while the request is in flight.

      await api.syncSecureAccountStatusFromResponse(
        _securityBody(email: 'previous@example.com', verified: true),
        fetchIfMissing: false,
        sessionEpoch: requestEpoch,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('secure_account_email'), isNull);
      expect(prefs.getBool('secure_account_email_verified_v1'), isNull);
      expect(prefs.getString('secure_account_status_cache_v1'), isNull);
    });

    test('sign-in repopulates the email and status for the new session',
        () async {
      final api = BackendApiService();
      await api.clearAuth();

      await api.syncSecureAccountStatusFromResponse(
        _securityBody(email: 'new@example.com', verified: true),
        fetchIfMissing: false,
        sessionEpoch: api.authSessionEpoch,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('secure_account_email'), 'new@example.com');
      expect(prefs.getBool('secure_account_email_verified_v1'), isTrue);
      expect(
        prefs.getString('secure_account_status_cache_v1'),
        contains('new@example.com'),
      );
    });
  });

  group('a profile fetched for a session that ended is not cached', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      _installSecureStorage();
      await UserService.clearCache();
    });

    tearDown(_uninstallSecureStorage);

    test('the late write neither reaches memory nor the persisted cache',
        () async {
      final requestEpoch = BackendApiService().authSessionEpoch;
      await BackendApiService().clearAuth(); // Sign-out during the fetch.

      UserService.setUsersInCacheAuthoritative(
        [_user('late-profile')],
        sessionEpoch: requestEpoch,
      );
      await _settleWrites();

      expect(UserService.getCachedUser('late-profile'), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_cache_v1'), isNull);
    });

    test('a write for the current session is cached and persisted', () async {
      final epoch = BackendApiService().authSessionEpoch;

      UserService.setUsersInCacheAuthoritative(
        [_user('current-profile')],
        sessionEpoch: epoch,
      );
      await _settleWrites();

      expect(
          UserService.getCachedUser('current-profile')?.id, 'current-profile');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_cache_v1'), contains('current-profile'));
    });
  });

  group('the socket handshake carries the current token', () {
    test('a socket created for a new sign-in uses the new token', () {
      const url = 'https://handshake-fresh.example.test';

      final before = io.io(
        url,
        SocketService.handshakeOptionsFor('pre-suspension.jwt'),
      );
      expect(before.auth, {'token': 'pre-suspension.jwt'});

      final after = io.io(
        url,
        SocketService.handshakeOptionsFor('post-reactivation.jwt'),
      );
      expect(identical(before, after), isFalse);
      expect(after.auth, {'token': 'post-reactivation.jwt'});
    });

    test('without forceNew the cached socket keeps the old token', () {
      // The root cause: socket_io_client returns the Socket it already holds for
      // this URL, and that Socket keeps the auth it was constructed with.
      const url = 'https://handshake-cache-check.example.test';
      Map<String, dynamic> withoutForceNew(String token) =>
          Map<String, dynamic>.from(SocketService.handshakeOptionsFor(token))
            ..remove('forceNew');

      final first = io.io(url, withoutForceNew('old.jwt'));
      final second = io.io(url, withoutForceNew('new.jwt'));

      expect(identical(first, second), isTrue);
      expect(second.auth, {'token': 'old.jwt'});
    });

    test('handshake options force a fresh manager and carry the token', () {
      final options = SocketService.handshakeOptionsFor('current.jwt');
      expect(options['forceNew'], isTrue);
      expect(options['autoConnect'], isFalse);
      expect(options['auth'], {'token': 'current.jwt'});
      expect(SocketService.handshakeOptionsFor('')['auth'], isEmpty);
    });
  });
}
