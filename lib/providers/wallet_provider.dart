import 'package:flutter/foundation.dart';
import '../models/wallet.dart';
import 'mockup_data_provider.dart';

class WalletProvider extends ChangeNotifier {
  final MockupDataProvider _mockupDataProvider;
  
  Wallet? _wallet;
  List<Token> _tokens = [];
  List<WalletTransaction> _transactions = [];
  bool _isLoading = false;
  bool _isBalanceVisible = true;

  WalletProvider(this._mockupDataProvider) {
    _mockupDataProvider.addListener(_onMockupModeChanged);
    _loadData();
  }

  @override
  void dispose() {
    _mockupDataProvider.removeListener(_onMockupModeChanged);
    super.dispose();
  }

  void _onMockupModeChanged() {
    _loadData();
  }

  // Getters
  Wallet? get wallet => _wallet;
  List<Token> get tokens => List.unmodifiable(_tokens);
  List<WalletTransaction> get transactions => List.unmodifiable(_transactions);
  bool get isLoading => _isLoading;
  bool get isBalanceVisible => _isBalanceVisible;
  double get totalBalance => _wallet?.totalValue ?? 0.0;

  Future<void> _loadData() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_mockupDataProvider.isMockDataEnabled) {
        await _loadMockWallet();
      } else {
        // TODO: Load from blockchain
        await _loadFromBlockchain();
      }
    } catch (e) {
      debugPrint('Error loading wallet data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadMockWallet() async {
    await _loadMockTokens();
    await _loadMockTransactions();
    
    _wallet = Wallet(
      id: 'wallet_1',
      address: '0x742d35Cc6235C501F0e8A0B36cf71FcC2F82b46F',
      name: 'Main Wallet',
      network: 'Polygon',
      tokens: _tokens,
      transactions: _transactions,
      totalValue: _tokens.fold(0.0, (sum, token) => sum + token.value),
      lastUpdated: DateTime.now(),
    );
  }

  Future<void> _loadMockTokens() async {
    _tokens = [
      Token(
        id: 'token_1',
        name: 'KUB8',
        symbol: 'KUB8',
        type: TokenType.governance,
        balance: 1250.00,
        value: 1875.00,
        changePercentage: 5.2,
        contractAddress: '0x123...abc',
        decimals: 18,
        logoUrl: 'https://example.com/kub8.png',
        network: 'Polygon',
      ),
      Token(
        id: 'token_2',
        name: 'Solana',
        symbol: 'SOL',
        type: TokenType.native,
        balance: 12.45,
        value: 623.45,
        changePercentage: 2.1,
        contractAddress: '0x456...def',
        decimals: 9,
        logoUrl: 'https://example.com/sol.png',
        network: 'Solana',
      ),
      Token(
        id: 'token_3',
        name: 'USD Coin',
        symbol: 'USDC',
        type: TokenType.erc20,
        balance: 500.00,
        value: 500.00,
        changePercentage: 0.1,
        contractAddress: '0x789...ghi',
        decimals: 6,
        logoUrl: 'https://example.com/usdc.png',
        network: 'Polygon',
      ),
      Token(
        id: 'token_4',
        name: 'Ethereum',
        symbol: 'ETH',
        type: TokenType.native,
        balance: 0.85,
        value: 2125.00,
        changePercentage: -1.2,
        contractAddress: '0xabc...123',
        decimals: 18,
        logoUrl: 'https://example.com/eth.png',
        network: 'Ethereum',
      ),
    ];
  }

  Future<void> _loadMockTransactions() async {
    final now = DateTime.now();
    
    _transactions = [
      WalletTransaction(
        id: 'tx_1',
        type: TransactionType.send,
        token: 'KUB8',
        amount: 50.00,
        fromAddress: '0x742d35Cc6235C501F0e8A0B36cf71FcC2F82b46F',
        toAddress: '0x123...abc',
        timestamp: now.subtract(const Duration(hours: 2)),
        status: TransactionStatus.confirmed,
        txHash: '0x123...abc',
        gasUsed: 21000,
        gasFee: 0.001,
        metadata: {'recipient_name': 'Artist Payment'},
      ),
      WalletTransaction(
        id: 'tx_2',
        type: TransactionType.receive,
        token: 'SOL',
        amount: 2.5,
        fromAddress: '0x456...def',
        toAddress: '0x742d35Cc6235C501F0e8A0B36cf71FcC2F82b46F',
        timestamp: now.subtract(const Duration(days: 1)),
        status: TransactionStatus.confirmed,
        txHash: '0x456...def',
        gasUsed: 5000,
        gasFee: 0.0005,
        metadata: {'source': 'NFT Sale'},
      ),
      WalletTransaction(
        id: 'tx_3',
        type: TransactionType.swap,
        token: 'SOL',
        amount: 0.05,
        fromAddress: '0x742d35Cc6235C501F0e8A0B36cf71FcC2F82b46F',
        toAddress: '0x742d35Cc6235C501F0e8A0B36cf71FcC2F82b46F',
        timestamp: now.subtract(const Duration(days: 3)),
        status: TransactionStatus.confirmed,
        txHash: '0x789...ghi',
        gasUsed: 150000,
        gasFee: 0.002,
        swapToToken: 'KUB8',
        swapToAmount: 12.5,
        metadata: {'dex': 'UniswapV3', 'slippage': '0.5%'},
      ),
      WalletTransaction(
        id: 'tx_4',
        type: TransactionType.governance_vote,
        token: 'KUB8',
        amount: 100.0,
        fromAddress: '0x742d35Cc6235C501F0e8A0B36cf71FcC2F82b46F',
        toAddress: '0xdao...contract',
        timestamp: now.subtract(const Duration(days: 5)),
        status: TransactionStatus.confirmed,
        txHash: '0xabc...123',
        gasUsed: 75000,
        gasFee: 0.003,
        metadata: {'proposal_id': 'prop_1', 'vote': 'yes'},
      ),
      WalletTransaction(
        id: 'tx_5',
        type: TransactionType.stake,
        token: 'KUB8',
        amount: 500.0,
        fromAddress: '0x742d35Cc6235C501F0e8A0B36cf71FcC2F82b46F',
        toAddress: '0xstaking...contract',
        timestamp: now.subtract(const Duration(days: 7)),
        status: TransactionStatus.confirmed,
        txHash: '0xdef...456',
        gasUsed: 120000,
        gasFee: 0.004,
        metadata: {'staking_period': '30_days', 'apy': '12%'},
      ),
    ];
  }

  Future<void> _loadFromBlockchain() async {
    // TODO: Implement blockchain loading
    _wallet = null;
    _tokens = [];
    _transactions = [];
  }

  // Balance visibility toggle
  void toggleBalanceVisibility() {
    _isBalanceVisible = !_isBalanceVisible;
    notifyListeners();
  }

  // Token methods
  Token? getTokenBySymbol(String symbol) {
    try {
      return _tokens.firstWhere((token) => token.symbol == symbol);
    } catch (e) {
      return null;
    }
  }

  List<Token> getTokensByType(TokenType type) {
    return _tokens.where((token) => token.type == type).toList();
  }

  double getTokenBalance(String symbol) {
    final token = getTokenBySymbol(symbol);
    return token?.balance ?? 0.0;
  }

  // Transaction methods
  List<WalletTransaction> getRecentTransactions({int limit = 10}) {
    return List<WalletTransaction>.from(_transactions)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp))
      ..take(limit);
  }

  List<WalletTransaction> getTransactionsByType(TransactionType type) {
    return _transactions.where((tx) => tx.type == type).toList();
  }

  List<WalletTransaction> getTransactionsByToken(String token) {
    return _transactions.where((tx) => tx.token == token).toList();
  }

  Future<void> sendTransaction({
    required String token,
    required double amount,
    required String toAddress,
    double? gasPrice,
    Map<String, dynamic>? metadata,
  }) async {
    if (_mockupDataProvider.isMockDataEnabled) {
      final transaction = WalletTransaction(
        id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
        type: TransactionType.send,
        token: token,
        amount: amount,
        fromAddress: _wallet?.address ?? '0x742d35Cc6235C501F0e8A0B36cf71FcC2F82b46F',
        toAddress: toAddress,
        timestamp: DateTime.now(),
        status: TransactionStatus.pending,
        txHash: '0x${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}',
        gasUsed: 21000,
        gasFee: gasPrice ?? 0.001,
        metadata: metadata ?? {},
      );
      
      _transactions.add(transaction);
      
      // Update token balance
      final tokenIndex = _tokens.indexWhere((t) => t.symbol == token);
      if (tokenIndex != -1) {
        final currentToken = _tokens[tokenIndex];
        _tokens[tokenIndex] = Token(
          id: currentToken.id,
          name: currentToken.name,
          symbol: currentToken.symbol,
          type: currentToken.type,
          balance: currentToken.balance - amount,
          value: currentToken.value - (amount * (currentToken.value / currentToken.balance)),
          changePercentage: currentToken.changePercentage,
          contractAddress: currentToken.contractAddress,
          decimals: currentToken.decimals,
          logoUrl: currentToken.logoUrl,
          network: currentToken.network,
        );
      }
      
      notifyListeners();
      
      // Simulate confirmation after delay
      Future.delayed(const Duration(seconds: 3), () {
        final txIndex = _transactions.indexWhere((tx) => tx.id == transaction.id);
        if (txIndex != -1) {
          _transactions[txIndex] = WalletTransaction(
            id: transaction.id,
            type: transaction.type,
            token: transaction.token,
            amount: transaction.amount,
            fromAddress: transaction.fromAddress,
            toAddress: transaction.toAddress,
            timestamp: transaction.timestamp,
            status: TransactionStatus.confirmed,
            txHash: transaction.txHash,
            gasUsed: transaction.gasUsed,
            gasFee: transaction.gasFee,
            metadata: transaction.metadata,
          );
          notifyListeners();
        }
      });
    } else {
      // TODO: Submit to blockchain
    }
  }

  Future<void> swapTokens({
    required String fromToken,
    required String toToken,
    required double fromAmount,
    required double toAmount,
    double? slippage,
  }) async {
    if (_mockupDataProvider.isMockDataEnabled) {
      final transaction = WalletTransaction(
        id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
        type: TransactionType.swap,
        token: fromToken,
        amount: fromAmount,
        fromAddress: _wallet?.address ?? '0x742d35Cc6235C501F0e8A0B36cf71FcC2F82b46F',
        toAddress: _wallet?.address ?? '0x742d35Cc6235C501F0e8A0B36cf71FcC2F82b46F',
        timestamp: DateTime.now(),
        status: TransactionStatus.pending,
        txHash: '0x${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}',
        gasUsed: 150000,
        gasFee: 0.002,
        swapToToken: toToken,
        swapToAmount: toAmount,
        metadata: {'slippage': '${slippage ?? 0.5}%', 'dex': 'UniswapV3'},
      );
      
      _transactions.add(transaction);
      notifyListeners();
      
      // Update token balances
      _updateTokenBalance(fromToken, -fromAmount);
      _updateTokenBalance(toToken, toAmount);
    } else {
      // TODO: Submit swap to blockchain
    }
  }

  void _updateTokenBalance(String symbol, double amount) {
    final tokenIndex = _tokens.indexWhere((t) => t.symbol == symbol);
    if (tokenIndex != -1) {
      final currentToken = _tokens[tokenIndex];
      final newBalance = currentToken.balance + amount;
      _tokens[tokenIndex] = Token(
        id: currentToken.id,
        name: currentToken.name,
        symbol: currentToken.symbol,
        type: currentToken.type,
        balance: newBalance,
        value: newBalance * (currentToken.value / currentToken.balance),
        changePercentage: currentToken.changePercentage,
        contractAddress: currentToken.contractAddress,
        decimals: currentToken.decimals,
        logoUrl: currentToken.logoUrl,
        network: currentToken.network,
      );
    }
  }

  // Analytics methods
  Map<String, dynamic> getWalletAnalytics() {
    final totalTransactions = _transactions.length;
    final sentTransactions = getTransactionsByType(TransactionType.send).length;
    final receivedTransactions = getTransactionsByType(TransactionType.receive).length;
    final swapTransactions = getTransactionsByType(TransactionType.swap).length;
    
    final totalSent = getTransactionsByType(TransactionType.send)
        .fold<double>(0, (sum, tx) => sum + tx.amount);
    final totalReceived = getTransactionsByType(TransactionType.receive)
        .fold<double>(0, (sum, tx) => sum + tx.amount);
    
    return {
      'totalBalance': totalBalance,
      'totalTokens': _tokens.length,
      'totalTransactions': totalTransactions,
      'sentTransactions': sentTransactions,
      'receivedTransactions': receivedTransactions,
      'swapTransactions': swapTransactions,
      'totalSent': totalSent,
      'totalReceived': totalReceived,
      'tokensByType': {
        for (var type in TokenType.values)
          type.name: getTokensByType(type).length,
      },
    };
  }

  Future<void> refreshData() async {
    await _loadData();
  }
}
