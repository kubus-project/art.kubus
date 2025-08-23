import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:solana/solana.dart';
import '../config/api_keys.dart';

class SolanaWalletService {
  static const String _devnetUrl = ApiKeys.solanaDevnetRpc;
  static const String _testnetUrl = ApiKeys.solanaTestnetRpc;
  static const String _mainnetUrl = ApiKeys.solanaMainnetRpc;
  
  late String _currentRpcUrl;
  late RpcClient _rpcClient;
  String _network = ApiKeys.defaultSolanaNetwork; // Use default from API keys

  SolanaWalletService() {
    // Initialize with the configured default network
    switchNetwork(ApiKeys.defaultSolanaNetwork);
  }

  // Network Management
  void switchNetwork(String network) {
    switch (network.toLowerCase()) {
      case 'mainnet':
        _currentRpcUrl = _mainnetUrl;
        _network = 'mainnet';
        break;
      case 'devnet':
        _currentRpcUrl = _devnetUrl;
        _network = 'devnet';
        break;
      case 'testnet':
        _currentRpcUrl = _testnetUrl;
        _network = 'testnet';
        break;
      default:
        _currentRpcUrl = _devnetUrl;
        _network = 'devnet';
    }
    
    // Initialize RPC client with the selected network
    _rpcClient = RpcClient(_currentRpcUrl);
  }

  String get currentNetwork => _network;
  String get currentRpcUrl => _currentRpcUrl;

  // Mnemonic and Wallet Generation
  String generateMnemonic() {
    // Use proper BIP39 mnemonic generation
    return bip39.generateMnemonic();
  }

  bool validateMnemonic(String mnemonic) {
    // Use proper BIP39 validation
    return bip39.validateMnemonic(mnemonic);
  }

  Future<SolanaKeyPair> generateKeyPairFromMnemonic(String mnemonic, {int accountIndex = 0}) async {
    if (!validateMnemonic(mnemonic)) {
      throw Exception('Invalid mnemonic phrase');
    }

    try {
      // Create key pair from mnemonic using Solana SDK
      final keyPair = await Ed25519HDKeyPair.fromMnemonic(mnemonic, account: accountIndex);
      
      // Extract the key data
      final keyData = await keyPair.extract();
      final publicKey = await keyPair.extractPublicKey();
      
      return SolanaKeyPair(
        publicKey: publicKey.toBase58(),
        privateKey: '', // We'll extract this when needed for security
        privateKeyBytes: Uint8List.fromList(keyData.bytes),
        publicKeyBytes: Uint8List.fromList(publicKey.bytes),
      );
    } catch (e) {
      throw Exception('Failed to generate key pair: $e');
    }
  }

  // Get balance for a public key
  Future<double> getSolBalance(String publicKey) async {
    try {
      final pubKey = Ed25519HDPublicKey.fromBase58(publicKey);
      final balance = await _rpcClient.getBalance(pubKey.toBase58());
      return balance.value / 1000000000; // Convert lamports to SOL
    } catch (e) {
      if (kDebugMode) {
        print('Error getting balance: $e');
      }
      return 0.0;
    }
  }

  // Request airdrop on devnet/testnet
  Future<String> requestDevnetAirdrop(String publicKey, {double amount = 1.0}) async {
    try {
      final pubKey = Ed25519HDPublicKey.fromBase58(publicKey);
      final lamports = (amount * 1000000000).toInt(); // Convert SOL to lamports
      
      // Request airdrop from Solana devnet
      final signature = await _rpcClient.requestAirdrop(
        pubKey.toBase58(),
        lamports,
      );
      
      return signature;
    } catch (e) {
      if (kDebugMode) {
        print('Error requesting airdrop: $e');
      }
      throw Exception('Failed to request airdrop: $e');
    }
  }

  // RPC Methods
  Future<double> getBalance(String publicKey) async {
    try {
      final response = await _makeRpcCall('getBalance', [publicKey]);
      final balance = response['result']['value'] as int;
      return balance / 1000000000.0; // Convert lamports to SOL
    } catch (e) {
      debugPrint('Error getting balance: $e');
      return 0.0;
    }
  }

  Future<List<TokenBalance>> getTokenBalances(String publicKey) async {
    try {
      final response = await _makeRpcCall('getTokenAccountsByOwner', [
        publicKey,
        {
          'programId': ApiKeys.splTokenProgramId,
        },
        {
          'encoding': 'jsonParsed',
        },
      ]);

      final accounts = response['result']['value'] as List;
      List<TokenBalance> tokenBalances = [];

      for (final account in accounts) {
        final parsedInfo = account['account']['data']['parsed']['info'];
        final tokenAmount = parsedInfo['tokenAmount'];
        final mint = parsedInfo['mint'];
        
        // Get token metadata (simplified - in real app you'd query token registry)
        final tokenInfo = await _getTokenInfo(mint);
        
        tokenBalances.add(TokenBalance(
          mint: mint,
          symbol: tokenInfo['symbol'] ?? 'UNKNOWN',
          name: tokenInfo['name'] ?? 'Unknown Token',
          balance: double.parse(tokenAmount['amount']) / pow(10, tokenAmount['decimals']),
          decimals: tokenAmount['decimals'],
          uiAmount: tokenAmount['uiAmount'] ?? 0.0,
        ));
      }

      return tokenBalances;
    } catch (e) {
      debugPrint('Error getting token balances: $e');
      return [];
    }
  }

  Future<String> requestAirdrop(String publicKey, {double amount = 1.0}) async {
    if (_network != 'devnet' && _network != 'testnet') {
      throw Exception('Airdrop only available on devnet and testnet');
    }

    try {
      final lamports = (amount * 1000000000).toInt(); // Convert SOL to lamports
      final response = await _makeRpcCall('requestAirdrop', [publicKey, lamports]);
      return response['result'] as String;
    } catch (e) {
      debugPrint('Error requesting airdrop: $e');
      rethrow;
    }
  }

  Future<List<TransactionInfo>> getTransactionHistory(String publicKey, {int limit = 10}) async {
    try {
      final response = await _makeRpcCall('getSignaturesForAddress', [
        publicKey,
        {'limit': limit}
      ]);

      final signatures = response['result'] as List;
      List<TransactionInfo> transactions = [];

      for (final sig in signatures) {
        final signature = sig['signature'];
        final txResponse = await _makeRpcCall('getTransaction', [
          signature,
          {'encoding': 'jsonParsed', 'maxSupportedTransactionVersion': 0}
        ]);

        if (txResponse['result'] != null) {
          final tx = txResponse['result'];
          transactions.add(TransactionInfo(
            signature: signature,
            blockTime: DateTime.fromMillisecondsSinceEpoch((tx['blockTime'] ?? 0) * 1000),
            fee: (tx['meta']['fee'] ?? 0) / 1000000000.0,
            status: tx['meta']['err'] == null ? 'success' : 'failed',
            slot: tx['slot'] ?? 0,
          ));
        }
      }

      return transactions;
    } catch (e) {
      debugPrint('Error getting transaction history: $e');
      return [];
    }
  }

  // Private helper methods
  Future<Map<String, dynamic>> _makeRpcCall(String method, List<dynamic> params) async {
    final response = await http.post(
      Uri.parse(_currentRpcUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'jsonrpc': '2.0',
        'id': 1,
        'method': method,
        'params': params,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['error'] != null) {
        throw Exception('RPC Error: ${data['error']['message']}');
      }
      return data;
    } else {
      throw Exception('HTTP Error: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> _getTokenInfo(String mint) async {
    // This is a simplified version. In a real app, you would query
    // the Solana Token Registry or a token metadata service
    final knownTokens = {
      // Add known token mints here
      'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v': {
        'symbol': 'USDC',
        'name': 'USD Coin',
      },
      'So11111111111111111111111111111111111111112': {
        'symbol': 'SOL',
        'name': 'Solana',
      },
    };

    return knownTokens[mint] ?? {
      'symbol': 'UNKNOWN',
      'name': 'Unknown Token',
    };
  }
}

// Data Models
class SolanaKeyPair {
  final String publicKey;
  final String privateKey;
  final Uint8List privateKeyBytes;
  final Uint8List publicKeyBytes;

  SolanaKeyPair({
    required this.publicKey,
    required this.privateKey,
    required this.privateKeyBytes,
    required this.publicKeyBytes,
  });
}

class TokenBalance {
  final String mint;
  final String symbol;
  final String name;
  final double balance;
  final int decimals;
  final double uiAmount;

  TokenBalance({
    required this.mint,
    required this.symbol,
    required this.name,
    required this.balance,
    required this.decimals,
    required this.uiAmount,
  });
}

class TransactionInfo {
  final String signature;
  final DateTime blockTime;
  final double fee;
  final String status;
  final int slot;

  TransactionInfo({
    required this.signature,
    required this.blockTime,
    required this.fee,
    required this.status,
    required this.slot,
  });
}
