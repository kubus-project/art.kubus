import 'package:flutter/services.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/services/settings_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const MethodChannel _secureStorage =
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

class _Wallet extends WalletProvider {
  _Wallet() : super(deferInit: true);
}

/// In-memory stand-in for the platform secure storage. [failingDeletes] is the
/// number of upcoming delete calls that throw before deletes succeed again;
/// use a large value to make deletion fail permanently.
class _FakeSecureStorage {
  final Map<String, String> values = <String, String>{};
  int failingDeletes = 0;

  /// Number of upcoming reads that throw; a large value makes reads fail.
  int failingReads = 0;
  final List<String> deleteKeys = <String>[];

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorage, (call) async {
      final args = (call.arguments as Map?) ?? const {};
      final key = args['key'] as String?;
      switch (call.method) {
        case 'read':
          if (failingReads > 0) {
            failingReads--;
            throw PlatformException(code: 'unavailable', message: 'locked');
          }
          return values[key];
        case 'write':
          values[key!] = args['value'] as String;
          return null;
        case 'delete':
          deleteKeys.add(key!);
          if (failingDeletes > 0) {
            failingDeletes--;
            throw PlatformException(code: 'unavailable', message: 'locked');
          }
          values.remove(key);
          return null;
      }
      return null;
    });
  }

  void uninstall() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorage, null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeSecureStorage storage;
  late _Wallet wallet;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    storage = _FakeSecureStorage()..install();
    wallet = _Wallet();
  });

  tearDown(() {
    storage.uninstall();
  });

  test('clearCachedMnemonic returns true and removes both keys on success',
      () async {
    storage.values['cached_mnemonic'] = 'phrase';
    storage.values['cached_mnemonic_ts'] = '1';

    expect(await wallet.clearCachedMnemonic(), isTrue);
    expect(storage.values, isEmpty);
  });

  test('clearCachedMnemonic retries once after a failed delete', () async {
    storage.values['cached_mnemonic'] = 'phrase';
    storage.failingDeletes = 1;

    expect(await wallet.clearCachedMnemonic(), isTrue);
    expect(storage.values.containsKey('cached_mnemonic'), isFalse);
  });

  test('clearCachedMnemonic reports false when deletion keeps failing',
      () async {
    storage.values['cached_mnemonic'] = 'phrase';
    storage.failingDeletes = 1000;

    expect(await wallet.clearCachedMnemonic(), isFalse);
    expect(
      storage.deleteKeys.where((k) => k == 'cached_mnemonic').length,
      2,
      reason: 'one attempt plus exactly one retry',
    );
    expect(storage.values['cached_mnemonic'], 'phrase');
  });

  test('logout with a failed purge persists a pending purge flag', () async {
    storage.values['cached_mnemonic'] = 'phrase';
    storage.failingDeletes = 1000;

    await wallet.disconnectWallet(preserveAuthenticatedWallet: false);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('pending_mnemonic_purge'), isTrue);
  });

  test('logout with a successful purge leaves no pending flag', () async {
    storage.values['cached_mnemonic'] = 'phrase';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pending_mnemonic_purge', true);

    await wallet.disconnectWallet(preserveAuthenticatedWallet: false);

    expect(storage.values.containsKey('cached_mnemonic'), isFalse);
    expect(prefs.getBool('pending_mnemonic_purge'), isNull);
  });

  test('startup with a pending purge deletes the phrase and does not import',
      () async {
    storage.values['cached_mnemonic'] = 'phrase';
    storage.values['cached_mnemonic_ts'] = '1';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pending_mnemonic_purge', true);

    await wallet.loadCachedWalletForTesting();

    expect(storage.values, isEmpty);
    expect(prefs.getBool('pending_mnemonic_purge'), isNull);
    expect(wallet.currentWalletAddress, isNull);
  });

  test(
      'startup keeps the pending flag and still does not import when purge fails',
      () async {
    storage.values['cached_mnemonic'] = 'phrase';
    storage.values['cached_mnemonic_ts'] = '1';
    storage.failingDeletes = 1000;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pending_mnemonic_purge', true);

    await wallet.loadCachedWalletForTesting();

    expect(prefs.getBool('pending_mnemonic_purge'), isTrue);
    expect(wallet.currentWalletAddress, isNull);
    expect(storage.values['cached_mnemonic'], 'phrase');
  });

  test('readCachedMnemonic returns null while a purge is pending and purges',
      () async {
    storage.values['cached_mnemonic'] = 'phrase';
    storage.values['cached_mnemonic_ts'] = '1';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pending_mnemonic_purge', true);

    expect(await wallet.readCachedMnemonic(), isNull);
    expect(storage.values, isEmpty);
    expect(prefs.getBool('pending_mnemonic_purge'), isNull);
  });

  test(
      'readCachedMnemonic returns null and keeps the flag when the purge fails',
      () async {
    storage.values['cached_mnemonic'] = 'phrase';
    storage.failingDeletes = 1000;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pending_mnemonic_purge', true);

    expect(await wallet.readCachedMnemonic(), isNull);
    expect(prefs.getBool('pending_mnemonic_purge'), isTrue);
    expect(storage.values['cached_mnemonic'], 'phrase');
  });

  test('readCachedMnemonic returns the phrase when no purge is pending',
      () async {
    storage.values['cached_mnemonic'] = 'phrase';

    expect(await wallet.readCachedMnemonic(), 'phrase');
  });

  test('reset keeps a failed purge flag alive through prefs.clear', () async {
    storage.values['cached_mnemonic'] = 'phrase';
    storage.failingDeletes = 1000;
    await wallet.disconnectWallet(preserveAuthenticatedWallet: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('unrelated', 'x');

    await SettingsService.clearPreferencesKeepingPendingPurgeForTesting(
      walletProvider: wallet,
    );

    expect(prefs.getString('unrelated'), isNull);
    expect(prefs.getBool('pending_mnemonic_purge'), isTrue);
    expect(storage.values['cached_mnemonic'], 'phrase');
  });

  test('reset keeps the flag when the phrase survives but the flag was unset',
      () async {
    storage.values['cached_mnemonic'] = 'phrase';
    storage.failingDeletes = 0;
    final prefs = await SharedPreferences.getInstance();
    // Simulate a read-back that fails: the phrase may still be present.
    storage.failingReads = 1000;

    await SettingsService.clearPreferencesKeepingPendingPurgeForTesting(
      walletProvider: wallet,
    );

    expect(prefs.getBool('pending_mnemonic_purge'), isTrue);
  });

  test('reset sets no flag when the phrase is verifiably absent', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('unrelated', 'x');

    await SettingsService.clearPreferencesKeepingPendingPurgeForTesting(
      walletProvider: wallet,
    );

    expect(prefs.getString('unrelated'), isNull);
    expect(prefs.getBool('pending_mnemonic_purge'), isNull);
  });
}
