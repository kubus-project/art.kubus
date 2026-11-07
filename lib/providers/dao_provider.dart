import 'package:flutter/foundation.dart';
import '../config/api_keys.dart';
import '../config/config.dart';
import '../models/dao.dart';
import '../services/backend_api_service.dart';
import '../services/dao_signed_envelope_service.dart';
import '../services/telemetry/telemetry_uuid.dart';
import '../services/solana_wallet_service.dart';
import 'wallet_provider.dart';

class DAOProvider extends ChangeNotifier {
  final SolanaWalletService _solanaService;
  final DAOSignedEnvelopeService _signedEnvelopeService;
  List<Proposal> _proposals = [];
  List<Vote> _votes = [];
  List<Delegate> _delegates = [];
  List<DAOTransaction> _transactions = [];
  bool _isLoading = false;
  Object? _loadError;
  double? _treasuryOnChainBalance;
  WalletProvider? _walletProvider;

  DAOProvider({
    SolanaWalletService? solanaWalletService,
    DAOSignedEnvelopeService? signedEnvelopeService,
  })  : _solanaService = solanaWalletService ?? SolanaWalletService(),
        _signedEnvelopeService =
            signedEnvelopeService ?? const DAOSignedEnvelopeService();

  // DAO data loads lazily on first read instead of in the constructor. The
  // provider is constructed at app startup (proxy provider), which used to
  // fire 5 backend requests + a Solana RPC on boot for every user — including
  // guests who never open a DAO surface. First access schedules the load in a
  // microtask (never synchronously, so no notifyListeners during build) and
  // listeners rebuild when data arrives, same as before.
  bool _loadRequested = false;

  void _scheduleInitialLoad() {
    if (_loadRequested) return;
    _loadRequested = true;
    Future.microtask(_loadData);
  }

  /// Explicitly kick off (or await) the initial DAO data load.
  Future<void> ensureLoaded() {
    _loadRequested = true;
    return refreshData();
  }

  // Getters
  List<Proposal> get proposals {
    _scheduleInitialLoad();
    return List.unmodifiable(_proposals);
  }

  List<Vote> get votes {
    _scheduleInitialLoad();
    return List.unmodifiable(_votes);
  }

  List<Delegate> get delegates {
    _scheduleInitialLoad();
    return List.unmodifiable(_delegates);
  }

  List<DAOTransaction> get transactions {
    _scheduleInitialLoad();
    return List.unmodifiable(_transactions);
  }

  bool get isLoading => _isLoading;

  /// The last load failure, or null. Screens use it to tell a network
  /// failure apart from "no proposals" (the lists are emptied on failure).
  Object? get loadError => _loadError;

  double? get treasuryOnChainBalance {
    _scheduleInitialLoad();
    return _treasuryOnChainBalance;
  }

  Future<void> _loadData() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _loadFromBackend();
    } catch (e) {
      debugPrint('Error loading DAO data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadFromBackend() async {
    _loadError = null;
    try {
      final api = BackendApiService();
      try {
        await api.ensureAuthLoaded();
      } catch (_) {}

      final proposalsJson = await api.getDAOProposals();
      _proposals = proposalsJson.map((e) => Proposal.fromJson(e)).toList();

      final votesJson = await api.getDAOVotes();
      _votes = votesJson.map((e) => Vote.fromJson(e)).toList();

      final delegatesJson = await api.getDAODelegates();
      _delegates = delegatesJson.map((e) => Delegate.fromJson(e)).toList();

      final txJson = await api.getDAOTransactions();
      _transactions = txJson.map((e) => DAOTransaction.fromJson(e)).toList();
    } catch (e) {
      debugPrint('DAOProvider _loadFromBackend error: $e');
      _loadError = e;
      _proposals = [];
      _votes = [];
      _delegates = [];
      _transactions = [];
      _treasuryOnChainBalance = null;
    }
  }

  Future<void>? _treasuryLoad;
  DateTime? _treasuryLoadedAt;
  static const Duration _treasuryMaxAge = Duration(minutes: 5);

  /// Reads the on-chain treasury balance for governance surfaces only.
  ///
  /// This is a Solana RPC, so it is deliberately not part of the shared DAO
  /// load: guests and walletless accounts must not trigger it just by opening
  /// the map. Concurrent callers share one in-flight read, and a fresh result
  /// is reused for [_treasuryMaxAge].
  Future<void> ensureTreasuryOnChainBalance() {
    final loadedAt = _treasuryLoadedAt;
    if (loadedAt != null &&
        DateTime.now().difference(loadedAt) < _treasuryMaxAge) {
      return Future<void>.value();
    }
    final inFlight = _treasuryLoad;
    if (inFlight != null) return inFlight;
    final load = _refreshOnChainTreasuryBalance().whenComplete(() {
      _treasuryLoadedAt = DateTime.now();
      _treasuryLoad = null;
    });
    _treasuryLoad = load;
    return load;
  }

  /// Public refresh hook so UI flows can ensure delegates/groups are present.
  Future<void> refreshData({bool force = false}) async {
    _loadRequested = true;
    if (_isLoading) return;
    final bool hasData = _delegates.isNotEmpty ||
        _proposals.isNotEmpty ||
        _transactions.isNotEmpty;
    if (!force && hasData) return;
    await _loadData();
  }

  void bindWalletProvider(WalletProvider walletProvider) {
    if (identical(_walletProvider, walletProvider)) return;
    _walletProvider = walletProvider;
  }

  String _requireSigningWallet() {
    final walletProvider = _walletProvider;
    if (walletProvider == null || !walletProvider.canTransact) {
      throw StateError('A ready wallet signer is required for DAO actions.');
    }

    final wallet = (walletProvider.currentWalletAddress ?? '').trim();
    if (wallet.isEmpty) {
      throw StateError('No active wallet signer is available.');
    }
    return wallet;
  }

  Future<void> _ensureBackendSessionForAction(
      DAOSignedEnvelope envelope) async {
    final walletProvider = _walletProvider;
    if (walletProvider == null) {
      throw StateError('A wallet provider is required for DAO actions.');
    }

    final ok = await walletProvider.ensureBackendSessionForActiveSigner(
      walletAddress: envelope.walletAddress,
    );
    if (!ok) {
      throw StateError('Unable to establish a wallet-signed backend session.');
    }
  }

  Future<DAOSignedEnvelope> _signEnvelope({
    required DAOSignedActionType actionType,
    required Map<String, dynamic> payload,
    Map<String, dynamic>? references,
    String? actionId,
    String? referenceId,
    String? referenceCid,
  }) async {
    final walletProvider = _walletProvider;
    final wallet = _requireSigningWallet();
    return _signedEnvelopeService.signEnvelope(
      actionType: actionType,
      walletAddress: wallet,
      signMessage: walletProvider!.signMessage,
      payload: payload,
      references: references,
      actionId: actionId,
      referenceId: referenceId,
      referenceCid: referenceCid,
    );
  }

  // Proposal methods
  List<Proposal> getActiveProposals() {
    return _proposals.where((p) => p.isActive).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<Proposal> getProposalsByType(ProposalType type) {
    return _proposals.where((p) => p.type == type).toList();
  }

  Proposal? getProposalById(String id) {
    try {
      return _proposals.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<Proposal?> createProposal({
    required String title,
    required String description,
    required ProposalType type,
    int votingPeriodDays = 7,
    double supportRequired = 0.5,
    double quorumRequired = 0.1,
    List<String>? supportingDocuments,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final api = BackendApiService();
      final proposalId = TelemetryUuid.v4();
      final signedEnvelope = await _signEnvelope(
        actionType: DAOSignedActionType.proposalCreate,
        referenceId: proposalId,
        referenceCid: metadata?['contentCid']?.toString(),
        references: <String, dynamic>{
          'proposalId': proposalId,
          if (metadata?['contentCid'] != null)
            'contentCid': metadata!['contentCid'].toString(),
        },
        payload: {
          'proposalId': proposalId,
          'title': title,
          'description': description,
          'type': type.name,
          'votingPeriodDays': votingPeriodDays,
          'supportRequired': supportRequired,
          'quorumRequired': quorumRequired,
          'supportingDocuments': supportingDocuments ?? const <String>[],
          'metadata': metadata ?? const <String, dynamic>{},
          if (metadata?['contentCid'] != null)
            'contentCid': metadata!['contentCid'].toString(),
        },
      );
      await _ensureBackendSessionForAction(signedEnvelope);
      final payload = await api.createDAOProposal(
        envelope: signedEnvelope.toJson(),
      );
      if (payload != null) {
        final proposal = Proposal.fromJson(payload);
        _proposals.insert(0, proposal);
        notifyListeners();
        return proposal;
      }
    } catch (e) {
      debugPrint('DAOProvider.createProposal error: $e');
      rethrow;
    }
    throw StateError('DAO proposal creation did not return a proposal.');
  }

  Future<void> castVote({
    required String proposalId,
    required VoteChoice choice,
    String? reason,
    String? txHash,
  }) async {
    try {
      final api = BackendApiService();
      final signedEnvelope = await _signEnvelope(
        actionType: DAOSignedActionType.voteCast,
        referenceId: proposalId,
        references: <String, dynamic>{
          'proposalId': proposalId,
        },
        payload: {
          'proposalId': proposalId,
          'choice': choice.name,
          'votingPowerMode': 'server_snapshot',
          if (reason != null && reason.isNotEmpty) 'reason': reason,
          if (txHash != null && txHash.isNotEmpty) 'txHash': txHash,
        },
      );
      await _ensureBackendSessionForAction(signedEnvelope);
      final payload = await api.submitDAOVote(
        proposalId: proposalId,
        envelope: signedEnvelope.toJson(),
      );

      if (payload != null) {
        final votePayload = payload['vote'] ?? payload;
        final proposalPayload = payload['proposal'];

        final vote = Vote.fromJson(votePayload as Map<String, dynamic>);
        _votes.removeWhere(
            (v) => v.proposalId == proposalId && v.voter == vote.voter);
        _votes.add(vote);

        if (proposalPayload is Map<String, dynamic>) {
          final updatedProposal = Proposal.fromJson(proposalPayload);
          _proposals.removeWhere((p) => p.id == updatedProposal.id);
          _proposals.add(updatedProposal);
        } else {
          await _loadFromBackend();
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('DAOProvider.castVote error: $e');
      rethrow;
    }
  }

  // Delegate methods
  List<Delegate> getTopDelegates({int limit = 10}) {
    final list = List<Delegate>.from(_delegates)
      ..sort((a, b) => b.votingPower.compareTo(a.votingPower));
    return list.take(limit).toList();
  }

  Delegate? getDelegateById(String id) {
    try {
      return _delegates.firstWhere((d) => d.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> delegateVotingPower({
    required String delegateId,
    Map<String, dynamic>? metadata,
    bool revoke = false,
  }) async {
    try {
      final api = BackendApiService();
      final signedEnvelope = await _signEnvelope(
        actionType: revoke
            ? DAOSignedActionType.delegationRevoke
            : DAOSignedActionType.delegationSet,
        referenceId: delegateId,
        references: <String, dynamic>{
          'delegateId': delegateId,
          if (metadata?['delegateWallet'] != null)
            'delegateWallet': metadata!['delegateWallet'].toString(),
        },
        payload: {
          'delegateId': delegateId,
          if (!revoke && metadata?['delegateWallet'] != null)
            'delegateWallet': metadata!['delegateWallet'].toString(),
          'scope': 'global',
          if (metadata != null) 'metadata': metadata,
        },
      );
      await _ensureBackendSessionForAction(signedEnvelope);
      final result = await api.delegateVotingPower(
        delegateId: delegateId,
        envelope: signedEnvelope.toJson(),
      );
      await _loadFromBackend();
      notifyListeners();
      return result;
    } catch (e) {
      debugPrint('DAOProvider.delegateVotingPower error: $e');
      return null;
    }
  }

  // Transaction methods
  List<DAOTransaction> getRecentTransactions({int limit = 10}) {
    final list = List<DAOTransaction>.from(_transactions)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list.take(limit).toList();
  }

  List<DAOTransaction> getTransactionsByType(String type) {
    return _transactions.where((tx) => tx.type == type).toList();
  }

  // Analytics methods
  Map<String, dynamic> getDAOAnalytics() {
    final activeProposals = getActiveProposals().length;
    final totalVotes = _votes.length;
    final totalDelegates = _delegates.length;
    final treasuryTransactions = getTransactionsByType('treasury');
    final totalTreasuryAmount =
        treasuryTransactions.fold<double>(0, (sum, tx) => sum + tx.amount);
    final treasuryTotal = _treasuryOnChainBalance ?? totalTreasuryAmount;

    return {
      'activeProposals': activeProposals,
      'totalProposals': _proposals.length,
      'totalVotes': totalVotes,
      'totalDelegates': totalDelegates,
      'treasuryAmount': treasuryTotal,
      'recentTransactions': getRecentTransactions(limit: 5).length,
      'proposalsByType': {
        for (var type in ProposalType.values)
          type.name: getProposalsByType(type).length,
      },
    };
  }

  Future<void> _refreshOnChainTreasuryBalance() async {
    if (!AppConfig.isFeatureEnabled('web3') ||
        !AppConfig.isFeatureEnabled('daoOnchainTreasury')) {
      _treasuryOnChainBalance = null;
      return;
    }

    final treasuryWallet = ApiKeys.kubusTreasuryWallet;
    if (treasuryWallet.isEmpty) return;

    try {
      final balance = await _solanaService.getSplTokenBalance(
        owner: treasuryWallet,
        mint: ApiKeys.kub8MintAddress,
        expectedDecimals: ApiKeys.kub8Decimals,
      );
      _treasuryOnChainBalance = balance;
    } catch (e) {
      debugPrint('DAOProvider: on-chain treasury load failed: $e');
    }
  }
}
