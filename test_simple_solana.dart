// Test file to test Solana SDK directly
import 'package:solana/solana.dart';
import 'package:bip39/bip39.dart' as bip39;

void main() async {
  print('Testing Solana SDK...');
  
  // Test mnemonic generation
  final mnemonic = bip39.generateMnemonic();
  print('Generated mnemonic: $mnemonic');
  
  try {
    print('\nTesting Ed25519HDKeyPair creation from mnemonic...');
    final keyPair = await Ed25519HDKeyPair.fromMnemonic(mnemonic);
    
    final publicKey = await keyPair.extractPublicKey();
    print('Created wallet:');
    print('Public Key: ${publicKey.toBase58()}');
    print('Address: ${keyPair.address}');
    
    print('\nTesting RPC client connection...');
    final client = RpcClient('https://api.devnet.solana.com');
    
    print('\nTesting balance query...');
    final balance = await client.getBalance(publicKey.toBase58());
    print('Balance: ${balance.value / 1000000000} SOL');
    
    print('\nTesting airdrop request...');
    final airdropSignature = await client.requestAirdrop(
      publicKey.toBase58(),
      100000000, // 0.1 SOL in lamports
    );
    print('Airdrop signature: $airdropSignature');
    
    // Wait a bit and check balance again
    await Future.delayed(Duration(seconds: 2));
    final newBalance = await client.getBalance(publicKey.toBase58());
    print('New balance: ${newBalance.value / 1000000000} SOL');
    
    print('\nWallet creation and devnet connectivity successful!');
  } catch (e) {
    print('Error testing wallet: $e');
  }
}
