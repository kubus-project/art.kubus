import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/services/solana_wallet_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Account-link wallet operations must be purely local until the strict
/// bind-wallet transaction verifies the link against the signed-in account:
/// signer material only, no wallet identity prefs, no backend session work.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('createWalletForAccountLink creates local signer material only',
      () async {
    final provider = WalletProvider(deferInit: true);

    final address = await provider.createWalletForAccountLink();

    expect(address, isNotEmpty);
    expect(provider.currentWalletAddress, address);
    expect(provider.hasSigner, isTrue);

    // No wallet identity prefs may exist before the verified bind commits.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('wallet_address'), isNull);
    expect(prefs.getString('walletAddress'), isNull);
    expect(prefs.getString('wallet'), isNull);
    expect(prefs.getBool('has_wallet'), isNull);

    // A newly created wallet must lead into mnemonic reveal/backup.
    expect(
      await provider.isMnemonicBackupRequired(walletAddress: address),
      isTrue,
    );
  });

  test(
      'importWalletForAccountLink derives the signer locally and writes no '
      'identity prefs', () async {
    final mnemonic = SolanaWalletService().generateMnemonic();
    final provider = WalletProvider(deferInit: true);

    final address = await provider.importWalletForAccountLink(mnemonic);

    expect(address, isNotEmpty);
    expect(provider.currentWalletAddress, address);
    expect(provider.hasSigner, isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('wallet_address'), isNull);
    expect(prefs.getString('walletAddress'), isNull);
    expect(prefs.getString('wallet'), isNull);
    expect(prefs.getBool('has_wallet'), isNull);
  });

  test('importWalletForAccountLink rejects an invalid recovery phrase',
      () async {
    final provider = WalletProvider(deferInit: true);

    await expectLater(
      provider.importWalletForAccountLink('definitely not a valid phrase'),
      throwsException,
    );
    expect(provider.currentWalletAddress, isNull);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('wallet_address'), isNull);
  });
}
