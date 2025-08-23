// Test file to explore Solana SDK imports
import 'package:solana/solana.dart';
import 'package:ed25519_hd_key/ed25519_hd_key.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'lib/services/solana_wallet_service.dart';

void main() async {
  print('Testing Solana SDK...');
  
  // Test mnemonic generation
  final mnemonic = bip39.generateMnemonic();
  print('Generated mnemonic: $mnemonic');
  
  // Test our wallet service
  final walletService = SolanaWalletService();
  
  try {
    print('\nTesting wallet creation from mnemonic...');
    final keyPair = await walletService.generateKeyPairFromMnemonic(mnemonic);
    print('Created wallet:');
    print('Public Key: ${keyPair.publicKey}');
    print('Private Key Bytes Length: ${keyPair.privateKeyBytes.length}');
    print('Public Key Bytes Length: ${keyPair.publicKeyBytes.length}');
    
    print('\nTesting balance query...');
    final balance = await walletService.getSolBalance(keyPair.publicKey);
    print('Balance: $balance SOL');
    
    print('\nTesting airdrop request...');
    final airdropSignature = await walletService.requestDevnetAirdrop(keyPair.publicKey, amount: 0.1);
    print('Airdrop signature: $airdropSignature');
    
    print('\nWallet creation and devnet connectivity successful!');
  } catch (e) {
    print('Error testing wallet: $e');
  }
}
