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
import '../utils/wallet_utils.dart';

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
      'logoUrl': 'https://assets.coingecko.com/coins/images/6319/standard/USD_Coin_icon.png',
      'decimals': 6,
    },
    'so11111111111111111111111111111111111111112': {
      'symbol': 'SOL',
      'name': 'Solana',
      'logoUrl': 'https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet/So11111111111111111111111111111111111111112/logo.png',
      'decimals': 9,
    },
    WalletUtils.canonical(ApiKeys.kub8MintAddress): {
      'symbol': 'KUB8',
      'name': 'Kubus Governance Token',
      'logoUrl': 'https://api.kubus.site/tokens/kub8.png',
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

  Future<Map<String, double>> _fetchLamportBalances(List<String> addresses) async {
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
      final batch = ordered.sublist(i, min(i + _maxAccountsPerBatch, ordered.length));
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
        debugPrint('SolanaWalletService: batched balance lookup failed for ${batch.length} accounts -> $e');
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

    final cacheKey = '${_cacheKeyForMnemonic(trimmedMnemonic)}::${accountCandidates.join('-')}|${changeCandidates.join('-')}|$includeLegacy';
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

  bool get hasActiveKeyPair => _activeKeyPair != null;

  String? get activePublicKey => _activeKeyPair?.address;

  Future<String?> getActivePublicKey() async {
    return activePublicKey;
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
      List<TokenBalance> tokenBalances = [];

      for (final account in accounts) {
        final parsedInfo = account['account']['data']['parsed']['info'];
        final tokenAmount = parsedInfo['tokenAmount'];
        final mint = parsedInfo['mint'];
        final decimals = (tokenAmount['decimals'] as num?)?.toInt() ?? 0;
        final amountRaw = double.tryParse(tokenAmount['amount']?.toString() ?? '0') ?? 0.0;
        final balance = decimals > 0 ? amountRaw / pow(10, decimals) : amountRaw;
        final uiAmount = tokenAmount['uiAmount'];

        final tokenInfo = await _getTokenInfo(mint, decimalsHint: decimals);

        tokenBalances.add(TokenBalance(
          mint: mint,
          symbol: (tokenInfo['symbol'] ?? _fallbackSymbol(mint)).toString(),
          name: (tokenInfo['name'] ?? 'Unknown Token').toString(),
          balance: balance,
          decimals: decimals,
          uiAmount: uiAmount is num ? uiAmount.toDouble() : balance,
          logoUrl: tokenInfo['logoUrl'] as String?,
          metadataUri: tokenInfo['uri'] as String?,
          description: tokenInfo['description'] as String?,
          rawMetadata: tokenInfo['rawOffChainMetadata'] as Map<String, dynamic>?,
        ));
      }

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
        final decimals = tokenAmount['decimals'] as int? ?? expectedDecimals ?? 0;
        final amountRaw = double.tryParse(tokenAmount['amount']?.toString() ?? '0') ?? 0.0;
        total += amountRaw / pow(10, decimals);
      }

      return total;
    } catch (e) {
      debugPrint('Error getting SPL balance for $mint: $e');
      return 0.0;
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

  // Transfer native SOL between accounts
  Future<String> transferSol({required String toAddress, required double amount}) async {
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
      final signature = await _sendInstructions([ix]);
      return signature;
    } catch (e) {
      debugPrint('SOL transfer failed: $e');
      rethrow;
    }
  }

  // Transfer SPL token (KUB8 or others) - placeholder wiring
  Future<String> transferSplToken({
    required String mint,
    required String toAddress,
    required double amount,
    required int decimals,
  }) async {
    if (!hasActiveKeyPair) {
      throw Exception('No active keypair set for SPL transfer');
    }
    final fromPub = Ed25519HDPublicKey.fromBase58(_activeKeyPair!.address);
    final mintPub = Ed25519HDPublicKey.fromBase58(mint);
    final toPub = Ed25519HDPublicKey.fromBase58(toAddress);

    final fromAta = await findAssociatedTokenAddress(owner: fromPub, mint: mintPub);
    final toAta = await findAssociatedTokenAddress(owner: toPub, mint: mintPub);

    final instructions = <Instruction>[];

    // Create destination ATA if missing
    final toAccountInfo = await _safeGetAccountInfo(toAta.toBase58());
    if (toAccountInfo == null) {
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
        source: fromAta,
        mint: mintPub,
        destination: toAta,
        owner: fromPub,
        amount: amountRaw,
        decimals: decimals,
      ),
    );

    return _sendInstructions(instructions);
  }

  // Swap SOL -> SPL token (e.g., SOL -> KUB8) via DEX aggregator (Jupiter/Raydium)
  Future<String> swapSolToSpl({required String mint, required double solAmount, double slippage = 0.5}) async {
    return _executeJupiterSwap(
      inputMint: 'So11111111111111111111111111111111111111112',
      outputMint: mint,
      inputAmountRaw: (solAmount * 1000000000).round(),
      slippageBps: (slippage * 100).round(),
      wrapAndUnwrapSol: true,
    );
  }

  // Swap SPL -> SPL token (client-side simulation until on-chain swap is wired)
  Future<String> swapSplToken({
    required String fromMint,
    required String toMint,
    required double amount,
    double slippage = 0.01,
  }) async {
    final decimals = ApiKeys.kub8Decimals; // assume SPL has decimals set; adjust if needed
    return _executeJupiterSwap(
      inputMint: fromMint,
      outputMint: toMint,
      inputAmountRaw: (amount * pow(10, decimals)).round(),
      slippageBps: (slippage * 10000).round(),
      wrapAndUnwrapSol: false,
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
      metadata['name']?.toString().trim() ?? 'Kubus Collectible',
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

    return _sendInstructions(
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
  }

  Future<dynamic> _safeGetAccountInfo(String address) async {
    try {
      return await _rpcClient.getAccountInfo(address);
    } catch (_) {
      return null;
    }
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
    final collectionAddress = raw is Map
        ? raw['address']?.toString()
        : (raw?.toString());
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

  Future<String> _sendInstructions(List<Instruction> instructions, {List<Ed25519HDKeyPair> extraSigners = const []}) async {
    final signers = [_activeKeyPair!, ...extraSigners];
    final latest = await _rpcClient.getLatestBlockhash();
    final message = Message(instructions: instructions);
    final signedTx = await signTransaction(
      latest.value,
      message,
      signers,
    );
    final sig = await _rpcClient.sendTransaction(
      signedTx.encode(),
      skipPreflight: true,
    );
    return sig;
  }

  Future<String> _executeJupiterSwap({
    required String inputMint,
    required String outputMint,
    required int inputAmountRaw,
    required int slippageBps,
    required bool wrapAndUnwrapSol,
  }) async {
    if (!hasActiveKeyPair) {
      throw Exception('No active keypair set for swap');
    }

    final quoteUri = Uri.parse('${ApiKeys.jupiterBaseUrl}/quote').replace(queryParameters: {
      'inputMint': inputMint,
      'outputMint': outputMint,
      'amount': '$inputAmountRaw',
      'slippageBps': '$slippageBps',
    });

    final quoteResp = await http.get(quoteUri);
    if (quoteResp.statusCode != 200) {
      throw Exception('Jupiter quote failed: ${quoteResp.statusCode} ${quoteResp.body}');
    }
    final quoteJson = jsonDecode(quoteResp.body) as Map<String, dynamic>;
    final route = (quoteJson['data'] as List).isNotEmpty ? quoteJson['data'][0] as Map<String, dynamic> : null;
    if (route == null) {
      throw Exception('No Jupiter route available');
    }

    final swapResp = await http.post(
      Uri.parse('${ApiKeys.jupiterBaseUrl}/swap'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'quoteResponse': route,
        'userPublicKey': _activeKeyPair!.address,
        'wrapAndUnwrapSol': wrapAndUnwrapSol,
      }),
    );

    if (swapResp.statusCode != 200) {
      throw Exception('Jupiter swap build failed: ${swapResp.statusCode} ${swapResp.body}');
    }

    final swapJson = jsonDecode(swapResp.body) as Map<String, dynamic>;
    final swapTx = swapJson['swapTransaction'] as String?;
    if (swapTx == null) {
      throw Exception('Jupiter swapTransaction missing');
    }

    final unsigned = SignedTx.decode(swapTx);
    final requiredSignatures = unsigned.compiledMessage.requiredSignatureCount;
    if (requiredSignatures < 1) {
      throw Exception('Jupiter swap did not request any signatures');
    }

    final signatures = List<Signature>.from(unsigned.signatures);
    if (signatures.length != requiredSignatures) {
      throw Exception(
        'Swap transaction expects $requiredSignatures signatures but received ${signatures.length}.',
      );
    }

    signatures[0] = await _activeKeyPair!.sign(
      unsigned.compiledMessage.toByteArray(),
    );

    final signedTx = unsigned.copyWith(signatures: signatures);

    return _rpcClient.sendTransaction(
      signedTx.encode(),
      skipPreflight: false,
      preflightCommitment: Commitment.confirmed,
    );
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

  String _fallbackSymbol(String mint) {
    final normalized = WalletUtils.canonical(mint);
    if (normalized.length >= 4) {
      return normalized.substring(0, 4).toUpperCase();
    }
    return normalized.toUpperCase();
  }

  String _fallbackName(String mint) {
    final normalized = WalletUtils.canonical(mint);
    final short = normalized.length >= 6 ? normalized.substring(0, 6) : normalized;
    return 'Token ${short.toUpperCase()}';
  }

  String? _resolveTokenImage(String? candidate) {
    if (candidate == null) return null;
    final trimmed = candidate.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('ipfs://')) {
      final cid = _normalizeIpfsPath(trimmed.substring(7));
      return '$_ipfsGatewayBase$cid';
    }
    if (trimmed.startsWith('ipfs/')) {
      final cid = _normalizeIpfsPath(trimmed.substring(5));
      return '$_ipfsGatewayBase$cid';
    }
    if (trimmed.startsWith('https://') || trimmed.startsWith('http://')) {
      return trimmed;
    }
    if (trimmed.startsWith('//')) {
      return 'https:$trimmed';
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

  String get _ipfsGatewayBase {
    final base = ApiKeys.ipfsGateway.trim();
    if (base.isEmpty) {
      return 'https://ipfs.io/ipfs/';
    }
    return base.endsWith('/') ? base : '$base/';
  }

  Future<Map<String, dynamic>> _getTokenInfo(String mint, {int? decimalsHint}) async {
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

        try {
            final offChain =
                await metadata.getExternalJson().timeout(const Duration(seconds: 6));
            base['description'] = offChain.description;
            if (offChain.name.trim().isNotEmpty) base['name'] = offChain.name.trim();
            if (offChain.symbol.trim().isNotEmpty) base['symbol'] = offChain.symbol.trim();
            final resolvedImage = _resolveTokenImage(offChain.image);
            if (resolvedImage != null) {
              base['logoUrl'] = resolvedImage;
            }
            base['rawOffChainMetadata'] = offChain.toJson();
        } catch (e) {
          debugPrint('SolanaWalletService: Failed to fetch off-chain metadata for $mint -> $e');
        }
      }
    } catch (e) {
      debugPrint('SolanaWalletService: Metadata lookup failed for $mint -> $e');
    }

    base['logoUrl'] ??= _knownTokens[normalizedMint]?['logoUrl'];
    base['decimals'] ??= decimalsHint ?? ApiKeys.kub8Decimals;

    final sanitized = Map<String, dynamic>.from(base)..removeWhere((key, value) => value == null);
    _tokenMetadataCache[normalizedMint] = _TokenMetadataCacheEntry(
      data: sanitized,
      timestamp: DateTime.now(),
    );
    return sanitized;
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
