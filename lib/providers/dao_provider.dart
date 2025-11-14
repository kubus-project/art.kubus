import 'package:flutter/foundation.dart';
import '../models/dao.dart';
import '../services/backend_api_service.dart';

class DAOProvider extends ChangeNotifier {
  List<Proposal> _proposals = [];
  List<Vote> _votes = [];
  List<Delegate> _delegates = [];
  List<DAOTransaction> _transactions = [];
  bool _isLoading = false;

  DAOProvider() {
    _loadData();
  }

  // Getters
  List<Proposal> get proposals => List.unmodifiable(_proposals);
  List<Vote> get votes => List.unmodifiable(_votes);
  List<Delegate> get delegates => List.unmodifiable(_delegates);
  List<DAOTransaction> get transactions => List.unmodifiable(_transactions);
  bool get isLoading => _isLoading;

  Future<void> _loadData() async {
    _isLoading = true;
    notifyListeners();

    try {
      // TODO: Load from backend/blockchain
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

      // If proposals exist, optionally fetch votes per proposal (best-effort)
      final votesAll = <Vote>[];
      for (final p in _proposals) {
        final votesJson = await api.getDAOVotes(proposalId: p.id);
        votesAll.addAll(votesJson.map((e) => Vote.fromJson(e)));
      }
      _votes = votesAll;

      final delegatesJson = await api.getDAODelegates();
      _delegates = delegatesJson.map((e) => Delegate.fromJson(e)).toList();

      final txJson = await api.getDAOTransactions();
      _transactions = txJson.map((e) => DAOTransaction.fromJson(e)).toList();
    } catch (e) {
      debugPrint('DAOProvider _loadFromBackend error: $e');
      _proposals = [];
      _votes = [];
      _delegates = [];
      _transactions = [];
    }
  }

  // Local mock loaders removed to ensure backend-driven data only

  Future<void> _loadFromBlockchain() async {
    // TODO: Implement blockchain loading
    _proposals = [];
    _votes = [];
    _delegates = [];
    _transactions = [];
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

  Future<void> createProposal(Proposal proposal) async {
    // TODO: Submit to backend/blockchain
    _proposals.add(proposal);
    notifyListeners();
  }

  Future<void> castVote(String proposalId, VoteChoice choice, int votingPower, {String? reason}) async {
    final vote = Vote(
      id: 'vote_${DateTime.now().millisecondsSinceEpoch}',
      proposalId: proposalId,
      voter: '0xcurrent...user', // TODO: Get from wallet
      choice: choice,
      votingPower: votingPower,
      timestamp: DateTime.now(),
      reason: reason,
    );

    // TODO: Submit to backend/blockchain
    _votes.add(vote);
      
      // Update proposal vote counts
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
      notifyListeners();
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

  Future<void> delegateVotingPower(String delegateId, int amount) async {
    // TODO: Submit delegation to backend/blockchain
    notifyListeners();
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

    return {
      'activeProposals': activeProposals,
      'totalProposals': _proposals.length,
      'totalVotes': totalVotes,
      'totalDelegates': totalDelegates,
      'treasuryAmount': totalTreasuryAmount,
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
}
