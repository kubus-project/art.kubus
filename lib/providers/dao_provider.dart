import 'package:flutter/foundation.dart';
import '../config/api_keys.dart';
import '../config/config.dart';
import '../models/dao.dart';
import '../services/backend_api_service.dart';
import '../utils/wallet_utils.dart';
import '../services/solana_wallet_service.dart';

class DAOProvider extends ChangeNotifier {
  final SolanaWalletService _solanaService;
  List<Proposal> _proposals = [];
  List<Vote> _votes = [];
  List<Delegate> _delegates = [];
  List<DAOTransaction> _transactions = [];
  List<DAOReview> _reviews = [];
  bool _isLoading = false;
  double? _treasuryOnChainBalance;

  DAOProvider({SolanaWalletService? solanaWalletService})
      : _solanaService = solanaWalletService ?? SolanaWalletService() {
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
        _reviews = reviewsJson.map((e) => DAOReview.fromJson(e)).toList();
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
    required String walletAddress,
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
      final payload = await api.createDAOProposal(
        walletAddress: walletAddress,
        title: title,
        description: description,
        type: type.name,
        votingPeriodDays: votingPeriodDays,
        supportRequired: supportRequired,
        quorumRequired: quorumRequired,
        supportingDocuments: supportingDocuments,
        metadata: metadata,
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
    required String walletAddress,
    required String portfolioUrl,
    required String medium,
    required String statement,
    String? title,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final api = BackendApiService();
      await api.ensureAuthLoaded(walletAddress: walletAddress);
      final payload = await api.submitDAOReview(
        walletAddress: walletAddress,
        portfolioUrl: portfolioUrl,
        medium: medium,
        statement: statement,
        title: title,
        metadata: metadata,
      );
      if (payload != null) {
        final review = DAOReview.fromJson(payload);
        _reviews.removeWhere((r) =>
            WalletUtils.equals(r.walletAddress, walletAddress) ||
            r.id == review.id);
        _reviews.insert(0, review);
        notifyListeners();
        return review;
      }
    } catch (e) {
      debugPrint('DAOProvider submitReview error: $e');
    }
    return null;
  }

  Future<void> castVote({
    required String proposalId,
    required VoteChoice choice,
    required int votingPower,
    required String walletAddress,
    String? reason,
    String? txHash,
  }) async {
    try {
      final api = BackendApiService();
      final payload = await api.submitDAOVote(
        proposalId: proposalId,
        walletAddress: walletAddress,
        choice: choice.name,
        votingPower: votingPower.toDouble(),
        reason: reason,
        txHash: txHash,
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
          // Fallback update when backend does not return proposal payload
          final proposalIndex = _proposals.indexWhere((p) => p.id == proposalId);
          if (proposalIndex != -1) {
            final proposal = _proposals[proposalIndex];
            switch (choice) {
              case VoteChoice.yes:
                _proposals[proposalIndex] = Proposal(
                  id: proposal.id,
                  title: proposal.title,
                  description: proposal.description,
                  type: proposal.type,
                  status: proposal.status,
                  proposer: proposal.proposer,
                  createdAt: proposal.createdAt,
                  votingStartDate: proposal.votingStartDate,
                  votingEndDate: proposal.votingEndDate,
                  yesVotes: proposal.yesVotes + votingPower,
                  noVotes: proposal.noVotes,
                  abstainVotes: proposal.abstainVotes,
                  quorumRequired: proposal.quorumRequired,
                  supportRequired: proposal.supportRequired,
                  supportingDocuments: proposal.supportingDocuments,
                  metadata: proposal.metadata,
                );
                break;
              case VoteChoice.no:
                _proposals[proposalIndex] = Proposal(
                  id: proposal.id,
                  title: proposal.title,
                  description: proposal.description,
                  type: proposal.type,
                  status: proposal.status,
                  proposer: proposal.proposer,
                  createdAt: proposal.createdAt,
                  votingStartDate: proposal.votingStartDate,
                  votingEndDate: proposal.votingEndDate,
                  yesVotes: proposal.yesVotes,
                  noVotes: proposal.noVotes + votingPower,
                  abstainVotes: proposal.abstainVotes,
                  quorumRequired: proposal.quorumRequired,
                  supportRequired: proposal.supportRequired,
                  supportingDocuments: proposal.supportingDocuments,
                  metadata: proposal.metadata,
                );
                break;
              case VoteChoice.abstain:
                _proposals[proposalIndex] = Proposal(
                  id: proposal.id,
                  title: proposal.title,
                  description: proposal.description,
                  type: proposal.type,
                  status: proposal.status,
                  proposer: proposal.proposer,
                  createdAt: proposal.createdAt,
                  votingStartDate: proposal.votingStartDate,
                  votingEndDate: proposal.votingEndDate,
                  yesVotes: proposal.yesVotes,
                  noVotes: proposal.noVotes,
                  abstainVotes: proposal.abstainVotes + votingPower,
                  quorumRequired: proposal.quorumRequired,
                  supportRequired: proposal.supportRequired,
                  supportingDocuments: proposal.supportingDocuments,
                  metadata: proposal.metadata,
                );
                break;
            }
          }
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
    required String walletAddress,
    double? votingPower,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final api = BackendApiService();
      final result = await api.delegateVotingPower(
        delegateId: delegateId,
        walletAddress: walletAddress,
        votingPower: votingPower,
        metadata: metadata,
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

  Future<void> refreshData() async {
    await _loadData();
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
