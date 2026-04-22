import 'package:flutter/foundation.dart';
import '../config/api_keys.dart';
import '../config/config.dart';
import '../models/dao.dart';
import '../services/backend_api_service.dart';
import '../services/dao_signed_envelope_service.dart';
import '../services/telemetry/telemetry_uuid.dart';
import '../utils/wallet_utils.dart';
import '../services/solana_wallet_service.dart';
import 'wallet_provider.dart';

class DAOProvider extends ChangeNotifier {
  final SolanaWalletService _solanaService;
  final DAOSignedEnvelopeService _signedEnvelopeService;
  List<Proposal> _proposals = [];
  List<Vote> _votes = [];
  List<Delegate> _delegates = [];
  List<DAOTransaction> _transactions = [];
  List<DAOReview> _reviews = [];
  bool _isLoading = false;
  double? _treasuryOnChainBalance;
  WalletProvider? _walletProvider;

  DAOProvider({
    SolanaWalletService? solanaWalletService,
    DAOSignedEnvelopeService? signedEnvelopeService,
  })  : _solanaService = solanaWalletService ?? SolanaWalletService(),
        _signedEnvelopeService =
            signedEnvelopeService ?? const DAOSignedEnvelopeService() {
    _loadData();
  }

  // Getters
  List<Proposal> get proposals => List.unmodifiable(_proposals);
  List<Vote> get votes => List.unmodifiable(_votes);
  List<Delegate> get delegates => List.unmodifiable(_delegates);
  List<DAOTransaction> get transactions => List.unmodifiable(_transactions);
  List<DAOReview> get reviews => List.unmodifiable(_reviews);
  bool get isLoading => _isLoading;
  double? get treasuryOnChainBalance => _treasuryOnChainBalance;

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
    try {
      final api = BackendApiService();
      try { await api.ensureAuthLoaded(); } catch (_) {}

      final proposalsJson = await api.getDAOProposals();
      _proposals = proposalsJson.map((e) => Proposal.fromJson(e)).toList();

      final votesJson = await api.getDAOVotes();
      _votes = votesJson.map((e) => Vote.fromJson(e)).toList();

      final delegatesJson = await api.getDAODelegates();
      _delegates = delegatesJson.map((e) => Delegate.fromJson(e)).toList();

      final txJson = await api.getDAOTransactions();
      _transactions = txJson.map((e) => DAOTransaction.fromJson(e)).toList();
      await _refreshOnChainTreasuryBalance();

      try {
        final reviewsJson = await api.getDAOReviews();
        final parsedReviews = <DAOReview>[];
        for (final reviewJson in reviewsJson) {
          try {
            parsedReviews.add(DAOReview.fromJson(reviewJson));
          } catch (e) {
            debugPrint('DAOProvider: skipping malformed review payload: $e');
          }
        }
        _reviews = parsedReviews;
      } catch (e) {
        debugPrint('DAOProvider: unable to load reviews (soft-fail): $e');
      }
    } catch (e) {
      debugPrint('DAOProvider _loadFromBackend error: $e');
      _proposals = [];
      _votes = [];
      _delegates = [];
      _transactions = [];
      _reviews = [];
      _treasuryOnChainBalance = null;
    }
  }

  /// Public refresh hook so UI flows can ensure delegates/groups are present.
  Future<void> refreshData({bool force = false}) async {
    if (_isLoading) return;
    final bool hasData =
        _delegates.isNotEmpty || _proposals.isNotEmpty || _transactions.isNotEmpty;
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

  String _normalizePortfolioUrl(String rawValue) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) return '';

    final hasScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:').hasMatch(trimmed);
    final withScheme = hasScheme
        ? trimmed
        : (trimmed.startsWith('//') ? 'https:$trimmed' : 'https://$trimmed');
    final parsed = Uri.tryParse(withScheme);
    if (parsed == null) return trimmed;

    final scheme = parsed.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return trimmed;
    return parsed.toString();
  }

  Future<void> _ensureBackendSessionForAction(DAOSignedEnvelope envelope) async {
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
    }
    return null;
  }

  Future<DAOReview?> submitReview({
    required String portfolioUrl,
    required String medium,
    required String statement,
    String? title,
    Map<String, dynamic>? metadata,
    String role = 'artist',
  }) async {
    try {
      // Review applications are signed locally, but they are not token-governance actions.
      final api = BackendApiService();
      final metadataPayload = <String, dynamic>{
        ...?metadata,
      };
      metadataPayload.putIfAbsent('role', () => role);
      final normalizedPortfolioUrl = _normalizePortfolioUrl(portfolioUrl);
      final signedEnvelope = await _signEnvelope(
        actionType: DAOSignedActionType.reviewSubmit,
        referenceCid: metadataPayload['contentCid']?.toString(),
        references: <String, dynamic>{
          'reviewDomain': 'application',
          if (metadataPayload['contentCid'] != null)
            'contentCid': metadataPayload['contentCid'].toString(),
        },
        payload: {
          'portfolioUrl': normalizedPortfolioUrl,
          'medium': medium,
          'statement': statement,
          if (title != null && title.isNotEmpty) 'title': title,
          'metadata': metadataPayload,
        },
      );
      await _ensureBackendSessionForAction(signedEnvelope);
      final walletAddress = signedEnvelope.walletAddress;
      final payload = await api.submitDAOReview(
        envelope: signedEnvelope.toJson(),
      );
      if (payload != null) {
        final review = DAOReview.fromJson(payload);
        _reviews.removeWhere((r) =>
            WalletUtils.equals(r.walletAddress, walletAddress) ||
            r.id == review.id);
        _reviews.insert(0, review);
        // Pull a fresh copy from backend to ensure persisted state (and any reviewer updates)
        final refreshed = await loadReviewForWallet(walletAddress, forceRefresh: true);
        notifyListeners();
        return refreshed ?? review;
      }
    } catch (e) {
      debugPrint('DAOProvider submitReview error: $e');
    }
    return null;
  }

  Future<DAOReview?> submitInstitutionReview({
    required String organization,
    required String contact,
    required String focus,
    required String mission,
    Map<String, dynamic>? metadata,
  }) {
    final mergedMeta = {
      'role': 'institution',
      'organization': organization,
      'contact': contact,
      'focus': focus,
      ...?metadata,
    };
    return submitReview(
      portfolioUrl: contact,
      medium: focus,
      statement: mission,
      title: organization,
      metadata: mergedMeta,
      role: 'institution',
    );
  }

  Future<DAOReview?> decideReview({
    required String idOrWallet,
    required String status,
    String? reviewerNotes,
  }) async {
    try {
      // Review decisions use a separate signed review-admin authority flow.
      final api = BackendApiService();
      final signedEnvelope = await _signEnvelope(
        actionType: DAOSignedActionType.reviewDecision,
        referenceId: idOrWallet,
        references: <String, dynamic>{
          'reviewId': idOrWallet,
          'domain': 'review_admin',
        },
        payload: {
          'reviewId': idOrWallet,
          'status': status,
          if (reviewerNotes != null && reviewerNotes.isNotEmpty)
            'reviewerNotes': reviewerNotes,
        },
      );
      await _ensureBackendSessionForAction(signedEnvelope);
      final payload = await api.decideDAOReview(
        idOrWallet: idOrWallet,
        envelope: signedEnvelope.toJson(),
      );
      if (payload != null) {
        final review = DAOReview.fromJson(payload);
        _reviews.removeWhere((r) =>
            r.id == review.id ||
            WalletUtils.equals(r.walletAddress, review.walletAddress));
        _reviews.insert(0, review);
        notifyListeners();
        return review;
      }
    } catch (e) {
      debugPrint('DAOProvider.decideReview error: $e');
      rethrow;
    }
    return null;
  }

  DAOReview? findReviewForWallet(String walletAddress) {
    if (walletAddress.isEmpty) return null;
    final normalized = walletAddress.trim().toLowerCase();
    try {
      return _reviews.firstWhere(
        (r) => r.walletAddress.trim().toLowerCase() == normalized,
      );
    } catch (_) {
      return null;
    }
  }

  Future<DAOReview?> loadReviewForWallet(String walletAddress, {bool forceRefresh = false}) async {
    final normalized = walletAddress.trim();
    if (normalized.isEmpty) return null;
    if (!forceRefresh) {
      final existing = findReviewForWallet(normalized);
      if (existing != null) return existing;
    }
    try {
      final api = BackendApiService();
      final payload = await api.getDAOReview(idOrWallet: normalized);
      if (payload != null) {
        final review = DAOReview.fromJson(payload);
        _reviews.removeWhere((r) =>
            r.id == review.id ||
            r.walletAddress.trim().toLowerCase() == review.walletAddress.trim().toLowerCase());
        _reviews.insert(0, review);
        notifyListeners();
        return review;
      }
    } catch (e) {
      debugPrint('DAOProvider.loadReviewForWallet error: $e');
    }
    return findReviewForWallet(normalized);
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
        _votes.removeWhere((v) => v.proposalId == proposalId && v.voter == vote.voter);
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
    final totalTreasuryAmount = treasuryTransactions.fold<double>(
      0, (sum, tx) => sum + tx.amount
    );
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