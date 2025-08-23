// Wallet and Token Models
enum TokenType { native, erc20, nft, governance }
enum TransactionType { send, receive, swap, stake, unstake, governance_vote }
enum TransactionStatus { pending, confirmed, failed }

class Token {
  final String id;
  final String name;
  final String symbol;
  final TokenType type;
  final double balance;
  final double value; // USD value
  final double changePercentage; // 24h change
  final String contractAddress;
  final int decimals;
  final String? logoUrl;
  final String network;

  Token({
    required this.id,
    required this.name,
    required this.symbol,
    required this.type,
    required this.balance,
    required this.value,
    required this.changePercentage,
    required this.contractAddress,
    this.decimals = 18,
    this.logoUrl,
    required this.network,
  });

  String get formattedBalance {
    if (balance >= 1000000) {
      return '${(balance / 1000000).toStringAsFixed(2)}M';
    } else if (balance >= 1000) {
      return '${(balance / 1000).toStringAsFixed(2)}K';
    }
    return balance.toStringAsFixed(4);
  }

  String get formattedValue {
    if (value >= 1000000) {
      return '\$${(value / 1000000).toStringAsFixed(2)}M';
    } else if (value >= 1000) {
      return '\$${(value / 1000).toStringAsFixed(2)}K';
    }
    return '\$${value.toStringAsFixed(2)}';
  }

  String get formattedChange {
    final sign = changePercentage >= 0 ? '+' : '';
    return '$sign${changePercentage.toStringAsFixed(1)}%';
  }

  bool get isPositiveChange => changePercentage >= 0;

  factory Token.fromJson(Map<String, dynamic> json) {
    return Token(
      id: json['id'],
      name: json['name'],
      symbol: json['symbol'],
      type: TokenType.values.firstWhere((e) => e.name == json['type']),
      balance: json['balance'].toDouble(),
      value: json['value'].toDouble(),
      changePercentage: json['changePercentage'].toDouble(),
      contractAddress: json['contractAddress'],
      decimals: json['decimals'] ?? 18,
      logoUrl: json['logoUrl'],
      network: json['network'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'symbol': symbol,
      'type': type.name,
      'balance': balance,
      'value': value,
      'changePercentage': changePercentage,
      'contractAddress': contractAddress,
      'decimals': decimals,
      'logoUrl': logoUrl,
      'network': network,
    };
  }
}

class WalletTransaction {
  final String id;
  final TransactionType type;
  final String token;
  final double amount;
  final String? fromAddress;
  final String? toAddress;
  final DateTime timestamp;
  final TransactionStatus status;
  final String txHash;
  final double? gasUsed;
  final double? gasFee;
  final String? swapToToken; // For swap transactions
  final double? swapToAmount;
  final Map<String, dynamic> metadata;

  WalletTransaction({
    required this.id,
    required this.type,
    required this.token,
    required this.amount,
    this.fromAddress,
    this.toAddress,
    required this.timestamp,
    required this.status,
    required this.txHash,
    this.gasUsed,
    this.gasFee,
    this.swapToToken,
    this.swapToAmount,
    this.metadata = const {},
  });

  String get formattedAmount {
    final sign = type == TransactionType.send ? '-' : '+';
    if (type == TransactionType.swap) {
      return '${amount.toStringAsFixed(4)} $token → ${swapToAmount?.toStringAsFixed(4)} $swapToToken';
    }
    return '$sign${amount.toStringAsFixed(4)}';
  }

  String get shortAddress {
    if (type == TransactionType.send && toAddress != null) {
      return '${toAddress!.substring(0, 6)}...${toAddress!.substring(toAddress!.length - 4)}';
    } else if (type == TransactionType.receive && fromAddress != null) {
      return '${fromAddress!.substring(0, 6)}...${fromAddress!.substring(fromAddress!.length - 4)}';
    }
    return '';
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  String get displayTitle {
    switch (type) {
      case TransactionType.send:
        return 'Sent';
      case TransactionType.receive:
        return 'Received';
      case TransactionType.swap:
        return 'Swapped';
      case TransactionType.stake:
        return 'Staked';
      case TransactionType.unstake:
        return 'Unstaked';
      case TransactionType.governance_vote:
        return 'Voted';
    }
  }

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id'],
      type: TransactionType.values.firstWhere((e) => e.name == json['type']),
      token: json['token'],
      amount: json['amount'].toDouble(),
      fromAddress: json['fromAddress'],
      toAddress: json['toAddress'],
      timestamp: DateTime.parse(json['timestamp']),
      status: TransactionStatus.values.firstWhere((e) => e.name == json['status']),
      txHash: json['txHash'],
      gasUsed: json['gasUsed']?.toDouble(),
      gasFee: json['gasFee']?.toDouble(),
      swapToToken: json['swapToToken'],
      swapToAmount: json['swapToAmount']?.toDouble(),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'token': token,
      'amount': amount,
      'fromAddress': fromAddress,
      'toAddress': toAddress,
      'timestamp': timestamp.toIso8601String(),
      'status': status.name,
      'txHash': txHash,
      'gasUsed': gasUsed,
      'gasFee': gasFee,
      'swapToToken': swapToToken,
      'swapToAmount': swapToAmount,
      'metadata': metadata,
    };
  }
}

class Wallet {
  final String id;
  final String address;
  final String name;
  final String network;
  final List<Token> tokens;
  final List<WalletTransaction> transactions;
  final double totalValue;
  final DateTime lastUpdated;

  Wallet({
    required this.id,
    required this.address,
    required this.name,
    required this.network,
    this.tokens = const [],
    this.transactions = const [],
    required this.totalValue,
    required this.lastUpdated,
  });

  String get shortAddress {
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  String get formattedTotalValue {
    if (totalValue >= 1000000) {
      return '\$${(totalValue / 1000000).toStringAsFixed(2)}M';
    } else if (totalValue >= 1000) {
      return '\$${(totalValue / 1000).toStringAsFixed(2)}K';
    }
    return '\$${totalValue.toStringAsFixed(2)}';
  }

  Token? getTokenBySymbol(String symbol) {
    try {
      return tokens.firstWhere((token) => token.symbol == symbol);
    } catch (e) {
      return null;
    }
  }

  List<WalletTransaction> getRecentTransactions({int limit = 10}) {
    final sortedTransactions = List<WalletTransaction>.from(transactions);
    sortedTransactions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sortedTransactions.take(limit).toList();
  }

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      id: json['id'],
      address: json['address'],
      name: json['name'],
      network: json['network'],
      tokens: (json['tokens'] as List<dynamic>?)
          ?.map((token) => Token.fromJson(token))
          .toList() ?? [],
      transactions: (json['transactions'] as List<dynamic>?)
          ?.map((tx) => WalletTransaction.fromJson(tx))
          .toList() ?? [],
      totalValue: json['totalValue'].toDouble(),
      lastUpdated: DateTime.parse(json['lastUpdated']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'address': address,
      'name': name,
      'network': network,
      'tokens': tokens.map((token) => token.toJson()).toList(),
      'transactions': transactions.map((tx) => tx.toJson()).toList(),
      'totalValue': totalValue,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }
}
