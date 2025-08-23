// Test to verify wallet address is correctly displayed
import 'package:flutter_test/flutter_test.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/providers/mockup_data_provider.dart';

void main() {
  test('Wallet provider should use real address when available', () async {
    final mockupDataProvider = MockupDataProvider();
    final walletProvider = WalletProvider(mockupDataProvider);
    
    // Create a wallet which should generate a real Solana address
    final walletInfo = await walletProvider.createWallet();
    
    print('Created wallet:');
    print('Address: ${walletInfo['address']}');
    print('Mnemonic: ${walletInfo['mnemonic']}');
    
    // Check that the address is a valid Solana address (base58, ~44 characters)
    final address = walletInfo['address']!;
    expect(address.length, greaterThanOrEqualTo(32));
    expect(address.length, lessThanOrEqualTo(44));
    
    // Should not be the old hardcoded Ethereum address
    expect(address, isNot('0x742d35Cc6235C501F0e8A0B36cf71FcC2F82b46F'));
    
    print('✅ Test passed! Wallet provider is using real Solana address');
  });
}
