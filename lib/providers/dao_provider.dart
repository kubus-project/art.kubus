import 'package:flutter/foundation.dart';
import '../models/dao.dart';
import 'mockup_data_provider.dart';

class DAOProvider extends ChangeNotifier {
  final MockupDataProvider _mockupDataProvider;
  
  List<Proposal> _proposals = [];
  List<Vote> _votes = [];
  List<Delegate> _delegates = [];
  List<DAOTransaction> _transactions = [];
  bool _isLoading = false;

  DAOProvider(this._mockupDataProvider) {
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
  List<Proposal> get proposals => List.unmodifiable(_proposals);
  List<Vote> get votes => List.unmodifiable(_votes);
  List<Delegate> get delegates => List.unmodifiable(_delegates);
  List<DAOTransaction> get transactions => List.unmodifiable(_transactions);
  bool get isLoading => _isLoading;

  Future<void> _loadData() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_mockupDataProvider.isMockDataEnabled) {
        await _loadMockData();
      } else {
        // TODO: Load from IPFS/blockchain
        await _loadFromBlockchain();
      }
    } catch (e) {
      debugPrint('Error loading DAO data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadMockData() async {
    await _loadMockProposals();
    await _loadMockVotes();
    await _loadMockDelegates();
    await _loadMockTransactions();
  }

  Future<void> _loadMockProposals() async {
    final now = DateTime.now();
    
    _proposals = [
      Proposal(
        id: 'prop_1',
        title: 'New Artist Verification System',
        description: 'Implement a comprehensive verification system for artists to prevent fraud and ensure authenticity. This system will include identity verification, portfolio validation, and community endorsements.',
        type: ProposalType.platform_update,
        status: ProposalStatus.active,
        proposer: '0x123...abc',
        createdAt: now.subtract(const Duration(days: 5)),
        votingStartDate: now.subtract(const Duration(days: 2)),
        votingEndDate: now.add(const Duration(days: 3)),
        yesVotes: 2100,
        noVotes: 340,
        abstainVotes: 120,
        quorumRequired: 0.1,
        supportRequired: 0.6,
        supportingDocuments: ['verification_proposal.pdf'],
        metadata: {'urgency': 'high', 'budget': '50000'},
      ),
      Proposal(
        id: 'prop_2',
        title: 'POAP Rewards for Event Attendance',
        description: 'Introduce POAP (Proof of Attendance Protocol) tokens for users who attend AR art exhibitions and events. This will incentivize community participation and create collectible memories.',
        type: ProposalType.rewards,
        status: ProposalStatus.voting,
        proposer: '0x456...def',
        createdAt: now.subtract(const Duration(days: 8)),
        votingStartDate: now.subtract(const Duration(days: 1)),
        votingEndDate: now.add(const Duration(days: 5)),
        yesVotes: 1800,
        noVotes: 200,
        abstainVotes: 85,
        quorumRequired: 0.08,
        supportRequired: 0.5,
        supportingDocuments: ['poap_implementation.pdf'],
        metadata: {'category': 'rewards', 'implementation_time': '30_days'},
      ),
      Proposal(
        id: 'prop_3',
        title: 'Enhanced AR Experience Features',
        description: 'Develop advanced AR features including multi-user experiences, real-time collaboration, and improved rendering quality for artwork presentations.',
        type: ProposalType.feature_request,
        status: ProposalStatus.draft,
        proposer: '0x789...ghi',
        createdAt: now.subtract(const Duration(days: 2)),
        yesVotes: 0,
        noVotes: 0,
        abstainVotes: 0,
        quorumRequired: 0.12,
        supportRequired: 0.55,
        supportingDocuments: ['ar_features_spec.pdf'],
        metadata: {'development_cost': '75000', 'timeline': '90_days'},
      ),
    ];
  }

  Future<void> _loadMockVotes() async {
    final now = DateTime.now();
    
    _votes = [
      Vote(
        id: 'vote_1',
        proposalId: 'prop_1',
        voter: '0xabc...123',
        choice: VoteChoice.yes,
        votingPower: 150,
        timestamp: now.subtract(const Duration(hours: 4)),
        reason: 'Artist verification is crucial for platform integrity',
      ),
      Vote(
        id: 'vote_2',
        proposalId: 'prop_1',
        voter: '0xdef...456',
        choice: VoteChoice.no,
        votingPower: 75,
        timestamp: now.subtract(const Duration(hours: 6)),
        reason: 'Implementation timeline seems too aggressive',
      ),
      Vote(
        id: 'vote_3',
        proposalId: 'prop_2',
        voter: '0xghi...789',
        choice: VoteChoice.yes,
        votingPower: 200,
        timestamp: now.subtract(const Duration(hours: 2)),
        reason: 'POAPs will greatly increase engagement',
      ),
    ];
  }

  Future<void> _loadMockDelegates() async {
    final now = DateTime.now();
    
    _delegates = [
      Delegate(
        id: 'del_1',
        name: 'ArtisticVision DAO',
        description: 'Focused on advancing digital art technologies and supporting emerging artists in the Web3 space.',
        address: '0x123...abc',
        votingPower: 15420,
        delegatorCount: 234,
        participationRate: 0.89,
        supportedCategories: ['platform_update', 'feature_request'],
        avatarUrl: 'https://example.com/delegate1.jpg',
        joinedAt: now.subtract(const Duration(days: 180)),
      ),
      Delegate(
        id: 'del_2',
        name: 'Community First',
        description: 'Dedicated to community governance and ensuring fair representation for all platform participants.',
        address: '0x456...def',
        votingPower: 12850,
        delegatorCount: 189,
        participationRate: 0.92,
        supportedCategories: ['governance', 'community'],
        avatarUrl: 'https://example.com/delegate2.jpg',
        joinedAt: now.subtract(const Duration(days: 120)),
      ),
      Delegate(
        id: 'del_3',
        name: 'Tech Innovation Hub',
        description: 'Specializing in technical proposals and platform infrastructure improvements.',
        address: '0x789...ghi',
        votingPower: 18900,
        delegatorCount: 156,
        participationRate: 0.85,
        supportedCategories: ['platform_update', 'feature_request'],
        avatarUrl: 'https://example.com/delegate3.jpg',
        joinedAt: now.subtract(const Duration(days: 250)),
      ),
    ];
  }

  Future<void> _loadMockTransactions() async {
    final now = DateTime.now();
    
    _transactions = [
      DAOTransaction(
        id: 'tx_1',
        type: 'treasury',
        description: 'Community treasury allocation for Q4 development',
        amount: 125000,
        currency: 'KUB8',
        recipient: '0xdev...team',
        timestamp: now.subtract(const Duration(days: 2)),
        txHash: '0x123...abc',
        status: 'confirmed',
      ),
      DAOTransaction(
        id: 'tx_2',
        type: 'proposal_execution',
        description: 'Artist verification system implementation payment',
        amount: 50000,
        currency: 'KUB8',
        recipient: '0xverify...contract',
        relatedProposalId: 'prop_1',
        timestamp: now.subtract(const Duration(days: 5)),
        txHash: '0x456...def',
        status: 'confirmed',
      ),
      DAOTransaction(
        id: 'tx_3',
        type: 'delegate_reward',
        description: 'Monthly delegate participation rewards',
        amount: 2500,
        currency: 'KUB8',
        recipient: '0x123...abc',
        timestamp: now.subtract(const Duration(days: 7)),
        txHash: '0x789...ghi',
        status: 'confirmed',
      ),
    ];
  }

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
    if (_mockupDataProvider.isMockDataEnabled) {
      _proposals.add(proposal);
      notifyListeners();
    } else {
      // TODO: Submit to blockchain
    }
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

    if (_mockupDataProvider.isMockDataEnabled) {
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
    } else {
      // TODO: Submit vote to blockchain
    }
  }

  // Delegate methods
  List<Delegate> getTopDelegates({int limit = 10}) {
    return List<Delegate>.from(_delegates)
      ..sort((a, b) => b.votingPower.compareTo(a.votingPower))
      ..take(limit);
  }

  Delegate? getDelegateById(String id) {
    try {
      return _delegates.firstWhere((d) => d.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> delegateVotingPower(String delegateId, int amount) async {
    if (_mockupDataProvider.isMockDataEnabled) {
      // TODO: Implement delegation logic
      notifyListeners();
    } else {
      // TODO: Submit delegation to blockchain
    }
  }

  // Transaction methods
  List<DAOTransaction> getRecentTransactions({int limit = 10}) {
    return List<DAOTransaction>.from(_transactions)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp))
      ..take(limit);
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
