import 'package:flutter/material.dart';
import 'package:http/http.dart';

// Solana wallet connection models
class SolanaWallet {
  final String address;
  final double balance;
  final double kub8Balance;

  SolanaWallet({
    required this.address,
    required this.balance,
    required this.kub8Balance,
  });
}

class Web3Provider extends ChangeNotifier {
  late Client _httpClient;
  bool _isConnected = false;
  SolanaWallet? _wallet;
  
  // Solana network configuration
  String _networkEndpoint = 'https://api.mainnet-beta.solana.com';
  String _currentNetwork = 'Mainnet';
  final String _kub8TokenAddress = 'YOUR_KUB8_TOKEN_ADDRESS'; // Replace with actual token address
  final String _kub8Symbol = 'KUB8';
  final String _kub8Name = 'Kubit';
  
  // Transaction history
  List<Map<String, dynamic>> _transactions = [];

  Web3Provider() {
    _httpClient = Client();
    _initializeNetwork();
  }

  // Initialize network from stored preferences
  Future<void> _initializeNetwork() async {
    try {
      // We'll import SharedPreferences if needed
      // For now, default to devnet for testing
      switchNetwork('devnet');
    } catch (e) {
      // Default to devnet if there's any issue
      switchNetwork('devnet');
    }
  }

  // Getters
  bool get isConnected => _isConnected;
  SolanaWallet? get wallet => _wallet;
  double get solBalance => _wallet?.balance ?? 0.0;
  double get kub8Balance => _wallet?.kub8Balance ?? 0.0;
  String get walletAddress => _wallet?.address ?? '';
  String get networkEndpoint => _networkEndpoint;
  String get currentNetwork => _currentNetwork;
  String get kub8TokenAddress => _kub8TokenAddress;
  String get kub8Symbol => _kub8Symbol;
  String get kub8Name => _kub8Name;
  List<Map<String, dynamic>> get transactions => _transactions;

  // Network management
  void switchNetwork(String network) {
    switch (network.toLowerCase()) {
      case 'mainnet':
        _networkEndpoint = 'https://api.mainnet-beta.solana.com';
        _currentNetwork = 'Mainnet';
        break;
      case 'devnet':
        _networkEndpoint = 'https://api.devnet.solana.com';
        _currentNetwork = 'Devnet';
        break;
      case 'testnet':
        _networkEndpoint = 'https://api.testnet.solana.com';
        _currentNetwork = 'Testnet';
        break;
    }
    notifyListeners();
  }

  // Wallet connection
  Future<void> connectWallet() async {
    try {
      // Simulate wallet connection - in real app would use Phantom, Solflare, etc.
      await Future.delayed(const Duration(seconds: 1));
      
      // Generate a testnet-like address
      final addressSuffix = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
      final networkPrefix = _networkEndpoint.contains('devnet') ? 'DEV' : 'MAIN';
      
      _wallet = SolanaWallet(
        address: '${networkPrefix}_ArtKubus$addressSuffix',
        balance: _networkEndpoint.contains('devnet') ? 10.0 : 2.5, // More SOL on devnet for testing
        kub8Balance: _networkEndpoint.contains('devnet') ? 1000.0 : 125.5, // More KUB8 on devnet for testing
      );
      
      _isConnected = true;
      await _loadTransactions();
      notifyListeners();
    } catch (e) {
      _isConnected = false;
      notifyListeners();
      throw Exception('Failed to connect wallet: $e');
    }
  }

  void disconnectWallet() {
    _isConnected = false;
    _wallet = null;
    _transactions.clear();
    notifyListeners();
  }

  // Balance updates
  Future<void> updateBalances() async {
    if (_wallet != null) {
      try {
        // Simulate balance fetching from Solana RPC
        await Future.delayed(const Duration(milliseconds: 500));
        
        // In real implementation, would call Solana RPC endpoints
        final updatedWallet = SolanaWallet(
          address: _wallet!.address,
          balance: _wallet!.balance + (DateTime.now().millisecond % 10) * 0.001,
          kub8Balance: _wallet!.kub8Balance + (DateTime.now().millisecond % 100) * 0.01,
        );
        
        _wallet = updatedWallet;
        notifyListeners();
      } catch (e) {
        // Handle error
        debugPrint('Error updating balances: $e');
      }
    }
  }

  // KUB8 token operations
  Future<void> sendKub8(String toAddress, double amount) async {
    if (!_isConnected || _wallet == null) {
      throw Exception('Wallet not connected');
    }

    if (amount > _wallet!.kub8Balance) {
      throw Exception('Insufficient KUB8 balance');
    }

    try {
      // Simulate transaction
      await Future.delayed(const Duration(seconds: 2));
      
      final newBalance = _wallet!.kub8Balance - amount;
      _wallet = SolanaWallet(
        address: _wallet!.address,
        balance: _wallet!.balance,
        kub8Balance: newBalance,
      );

      // Add transaction to history
      _transactions.insert(0, {
        'type': 'send',
        'token': 'KUB8',
        'amount': amount,
        'to': toAddress,
        'timestamp': DateTime.now(),
        'status': 'completed',
        'txHash': 'kub8_tx_${DateTime.now().millisecondsSinceEpoch}',
      });

      notifyListeners();
    } catch (e) {
      throw Exception('Failed to send KUB8: $e');
    }
  }

  Future<void> swapSolToKub8(double solAmount) async {
    if (!_isConnected || _wallet == null) {
      throw Exception('Wallet not connected');
    }

    if (solAmount > _wallet!.balance) {
      throw Exception('Insufficient SOL balance');
    }

    try {
      // Simulate swap (1 SOL = 20 KUB8)
      const double exchangeRate = 20.0;
      final kub8Amount = solAmount * exchangeRate;
      
      await Future.delayed(const Duration(seconds: 2));
      
      _wallet = SolanaWallet(
        address: _wallet!.address,
        balance: _wallet!.balance - solAmount,
        kub8Balance: _wallet!.kub8Balance + kub8Amount,
      );

      // Add swap transaction
      _transactions.insert(0, {
        'type': 'swap',
        'fromToken': 'SOL',
        'toToken': 'KUB8',
        'fromAmount': solAmount,
        'toAmount': kub8Amount,
        'timestamp': DateTime.now(),
        'status': 'completed',
        'txHash': 'swap_tx_${DateTime.now().millisecondsSinceEpoch}',
      });

      notifyListeners();
    } catch (e) {
      throw Exception('Failed to swap: $e');
    }
  }

  // Governance functions
  Future<void> voteOnProposal(String proposalId, bool support) async {
    if (!_isConnected || _wallet == null) {
      throw Exception('Wallet not connected');
    }

    try {
      await Future.delayed(const Duration(seconds: 1));
      
      // Add voting transaction
      _transactions.insert(0, {
        'type': 'vote',
        'proposalId': proposalId,
        'support': support,
        'votingPower': _wallet!.kub8Balance,
        'timestamp': DateTime.now(),
        'status': 'completed',
        'txHash': 'vote_tx_${DateTime.now().millisecondsSinceEpoch}',
      });

      notifyListeners();
    } catch (e) {
      throw Exception('Failed to vote: $e');
    }
  }

  // NFT functions
  Future<void> mintArtworkNFT(String artworkData) async {
    if (!_isConnected || _wallet == null) {
      throw Exception('Wallet not connected');
    }

    try {
      await Future.delayed(const Duration(seconds: 3));
      
      // Add minting transaction
      _transactions.insert(0, {
        'type': 'mint',
        'token': 'NFT',
        'artwork': artworkData,
        'timestamp': DateTime.now(),
        'status': 'completed',
        'txHash': 'nft_tx_${DateTime.now().millisecondsSinceEpoch}',
      });

      notifyListeners();
    } catch (e) {
      throw Exception('Failed to mint NFT: $e');
    }
  }

  // Transaction loading
  Future<void> _loadTransactions() async {
    // Simulate loading transaction history
    _transactions = [
      {
        'type': 'receive',
        'token': 'KUB8',
        'amount': 25.0,
        'from': 'ArtKubus_Official',
        'timestamp': DateTime.now().subtract(const Duration(hours: 2)),
        'status': 'completed',
        'txHash': 'kub8_tx_received_001',
      },
      {
        'type': 'mint',
        'token': 'NFT',
        'artwork': 'Digital Sculpture #001',
        'timestamp': DateTime.now().subtract(const Duration(days: 1)),
        'status': 'completed',
        'txHash': 'nft_tx_mint_001',
      },
      {
        'type': 'swap',
        'fromToken': 'SOL',
        'toToken': 'KUB8',
        'fromAmount': 1.0,
        'toAmount': 20.0,
        'timestamp': DateTime.now().subtract(const Duration(days: 3)),
        'status': 'completed',
        'txHash': 'swap_tx_001',
      },
    ];
  }

  // Add mock transaction for demo purposes
  void addMockTransaction() {
    if (!_isConnected) return;
    
    final currencies = ['SOL', 'KUB8'];
    final random = DateTime.now().millisecondsSinceEpoch;
    final isReceived = random % 2 == 0;
    final currency = currencies[random % 2];
    final amount = (random % 1000) / 100.0;
    
    _transactions.insert(0, {
      'type': isReceived ? 'received' : 'sent',
      'currency': currency,
      'amount': amount,
      'from': isReceived ? 'DEV_MockSender$random' : _wallet?.address ?? 'Unknown',
      'to': isReceived ? _wallet?.address ?? 'Unknown' : 'DEV_MockReceiver$random',
      'timestamp': _formatTimestamp(DateTime.now()),
      'status': 'completed',
      'txHash': 'mock_tx_$random',
    });
    
    notifyListeners();
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  // Utility functions
  String formatBalance(double balance, {int decimals = 2}) {
    return balance.toStringAsFixed(decimals);
  }

  String formatAddress(String address, {int startChars = 6, int endChars = 4}) {
    if (address.length <= startChars + endChars) return address;
    return '${address.substring(0, startChars)}...${address.substring(address.length - endChars)}';
  }
}
