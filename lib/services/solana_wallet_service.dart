import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:crypto/crypto.dart' as crypto;
import 'package:solana/solana.dart';
import 'package:solana/encoder.dart';
import 'package:solana/metaplex.dart';
import '../config/api_keys.dart';
import '../config/config.dart';
import '../models/wallet.dart';
import 'storage_config.dart';
import '../models/swap_quote.dart';
import '../utils/wallet_utils.dart';
import 'ipfs_metadata_resolver.dart';

enum DerivationPathType { standard, legacy }

class DerivedKeyPairResult {
  final SolanaKeyPair keyPair;
  final Ed25519HDKeyPair hdKeyPair;
  final DerivationPathType pathType;
  final int accountIndex;
  final int changeIndex;

  const DerivedKeyPairResult({
    required this.keyPair,
    required this.hdKeyPair,
    required this.pathType,
    required this.accountIndex,
    required this.changeIndex,
  });

  String get address => keyPair.publicKey;
}

class SolanaWalletService {
  static const String _devnetUrl = ApiKeys.solanaDevnetRpc;
  static const String _testnetUrl = ApiKeys.solanaTestnetRpc;
  static const String _mainnetUrl = ApiKeys.solanaMainnetRpc;
  static const int _lamportsPerSol = 1000000000;
  static const int _maxAccountsPerBatch = 64;
  static final Map<String, DerivedKeyPairResult> _mnemonicCache = {};
  static final Map<String, Map<String, dynamic>> _knownTokens = {
    'epjfwdd5aufqssqem2qn1xzybapc8g4weggkzwytdt1v': {
      'symbol': 'USDC',
      'name': 'USD Coin',
      'logoUrl':
          'https://assets.coingecko.com/coins/images/6319/standard/USD_Coin_icon.png',
      'decimals': 6,
    },
    'so11111111111111111111111111111111111111112': {
      'symbol': 'SOL',
      'name': 'Solana',
      'logoUrl':
          'https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet/So11111111111111111111111111111111111111112/logo.png',
      'decimals': 9,
    },
    WalletUtils.canonical(ApiKeys.kub8MintAddress): {
      'symbol': 'KUB8',
      'name': 'kubus Governance Token',
      'logoUrl': 'assets/images/logo.png',
      'decimals': ApiKeys.kub8Decimals,
    },
  };
  static const Duration _tokenMetadataCacheTtl = Duration(minutes: 30);
  final Map<String, _TokenMetadataCacheEntry> _tokenMetadataCache = {};

  late String _currentRpcUrl;
  late RpcClient _rpcClient;
  String _network = ApiKeys.defaultSolanaNetwork; // Use default from API keys

  SolanaWalletService() {
    // Initialize with the configured default network
    switchNetwork(ApiKeys.defaultSolanaNetwork);
  }

  Uri _jupiterBackendUri(
    String path, {
    Map<String, String>? queryParameters,
  }) {
    return Uri.parse('${AppConfig.baseApiUrl}/api/dao/jupiter/$path').replace(
      queryParameters: queryParameters,
    );
  }

  Uri _jupiterDirectUri(
    String path, {
    Map<String, String>? queryParameters,
  }) {
    return Uri.parse('${ApiKeys.jupiterBaseUrl}/$path').replace(
      queryParameters: queryParameters,
    );
  }

  Future<Map<String, dynamic>> _getJupiterJson({
    required String path,
    required Map<String, String> queryParameters,
  }) async {
    final attempts = <({String source, Uri uri})>[
      (source: 'direct', uri: _jupiterDirectUri(path, queryParameters: queryParameters)),
      (source: 'backend', uri: _jupiterBackendUri(path, queryParameters: queryParameters)),
    ];

    final failures = <String>[];
    for (final attempt in attempts) {
      try {
        final response = await http.get(attempt.uri);
        if (response.statusCode != 200) {
          failures.add(
            '${attempt.source}: HTTP ${response.statusCode} ${response.body}',
          );
          continue;
        }
        return jsonDecode(response.body) as Map<String, dynamic>;
      } catch (error) {
        failures.add('${attempt.source}: $error');
      }
    }

    throw Exception('Jupiter $path failed. ${failures.join(' | ')}');
  }

  Future<Map<String, dynamic>> _postJupiterJson({
    required String path,
    required Map<String, dynamic> body,
  }) async {
    final attempts = <({String source, Uri uri})>[
      (source: 'direct', uri: _jupiterDirectUri(path)),
      (source: 'backend', uri: _jupiterBackendUri(path)),
    ];

    final failures = <String>[];
    for (final attempt in attempts) {
      try {
        final response = await http.post(
          attempt.uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        );
        if (response.statusCode != 200) {
          failures.add(
            '${attempt.source}: HTTP ${response.statusCode} ${response.body}',
          );
          continue;
        }
        return jsonDecode(response.body) as Map<String, dynamic>;
      } catch (error) {
        failures.add('${attempt.source}: $error');
      }
    }

    throw Exception('Jupiter $path failed. ${failures.join(' | ')}');
  }

  Map<String, dynamic> _extractProxyPayload(Map<String, dynamic> decoded) {
    final payload = decoded['data'];
    if (payload is Map<String, dynamic>) {
      return payload;
    }
    if (decoded.containsKey('swapTransaction') ||
        (decoded.containsKey('inputMint') && decoded.containsKey('outputMint'))) {
      return decoded;
    }
    throw Exception('Invalid Jupiter proxy response payload');
  }

  String _cacheKeyForMnemonic(String mnemonic) {
    final normalized = mnemonic.trim().toLowerCase();
    return crypto.sha256.convert(utf8.encode(normalized)).toString();
  }

  Future<List<DerivedKeyPairResult>> _buildDerivationCandidates(
    String mnemonic, {
    required List<int> accountCandidates,
    required List<int> changeCandidates,
    required bool includeLegacy,
  }) async {
    final results = <DerivedKeyPairResult>[];

    for (final account in accountCandidates) {
      for (final change in changeCandidates) {
        results.add(
          await _deriveKeyPairResult(
            mnemonic,
            accountIndex: account,
            changeIndex: change,
            pathType: DerivationPathType.standard,
          ),
        );
      }
    }

    if (includeLegacy) {
      for (final account in accountCandidates) {
        results.add(
          await _deriveKeyPairResult(
            mnemonic,
            accountIndex: account,
            changeIndex: 0,
            pathType: DerivationPathType.legacy,
          ),
        );
      }
    }

    return results;
  }

  Future<Map<String, double>> _fetchLamportBalances(
      List<String> addresses) async {
    if (addresses.isEmpty) return const {};

    final seen = <String>{};
    final ordered = <String>[];
    for (final address in addresses) {
      if (seen.add(address)) {
        ordered.add(address);
      }
    }

    final balances = <String, double>{};

    for (var i = 0; i < ordered.length; i += _maxAccountsPerBatch) {
      final batch =
          ordered.sublist(i, min(i + _maxAccountsPerBatch, ordered.length));
      try {
        final response = await _makeRpcCall('getMultipleAccounts', [
          batch,
          {'encoding': 'base64'},
        ]);
        final value = response['result']?['value'] as List?;
        if (value == null) continue;
        for (var idx = 0; idx < batch.length; idx++) {
          final address = batch[idx];
          final entry = idx < value.length ? value[idx] : null;
          final lamports = (entry is Map && entry['lamports'] is num)
              ? (entry['lamports'] as num).toDouble()
              : 0.0;
          balances[address] = lamports / _lamportsPerSol;
        }
      } catch (e) {
        debugPrint(
            'SolanaWalletService: batched balance lookup failed for ${batch.length} accounts -> $e');
      }
    }

    return balances;
  }

  Future<DerivedKeyPairResult> _deriveKeyPairResult(
    String mnemonic, {
    required int accountIndex,
    required int changeIndex,
    required DerivationPathType pathType,
  }) async {
    final hdKeyPair = await _createHdKeyPair(
      mnemonic,
      accountIndex: accountIndex,
      changeIndex: changeIndex,
      pathType: pathType,
    );

    final keyData = await hdKeyPair.extract();
    final publicKey = await hdKeyPair.extractPublicKey();
    final solanaKeyPair = SolanaKeyPair(
      publicKey: publicKey.toBase58(),
      privateKey: '',
      privateKeyBytes: Uint8List.fromList(keyData.bytes),
      publicKeyBytes: Uint8List.fromList(publicKey.bytes),
    );

    return DerivedKeyPairResult(
      keyPair: solanaKeyPair,
      hdKeyPair: hdKeyPair,
      pathType: pathType,
      accountIndex: accountIndex,
      changeIndex: pathType == DerivationPathType.standard ? changeIndex : 0,
    );
  }

  Future<Ed25519HDKeyPair> _createHdKeyPair(
    String mnemonic, {
    required int accountIndex,
    required int changeIndex,
    required DerivationPathType pathType,
  }) {
    switch (pathType) {
      case DerivationPathType.standard:
        return Ed25519HDKeyPair.fromMnemonic(
          mnemonic,
          account: accountIndex,
          change: changeIndex,
        );
      case DerivationPathType.legacy:
        // Legacy derivation omitted the final change index (m/44'/501'/account')
        return Ed25519HDKeyPair.fromMnemonic(
          mnemonic,
          account: accountIndex,
        );
    }
  }

  // Active keypair (in-memory only for current session; DO NOT persist private key in plaintext)
  Ed25519HDKeyPair? _activeKeyPair;

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

  String buildExplorerTransactionUrl(String signature) {
    final trimmed = signature.trim();
    if (trimmed.isEmpty) {
      return 'https://explorer.solana.com';
    }
    final query = switch (_network) {
      'devnet' => '?cluster=devnet',
      'testnet' => '?cluster=testnet',
      _ => '',
    };
    return 'https://explorer.solana.com/tx/$trimmed$query';
  }

  // Mnemonic and Wallet Generation
  String generateMnemonic() {
    // Use proper BIP39 mnemonic generation
    return bip39.generateMnemonic();
  }

  bool validateMnemonic(String mnemonic) {
    // Use proper BIP39 validation
    return bip39.validateMnemonic(mnemonic);
  }

  Future<SolanaKeyPair> generateKeyPairFromMnemonic(
    String mnemonic, {
    int accountIndex = 0,
    int changeIndex = 0,
    DerivationPathType pathType = DerivationPathType.standard,
  }) async {
    if (!validateMnemonic(mnemonic)) {
      throw Exception('Invalid mnemonic phrase');
    }

    try {
      final hdKeyPair = await _createHdKeyPair(
        mnemonic,
        accountIndex: accountIndex,
        changeIndex: changeIndex,
        pathType: pathType,
      );

      // Extract the key data
      final keyData = await hdKeyPair.extract();
      final publicKey = await hdKeyPair.extractPublicKey();

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

  /// Derives the keypair that should be displayed to the user.
  ///
  /// By default we return the primary account (m/44'/501'/0'/0') immediately.
  /// Pass additional [accountCandidates], [changeCandidates], or set
  /// [includeLegacy] to true when you explicitly need discovery across other
  /// derivation paths.
  Future<DerivedKeyPairResult> derivePreferredKeyPair(
    String mnemonic, {
    List<int> accountCandidates = const [0],
    List<int> changeCandidates = const [0],
    bool includeLegacy = false,
    Duration scoreTimeout = const Duration(milliseconds: 900),
  }) async {
    final trimmedMnemonic = mnemonic.trim();
    if (!validateMnemonic(trimmedMnemonic)) {
      throw Exception('Invalid mnemonic phrase');
    }

    if (accountCandidates.isEmpty || changeCandidates.isEmpty) {
      throw ArgumentError('Account and change candidate lists cannot be empty');
    }

    final cacheKey =
        '${_cacheKeyForMnemonic(trimmedMnemonic)}::${accountCandidates.join('-')}|${changeCandidates.join('-')}|$includeLegacy';
    final cached = _mnemonicCache[cacheKey];
    if (cached != null) {
      return cached;
    }

    final primaryCandidate = await _deriveKeyPairResult(
      trimmedMnemonic,
      accountIndex: accountCandidates.first,
      changeIndex: changeCandidates.first,
      pathType: DerivationPathType.standard,
    );

    final shouldDiscover = accountCandidates.length > 1 ||
        changeCandidates.length > 1 ||
        includeLegacy;

    if (!shouldDiscover) {
      _mnemonicCache[cacheKey] = primaryCandidate;
      return primaryCandidate;
    }

    List<DerivedKeyPairResult> candidates = <DerivedKeyPairResult>[];
    try {
      candidates = await _buildDerivationCandidates(
        trimmedMnemonic,
        accountCandidates: accountCandidates,
        changeCandidates: changeCandidates,
        includeLegacy: includeLegacy,
      );
    } catch (e) {
      debugPrint('SolanaWalletService: derivation discovery failed -> $e');
      _mnemonicCache[cacheKey] = primaryCandidate;
      return primaryCandidate;
    }

    if (candidates.isEmpty) {
      _mnemonicCache[cacheKey] = primaryCandidate;
      return primaryCandidate;
    }

    Map<String, double> lamportScores = const <String, double>{};
    try {
      lamportScores = await _fetchLamportBalances(
        candidates.map((c) => c.address).toList(),
      ).timeout(scoreTimeout, onTimeout: () => const <String, double>{});
    } catch (e) {
      debugPrint('SolanaWalletService: lamport scoring failed -> $e');
    }

    var bestCandidate = primaryCandidate;
    var bestScore = lamportScores[primaryCandidate.address] ?? 0.0;
    if (lamportScores.isNotEmpty) {
      for (final candidate in candidates) {
        final candidateScore = lamportScores[candidate.address] ?? 0.0;
        if (candidateScore > bestScore) {
          bestCandidate = candidate;
          bestScore = candidateScore;
        }
      }
    }

    if (kDebugMode) {
      debugPrint(
        'SolanaWalletService: discovery evaluated ${candidates.length} candidates, bestScore=$bestScore',
      );
    }

    final resolved = bestScore > 0 ? bestCandidate : primaryCandidate;
    if (_mnemonicCache.length > 64) {
      final oldestKey = _mnemonicCache.keys.first;
      _mnemonicCache.remove(oldestKey);
    }
    _mnemonicCache[cacheKey] = resolved;
    return resolved;
  }

  // Set active keypair for signing operations (store only in memory)
  void setActiveKeyPair(Ed25519HDKeyPair keyPair) {
    _activeKeyPair = keyPair;
  }

  void clearActiveKeyPair() {
    _activeKeyPair = null;
  }

  bool get hasActiveKeyPair => _activeKeyPair != null;

  String? get activePublicKey => _activeKeyPair?.address;

  Future<String?> getActivePublicKey() async {
    return activePublicKey;
  }

  Future<String> signMessageBase64(String messageBase64) async {
    if (!hasActiveKeyPair) {
      throw Exception('No active keypair set for message signing');
    }

    final messageBytes = base64Decode(messageBase64);
    final signature = await _activeKeyPair!.sign(messageBytes);
    return base64Encode(signature.bytes);
  }

  Future<String> signTransactionBase64(String transactionBase64) async {
    if (!hasActiveKeyPair) {
      throw Exception('No active keypair set for transaction signing');
    }

    final unsigned = SignedTx.decode(transactionBase64);
    final requiredSignatures = unsigned.compiledMessage.requiredSignatureCount;
    if (requiredSignatures < 1) {
      throw Exception('Transaction does not require signatures');
    }

    final signatures = List<Signature>.from(unsigned.signatures);
    if (signatures.length != requiredSignatures) {
      throw Exception(
        'Transaction expects $requiredSignatures signatures but received ${signatures.length}.',
      );
    }

    signatures[0] = await _activeKeyPair!.sign(
      unsigned.compiledMessage.toByteArray(),
    );

    final signedTx = unsigned.copyWith(signatures: signatures);
    return signedTx.encode();
  }

  Future<String> signAndSendTransactionBase64(String transactionBase64) async {
    if (!hasActiveKeyPair) {
      throw Exception('No active keypair set for transaction signing');
    }

    final signedTransactionBase64 =
        await signTransactionBase64(transactionBase64);
    return _sendEncodedTransactionWithDiagnostics(signedTransactionBase64);
  }

  Future<String> submitSignedTransactionBase64(String transactionBase64) {
    return _sendEncodedTransactionWithDiagnostics(transactionBase64);
  }

  // Get balance for a public key
  Future<double> getSolBalance(String publicKey) async {
    try {
      final pubKey = Ed25519HDPublicKey.fromBase58(publicKey);
      final balance = await _rpcClient.getBalance(pubKey.toBase58());
      return balance.value / 1000000000; // Convert lamports to SOL
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting balance: $e');
      }
      return 0.0;
    }
  }

  // Request airdrop on devnet/testnet
  Future<String> requestDevnetAirdrop(String publicKey,
      {double amount = 1.0}) async {
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
        debugPrint('Error requesting airdrop: $e');
      }
      throw Exception('Failed to request airdrop: $e');
    }
  }

  // RPC Methods
  Future<double> getBalance(String publicKey) async {
    try {
      final lamports = await _rpcClient.getBalance(
        publicKey,
        commitment: Commitment.confirmed,
      );
      return lamports.value / 1000000000.0; // Convert lamports to SOL
    } catch (e) {
      debugPrint('Error getting balance via RpcClient: $e');
      try {
        // Fallback to raw RPC call
        final response = await _makeRpcCall('getBalance', [publicKey]);
        final balance = response['result']['value'] as int;
        return balance / 1000000000.0;
      } catch (err) {
        debugPrint('Fallback getBalance failed: $err');
        return 0.0;
      }
    }
  }

  Future<List<TokenBalance>> getTokenBalances(String publicKey) async {
    try {
      final response = await _makeRpcCall(
        'getTokenAccountsByOwner',
        [
          publicKey,
          {
            'programId': ApiKeys.splTokenProgramId,
          },
          {
            'encoding': 'jsonParsed',
          },
        ],
      );

      final accounts = response['result']['value'] as List;
      final ownerPub = Ed25519HDPublicKey.fromBase58(publicKey);
      final aggregatedByMint = <String, _OwnedMintBalanceAggregationRecord>{};

      for (final account in accounts) {
        if (account is! Map) continue;
        final accountAddress = account['pubkey']?.toString().trim() ?? '';
        if (accountAddress.isEmpty) continue;
        final parsedInfo = account['account']['data']['parsed']['info'];
        final tokenAmount = parsedInfo['tokenAmount'];
        final mint = parsedInfo['mint']?.toString().trim() ?? '';
        if (mint.isEmpty) continue;
        final decimals = (tokenAmount['decimals'] as num?)?.toInt() ?? 0;
        final amountRaw =
            double.tryParse(tokenAmount['amount']?.toString() ?? '0') ?? 0.0;
        final balance =
            decimals > 0 ? amountRaw / pow(10, decimals) : amountRaw;
        final uiAmount = tokenAmount['uiAmount'];
        final aggregated = aggregatedByMint.putIfAbsent(
          mint,
          () => _OwnedMintBalanceAggregationRecord(
            mint: mint,
            decimals: decimals,
          ),
        );
        aggregated.totalBalance += balance;
        aggregated.totalUiAmount += uiAmount is num ? uiAmount.toDouble() : balance;
        aggregated.decimals = decimals;
        aggregated.ownedTokenAccounts.add(
          TokenAccountHolding(
            address: accountAddress,
            rawAmount: tokenAmount['amount']?.toString() ?? '0',
            balance: balance,
            decimals: decimals,
            state: parsedInfo['state']?.toString() ?? 'unknown',
          ),
        );
      }

      final tokenBalances = <TokenBalance>[];
      for (final entry in aggregatedByMint.entries) {
        final mint = entry.key;
        final aggregated = entry.value;
        final tokenInfo = await _getTokenInfo(
          mint,
          decimalsHint: aggregated.decimals,
        );
        final canonicalAta = await _findAssociatedTokenAddressSafe(
          owner: ownerPub,
          mintAddress: mint,
        );
        final ownedTokenAccounts = _orderOwnedTokenAccounts(
          accounts: aggregated.ownedTokenAccounts,
          canonicalAta: canonicalAta,
        );

        tokenBalances.add(
          TokenBalance(
            mint: mint,
            symbol: (tokenInfo['symbol'] ?? _fallbackSymbol(mint)).toString(),
            name: (tokenInfo['name'] ?? 'Unknown Token').toString(),
            balance: aggregated.totalBalance,
            decimals: aggregated.decimals,
            uiAmount: aggregated.totalUiAmount,
            logoUrl: tokenInfo['logoUrl'] as String?,
            metadataUri: tokenInfo['uri'] as String?,
            description: tokenInfo['description'] as String?,
            rawMetadata:
                tokenInfo['rawOffChainMetadata'] as Map<String, dynamic>?,
            preferredSourceTokenAccount:
                _defaultPreferredSourceTokenAccount(ownedTokenAccounts),
            ownedTokenAccounts: ownedTokenAccounts,
          ),
        );
      }

      tokenBalances.sort((a, b) {
        final symbolCompare = a.symbol.toLowerCase().compareTo(
              b.symbol.toLowerCase(),
            );
        if (symbolCompare != 0) return symbolCompare;
        return a.mint.toLowerCase().compareTo(b.mint.toLowerCase());
      });
      return tokenBalances;
    } catch (e) {
      debugPrint('Error getting token balances: $e');
      return [];
    }
  }

  Future<double> getSplTokenBalance({
    required String owner,
    required String mint,
    int? expectedDecimals,
  }) async {
    try {
      final response = await _makeRpcCall('getTokenAccountsByOwner', [
        owner,
        {'mint': mint},
        {'encoding': 'jsonParsed'},
      ]);

      final accounts = response['result']['value'] as List;
      if (accounts.isEmpty) return 0.0;

      double total = 0.0;
      for (final account in accounts) {
        final parsedInfo = account['account']['data']['parsed']['info'];
        final tokenAmount = parsedInfo['tokenAmount'];
        final decimals =
            tokenAmount['decimals'] as int? ?? expectedDecimals ?? 0;
        final amountRaw =
            double.tryParse(tokenAmount['amount']?.toString() ?? '0') ?? 0.0;
        total += amountRaw / pow(10, decimals);
      }

      return total;
    } catch (e) {
      debugPrint('Error getting SPL balance for $mint: $e');
      return 0.0;
    }
  }

  Future<List<TokenAccountHolding>> getOwnedTokenAccountsForMint({
    required String ownerAddress,
    required String mint,
  }) {
    return _loadOwnedTokenAccountsForMint(
      ownerAddress: ownerAddress,
      mint: mint,
    );
  }

  Future<String> requestAirdrop(String publicKey, {double amount = 1.0}) async {
    if (_network != 'devnet' && _network != 'testnet') {
      throw Exception('Airdrop only available on devnet and testnet');
    }

    try {
      final lamports = (amount * 1000000000).toInt(); // Convert SOL to lamports
      final response =
          await _makeRpcCall('requestAirdrop', [publicKey, lamports]);
      return response['result'] as String;
    } catch (e) {
      debugPrint('Error requesting airdrop: $e');
      rethrow;
    }
  }

  Future<List<WalletTransaction>> getTransactionHistory(
    String publicKey, {
    int limit = 25,
    String? beforeSignature,
  }) async {
    try {
      final response = await _makeRpcCall('getSignaturesForAddress', [
        publicKey,
        {
          'limit': limit,
          if (beforeSignature != null && beforeSignature.trim().isNotEmpty)
            'before': beforeSignature.trim(),
        },
      ]);

      final signatures = response['result'] as List? ?? const [];
      final currentSlot = await _fetchCurrentSlot();
      final transactions = <WalletTransaction>[];

      for (final rawSignature in signatures) {
        if (rawSignature is! Map) continue;
        final signatureRecord = _SignatureStatusRecord.fromJson(
          Map<String, dynamic>.from(rawSignature),
        );

        try {
          final txResponse = await _makeRpcCall('getTransaction', [
            signatureRecord.signature,
            {
              'encoding': 'jsonParsed',
              'maxSupportedTransactionVersion': 0,
            },
          ]);
          final transaction = await _parseWalletTransaction(
            publicKey: publicKey,
            signatureRecord: signatureRecord,
            transactionJson: txResponse['result'] as Map<String, dynamic>?,
            currentSlot: currentSlot,
          );
          if (transaction != null) {
            transactions.add(transaction);
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
              'SolanaWalletService: failed to parse transaction ${signatureRecord.signature}: $e',
            );
          }
        }
      }

      transactions.sort((a, b) {
        final slotCompare = (b.slot ?? 0).compareTo(a.slot ?? 0);
        if (slotCompare != 0) {
          return slotCompare;
        }
        return b.timestamp.compareTo(a.timestamp);
      });
      return transactions;
    } catch (e) {
      debugPrint('Error getting transaction history: $e');
      return [];
    }
  }

  // Transfer native SOL between accounts
  Future<SubmittedSolanaTransactionRecord> transferSol({
    required String toAddress,
    required double amount,
  }) async {
    if (!hasActiveKeyPair) {
      throw Exception('No active keypair set for signing');
    }
    try {
      final lamports = (amount * 1000000000).floor();
      final ix = SystemInstruction.transfer(
        fundingAccount: Ed25519HDPublicKey.fromBase58(_activeKeyPair!.address),
        recipientAccount: Ed25519HDPublicKey.fromBase58(toAddress),
        lamports: lamports,
      );
      return _sendInstructions([ix]);
    } catch (e) {
      debugPrint('SOL transfer failed: $e');
      rethrow;
    }
  }

  Future<UnsignedSolanaTransactionRecord> buildTransferSolTransactionBase64({
    required String fromAddress,
    required String toAddress,
    required double amount,
  }) async {
    final lamports = (amount * _lamportsPerSol).floor();
    final ix = SystemInstruction.transfer(
      fundingAccount: Ed25519HDPublicKey.fromBase58(fromAddress),
      recipientAccount: Ed25519HDPublicKey.fromBase58(toAddress),
      lamports: lamports,
    );
    return _buildUnsignedTransaction(
      feePayerAddress: fromAddress,
      instructions: [ix],
    );
  }

  // Transfer SPL token (KUB8 or others)
  Future<SubmittedSolanaTransactionRecord> transferSplToken({
    required String mint,
    required String toAddress,
    required double amount,
    required int decimals,
    String? sourceTokenAccount,
  }) async {
    if (!hasActiveKeyPair) {
      throw Exception('No active keypair set for SPL transfer');
    }
    try {
      final instructions = await _buildSplTokenTransferInstructions(
        fromAddress: _activeKeyPair!.address,
        mint: mint,
        toAddress: toAddress,
        amount: amount,
        decimals: decimals,
        sourceTokenAccount: sourceTokenAccount,
      );
      return _sendInstructions(instructions);
    } catch (e) {
      if (e is SolanaWalletSendException) rethrow;
      throw SolanaWalletSendException(
        _normalizeSendFailureMessage(e.toString()),
        cause: e,
      );
    }
  }

  Future<UnsignedSolanaTransactionRecord>
      buildTransferSplTokenTransactionBase64({
    required String fromAddress,
    required String mint,
    required String toAddress,
    required double amount,
    required int decimals,
    String? sourceTokenAccount,
  }) async {
    try {
      final instructions = await _buildSplTokenTransferInstructions(
        fromAddress: fromAddress,
        mint: mint,
        toAddress: toAddress,
        amount: amount,
        decimals: decimals,
        sourceTokenAccount: sourceTokenAccount,
      );
      return _buildUnsignedTransaction(
        feePayerAddress: fromAddress,
        instructions: instructions,
      );
    } catch (e) {
      if (e is SolanaWalletSendException) rethrow;
      throw SolanaWalletSendException(
        _normalizeSendFailureMessage(e.toString()),
        cause: e,
      );
    }
  }

  // Swap SOL -> SPL token (e.g., SOL -> KUB8) via DEX aggregator (Jupiter/Raydium)
  Future<SubmittedSolanaTransactionRecord> swapSolToSpl({
    required String mint,
    required double solAmount,
    int slippageBps = 50,
    SwapQuote? quote,
    int platformFeeBps = 0,
    String? platformFeeOwnerAddress,
    FeeSplitterProgramInstructionRecord? feeSplitterProgram,
  }) async {
    if (!hasActiveKeyPair) {
      throw Exception('No active keypair set for swap');
    }
    final unsigned = await buildJupiterSwapTransactionBase64(
      userPublicKey: _activeKeyPair!.address,
      inputMint: ApiKeys.wrappedSolMintAddress,
      outputMint: mint,
      inputAmountRaw: (solAmount * 1000000000).round(),
      slippageBps: slippageBps,
      wrapAndUnwrapSol: true,
      quote: quote,
      platformFeeBps: platformFeeBps,
      platformFeeOwnerAddress: platformFeeOwnerAddress,
      feeSplitterProgram: feeSplitterProgram,
    );
    final signature = await signAndSendTransactionBase64(
      unsigned.transactionBase64,
    );
    return SubmittedSolanaTransactionRecord(
      signature: signature,
      lastValidBlockHeight: unsigned.lastValidBlockHeight,
      explorerUrl: buildExplorerTransactionUrl(signature),
      metadata: unsigned.metadata,
    );
  }

  Future<SubmittedSolanaTransactionRecord> swapSplToken({
    required String fromMint,
    required String toMint,
    required double amount,
    required int decimals,
    int slippageBps = 50,
    SwapQuote? quote,
    int platformFeeBps = 0,
    String? platformFeeOwnerAddress,
    FeeSplitterProgramInstructionRecord? feeSplitterProgram,
  }) async {
    if (!hasActiveKeyPair) {
      throw Exception('No active keypair set for swap');
    }
    final unsigned = await buildJupiterSwapTransactionBase64(
      userPublicKey: _activeKeyPair!.address,
      inputMint: fromMint,
      outputMint: toMint,
      inputAmountRaw: (amount * pow(10, decimals)).round(),
      slippageBps: slippageBps,
      wrapAndUnwrapSol: false,
      quote: quote,
      platformFeeBps: platformFeeBps,
      platformFeeOwnerAddress: platformFeeOwnerAddress,
      feeSplitterProgram: feeSplitterProgram,
    );
    final signature = await signAndSendTransactionBase64(
      unsigned.transactionBase64,
    );
    return SubmittedSolanaTransactionRecord(
      signature: signature,
      lastValidBlockHeight: unsigned.lastValidBlockHeight,
      explorerUrl: buildExplorerTransactionUrl(signature),
      metadata: unsigned.metadata,
    );
  }

  Future<UnsignedSolanaTransactionRecord> buildJupiterSwapTransactionBase64({
    required String userPublicKey,
    required String inputMint,
    required String outputMint,
    required int inputAmountRaw,
    required int slippageBps,
    required bool wrapAndUnwrapSol,
    SwapQuote? quote,
    int platformFeeBps = 0,
    String? platformFeeOwnerAddress,
    FeeSplitterProgramInstructionRecord? feeSplitterProgram,
  }) async {
    final swapRequestRecord = await _buildJupiterSwapRequest(
      inputMint: inputMint,
      outputMint: outputMint,
      inputAmountRaw: inputAmountRaw,
      slippageBps: slippageBps,
      quote: quote,
      platformFeeBps: platformFeeBps,
    );
    final route = swapRequestRecord.route;
    if (route == null) {
      throw Exception('No Jupiter route available');
    }
    return _buildAtomicJupiterSwapTransaction(
      userPublicKey: userPublicKey,
      outputMint: outputMint,
      wrapAndUnwrapSol: wrapAndUnwrapSol,
      route: route,
      quoteContextSlot: swapRequestRecord.contextSlot,
      quoteTimeTakenMs: swapRequestRecord.timeTakenMs,
      platformFeeBps: platformFeeBps,
      platformFeeOwnerAddress: platformFeeOwnerAddress,
      feeSplitterProgram: feeSplitterProgram,
    );
  }

  Future<SwapQuote> fetchSwapQuote({
    required String inputMint,
    required String outputMint,
    required int inputAmountRaw,
    required int inputDecimals,
    required int outputDecimals,
    int slippageBps = 50,
    int platformFeeBps = 0,
  }) async {
    final decoded = await _getJupiterJson(
      path: 'quote',
      queryParameters: {
        'inputMint': inputMint,
        'outputMint': outputMint,
        'amount': inputAmountRaw.toString(),
        'slippageBps': slippageBps.toString(),
        'swapMode': 'ExactIn',
        if (platformFeeBps > 0) 'platformFeeBps': platformFeeBps.toString(),
        'instructionVersion': 'V2',
      },
    );
    final route = _extractProxyPayload(decoded);
    return SwapQuote.fromRoute(
      route: route,
      inputMint: inputMint,
      outputMint: outputMint,
      inputDecimals: inputDecimals,
      outputDecimals: outputDecimals,
      slippageBps: slippageBps,
      contextSlot: (route['contextSlot'] as num?)?.toInt(),
      timeTakenMs: (route['timeTaken'] as num?)?.toDouble(),
    );
  }

  // Mint NFT with Metaplex metadata + master edition
  Future<String> mintNft({required Map<String, dynamic> metadata}) async {
    if (!hasActiveKeyPair) {
      throw Exception('No active keypair set for mint');
    }

    final payer = _activeKeyPair!;
    final mint = await Ed25519HDKeyPair.random();
    final mintPub = mint.publicKey;

    final uri = metadata['uri']?.toString().trim() ?? '';
    if (uri.isEmpty) {
      throw Exception('Metadata URI required for NFT mint');
    }

    final name = _truncateMetadataField(
      metadata['name']?.toString().trim() ?? 'kubus Collectible',
      32,
    );
    final symbol = _truncateMetadataField(
      metadata['symbol']?.toString().trim() ?? 'KUB8',
      10,
    );
    final sellerFeeBps = _parseSellerFeeBps(metadata);
    final isMutable = metadata['isMutable'] as bool? ?? true;
    final collection = _parseMetadataCollection(metadata);
    final creators = _parseMetadataCreators(metadata, payer.publicKey);

    // Rent-exempt lamports for mint account
    final mintRent = await _rpcClient.getMinimumBalanceForRentExemption(
      TokenProgram.neededMintAccountSpace,
    );

    final createMintIx = SystemInstruction.createAccount(
      fundingAccount: payer.publicKey,
      newAccount: mintPub,
      lamports: mintRent,
      space: TokenProgram.neededMintAccountSpace,
      owner: TokenProgram.id,
    );

    final initMintIx = TokenInstruction.initializeMint(
      mint: mintPub,
      mintAuthority: payer.publicKey,
      freezeAuthority: payer.publicKey,
      decimals: 0,
    );

    final ata = await findAssociatedTokenAddress(
      owner: payer.publicKey,
      mint: mintPub,
    );

    final createAtaIx = AssociatedTokenAccountInstruction.createAccount(
      funder: payer.publicKey,
      address: ata,
      owner: payer.publicKey,
      mint: mintPub,
    );

    final mintToIx = TokenInstruction.mintTo(
      mint: mintPub,
      destination: ata,
      amount: 1,
      authority: payer.publicKey,
    );

    final metadataIx = await createMetadataAccountV3(
      mint: mintPub,
      mintAuthority: payer.publicKey,
      payer: payer.publicKey,
      updateAuthority: payer.publicKey,
      data: CreateMetadataAccountV3Data(
        name: name,
        symbol: symbol,
        uri: _truncateMetadataField(uri, 200),
        sellerFeeBasisPoints: sellerFeeBps,
        creators: creators,
        collection: collection,
        uses: null,
        isMutable: isMutable,
        colectionDetails: false,
      ),
    );

    final masterEditionIx = await createMasterEditionV3(
      mint: mintPub,
      updateAuthority: payer.publicKey,
      mintAuthority: payer.publicKey,
      payer: payer.publicKey,
      data: CreateMasterEditionV3Data(maxSupply: BigInt.zero),
    );

    final submission = await _sendInstructions(
      [
        createMintIx,
        initMintIx,
        createAtaIx,
        mintToIx,
        metadataIx,
        masterEditionIx,
      ],
      extraSigners: [mint],
    );
    return submission.signature;
  }

  Future<dynamic> _safeGetAccountInfo(String address) async {
    try {
      return await _rpcClient.getAccountInfo(address);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _findAssociatedTokenAddressSafe({
    required Ed25519HDPublicKey owner,
    required String mintAddress,
  }) async {
    try {
      final mint = Ed25519HDPublicKey.fromBase58(mintAddress);
      final ata = await findAssociatedTokenAddress(owner: owner, mint: mint);
      return ata.toBase58();
    } catch (_) {
      return null;
    }
  }

  List<TokenAccountHolding> _orderOwnedTokenAccounts({
    required List<TokenAccountHolding> accounts,
    required String? canonicalAta,
  }) {
    final ordered = accounts
        .map(
          (account) => TokenAccountHolding(
            address: account.address,
            rawAmount: account.rawAmount,
            balance: account.balance,
            decimals: account.decimals,
            state: account.state,
            isAssociatedTokenAccount:
                canonicalAta != null &&
                WalletUtils.equals(account.address, canonicalAta),
          ),
        )
        .toList(growable: false);

    ordered.sort((a, b) {
      if (a.isAssociatedTokenAccount != b.isAssociatedTokenAccount) {
        return a.isAssociatedTokenAccount ? -1 : 1;
      }
      final rawCompare = _parseRawTokenAmount(b.rawAmount).compareTo(
        _parseRawTokenAmount(a.rawAmount),
      );
      if (rawCompare != 0) return rawCompare;
      return a.address.toLowerCase().compareTo(b.address.toLowerCase());
    });
    return ordered;
  }

  String? _defaultPreferredSourceTokenAccount(
    List<TokenAccountHolding> ownedTokenAccounts,
  ) {
    for (final account in ownedTokenAccounts) {
      if (_isSpendableTokenAccount(account) &&
          account.isAssociatedTokenAccount &&
          account.balance > 0) {
        return account.address;
      }
    }
    for (final account in ownedTokenAccounts) {
      if (_isSpendableTokenAccount(account) && account.balance > 0) {
        return account.address;
      }
    }
    return null;
  }

  Future<List<TokenAccountHolding>> _loadOwnedTokenAccountsForMint({
    required String ownerAddress,
    required String mint,
  }) async {
    final response = await _makeRpcCall('getTokenAccountsByOwner', [
      ownerAddress,
      {'mint': mint},
      {'encoding': 'jsonParsed'},
    ]);

    final accounts = response['result']?['value'] as List? ?? const [];
    final ownerPub = Ed25519HDPublicKey.fromBase58(ownerAddress);
    final canonicalAta = await _findAssociatedTokenAddressSafe(
      owner: ownerPub,
      mintAddress: mint,
    );
    final ownedTokenAccounts = <TokenAccountHolding>[];
    for (final account in accounts) {
      if (account is! Map) continue;
      final address = account['pubkey']?.toString().trim() ?? '';
      if (address.isEmpty) continue;
      final parsedInfo =
          account['account']?['data']?['parsed']?['info'] as Map? ?? const {};
      final tokenAmount = parsedInfo['tokenAmount'] as Map? ?? const {};
      final decimals = (tokenAmount['decimals'] as num?)?.toInt() ?? 0;
      final rawAmount = tokenAmount['amount']?.toString() ?? '0';
      final amountRaw =
          double.tryParse(rawAmount) ?? 0.0;
      final balance =
          decimals > 0 ? amountRaw / pow(10, decimals) : amountRaw;
      ownedTokenAccounts.add(
        TokenAccountHolding(
          address: address,
          rawAmount: rawAmount,
          balance: balance,
          decimals: decimals,
          state: parsedInfo['state']?.toString() ?? 'unknown',
          isAssociatedTokenAccount:
              canonicalAta != null && WalletUtils.equals(address, canonicalAta),
        ),
      );
    }
    return _orderOwnedTokenAccounts(
      accounts: ownedTokenAccounts,
      canonicalAta: canonicalAta,
    );
  }

  TokenAccountHolding? _selectOwnedTokenAccountForAmount({
    required List<TokenAccountHolding> ownedTokenAccounts,
    required BigInt rawAmount,
  }) {
    for (final account in ownedTokenAccounts) {
      if (!_isSpendableTokenAccount(account)) continue;
      if (account.isAssociatedTokenAccount &&
          _parseRawTokenAmount(account.rawAmount) >= rawAmount) {
        return account;
      }
    }
    for (final account in ownedTokenAccounts) {
      if (!_isSpendableTokenAccount(account)) continue;
      if (_parseRawTokenAmount(account.rawAmount) >= rawAmount) {
        return account;
      }
    }
    return null;
  }

  Future<_ResolvedSplSourceAccountRecord> _resolveSplSourceAccount({
    required String ownerAddress,
    required String mint,
    required double amount,
    required int decimals,
    String? sourceTokenAccount,
  }) async {
    if (amount <= 0) {
      throw const SolanaWalletSendException(
        'Token amount must be greater than zero.',
      );
    }
    if (decimals < 0) {
      throw SolanaWalletSendException(
        'Invalid token decimals for mint $mint.',
      );
    }
    final requiredRawAmount = BigInt.from((amount * pow(10, decimals)).round());

    final ownedTokenAccounts = await _loadOwnedTokenAccountsForMint(
      ownerAddress: ownerAddress,
      mint: mint,
    );
    if (ownedTokenAccounts.isEmpty) {
      throw SolanaWalletSendException(
        'No owned token account found for mint $mint.',
      );
    }

    final actualDecimals = ownedTokenAccounts.first.decimals;
    if (actualDecimals != decimals) {
      throw SolanaWalletSendException(
        'Token decimals mismatch for mint $mint. Expected $decimals but RPC reported $actualDecimals.',
      );
    }

    final requestedSource = sourceTokenAccount?.trim();
    if (requestedSource != null && requestedSource.isNotEmpty) {
      TokenAccountHolding? matchedSource;
      for (final account in ownedTokenAccounts) {
        if (WalletUtils.equals(account.address, requestedSource)) {
          matchedSource = account;
          break;
        }
      }
      if (matchedSource == null) {
        throw SolanaWalletSendException(
          'Selected source token account is not owned by this wallet for mint $mint.',
        );
      }
      if (!_isSpendableTokenAccount(matchedSource)) {
        throw SolanaWalletSendException(
          'Selected source token account is not spendable (state: ${matchedSource.state}).',
        );
      }
      if (_parseRawTokenAmount(matchedSource.rawAmount) < requiredRawAmount) {
        throw SolanaWalletSendException(
          'Selected source token account does not have enough $mint balance for this send.',
        );
      }
      return _ResolvedSplSourceAccountRecord(
        address: matchedSource.address,
        publicKey: Ed25519HDPublicKey.fromBase58(matchedSource.address),
        balance: matchedSource.balance,
        isAssociatedTokenAccount: matchedSource.isAssociatedTokenAccount,
      );
    }

    final selected = _selectOwnedTokenAccountForAmount(
      ownedTokenAccounts: ownedTokenAccounts,
      rawAmount: requiredRawAmount,
    );
    if (selected == null) {
      final totalRawBalance = ownedTokenAccounts.fold<BigInt>(
        BigInt.zero,
        (sum, account) =>
            _isSpendableTokenAccount(account)
                ? sum + _parseRawTokenAmount(account.rawAmount)
                : sum,
      );
      if (totalRawBalance >= requiredRawAmount) {
        throw SolanaWalletSendException(
          'No single owned token account can cover $amount tokens for mint $mint. Balance is split across multiple token accounts.',
        );
      }
      throw SolanaWalletSendException(
        'Insufficient token balance in owned token accounts for mint $mint.',
      );
    }

    return _ResolvedSplSourceAccountRecord(
      address: selected.address,
      publicKey: Ed25519HDPublicKey.fromBase58(selected.address),
      balance: selected.balance,
      isAssociatedTokenAccount: selected.isAssociatedTokenAccount,
    );
  }

  Ed25519HDPublicKey _parsePublicKeyOrThrow(
    String value, {
    required String fieldName,
  }) {
    final normalized = value.trim();
    try {
      return Ed25519HDPublicKey.fromBase58(normalized);
    } catch (_) {
      throw SolanaWalletSendException(
        '$fieldName is not a valid Solana address.',
      );
    }
  }

  SolanaWalletSendException _buildRecipientAtaValidationException({
    required String ataAddress,
    required String reason,
    required String recipientAddress,
    required String mint,
    Map<String, dynamic> rpcData = const <String, dynamic>{},
  }) {
    return SolanaWalletSendException(
      'Recipient token account at $ataAddress is not valid for this token transfer: $reason',
      rpcData: {
        'recipientAta': ataAddress,
        'recipientAddress': recipientAddress,
        'mint': mint,
        ...rpcData,
      },
    );
  }

  Future<_RecipientAtaResolutionRecord> _resolveRecipientAtaForTransfer({
    required String recipientAddress,
    required String mint,
    required int decimals,
  }) async {
    final recipientPub = _parsePublicKeyOrThrow(
      recipientAddress,
      fieldName: 'Recipient address',
    );
    final mintPub = _parsePublicKeyOrThrow(
      mint,
      fieldName: 'Token mint',
    );
    late final Ed25519HDPublicKey recipientAta;
    String recipientAtaAddress = '';

    late final Map<String, dynamic> accountInfo;
    try {
      recipientAta = await findAssociatedTokenAddress(
        owner: recipientPub,
        mint: mintPub,
      );
      recipientAtaAddress = recipientAta.toBase58();
      final response = await _makeRpcCall('getAccountInfo', [
        recipientAtaAddress,
        {'encoding': 'jsonParsed'},
      ]);
      final value = response['result']?['value'];
      if (value == null) {
        return _RecipientAtaResolutionRecord(
          address: recipientAta,
          needsCreation: true,
        );
      }
      if (value is! Map) {
        throw _buildRecipientAtaValidationException(
          ataAddress: recipientAtaAddress,
          recipientAddress: recipientPub.toBase58(),
          mint: mintPub.toBase58(),
          reason:
              'the on-chain account data could not be parsed as an SPL token account',
          rpcData: {'rawAccountInfo': value},
        );
      }
      accountInfo = Map<String, dynamic>.from(value);
    } catch (e) {
      if (e is SolanaWalletSendException) rethrow;
      throw SolanaWalletSendException(
        'Unable to verify the recipient token account before creating it.',
        cause: e,
        rpcData: {
          'recipientAta': recipientAtaAddress,
          'recipientAddress': recipientPub.toBase58(),
          'mint': mintPub.toBase58(),
        },
      );
    }

    final programOwner = accountInfo['owner']?.toString().trim() ?? '';
    final data = accountInfo['data'];
    if (!WalletUtils.equals(programOwner, ApiKeys.splTokenProgramId) ||
        data is! Map) {
      throw _buildRecipientAtaValidationException(
        ataAddress: recipientAtaAddress,
        recipientAddress: recipientPub.toBase58(),
        mint: mintPub.toBase58(),
        reason: 'it is not owned by the SPL token program',
        rpcData: {
          'programOwner': programOwner,
        },
      );
    }

    final parsed = data['parsed'];
    if (parsed is! Map) {
      throw _buildRecipientAtaValidationException(
        ataAddress: recipientAtaAddress,
        recipientAddress: recipientPub.toBase58(),
        mint: mintPub.toBase58(),
        reason: 'it does not contain parsed SPL token account data',
      );
    }

    final info = parsed['info'];
    if (info is! Map) {
      throw _buildRecipientAtaValidationException(
        ataAddress: recipientAtaAddress,
        recipientAddress: recipientPub.toBase58(),
        mint: mintPub.toBase58(),
        reason: 'it does not expose the expected token account fields',
      );
    }

    final tokenOwner = info['owner']?.toString().trim() ?? '';
    final tokenMint = info['mint']?.toString().trim() ?? '';
    final state = info['state']?.toString().trim().toLowerCase() ?? 'unknown';
    final tokenAmount = info['tokenAmount'];
    if (tokenAmount is! Map) {
      throw _buildRecipientAtaValidationException(
        ataAddress: recipientAtaAddress,
        recipientAddress: recipientPub.toBase58(),
        mint: mintPub.toBase58(),
        reason: 'it is missing token balance metadata',
      );
    }

    final accountDecimals = (tokenAmount['decimals'] as num?)?.toInt();
    if (!WalletUtils.equals(tokenOwner, recipientPub.toBase58())) {
      throw _buildRecipientAtaValidationException(
        ataAddress: recipientAtaAddress,
        recipientAddress: recipientPub.toBase58(),
        mint: mintPub.toBase58(),
        reason: 'it belongs to a different owner than the intended recipient',
        rpcData: {'tokenOwner': tokenOwner},
      );
    }
    if (!WalletUtils.equals(tokenMint, mintPub.toBase58())) {
      throw _buildRecipientAtaValidationException(
        ataAddress: recipientAtaAddress,
        recipientAddress: recipientPub.toBase58(),
        mint: mintPub.toBase58(),
        reason: 'it belongs to a different mint',
        rpcData: {'tokenMint': tokenMint},
      );
    }
    if (state != 'initialized') {
      throw _buildRecipientAtaValidationException(
        ataAddress: recipientAtaAddress,
        recipientAddress: recipientPub.toBase58(),
        mint: mintPub.toBase58(),
        reason: 'it is not in an initialized, spendable state',
        rpcData: {'state': state},
      );
    }
    if (accountDecimals != null && accountDecimals != decimals) {
      throw _buildRecipientAtaValidationException(
        ataAddress: recipientAtaAddress,
        recipientAddress: recipientPub.toBase58(),
        mint: mintPub.toBase58(),
        reason: 'it reports token decimals that do not match the transfer mint',
        rpcData: {'decimals': accountDecimals},
      );
    }

    return _RecipientAtaResolutionRecord(
      address: recipientAta,
      needsCreation: false,
    );
  }

  Future<String> _sendEncodedTransactionWithDiagnostics(
    String transactionBase64,
  ) async {
    http.Response response;
    try {
      response = await http.post(
        Uri.parse(_currentRpcUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'sendTransaction',
          'params': [
            transactionBase64,
            {
              'encoding': 'base64',
              'skipPreflight': false,
              'preflightCommitment': 'confirmed',
            },
          ],
        }),
      );
    } catch (e) {
      throw SolanaWalletSendException(
        'Transaction submission failed before reaching the RPC endpoint.',
        cause: e,
      );
    }

    if (response.statusCode != 200) {
      final responseBody = _summarizeRpcBody(response.body);
      throw SolanaWalletSendException(
        responseBody.isEmpty
            ? 'Transaction submission failed: HTTP ${response.statusCode}.'
            : 'Transaction submission failed: HTTP ${response.statusCode}. $responseBody',
        rpcData: {
          'statusCode': response.statusCode,
          'body': response.body,
        },
      );
    }

    late final Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw SolanaWalletSendException(
        'Transaction submission failed: invalid RPC response.',
        cause: e,
        rpcData: {'body': response.body},
      );
    }
    final error = data['error'];
    if (error is Map) {
      throw _buildRpcSendException(Map<String, dynamic>.from(error));
    }

    final signature = data['result']?.toString().trim() ?? '';
    if (signature.isEmpty) {
      throw const SolanaWalletSendException(
        'Transaction submission failed: missing RPC signature.',
      );
    }
    return signature;
  }

  SolanaWalletSendException _buildRpcSendException(
    Map<String, dynamic> error,
  ) {
    final rpcMessage = error['message']?.toString().trim();
    final data = error['data'] is Map
        ? Map<String, dynamic>.from(error['data'] as Map)
        : const <String, dynamic>{};
    final logs = (data['logs'] as List?)
            ?.map((entry) => entry?.toString() ?? '')
            .where((entry) => entry.trim().isNotEmpty)
            .toList(growable: false) ??
        const <String>[];

    String message = rpcMessage?.isNotEmpty == true
        ? rpcMessage!
        : 'Transaction simulation failed.';
    final loweredLogs = logs.map((entry) => entry.toLowerCase()).toList();
    final loweredMessage = message.toLowerCase();

    final insufficientRent = loweredLogs.any(
          (entry) =>
              entry.contains('rent-exempt') ||
              entry.contains('rent exemption') ||
              entry.contains('insufficient lamports') ||
              entry.contains('create associated token account') ||
              entry.contains('associated token account'),
        ) ||
        loweredMessage.contains('insufficient lamports');
    if (insufficientRent) {
      message =
          'Insufficient SOL to pay network fees or create the recipient token account.';
    } else if (loweredMessage.contains('insufficient funds') ||
        loweredLogs.any((entry) => entry.contains('insufficient funds'))) {
      message =
          'Insufficient funds in the selected source account for this transfer.';
    } else if (loweredMessage.contains('owner does not match') ||
        loweredLogs.any(
          (entry) =>
              entry.contains('owner does not match') ||
              entry.contains('provided owner is not allowed') ||
              entry.contains('owner mismatch'),
        )) {
      message =
        'A token account used for this transfer is not valid for the expected owner or mint.';
    } else if (loweredMessage.contains('invalid account data') ||
        loweredLogs.any((entry) => entry.contains('invalid account data'))) {
      message =
        'A token account used for this transfer is invalid for the selected mint.';
    } else if (loweredMessage.contains('frozen') ||
        loweredLogs.any((entry) => entry.contains('frozen'))) {
      message =
        'A token account used for this transfer is frozen and cannot move tokens.';
    } else if (loweredMessage.contains('mint decimals') ||
        loweredMessage.contains('decimals mismatch') ||
        loweredMessage.contains('decimal') ||
        loweredLogs.any((entry) => entry.contains('decimal'))) {
      message =
          'Token decimals do not match the mint configuration for this transfer.';
    } else if (loweredLogs.any(
      (entry) =>
          entry.contains('associated token account') &&
          entry.contains('create'),
    )) {
      message =
          'Failed to create the recipient token account. The recipient address may be invalid or the wallet may not have enough SOL.';
    }

    return SolanaWalletSendException(
      _normalizeSendFailureMessage(message),
      rpcMessage: rpcMessage,
      logs: logs,
      rpcData: data,
    );
  }

  String _normalizeSendFailureMessage(String message) {
    final trimmed = message.trim();
    if (trimmed.startsWith('Exception:')) {
      return trimmed.substring('Exception:'.length).trim();
    }
    return trimmed;
  }

  String _summarizeRpcBody(String body) {
    final normalized = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return '';
    if (normalized.length <= 180) return normalized;
    return '${normalized.substring(0, 177)}...';
  }

  BigInt _parseRawTokenAmount(String rawAmount) {
    final normalized = rawAmount.trim();
    if (normalized.isEmpty) return BigInt.zero;
    return BigInt.tryParse(normalized) ?? BigInt.zero;
  }

  bool _isSpendableTokenAccount(TokenAccountHolding account) {
    final state = account.state.trim().toLowerCase();
    return state.isEmpty || state == 'initialized';
  }

  List<MetadataCreator>? _parseMetadataCreators(
    Map<String, dynamic> metadata,
    Ed25519HDPublicKey payer,
  ) {
    final raw = metadata['creators'];
    if (raw is List) {
      final parsed = <MetadataCreator>[];
      for (final entry in raw) {
        if (entry is! Map<String, dynamic>) continue;
        final address = entry['address']?.toString().trim() ?? '';
        if (address.isEmpty) continue;
        try {
          parsed.add(
            MetadataCreator(
              address: Ed25519HDPublicKey.fromBase58(address),
              verified: entry['verified'] as bool? ?? false,
              share: (entry['share'] as num?)?.toInt() ?? 0,
            ),
          );
        } catch (_) {
          continue;
        }
      }
      final totalShare = parsed.fold<int>(0, (sum, c) => sum + c.share);
      if (parsed.isNotEmpty && totalShare == 100) {
        return parsed;
      }
    }
    return [
      MetadataCreator(
        address: payer,
        verified: true,
        share: 100,
      ),
    ];
  }

  MetadataCollection? _parseMetadataCollection(Map<String, dynamic> metadata) {
    final raw = metadata['collection'] ?? metadata['collectionMint'];
    final collectionAddress =
        raw is Map ? raw['address']?.toString() : (raw?.toString());
    if (collectionAddress == null || collectionAddress.isEmpty) {
      return null;
    }
    try {
      return MetadataCollection(
        verified: (raw is Map && raw['verified'] is bool)
            ? raw['verified'] as bool
            : false,
        key: Ed25519HDPublicKey.fromBase58(collectionAddress),
      );
    } catch (_) {
      return null;
    }
  }

  int _parseSellerFeeBps(Map<String, dynamic> metadata) {
    final raw = metadata['sellerFeeBasisPoints'] ??
        metadata['seller_fee_basis_points'] ??
        metadata['sellerFee'] ??
        metadata['royaltyBps'];
    final bps = (raw is num) ? raw.toInt() : 0;
    return bps.clamp(0, 10000).toInt();
  }

  String _truncateMetadataField(String value, int maxLength) {
    if (value.length <= maxLength) return value;
    return value.substring(0, maxLength);
  }

  Future<SubmittedSolanaTransactionRecord> _sendInstructions(
    List<Instruction> instructions, {
    List<Ed25519HDKeyPair> extraSigners = const [],
  }) async {
    if (!hasActiveKeyPair) {
      throw SolanaWalletSendException('No active keypair set for signing.');
    }
    final signers = [_activeKeyPair!, ...extraSigners];
    final latest = await _rpcClient.getLatestBlockhash();
    final message = Message(instructions: instructions);
    final signedTx = await signTransaction(
      latest.value,
      message,
      signers,
    );
    final sig = await _sendEncodedTransactionWithDiagnostics(signedTx.encode());
    return SubmittedSolanaTransactionRecord(
      signature: sig,
      lastValidBlockHeight: latest.value.lastValidBlockHeight,
      explorerUrl: buildExplorerTransactionUrl(sig),
    );
  }

  Future<UnsignedSolanaTransactionRecord> _buildUnsignedTransaction({
    required String feePayerAddress,
    required List<Instruction> instructions,
  }) async {
    final latest = await _rpcClient.getLatestBlockhash();
    final message = Message(instructions: instructions);
    final compiledMessage = message.compile(
      recentBlockhash: latest.value.blockhash,
      feePayer: Ed25519HDPublicKey.fromBase58(feePayerAddress),
    );
    final signatures = List<Signature>.generate(
      compiledMessage.requiredSignatureCount,
      (index) => Signature(
        List<int>.filled(64, 0),
        publicKey: compiledMessage.accountKeys[index],
      ),
    );
    return UnsignedSolanaTransactionRecord(
      transactionBase64: SignedTx(
        signatures: signatures,
        compiledMessage: compiledMessage,
      ).encode(),
      lastValidBlockHeight: latest.value.lastValidBlockHeight,
    );
  }

  Future<UnsignedSolanaTransactionRecord> _buildUnsignedVersionedTransaction({
    required String feePayerAddress,
    required List<Instruction> instructions,
    required List<AddressLookupTableAccount> addressLookupTableAccounts,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    final latest = await _rpcClient.getLatestBlockhash();
    final message = Message(instructions: instructions);
    final compiledMessage = message.compileV0(
      recentBlockhash: latest.value.blockhash,
      feePayer: Ed25519HDPublicKey.fromBase58(feePayerAddress),
      addressLookupTableAccounts: addressLookupTableAccounts,
    );
    final signatures = List<Signature>.generate(
      compiledMessage.requiredSignatureCount,
      (index) => Signature(
        List<int>.filled(64, 0),
        publicKey: compiledMessage.accountKeys[index],
      ),
    );
    return UnsignedSolanaTransactionRecord(
      transactionBase64: SignedTx(
        signatures: signatures,
        compiledMessage: compiledMessage,
      ).encode(),
      lastValidBlockHeight: latest.value.lastValidBlockHeight,
      metadata: metadata,
    );
  }

  Future<List<Instruction>> _buildSplTokenTransferInstructions({
    required String fromAddress,
    required String mint,
    required String toAddress,
    required double amount,
    required int decimals,
    String? sourceTokenAccount,
  }) async {
    final fromPub = Ed25519HDPublicKey.fromBase58(fromAddress);
    final mintPub = _parsePublicKeyOrThrow(
      mint,
      fieldName: 'Token mint',
    );
    final toPub = _parsePublicKeyOrThrow(
      toAddress,
      fieldName: 'Recipient address',
    );
    final resolvedSource = await _resolveSplSourceAccount(
      ownerAddress: fromAddress,
      mint: mint,
      amount: amount,
      decimals: decimals,
      sourceTokenAccount: sourceTokenAccount,
    );
    final recipientAta = await _resolveRecipientAtaForTransfer(
      recipientAddress: toAddress,
      mint: mint,
      decimals: decimals,
    );
    final toAta = recipientAta.address;

    final instructions = <Instruction>[];
    if (recipientAta.needsCreation) {
      instructions.add(
        AssociatedTokenAccountInstruction.createAccount(
          address: toAta,
          funder: fromPub,
          owner: toPub,
          mint: mintPub,
        ),
      );
    }

    final amountRaw = (amount * pow(10, decimals)).round();
    instructions.add(
      TokenInstruction.transferChecked(
        source: resolvedSource.publicKey,
        mint: mintPub,
        destination: toAta,
        owner: fromPub,
        amount: amountRaw,
        decimals: decimals,
      ),
    );
    return instructions;
  }

  Future<UnsignedSolanaTransactionRecord> _buildAtomicJupiterSwapTransaction({
    required String userPublicKey,
    required String outputMint,
    required bool wrapAndUnwrapSol,
    required Map<String, dynamic> route,
    required int platformFeeBps,
    required String? platformFeeOwnerAddress,
    FeeSplitterProgramInstructionRecord? feeSplitterProgram,
    int? quoteContextSlot,
    double? quoteTimeTakenMs,
  }) async {
    final rawRoutePlatformFeeBps = (route['platformFee'] as Map?)?['feeBps'];
    final routePlatformFeeBps = switch (rawRoutePlatformFeeBps) {
      int value => value,
      num value => value.toInt(),
      String value => int.tryParse(value) ?? 0,
      _ => 0,
    };
    final rawRoutePlatformFeeAmount = (route['platformFee'] as Map?)?['amount'];
    final routePlatformFeeAmountRaw = switch (rawRoutePlatformFeeAmount) {
      int value => value,
      num value => value.toInt(),
      String value => int.tryParse(value) ?? 0,
      _ => 0,
    };
    if (platformFeeBps > 0 && routePlatformFeeBps != platformFeeBps) {
      throw const SolanaWalletSendException(
        'Swap quote is missing the required platform fee metadata. Refresh the quote and try again.',
      );
    }

    final userPub = Ed25519HDPublicKey.fromBase58(userPublicKey);
    final outputMintPub = Ed25519HDPublicKey.fromBase58(outputMint);
    final createdAtaAddresses = <String>{};
    final preSwapInstructions = <Instruction>[];

    String? destinationTokenAccount;
    final outputIsWrappedSol = WalletUtils.equals(
      outputMint,
      ApiKeys.wrappedSolMintAddress,
    );
    if (!outputIsWrappedSol) {
      final userOutputAta = await findAssociatedTokenAddress(
        owner: userPub,
        mint: outputMintPub,
      );
      destinationTokenAccount = userOutputAta.toBase58();
      if (await _safeGetAccountInfo(destinationTokenAccount) == null &&
          createdAtaAddresses.add(destinationTokenAccount)) {
        preSwapInstructions.add(
          AssociatedTokenAccountInstruction.createAccount(
            funder: userPub,
            address: userOutputAta,
            owner: userPub,
            mint: outputMintPub,
          ),
        );
      }
    }

    String? feeAccount;
    final feeOwnerAddress = feeSplitterProgram?.vaultAuthorityAddress.trim() ??
        platformFeeOwnerAddress?.trim() ??
        '';
    if (platformFeeBps > 0) {
      if (feeOwnerAddress.isEmpty) {
        throw const SolanaWalletSendException(
          'Swap platform fee collection is not configured for this wallet.',
        );
      }
      final feeOwnerPub = Ed25519HDPublicKey.fromBase58(feeOwnerAddress);
      final feeAta = await findAssociatedTokenAddress(
        owner: feeOwnerPub,
        mint: outputMintPub,
      );
      feeAccount = feeAta.toBase58();
      if (await _safeGetAccountInfo(feeAccount) == null &&
          createdAtaAddresses.add(feeAccount)) {
        preSwapInstructions.add(
          AssociatedTokenAccountInstruction.createAccount(
            funder: userPub,
            address: feeAta,
            owner: feeOwnerPub,
            mint: outputMintPub,
          ),
        );
      }
    }

    Instruction? feeSplitterInstruction;
    if (feeSplitterProgram != null && routePlatformFeeAmountRaw > 0) {
      if (!WalletUtils.equals(
        feeOwnerAddress,
        feeSplitterProgram.vaultAuthorityAddress,
      )) {
        throw const SolanaWalletSendException(
          'Fee splitter program configuration does not match the platform fee vault authority.',
        );
      }
      if (feeSplitterProgram.totalPlatformFeeAmountRaw != routePlatformFeeAmountRaw) {
        throw const SolanaWalletSendException(
          'Fee splitter amounts do not match the Jupiter platform fee amount for this quote.',
        );
      }
      if (feeAccount == null || feeAccount.isEmpty) {
        throw const SolanaWalletSendException(
          'Fee splitter program requires a platform fee token account.',
        );
      }
      feeSplitterInstruction = await _buildFeeSplitterProgramInstruction(
        feeSplitterProgram: feeSplitterProgram,
        userPublicKey: userPub,
        outputMintPublicKey: outputMintPub,
        platformFeeAccountAddress: feeAccount,
      );
    }

    final swapInstructionJson = _extractProxyPayload(
      await _postJupiterJson(
        path: 'swap-instructions',
        body: {
          'quoteResponse': route,
          'userPublicKey': userPublicKey,
          'payer': userPublicKey,
          'wrapAndUnwrapSol': wrapAndUnwrapSol,
          'useSharedAccounts': true,
          'asLegacyTransaction': false,
          'dynamicComputeUnitLimit': true,
          'skipUserAccountsRpcCalls': preSwapInstructions.isNotEmpty,
          if (feeAccount != null) 'feeAccount': feeAccount,
          if (feeOwnerAddress.isNotEmpty) 'trackingAccount': feeOwnerAddress,
          if (destinationTokenAccount != null)
            'destinationTokenAccount': destinationTokenAccount,
          if (outputIsWrappedSol) 'nativeDestinationAccount': userPublicKey,
        },
      ),
    );

    final instructions = <Instruction>[
      ..._parseJupiterInstructionList(
        swapInstructionJson['computeBudgetInstructions'],
      ),
      ...preSwapInstructions,
      ..._parseJupiterInstructionList(swapInstructionJson['otherInstructions']),
      ..._parseJupiterInstructionList(swapInstructionJson['setupInstructions']),
      _buildJupiterInstruction(
        Map<String, dynamic>.from(
          swapInstructionJson['swapInstruction'] as Map? ?? const {},
        ),
      ),
      ..._parseJupiterInstructionList(
        swapInstructionJson['cleanupInstruction'] == null
            ? const <dynamic>[]
            : <dynamic>[swapInstructionJson['cleanupInstruction']],
      ),
      if (feeSplitterInstruction != null) feeSplitterInstruction,
    ];

    if (instructions.isEmpty) {
      throw const SolanaWalletSendException(
        'Jupiter did not return any swap instructions.',
      );
    }

    final addressLookupTableAccounts = await _loadAddressLookupTableAccounts(
      swapInstructionJson['addressLookupTableAddresses'] as List?,
    );
    return _buildUnsignedVersionedTransaction(
      feePayerAddress: userPublicKey,
      instructions: instructions,
      addressLookupTableAccounts: addressLookupTableAccounts,
      metadata: {
        'route': route,
        'quoteContextSlot': quoteContextSlot,
        'quoteTimeTakenMs': quoteTimeTakenMs,
        'programs': _extractRouteLabels(route),
        'platformFeeBps': platformFeeBps,
        'platformFeeAccount': feeAccount,
        'platformFeeOwnerAddress': feeOwnerAddress.isEmpty
            ? null
            : feeOwnerAddress,
        'feeSettlementMode': feeSplitterProgram == null ? 'direct' : 'program',
        'feeSplitterProgramId': feeSplitterProgram?.programId,
        'feeSplitterConfigAccount': feeSplitterProgram?.configAccountAddress,
        'feeSplitterVaultAuthority': feeSplitterProgram?.vaultAuthorityAddress,
        'destinationTokenAccount': destinationTokenAccount,
      },
    );
  }

  Future<Instruction> _buildFeeSplitterProgramInstruction({
    required FeeSplitterProgramInstructionRecord feeSplitterProgram,
    required Ed25519HDPublicKey userPublicKey,
    required Ed25519HDPublicKey outputMintPublicKey,
    required String platformFeeAccountAddress,
  }) async {
    final programId =
        Ed25519HDPublicKey.fromBase58(feeSplitterProgram.programId);
    final configAccount = Ed25519HDPublicKey.fromBase58(
      feeSplitterProgram.configAccountAddress,
    );
    final vaultAuthority = Ed25519HDPublicKey.fromBase58(
      feeSplitterProgram.vaultAuthorityAddress,
    );
    final platformFeeAccount =
        Ed25519HDPublicKey.fromBase58(platformFeeAccountAddress);
    final teamWallet = Ed25519HDPublicKey.fromBase58(
      feeSplitterProgram.teamWalletAddress,
    );
    final treasuryWallet = Ed25519HDPublicKey.fromBase58(
      feeSplitterProgram.treasuryWalletAddress,
    );
    final teamTokenAccount = await findAssociatedTokenAddress(
      owner: teamWallet,
      mint: outputMintPublicKey,
    );
    final treasuryTokenAccount = await findAssociatedTokenAddress(
      owner: treasuryWallet,
      mint: outputMintPublicKey,
    );

    return Instruction(
      programId: programId,
      accounts: <AccountMeta>[
        AccountMeta.writeable(pubKey: configAccount, isSigner: false),
        AccountMeta.readonly(pubKey: vaultAuthority, isSigner: false),
        AccountMeta.writeable(pubKey: platformFeeAccount, isSigner: false),
        AccountMeta.writeable(pubKey: userPublicKey, isSigner: true),
        AccountMeta.readonly(pubKey: teamWallet, isSigner: false),
        AccountMeta.writeable(pubKey: teamTokenAccount, isSigner: false),
        AccountMeta.readonly(pubKey: treasuryWallet, isSigner: false),
        AccountMeta.writeable(pubKey: treasuryTokenAccount, isSigner: false),
        AccountMeta.readonly(pubKey: outputMintPublicKey, isSigner: false),
        AccountMeta.readonly(pubKey: TokenProgram.id, isSigner: false),
        AccountMeta.readonly(
          pubKey: AssociatedTokenAccountProgram.id,
          isSigner: false,
        ),
        AccountMeta.readonly(pubKey: SystemProgram.id, isSigner: false),
      ],
      data: ByteArray.merge([
        ByteArray.u8(1),
        ByteArray.u64(feeSplitterProgram.totalPlatformFeeAmountRaw),
      ]),
    );
  }

  List<Instruction> _parseJupiterInstructionList(dynamic instructions) {
    if (instructions is! List) return const <Instruction>[];
    return instructions
        .whereType<Map>()
        .map((entry) => _buildJupiterInstruction(Map<String, dynamic>.from(entry)))
        .toList(growable: false);
  }

  Instruction _buildJupiterInstruction(Map<String, dynamic> rawInstruction) {
    final programId = rawInstruction['programId']?.toString().trim() ?? '';
    if (programId.isEmpty) {
      throw const SolanaWalletSendException(
        'Jupiter returned an instruction without a program id.',
      );
    }
    final accounts = (rawInstruction['accounts'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (entry) => AccountMeta(
            pubKey: Ed25519HDPublicKey.fromBase58(
              entry['pubkey']?.toString().trim() ?? '',
            ),
            isWriteable: entry['isWritable'] as bool? ?? false,
            isSigner: entry['isSigner'] as bool? ?? false,
          ),
        )
        .toList(growable: false);
    final data = rawInstruction['data']?.toString() ?? '';
    return Instruction(
      programId: Ed25519HDPublicKey.fromBase58(programId),
      accounts: accounts,
      data: ByteArray(base64Decode(data)),
    );
  }

  Future<List<AddressLookupTableAccount>> _loadAddressLookupTableAccounts(
    List? rawAddresses,
  ) async {
    if (rawAddresses == null || rawAddresses.isEmpty) {
      return const <AddressLookupTableAccount>[];
    }
    final addresses = rawAddresses
        .map((entry) => entry?.toString().trim() ?? '')
        .where((entry) => entry.isNotEmpty)
        .toSet()
        .toList(growable: false);
    return Future.wait(
      addresses.map(
        (address) => _rpcClient.getAddressLookupTable(
          Ed25519HDPublicKey.fromBase58(address),
        ),
      ),
    );
  }

  Future<_JupiterSwapRequestRecord> _buildJupiterSwapRequest({
    required String inputMint,
    required String outputMint,
    required int inputAmountRaw,
    required int slippageBps,
    SwapQuote? quote,
    int platformFeeBps = 0,
  }) async {
    if (quote != null) {
      return _JupiterSwapRequestRecord(
        route: quote.rawRoute,
        contextSlot: quote.contextSlot,
        timeTakenMs: quote.timeTakenMs,
      );
    }

    final quoteJson = _extractProxyPayload(
      await _getJupiterJson(
        path: 'quote',
        queryParameters: {
          'inputMint': inputMint,
          'outputMint': outputMint,
          'amount': '$inputAmountRaw',
          'slippageBps': '$slippageBps',
          'swapMode': 'ExactIn',
          if (platformFeeBps > 0) 'platformFeeBps': '$platformFeeBps',
          'instructionVersion': 'V2',
        },
      ),
    );

    return _JupiterSwapRequestRecord(
      route: Map<String, dynamic>.from(quoteJson),
      contextSlot: (quoteJson['contextSlot'] as num?)?.toInt(),
      timeTakenMs: (quoteJson['timeTaken'] as num?)?.toDouble(),
    );
  }

  List<String> _extractRouteLabels(Map<String, dynamic>? route) {
    if (route == null) return const <String>[];
    final routePlan = route['routePlan'] as List?;
    if (routePlan == null) return const <String>[];
    return routePlan
        .map((step) {
          if (step is! Map) return '';
          final swapInfo = step['swapInfo'];
          if (swapInfo is Map && swapInfo['label'] != null) {
            return swapInfo['label'].toString();
          }
          return step['label']?.toString() ?? '';
        })
        .where((label) => label.trim().isNotEmpty)
        .cast<String>()
        .toList();
  }

  Future<int?> _fetchCurrentSlot() async {
    try {
      final response = await _makeRpcCall('getSlot', [
        {'commitment': 'processed'},
      ]);
      return (response['result'] as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }

  Future<WalletTransaction?> _parseWalletTransaction({
    required String publicKey,
    required _SignatureStatusRecord signatureRecord,
    required Map<String, dynamic>? transactionJson,
    required int? currentSlot,
  }) async {
    if (transactionJson == null) {
      return null;
    }

    final meta = Map<String, dynamic>.from(
      transactionJson['meta'] as Map? ?? const {},
    );
    final transaction = Map<String, dynamic>.from(
      transactionJson['transaction'] as Map? ?? const {},
    );
    final message = Map<String, dynamic>.from(
      transaction['message'] as Map? ?? const {},
    );
    final accountKeysRaw = message['accountKeys'] as List? ?? const [];
    final accountKeys = accountKeysRaw
        .map((item) => _accountKeyToString(item))
        .where((item) => item.isNotEmpty)
        .toList();

    final feeLamports = (meta['fee'] as num?)?.toInt() ?? 0;
    final feeAmount = feeLamports / _lamportsPerSol;
    final tokenOwnerLookup =
        _buildTokenOwnerLookup(meta: meta, accountKeys: accountKeys);
    final tokenMintLookup =
        _buildTokenMintLookup(meta: meta, accountKeys: accountKeys);
    final transferRecords = _extractTransferRecords(
      transactionMessage: message,
      meta: meta,
      tokenOwnerLookup: tokenOwnerLookup,
      tokenMintLookup: tokenMintLookup,
    );
    final assetChanges = await _buildAssetChanges(
      publicKey: publicKey,
      meta: meta,
      accountKeys: accountKeys,
      feeAmount: feeAmount,
      transferRecords: transferRecords,
    );
    final classification = _classifyTransaction(
      publicKey: publicKey,
      assetChanges: assetChanges,
      transferRecords: transferRecords,
    );

    final timestamp = signatureRecord.blockTime ??
        _parseRpcBlockTime(transactionJson['blockTime']) ??
        DateTime.now();
    final slot =
        (transactionJson['slot'] as num?)?.toInt() ?? signatureRecord.slot;
    final confirmationCount = currentSlot == null || slot == null
        ? null
        : max(0, currentSlot - slot).clamp(0, 1 << 31);

    return WalletTransaction(
      id: signatureRecord.signature,
      signature: signatureRecord.signature,
      explorerUrl: buildExplorerTransactionUrl(signatureRecord.signature),
      type: classification.type,
      status: _mapStatus(signatureRecord),
      direction: classification.direction,
      finality: _mapFinality(signatureRecord.confirmationStatus),
      token: classification.primarySymbol,
      tokenMint: classification.primaryMint,
      assetKind: classification.primaryAssetKind,
      amount: classification.primaryAmount,
      amountIn: classification.amountIn,
      amountOut: classification.amountOut,
      netAmount: classification.netAmount,
      primaryCounterparty: classification.counterparty,
      fromAddress: classification.fromAddress,
      toAddress: classification.toAddress,
      timestamp: timestamp,
      slot: slot,
      confirmationCount: confirmationCount,
      feeAmount: feeAmount > 0 ? feeAmount : null,
      feeToken: 'SOL',
      feeTokenMint: 'native',
      gasUsed: (meta['computeUnitsConsumed'] as num?)?.toDouble(),
      gasFee: feeAmount > 0 ? feeAmount : null,
      swapToToken: classification.swapToToken,
      swapToAmount: classification.swapToAmount,
      assetChanges: assetChanges,
      metadata: {
        'memo': signatureRecord.memo,
        'confirmationStatus': signatureRecord.confirmationStatus,
        'err': signatureRecord.err,
        'version': transactionJson['version'],
        'programs': transferRecords
            .map((record) => record.program)
            .where((program) => program.trim().isNotEmpty)
            .toSet()
            .toList(),
      },
    );
  }

  Map<String, String> _buildTokenOwnerLookup({
    required Map<String, dynamic> meta,
    required List<String> accountKeys,
  }) {
    final lookup = <String, String>{};
    for (final entry in [
      ...(meta['preTokenBalances'] as List? ?? const []),
      ...(meta['postTokenBalances'] as List? ?? const []),
    ]) {
      if (entry is! Map) continue;
      final accountIndex = (entry['accountIndex'] as num?)?.toInt();
      final owner = entry['owner']?.toString();
      if (accountIndex == null ||
          accountIndex < 0 ||
          accountIndex >= accountKeys.length ||
          owner == null ||
          owner.trim().isEmpty) {
        continue;
      }
      lookup[accountKeys[accountIndex]] = owner;
    }
    return lookup;
  }

  Map<String, String> _buildTokenMintLookup({
    required Map<String, dynamic> meta,
    required List<String> accountKeys,
  }) {
    final lookup = <String, String>{};
    for (final entry in [
      ...(meta['preTokenBalances'] as List? ?? const []),
      ...(meta['postTokenBalances'] as List? ?? const []),
    ]) {
      if (entry is! Map) continue;
      final accountIndex = (entry['accountIndex'] as num?)?.toInt();
      final mint = entry['mint']?.toString();
      if (accountIndex == null ||
          accountIndex < 0 ||
          accountIndex >= accountKeys.length ||
          mint == null ||
          mint.trim().isEmpty) {
        continue;
      }
      lookup[accountKeys[accountIndex]] = mint;
    }
    return lookup;
  }

  List<_TransferRecord> _extractTransferRecords({
    required Map<String, dynamic> transactionMessage,
    required Map<String, dynamic> meta,
    required Map<String, String> tokenOwnerLookup,
    required Map<String, String> tokenMintLookup,
  }) {
    final instructions = <dynamic>[
      ...(transactionMessage['instructions'] as List? ?? const []),
    ];
    final innerInstructions = meta['innerInstructions'] as List? ?? const [];
    for (final entry in innerInstructions) {
      if (entry is! Map) continue;
      instructions.addAll(entry['instructions'] as List? ?? const []);
    }

    final records = <_TransferRecord>[];
    for (final instruction in instructions) {
      if (instruction is! Map) continue;
      final parsed = instruction['parsed'];
      if (parsed is! Map) continue;
      final program = instruction['program']?.toString() ?? '';
      final type = parsed['type']?.toString() ?? '';
      final info = parsed['info'];
      if (info is! Map) continue;

      if (program == 'system' && type == 'transfer') {
        final source = info['source']?.toString() ?? '';
        final destination = info['destination']?.toString() ?? '';
        final lamports = (info['lamports'] as num?)?.toInt() ?? 0;
        records.add(
          _TransferRecord(
            program: program,
            type: type,
            assetKind: WalletTransactionAssetKind.native,
            mint: 'native',
            sourceAddress: source,
            destinationAddress: destination,
            sourceOwner: source,
            destinationOwner: destination,
            amount: lamports / _lamportsPerSol,
          ),
        );
        continue;
      }

      if (program == 'spl-token' &&
          (type == 'transfer' || type == 'transferChecked')) {
        final source = info['source']?.toString() ?? '';
        final destination = info['destination']?.toString() ?? '';
        final tokenAmount = info['tokenAmount'];
        final amount = _parseUiTokenAmount(tokenAmount);
        final mint = info['mint']?.toString() ??
            tokenMintLookup[source] ??
            tokenMintLookup[destination];
        if (mint == null || mint.trim().isEmpty) {
          continue;
        }
        records.add(
          _TransferRecord(
            program: program,
            type: type,
            assetKind: WalletTransactionAssetKind.spl,
            mint: mint,
            sourceAddress: source,
            destinationAddress: destination,
            sourceOwner: tokenOwnerLookup[source] ?? source,
            destinationOwner: tokenOwnerLookup[destination] ?? destination,
            amount: amount,
          ),
        );
      }
    }
    return records;
  }

  Future<List<WalletTransactionAssetChange>> _buildAssetChanges({
    required String publicKey,
    required Map<String, dynamic> meta,
    required List<String> accountKeys,
    required double feeAmount,
    required List<_TransferRecord> transferRecords,
  }) async {
    final changes = <WalletTransactionAssetChange>[];
    final preToken = _aggregateOwnedTokenBalances(
      balances: meta['preTokenBalances'] as List? ?? const [],
      owner: publicKey,
    );
    final postToken = _aggregateOwnedTokenBalances(
      balances: meta['postTokenBalances'] as List? ?? const [],
      owner: publicKey,
    );
    final mints = <String>{...preToken.keys, ...postToken.keys};
    for (final mint in mints) {
      final preAmount = preToken[mint]?.amount ?? 0.0;
      final postAmount = postToken[mint]?.amount ?? 0.0;
      final delta = postAmount - preAmount;
      if (delta.abs() < 0.000000001) continue;
      final tokenInfo = await _getTokenInfo(
        mint,
        decimalsHint: postToken[mint]?.decimals ?? preToken[mint]?.decimals,
      );
      changes.add(
        WalletTransactionAssetChange(
          symbol: (tokenInfo['symbol'] ?? _fallbackSymbol(mint)).toString(),
          mint: mint,
          decimals: (tokenInfo['decimals'] as num?)?.toInt() ??
              postToken[mint]?.decimals ??
              preToken[mint]?.decimals,
          assetKind: WalletTransactionAssetKind.spl,
          amount: delta,
          direction: delta > 0
              ? WalletTransactionDirection.incoming
              : WalletTransactionDirection.outgoing,
        ),
      );
    }

    final nativeIndex = accountKeys.indexOf(publicKey);
    if (nativeIndex >= 0) {
      final preBalances =
          (meta['preBalances'] as List? ?? const []).cast<num>();
      final postBalances =
          (meta['postBalances'] as List? ?? const []).cast<num>();
      final preLamports =
          nativeIndex < preBalances.length ? preBalances[nativeIndex] : 0;
      final postLamports =
          nativeIndex < postBalances.length ? postBalances[nativeIndex] : 0;
      final nativeDelta =
          (postLamports.toDouble() - preLamports.toDouble()) / _lamportsPerSol;
      var adjustedNativeDelta = nativeDelta;
      if (adjustedNativeDelta < 0 && feeAmount > 0) {
        adjustedNativeDelta += feeAmount;
      }
      if (adjustedNativeDelta.abs() >= 0.000000001) {
        changes.add(
          WalletTransactionAssetChange(
            symbol: 'SOL',
            mint: 'native',
            decimals: 9,
            assetKind: WalletTransactionAssetKind.native,
            amount: adjustedNativeDelta,
            direction: adjustedNativeDelta > 0
                ? WalletTransactionDirection.incoming
                : WalletTransactionDirection.outgoing,
          ),
        );
      }
    }

    if (feeAmount > 0) {
      changes.add(
        WalletTransactionAssetChange(
          symbol: 'SOL',
          mint: 'native',
          decimals: 9,
          assetKind: WalletTransactionAssetKind.native,
          amount: -feeAmount,
          direction: WalletTransactionDirection.outgoing,
          isFee: true,
          label: 'Network fee',
        ),
      );
    }

    return changes;
  }

  Map<String, _OwnedTokenBalanceRecord> _aggregateOwnedTokenBalances({
    required List balances,
    required String owner,
  }) {
    final aggregated = <String, _OwnedTokenBalanceRecord>{};
    for (final entry in balances) {
      if (entry is! Map) continue;
      final normalizedOwner = entry['owner']?.toString();
      if (normalizedOwner == null ||
          !WalletUtils.equals(normalizedOwner, owner)) {
        continue;
      }
      final mint = entry['mint']?.toString();
      if (mint == null || mint.trim().isEmpty) continue;
      final uiTokenAmount = entry['uiTokenAmount'];
      final amount = _parseUiTokenAmount(uiTokenAmount);
      final decimals =
          (uiTokenAmount is Map ? uiTokenAmount['decimals'] as num? : null)
              ?.toInt();
      final existing = aggregated[mint];
      aggregated[mint] = _OwnedTokenBalanceRecord(
        amount: (existing?.amount ?? 0) + amount,
        decimals: decimals ?? existing?.decimals,
      );
    }
    return aggregated;
  }

  _TransactionClassificationRecord _classifyTransaction({
    required String publicKey,
    required List<WalletTransactionAssetChange> assetChanges,
    required List<_TransferRecord> transferRecords,
  }) {
    final nonFeeChanges = assetChanges.where((change) => !change.isFee).toList()
      ..sort((a, b) => b.absoluteAmount.compareTo(a.absoluteAmount));
    final incoming = nonFeeChanges
        .where((change) => change.amount > 0)
        .toList(growable: false);
    final outgoing = nonFeeChanges
        .where((change) => change.amount < 0)
        .toList(growable: false);

    TransactionType type = TransactionType.receive;
    WalletTransactionDirection direction = WalletTransactionDirection.neutral;
    WalletTransactionAssetChange? primaryChange;
    WalletTransactionAssetChange? secondaryChange;

    if (incoming.isNotEmpty && outgoing.isNotEmpty) {
      type = TransactionType.swap;
      direction = WalletTransactionDirection.swap;
      primaryChange = outgoing.first;
      secondaryChange = incoming.first;
    } else if (outgoing.isNotEmpty) {
      primaryChange = outgoing.first;
      final transferRecord = _matchTransferRecord(
        publicKey: publicKey,
        primaryChange: primaryChange,
        transferRecords: transferRecords,
        preferredDirection: WalletTransactionDirection.outgoing,
      );
      if (transferRecord != null &&
          _directionForTransfer(publicKey, transferRecord) ==
              WalletTransactionDirection.self) {
        type = TransactionType.send;
        direction = WalletTransactionDirection.self;
      } else {
        type = TransactionType.send;
        direction = WalletTransactionDirection.outgoing;
      }
    } else if (incoming.isNotEmpty) {
      primaryChange = incoming.first;
      type = TransactionType.receive;
      direction = WalletTransactionDirection.incoming;
    } else {
      final feeOnly = assetChanges.firstWhere(
        (change) => change.isFee,
        orElse: () => const WalletTransactionAssetChange(
          symbol: 'SOL',
          amount: 0,
          isFee: true,
        ),
      );
      primaryChange = feeOnly;
      type = TransactionType.send;
      direction = WalletTransactionDirection.outgoing;
    }

    final transferRecord = _matchTransferRecord(
      publicKey: publicKey,
      primaryChange: primaryChange,
      transferRecords: transferRecords,
      preferredDirection: direction,
    );
    final netAmount = nonFeeChanges.fold<double>(
      0.0,
      (sum, change) => sum + change.amount,
    );

    return _TransactionClassificationRecord(
      type: type,
      direction: direction,
      primarySymbol: primaryChange.symbol,
      primaryMint: primaryChange.mint,
      primaryAssetKind: primaryChange.assetKind,
      primaryAmount: primaryChange.absoluteAmount,
      amountIn: incoming.isNotEmpty ? incoming.first.absoluteAmount : null,
      amountOut: outgoing.isNotEmpty ? outgoing.first.absoluteAmount : null,
      netAmount: netAmount == 0 ? null : netAmount,
      counterparty: transferRecord == null
          ? primaryChange.counterparty
          : _counterpartyForTransfer(
              publicKey: publicKey,
              direction: direction,
              record: transferRecord,
            ),
      fromAddress: transferRecord?.sourceOwner,
      toAddress: transferRecord?.destinationOwner,
      swapToToken: secondaryChange?.symbol,
      swapToAmount: secondaryChange?.absoluteAmount,
    );
  }

  _TransferRecord? _matchTransferRecord({
    required String publicKey,
    required WalletTransactionAssetChange? primaryChange,
    required List<_TransferRecord> transferRecords,
    required WalletTransactionDirection preferredDirection,
  }) {
    if (primaryChange == null) {
      return null;
    }
    for (final record in transferRecords) {
      final sameAsset = primaryChange.isNative
          ? record.assetKind == WalletTransactionAssetKind.native
          : WalletUtils.equals(record.mint, primaryChange.mint);
      if (!sameAsset) continue;
      final recordDirection = _directionForTransfer(publicKey, record);
      if (preferredDirection == WalletTransactionDirection.swap ||
          recordDirection == preferredDirection) {
        return record;
      }
    }
    return null;
  }

  WalletTransactionDirection _directionForTransfer(
    String publicKey,
    _TransferRecord record,
  ) {
    final sourceMatches = WalletUtils.equals(record.sourceOwner, publicKey);
    final destinationMatches =
        WalletUtils.equals(record.destinationOwner, publicKey);
    if (sourceMatches && destinationMatches) {
      return WalletTransactionDirection.self;
    }
    if (sourceMatches) {
      return WalletTransactionDirection.outgoing;
    }
    if (destinationMatches) {
      return WalletTransactionDirection.incoming;
    }
    return WalletTransactionDirection.neutral;
  }

  String? _counterpartyForTransfer({
    required String publicKey,
    required WalletTransactionDirection direction,
    required _TransferRecord record,
  }) {
    switch (direction) {
      case WalletTransactionDirection.incoming:
        return WalletUtils.equals(record.sourceOwner, publicKey)
            ? record.sourceAddress
            : record.sourceOwner;
      case WalletTransactionDirection.outgoing:
        return WalletUtils.equals(record.destinationOwner, publicKey)
            ? record.destinationAddress
            : record.destinationOwner;
      case WalletTransactionDirection.swap:
        return record.program;
      case WalletTransactionDirection.self:
        return WalletUtils.equals(record.destinationOwner, publicKey)
            ? record.destinationAddress
            : record.destinationOwner;
      case WalletTransactionDirection.neutral:
        return record.destinationOwner;
    }
  }

  DateTime? _parseRpcBlockTime(dynamic blockTime) {
    if (blockTime is num) {
      return DateTime.fromMillisecondsSinceEpoch(blockTime.toInt() * 1000);
    }
    final asString = blockTime?.toString();
    if (asString == null || asString.trim().isEmpty) {
      return null;
    }
    final asInt = int.tryParse(asString);
    if (asInt != null) {
      return DateTime.fromMillisecondsSinceEpoch(asInt * 1000);
    }
    return DateTime.tryParse(asString);
  }

  TransactionStatus _mapStatus(_SignatureStatusRecord signatureRecord) {
    if (signatureRecord.err != null) {
      return TransactionStatus.failed;
    }
    switch (signatureRecord.confirmationStatus) {
      case 'finalized':
        return TransactionStatus.finalized;
      case 'confirmed':
        return TransactionStatus.confirmed;
      case 'processed':
        return TransactionStatus.pending;
      default:
        return TransactionStatus.pending;
    }
  }

  WalletTransactionFinality _mapFinality(String? confirmationStatus) {
    switch (confirmationStatus) {
      case 'processed':
        return WalletTransactionFinality.processed;
      case 'confirmed':
        return WalletTransactionFinality.confirmed;
      case 'finalized':
        return WalletTransactionFinality.finalized;
      default:
        return WalletTransactionFinality.unknown;
    }
  }

  String _accountKeyToString(dynamic value) {
    if (value is String) {
      return value;
    }
    if (value is Map && value['pubkey'] != null) {
      return value['pubkey'].toString();
    }
    return '';
  }

  double _parseUiTokenAmount(dynamic value) {
    if (value is Map) {
      final uiAmountString = value['uiAmountString']?.toString();
      if (uiAmountString != null && uiAmountString.isNotEmpty) {
        return double.tryParse(uiAmountString) ?? 0.0;
      }
      final uiAmount = value['uiAmount'];
      if (uiAmount is num) {
        return uiAmount.toDouble();
      }
      final amountRaw = value['amount']?.toString();
      final decimals = (value['decimals'] as num?)?.toInt() ?? 0;
      final raw = double.tryParse(amountRaw ?? '0') ?? 0.0;
      if (decimals <= 0) {
        return raw;
      }
      return raw / pow(10, decimals);
    }
    if (value is num) {
      return value.toDouble();
    }
    return 0.0;
  }

  // Private helper methods
  Future<Map<String, dynamic>> _makeRpcCall(
      String method, List<dynamic> params) async {
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

  String _fallbackSymbol(String mint) {
    final normalized = WalletUtils.canonical(mint);
    if (normalized.length >= 4) {
      return normalized.substring(0, 4).toUpperCase();
    }
    return normalized.toUpperCase();
  }

  String _fallbackName(String mint) {
    final normalized = WalletUtils.canonical(mint);
    final short =
        normalized.length >= 6 ? normalized.substring(0, 6) : normalized;
    return 'Token ${short.toUpperCase()}';
  }

  String? _resolveTokenImage(String? candidate) {
    if (candidate == null) return null;
    final trimmed = candidate.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('https://') || trimmed.startsWith('http://')) {
      return trimmed;
    }
    if (trimmed.startsWith('//')) {
      return 'https:$trimmed';
    }
    if (trimmed.startsWith('ipfs://')) {
      final cid = _normalizeIpfsPath(trimmed.substring(7));
      return StorageConfig.resolveUrl('ipfs://$cid');
    }
    if (trimmed.startsWith('ipfs/')) {
      final cid = _normalizeIpfsPath(trimmed.substring(5));
      return StorageConfig.resolveUrl('ipfs://$cid');
    }
    if (trimmed.startsWith('/ipfs/')) {
      final cid = _normalizeIpfsPath(trimmed.substring(6));
      return StorageConfig.resolveUrl('ipfs://$cid');
    }
    if (trimmed.contains('/ipfs/') && !trimmed.startsWith('http')) {
      return StorageConfig.resolveUrl(trimmed);
    }
    if (StorageConfig.isLikelyCid(trimmed)) {
      return StorageConfig.resolveUrl(trimmed);
    }
    return trimmed;
  }

  String _normalizeIpfsPath(String value) {
    var normalized = value.trim();
    if (normalized.startsWith('ipfs/')) {
      normalized = normalized.substring(5);
    }
    while (normalized.startsWith('/')) {
      normalized = normalized.substring(1);
    }
    return normalized;
  }

  Future<Map<String, dynamic>> _getTokenInfo(String mint,
      {int? decimalsHint}) async {
    final normalizedMint = WalletUtils.canonical(mint);
    final cached = _tokenMetadataCache[normalizedMint];
    if (cached != null && !cached.isExpired(_tokenMetadataCacheTtl)) {
      final cachedData = Map<String, dynamic>.from(cached.data);
      cachedData['decimals'] ??= decimalsHint;
      return cachedData;
    }

    final base = Map<String, dynamic>.from(_knownTokens[normalizedMint] ?? {});
    base['decimals'] ??= decimalsHint;
    base['symbol'] ??= _fallbackSymbol(normalizedMint);
    base['name'] ??= _fallbackName(normalizedMint);

    if (WalletUtils.equals(normalizedMint, ApiKeys.kub8MintAddress)) {
      final sanitized = Map<String, dynamic>.from(base)
        ..removeWhere((key, value) => value == null);
      _tokenMetadataCache[normalizedMint] = _TokenMetadataCacheEntry(
        data: sanitized,
        timestamp: DateTime.now(),
      );
      return sanitized;
    }

    try {
      final metadata = await _rpcClient.getMetadata(
        mint: Ed25519HDPublicKey.fromBase58(mint),
        commitment: Commitment.confirmed,
      );

      if (metadata != null) {
        final onChainSymbol = metadata.symbol.trim();
        final onChainName = metadata.name.trim();
        final metadataUri = metadata.uri.trim();
        if (onChainSymbol.isNotEmpty) base['symbol'] = onChainSymbol;
        if (onChainName.isNotEmpty) base['name'] = onChainName;
        if (metadataUri.isNotEmpty) base['uri'] = metadataUri;

        final offChain =
            await IpfsMetadataResolver.instance.resolveJson(metadataUri);
        if (offChain != null) {
          final description = offChain['description']?.toString().trim();
          if (description != null && description.isNotEmpty) {
            base['description'] = description;
          }
          final offChainName = offChain['name']?.toString().trim();
          if (offChainName != null && offChainName.isNotEmpty) {
            base['name'] = offChainName;
          }
          final offChainSymbol = offChain['symbol']?.toString().trim();
          if (offChainSymbol != null && offChainSymbol.isNotEmpty) {
            base['symbol'] = offChainSymbol;
          }
          final resolvedImage = _resolveTokenImage(
            offChain['image']?.toString(),
          );
          if (resolvedImage != null) {
            base['logoUrl'] = resolvedImage;
          }
          base['rawOffChainMetadata'] = offChain;
        }
      }
    } catch (e) {
      debugPrint('SolanaWalletService: Metadata lookup failed for $mint -> $e');
    }

    base['logoUrl'] ??= _knownTokens[normalizedMint]?['logoUrl'];
    base['decimals'] ??= decimalsHint ?? ApiKeys.kub8Decimals;

    final sanitized = Map<String, dynamic>.from(base)
      ..removeWhere((key, value) => value == null);
    _tokenMetadataCache[normalizedMint] = _TokenMetadataCacheEntry(
      data: sanitized,
      timestamp: DateTime.now(),
    );
    return sanitized;
  }

  @visibleForTesting
  Future<Map<String, dynamic>> getTokenInfoForTesting(
    String mint, {
    int? decimalsHint,
  }) {
    return _getTokenInfo(mint, decimalsHint: decimalsHint);
  }
}

class _TokenMetadataCacheEntry {
  final Map<String, dynamic> data;
  final DateTime timestamp;

  _TokenMetadataCacheEntry({required this.data, required this.timestamp});

  bool isExpired(Duration ttl) => DateTime.now().difference(timestamp) > ttl;
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
  final String? logoUrl;
  final String? metadataUri;
  final String? description;
  final Map<String, dynamic>? rawMetadata;
  final String? preferredSourceTokenAccount;
  final List<TokenAccountHolding> ownedTokenAccounts;

  TokenBalance({
    required this.mint,
    required this.symbol,
    required this.name,
    required this.balance,
    required this.decimals,
    required this.uiAmount,
    this.logoUrl,
    this.metadataUri,
    this.description,
    this.rawMetadata,
    this.preferredSourceTokenAccount,
    this.ownedTokenAccounts = const [],
  });
}

class UnsignedSolanaTransactionRecord {
  const UnsignedSolanaTransactionRecord({
    required this.transactionBase64,
    this.lastValidBlockHeight,
    this.metadata = const {},
  });

  final String transactionBase64;
  final int? lastValidBlockHeight;
  final Map<String, dynamic> metadata;
}

class SubmittedSolanaTransactionRecord {
  const SubmittedSolanaTransactionRecord({
    required this.signature,
    this.lastValidBlockHeight,
    this.explorerUrl,
    this.metadata = const {},
  });

  final String signature;
  final int? lastValidBlockHeight;
  final String? explorerUrl;
  final Map<String, dynamic> metadata;
}

class FeeSplitterProgramInstructionRecord {
  const FeeSplitterProgramInstructionRecord({
    required this.programId,
    required this.configAccountAddress,
    required this.vaultAuthorityAddress,
    required this.teamWalletAddress,
    required this.treasuryWalletAddress,
    required this.totalPlatformFeeAmountRaw,
  });

  final String programId;
  final String configAccountAddress;
  final String vaultAuthorityAddress;
  final String teamWalletAddress;
  final String treasuryWalletAddress;
  final int totalPlatformFeeAmountRaw;
}

class SolanaWalletSendException implements Exception {
  const SolanaWalletSendException(
    this.message, {
    this.rpcMessage,
    this.logs = const <String>[],
    this.rpcData = const <String, dynamic>{},
    this.cause,
  });

  final String message;
  final String? rpcMessage;
  final List<String> logs;
  final Map<String, dynamic> rpcData;
  final Object? cause;

  @override
  String toString() => message;
}

class _OwnedMintBalanceAggregationRecord {
  _OwnedMintBalanceAggregationRecord({
    required this.mint,
    required this.decimals,
  });

  final String mint;
  int decimals;
  double totalBalance = 0;
  double totalUiAmount = 0;
  final List<TokenAccountHolding> ownedTokenAccounts = <TokenAccountHolding>[];
}

class _ResolvedSplSourceAccountRecord {
  const _ResolvedSplSourceAccountRecord({
    required this.address,
    required this.publicKey,
    required this.balance,
    required this.isAssociatedTokenAccount,
  });

  final String address;
  final Ed25519HDPublicKey publicKey;
  final double balance;
  final bool isAssociatedTokenAccount;
}

class _RecipientAtaResolutionRecord {
  const _RecipientAtaResolutionRecord({
    required this.address,
    required this.needsCreation,
  });

  final Ed25519HDPublicKey address;
  final bool needsCreation;
}

class _SignatureStatusRecord {
  const _SignatureStatusRecord({
    required this.signature,
    required this.slot,
    required this.blockTime,
    required this.confirmationStatus,
    this.memo,
    this.err,
  });

  final String signature;
  final int? slot;
  final DateTime? blockTime;
  final String? confirmationStatus;
  final String? memo;
  final dynamic err;

  factory _SignatureStatusRecord.fromJson(Map<String, dynamic> json) {
    final blockTimeSeconds = (json['blockTime'] as num?)?.toInt();
    return _SignatureStatusRecord(
      signature: (json['signature'] ?? '').toString(),
      slot: (json['slot'] as num?)?.toInt(),
      blockTime: blockTimeSeconds == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(blockTimeSeconds * 1000),
      confirmationStatus: json['confirmationStatus']?.toString(),
      memo: json['memo']?.toString(),
      err: json['err'],
    );
  }
}

class _OwnedTokenBalanceRecord {
  const _OwnedTokenBalanceRecord({
    required this.amount,
    this.decimals,
  });

  final double amount;
  final int? decimals;
}

class _TransferRecord {
  const _TransferRecord({
    required this.program,
    required this.type,
    required this.assetKind,
    this.mint,
    required this.sourceAddress,
    required this.destinationAddress,
    required this.sourceOwner,
    required this.destinationOwner,
    required this.amount,
  });

  final String program;
  final String type;
  final WalletTransactionAssetKind assetKind;
  final String? mint;
  final String sourceAddress;
  final String destinationAddress;
  final String sourceOwner;
  final String destinationOwner;
  final double amount;
}

class _TransactionClassificationRecord {
  const _TransactionClassificationRecord({
    required this.type,
    required this.direction,
    required this.primarySymbol,
    required this.primaryMint,
    required this.primaryAssetKind,
    required this.primaryAmount,
    this.amountIn,
    this.amountOut,
    this.netAmount,
    this.counterparty,
    this.fromAddress,
    this.toAddress,
    this.swapToToken,
    this.swapToAmount,
  });

  final TransactionType type;
  final WalletTransactionDirection direction;
  final String primarySymbol;
  final String? primaryMint;
  final WalletTransactionAssetKind primaryAssetKind;
  final double primaryAmount;
  final double? amountIn;
  final double? amountOut;
  final double? netAmount;
  final String? counterparty;
  final String? fromAddress;
  final String? toAddress;
  final String? swapToToken;
  final double? swapToAmount;
}

class _JupiterSwapRequestRecord {
  const _JupiterSwapRequestRecord({
    required this.route,
    this.contextSlot,
    this.timeTakenMs,
  });

  final Map<String, dynamic>? route;
  final int? contextSlot;
  final double? timeTakenMs;
}
