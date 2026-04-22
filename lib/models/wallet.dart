enum TokenType { native, erc20, nft, governance }

enum TransactionType { send, receive, swap, stake, unstake, governanceVote }

enum TransactionStatus { submitted, pending, confirmed, finalized, failed }

enum WalletTransactionDirection { incoming, outgoing, swap, self, neutral }

enum WalletTransactionAssetKind { native, spl, unknown }

enum WalletTransactionFinality { unknown, processed, confirmed, finalized }

class Token {
  final String id;
  final String name;
  final String symbol;
  final TokenType type;
  final double balance;
  final double value;
  final double changePercentage;
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
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      symbol: (json['symbol'] ?? '').toString(),
      type: _parseTokenType(json['type']),
      balance: _toDouble(json['balance']),
      value: _toDouble(json['value']),
      changePercentage: _toDouble(json['changePercentage']),
      contractAddress: (json['contractAddress'] ?? '').toString(),
      decimals: (json['decimals'] as num?)?.toInt() ?? 18,
      logoUrl: json['logoUrl']?.toString(),
      network: (json['network'] ?? '').toString(),
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

class WalletTransactionAssetChange {
  const WalletTransactionAssetChange({
    required this.symbol,
    this.mint,
    this.decimals,
    this.assetKind = WalletTransactionAssetKind.unknown,
    required this.amount,
    this.direction = WalletTransactionDirection.neutral,
    this.isFee = false,
    this.isPrimary = false,
    this.label,
    this.counterparty,
    this.fromAddress,
    this.toAddress,
    this.metadata = const {},
  });

  final String symbol;
  final String? mint;
  final int? decimals;
  final WalletTransactionAssetKind assetKind;
  final double amount;
  final WalletTransactionDirection direction;
  final bool isFee;
  final bool isPrimary;
  final String? label;
  final String? counterparty;
  final String? fromAddress;
  final String? toAddress;
  final Map<String, dynamic> metadata;

  double get absoluteAmount => amount.abs();
  bool get isIncoming => amount > 0;
  bool get isOutgoing => amount < 0;
  bool get isNative =>
      assetKind == WalletTransactionAssetKind.native ||
      symbol.toUpperCase() == 'SOL';

  WalletTransactionAssetChange copyWith({
    String? symbol,
    String? mint,
    int? decimals,
    WalletTransactionAssetKind? assetKind,
    double? amount,
    WalletTransactionDirection? direction,
    bool? isFee,
    bool? isPrimary,
    String? label,
    String? counterparty,
    String? fromAddress,
    String? toAddress,
    Map<String, dynamic>? metadata,
  }) {
    return WalletTransactionAssetChange(
      symbol: symbol ?? this.symbol,
      mint: mint ?? this.mint,
      decimals: decimals ?? this.decimals,
      assetKind: assetKind ?? this.assetKind,
      amount: amount ?? this.amount,
      direction: direction ?? this.direction,
      isFee: isFee ?? this.isFee,
      isPrimary: isPrimary ?? this.isPrimary,
      label: label ?? this.label,
      counterparty: counterparty ?? this.counterparty,
      fromAddress: fromAddress ?? this.fromAddress,
      toAddress: toAddress ?? this.toAddress,
      metadata: metadata ?? this.metadata,
    );
  }

  factory WalletTransactionAssetChange.fromJson(Map<String, dynamic> json) {
    return WalletTransactionAssetChange(
      symbol: (json['symbol'] ?? '').toString(),
      mint: json['mint']?.toString(),
      decimals: (json['decimals'] as num?)?.toInt(),
      assetKind: _parseAssetKind(json['assetKind']),
      amount: _toDouble(json['amount']),
      direction: _parseDirection(json['direction']),
      isFee: json['isFee'] == true,
      isPrimary: json['isPrimary'] == true,
      label: json['label']?.toString(),
      counterparty: json['counterparty']?.toString(),
      fromAddress: json['fromAddress']?.toString(),
      toAddress: json['toAddress']?.toString(),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? const {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'mint': mint,
      'decimals': decimals,
      'assetKind': assetKind.name,
      'amount': amount,
      'direction': direction.name,
      'isFee': isFee,
      'isPrimary': isPrimary,
      'label': label,
      'counterparty': counterparty,
      'fromAddress': fromAddress,
      'toAddress': toAddress,
      'metadata': metadata,
    };
  }
}

class WalletRelatedTransaction {
  const WalletRelatedTransaction({
    required this.signature,
    required this.label,
    this.token,
    this.tokenMint,
    this.amount,
    this.status = TransactionStatus.pending,
    this.explorerUrl,
    this.metadata = const {},
  });

  final String signature;
  final String label;
  final String? token;
  final String? tokenMint;
  final double? amount;
  final TransactionStatus status;
  final String? explorerUrl;
  final Map<String, dynamic> metadata;

  WalletRelatedTransaction copyWith({
    String? signature,
    String? label,
    String? token,
    String? tokenMint,
    double? amount,
    TransactionStatus? status,
    String? explorerUrl,
    Map<String, dynamic>? metadata,
  }) {
    return WalletRelatedTransaction(
      signature: signature ?? this.signature,
      label: label ?? this.label,
      token: token ?? this.token,
      tokenMint: tokenMint ?? this.tokenMint,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      explorerUrl: explorerUrl ?? this.explorerUrl,
      metadata: metadata ?? this.metadata,
    );
  }

  factory WalletRelatedTransaction.fromJson(Map<String, dynamic> json) {
    return WalletRelatedTransaction(
      signature: (json['signature'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      token: json['token']?.toString(),
      tokenMint: json['tokenMint']?.toString(),
      amount: _nullableDouble(json['amount']),
      status: _parseTransactionStatus(json['status']),
      explorerUrl: json['explorerUrl']?.toString(),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? const {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'signature': signature,
      'label': label,
      'token': token,
      'tokenMint': tokenMint,
      'amount': amount,
      'status': status.name,
      'explorerUrl': explorerUrl,
      'metadata': metadata,
    };
  }
}

class WalletTransactionSubmissionResult {
  const WalletTransactionSubmissionResult({
    required this.primaryTransaction,
    this.relatedTransactions = const [],
    this.metadata = const {},
  });

  final WalletTransaction primaryTransaction;
  final List<WalletRelatedTransaction> relatedTransactions;
  final Map<String, dynamic> metadata;

  String get primarySignature => primaryTransaction.signature;
}

class WalletTransaction {
  final String id;
  final String signature;
  final String? explorerUrl;
  final TransactionType type;
  final TransactionStatus status;
  final WalletTransactionDirection direction;
  final WalletTransactionFinality finality;
  final String token;
  final String? tokenMint;
  final WalletTransactionAssetKind assetKind;
  final double amount;
  final double? amountIn;
  final double? amountOut;
  final double? netAmount;
  final String? primaryCounterparty;
  final String? fromAddress;
  final String? toAddress;
  final DateTime timestamp;
  final int? slot;
  final int? confirmationCount;
  final int? lastValidBlockHeight;
  final bool isOptimistic;
  final double? feeAmount;
  final String feeToken;
  final String? feeTokenMint;
  final double? gasUsed;
  final double? gasFee;
  final String? swapToToken;
  final double? swapToAmount;
  final List<WalletTransactionAssetChange> assetChanges;
  final List<WalletRelatedTransaction> relatedTransactions;
  final Map<String, dynamic> metadata;

  WalletTransaction({
    required this.id,
    required this.signature,
    this.explorerUrl,
    required this.type,
    required this.status,
    this.direction = WalletTransactionDirection.neutral,
    this.finality = WalletTransactionFinality.unknown,
    required this.token,
    this.tokenMint,
    this.assetKind = WalletTransactionAssetKind.unknown,
    required this.amount,
    this.amountIn,
    this.amountOut,
    this.netAmount,
    this.primaryCounterparty,
    this.fromAddress,
    this.toAddress,
    required this.timestamp,
    this.slot,
    this.confirmationCount,
    this.lastValidBlockHeight,
    this.isOptimistic = false,
    this.feeAmount,
    this.feeToken = 'SOL',
    this.feeTokenMint,
    this.gasUsed,
    this.gasFee,
    this.swapToToken,
    this.swapToAmount,
    this.assetChanges = const [],
    this.relatedTransactions = const [],
    this.metadata = const {},
  });

  WalletTransactionAssetChange? get primaryAssetChange {
    for (final change in assetChanges) {
      if (change.isPrimary && !change.isFee) {
        return change;
      }
    }
    WalletTransactionAssetChange? candidate;
    for (final change in assetChanges) {
      if (change.isFee) continue;
      if (candidate == null ||
          change.absoluteAmount > candidate.absoluteAmount) {
        candidate = change;
      }
    }
    return candidate;
  }

  bool get hasRelatedTransactions => relatedTransactions.isNotEmpty;
  bool get isLinkedSecondaryAction =>
      metadata['isLinkedSecondaryAction'] == true;
  String? get linkedPrimarySignature =>
      metadata['linkedPrimarySignature']?.toString();
  String get txHash => signature;
  String get shortSignature {
    if (signature.length <= 16) return signature;
    return '${signature.substring(0, 8)}...${signature.substring(signature.length - 6)}';
  }

  String get formattedAmount {
    if (type == TransactionType.swap &&
        swapToToken != null &&
        swapToAmount != null) {
      return '${amount.toStringAsFixed(4)} $token → ${swapToAmount!.toStringAsFixed(4)} $swapToToken';
    }

    final signedAmount = switch (direction) {
      WalletTransactionDirection.incoming => amount,
      WalletTransactionDirection.outgoing => -amount,
      WalletTransactionDirection.self => 0.0,
      WalletTransactionDirection.swap => amount,
      WalletTransactionDirection.neutral => netAmount ?? amount,
    };
    final sign = signedAmount > 0
        ? '+'
        : signedAmount < 0
            ? '-'
            : '';
    return '$sign${signedAmount.abs().toStringAsFixed(4)}';
  }

  String get shortAddress {
    final candidate = switch (direction) {
      WalletTransactionDirection.incoming => fromAddress ?? primaryCounterparty,
      WalletTransactionDirection.outgoing =>
        toAddress ?? primaryCounterparty,
      WalletTransactionDirection.swap => primaryCounterparty,
      WalletTransactionDirection.self => toAddress ?? fromAddress,
      WalletTransactionDirection.neutral =>
        primaryCounterparty ?? toAddress ?? fromAddress,
    };
    if (candidate == null || candidate.isEmpty) {
      return '';
    }
    if (candidate.length <= 12) {
      return candidate;
    }
    return '${candidate.substring(0, 6)}...${candidate.substring(candidate.length - 4)}';
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
    if (metadata['isFeeTransfer'] == true) {
      return 'Fee transfer';
    }
    switch (type) {
      case TransactionType.send:
        return direction == WalletTransactionDirection.self
            ? 'Moved'
            : 'Sent';
      case TransactionType.receive:
        return 'Received';
      case TransactionType.swap:
        return 'Swapped';
      case TransactionType.stake:
        return 'Staked';
      case TransactionType.unstake:
        return 'Unstaked';
      case TransactionType.governanceVote:
        return 'Voted';
    }
  }

  WalletTransaction copyWith({
    String? id,
    String? signature,
    String? explorerUrl,
    TransactionType? type,
    TransactionStatus? status,
    WalletTransactionDirection? direction,
    WalletTransactionFinality? finality,
    String? token,
    String? tokenMint,
    WalletTransactionAssetKind? assetKind,
    double? amount,
    double? amountIn,
    double? amountOut,
    double? netAmount,
    String? primaryCounterparty,
    String? fromAddress,
    String? toAddress,
    DateTime? timestamp,
    int? slot,
    int? confirmationCount,
    int? lastValidBlockHeight,
    bool? isOptimistic,
    double? feeAmount,
    String? feeToken,
    String? feeTokenMint,
    double? gasUsed,
    double? gasFee,
    String? swapToToken,
    double? swapToAmount,
    List<WalletTransactionAssetChange>? assetChanges,
    List<WalletRelatedTransaction>? relatedTransactions,
    Map<String, dynamic>? metadata,
  }) {
    return WalletTransaction(
      id: id ?? this.id,
      signature: signature ?? this.signature,
      explorerUrl: explorerUrl ?? this.explorerUrl,
      type: type ?? this.type,
      status: status ?? this.status,
      direction: direction ?? this.direction,
      finality: finality ?? this.finality,
      token: token ?? this.token,
      tokenMint: tokenMint ?? this.tokenMint,
      assetKind: assetKind ?? this.assetKind,
      amount: amount ?? this.amount,
      amountIn: amountIn ?? this.amountIn,
      amountOut: amountOut ?? this.amountOut,
      netAmount: netAmount ?? this.netAmount,
      primaryCounterparty: primaryCounterparty ?? this.primaryCounterparty,
      fromAddress: fromAddress ?? this.fromAddress,
      toAddress: toAddress ?? this.toAddress,
      timestamp: timestamp ?? this.timestamp,
      slot: slot ?? this.slot,
      confirmationCount: confirmationCount ?? this.confirmationCount,
      lastValidBlockHeight:
          lastValidBlockHeight ?? this.lastValidBlockHeight,
      isOptimistic: isOptimistic ?? this.isOptimistic,
      feeAmount: feeAmount ?? this.feeAmount,
      feeToken: feeToken ?? this.feeToken,
      feeTokenMint: feeTokenMint ?? this.feeTokenMint,
      gasUsed: gasUsed ?? this.gasUsed,
      gasFee: gasFee ?? this.gasFee,
      swapToToken: swapToToken ?? this.swapToToken,
      swapToAmount: swapToAmount ?? this.swapToAmount,
      assetChanges: assetChanges ?? this.assetChanges,
      relatedTransactions: relatedTransactions ?? this.relatedTransactions,
      metadata: metadata ?? this.metadata,
    );
  }

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    final signature = (json['signature'] ??
            json['txHash'] ??
            json['id'] ??
            '')
        .toString();
    final legacyType = _parseTransactionType(json['type']);
    final legacyToken = (json['token'] ?? 'SOL').toString();
    final legacyAmount = _toDouble(json['amount']);
    final assetChanges = (json['assetChanges'] as List<dynamic>?)
            ?.map((change) => WalletTransactionAssetChange.fromJson(
                Map<String, dynamic>.from(change as Map)))
            .toList() ??
        const <WalletTransactionAssetChange>[];
    final relatedTransactions =
        (json['relatedTransactions'] as List<dynamic>?)
                ?.map((item) => WalletRelatedTransaction.fromJson(
                    Map<String, dynamic>.from(item as Map)))
                .toList() ??
            const <WalletRelatedTransaction>[];

    return WalletTransaction(
      id: (json['id'] ?? signature).toString(),
      signature: signature,
      explorerUrl: json['explorerUrl']?.toString(),
      type: legacyType,
      status: _parseTransactionStatus(json['status']),
      direction: _parseDirection(json['direction']),
      finality: _parseFinality(json['finality'] ?? json['confirmationStatus']),
      token: legacyToken,
      tokenMint: json['tokenMint']?.toString(),
      assetKind: _parseAssetKind(json['assetKind']),
      amount: legacyAmount,
      amountIn: _nullableDouble(json['amountIn']),
      amountOut: _nullableDouble(json['amountOut']),
      netAmount: _nullableDouble(json['netAmount']),
      primaryCounterparty: json['primaryCounterparty']?.toString(),
      fromAddress: json['fromAddress']?.toString(),
      toAddress: json['toAddress']?.toString(),
      timestamp: DateTime.tryParse((json['timestamp'] ?? '').toString()) ??
          DateTime.now(),
      slot: (json['slot'] as num?)?.toInt(),
      confirmationCount: (json['confirmationCount'] as num?)?.toInt(),
      lastValidBlockHeight: (json['lastValidBlockHeight'] as num?)?.toInt(),
      isOptimistic: json['isOptimistic'] == true,
      feeAmount:
          _nullableDouble(json['feeAmount'] ?? json['gasFee']),
      feeToken: (json['feeToken'] ?? 'SOL').toString(),
      feeTokenMint: json['feeTokenMint']?.toString(),
      gasUsed: _nullableDouble(json['gasUsed']),
      gasFee: _nullableDouble(json['gasFee'] ?? json['feeAmount']),
      swapToToken: json['swapToToken']?.toString(),
      swapToAmount: _nullableDouble(json['swapToAmount']),
      assetChanges: assetChanges,
      relatedTransactions: relatedTransactions,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? const {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'signature': signature,
      'explorerUrl': explorerUrl,
      'type': type.name,
      'status': status.name,
      'direction': direction.name,
      'finality': finality.name,
      'token': token,
      'tokenMint': tokenMint,
      'assetKind': assetKind.name,
      'amount': amount,
      'amountIn': amountIn,
      'amountOut': amountOut,
      'netAmount': netAmount,
      'primaryCounterparty': primaryCounterparty,
      'fromAddress': fromAddress,
      'toAddress': toAddress,
      'timestamp': timestamp.toIso8601String(),
      'slot': slot,
      'confirmationCount': confirmationCount,
      'lastValidBlockHeight': lastValidBlockHeight,
      'isOptimistic': isOptimistic,
      'feeAmount': feeAmount,
      'feeToken': feeToken,
      'feeTokenMint': feeTokenMint,
      'gasUsed': gasUsed,
      'gasFee': gasFee,
      'swapToToken': swapToToken,
      'swapToAmount': swapToAmount,
      'assetChanges': assetChanges.map((change) => change.toJson()).toList(),
      'relatedTransactions':
          relatedTransactions.map((item) => item.toJson()).toList(),
      'metadata': metadata,
      'txHash': signature,
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
    if (address.length <= 10) {
      return address;
    }
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
    } catch (_) {
      return null;
    }
  }

  List<WalletTransaction> getRecentTransactions({int limit = 10}) {
    final sortedTransactions = List<WalletTransaction>.from(transactions)
      ..sort((a, b) {
        final timeCompare = b.timestamp.compareTo(a.timestamp);
        if (timeCompare != 0) {
          return timeCompare;
        }
        return (b.slot ?? 0).compareTo(a.slot ?? 0);
      });
    return sortedTransactions.take(limit).toList();
  }

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      id: (json['id'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      network: (json['network'] ?? '').toString(),
      tokens: (json['tokens'] as List<dynamic>?)
              ?.map((token) =>
                  Token.fromJson(Map<String, dynamic>.from(token as Map)))
              .toList() ??
          [],
      transactions: (json['transactions'] as List<dynamic>?)
              ?.map((tx) => WalletTransaction.fromJson(
                  Map<String, dynamic>.from(tx as Map)))
              .toList() ??
          [],
      totalValue: _toDouble(json['totalValue']),
      lastUpdated: DateTime.tryParse((json['lastUpdated'] ?? '').toString()) ??
          DateTime.now(),
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

double _toDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

double? _nullableDouble(dynamic value) {
  if (value == null) return null;
  return _toDouble(value);
}

TokenType _parseTokenType(dynamic value) {
  final name = value?.toString();
  return TokenType.values.firstWhere(
    (candidate) => candidate.name == name,
    orElse: () => TokenType.erc20,
  );
}

TransactionType _parseTransactionType(dynamic value) {
  final name = value?.toString();
  return TransactionType.values.firstWhere(
    (candidate) => candidate.name == name,
    orElse: () => TransactionType.receive,
  );
}

TransactionStatus _parseTransactionStatus(dynamic value) {
  final raw = value?.toString().toLowerCase();
  switch (raw) {
    case 'submitted':
      return TransactionStatus.submitted;
    case 'pending':
    case 'processed':
      return TransactionStatus.pending;
    case 'confirmed':
      return TransactionStatus.confirmed;
    case 'finalized':
    case 'success':
      return TransactionStatus.finalized;
    case 'failed':
    case 'error':
      return TransactionStatus.failed;
    default:
      return TransactionStatus.pending;
  }
}

WalletTransactionDirection _parseDirection(dynamic value) {
  final raw = value?.toString();
  return WalletTransactionDirection.values.firstWhere(
    (candidate) => candidate.name == raw,
    orElse: () => WalletTransactionDirection.neutral,
  );
}

WalletTransactionAssetKind _parseAssetKind(dynamic value) {
  final raw = value?.toString();
  return WalletTransactionAssetKind.values.firstWhere(
    (candidate) => candidate.name == raw,
    orElse: () => WalletTransactionAssetKind.unknown,
  );
}

WalletTransactionFinality _parseFinality(dynamic value) {
  final raw = value?.toString().toLowerCase();
  switch (raw) {
    case 'processed':
    case 'pending':
      return WalletTransactionFinality.processed;
    case 'confirmed':
      return WalletTransactionFinality.confirmed;
    case 'finalized':
    case 'success':
      return WalletTransactionFinality.finalized;
    default:
      return WalletTransactionFinality.unknown;
  }
}
