// DAO and Governance Models
enum ProposalType { platformUpdate, rewards, featureRequest, governance, community }
enum ProposalStatus { draft, active, voting, passed, failed, executed }
enum VoteChoice { yes, no, abstain }

enum DAOReviewRole { artist, institution, general }

class DAOReview {
  final String id;
  final String walletAddress;
  final String portfolioUrl;
  final String medium;
  final String statement;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? reviewerNotes;
  final Map<String, dynamic>? metadata;
  final Map<String, dynamic>? applicantProfile;
  final bool canVote;

  DAOReview({
    required this.id,
    required this.walletAddress,
    required this.portfolioUrl,
    required this.medium,
    required this.statement,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.reviewerNotes,
    this.metadata,
    this.applicantProfile,
    this.canVote = true,
  });

  factory DAOReview.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value is String) return DateTime.tryParse(value);
      return null;
    }
    bool parseBool(dynamic value) {
      if (value is bool) return value;
      if (value is String) {
        final normalized = value.toLowerCase();
        return normalized == 'true' || normalized == '1' || normalized == 'yes';
      }
      if (value is num) return value != 0;
      return false;
    }

    final canVoteField = json['canVote'] ?? json['can_vote'];

    return DAOReview(
      id: json['id']?.toString() ?? '',
      walletAddress: json['walletAddress']?.toString() ?? json['wallet_address']?.toString() ?? '',
      portfolioUrl: json['portfolioUrl']?.toString() ?? json['portfolio_url']?.toString() ?? '',
      medium: json['medium']?.toString() ?? '',
      statement: json['statement']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      reviewerNotes: json['reviewerNotes']?.toString() ?? json['reviewer_notes']?.toString(),
      createdAt: parseDate(json['createdAt'] ?? json['created_at']) ?? DateTime.now(),
      updatedAt: parseDate(json['updatedAt'] ?? json['updated_at']),
      metadata: json['metadata'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['metadata'] as Map<String, dynamic>)
          : null,
      applicantProfile: json['applicantProfile'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['applicantProfile'] as Map<String, dynamic>)
          : null,
      canVote: canVoteField == null ? true : parseBool(canVoteField),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'walletAddress': walletAddress,
      'portfolioUrl': portfolioUrl,
      'medium': medium,
      'statement': statement,
      'status': status,
      'reviewerNotes': reviewerNotes,
      'createdAt': createdAt.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      if (metadata != null) 'metadata': metadata,
      if (applicantProfile != null) 'applicantProfile': applicantProfile,
      'canVote': canVote,
    };
  }
}

extension DAOReviewRoleParsing on DAOReview {
  String get _normalizedRoleValue {
    final candidates = ['role', 'type', 'category', 'source'];
    for (final key in candidates) {
      final value = metadata?[key];
      if (value == null) continue;
      final normalized = value.toString().trim().toLowerCase();
      if (normalized.isNotEmpty) return normalized;
    }
    return '';
  }

  DAOReviewRole get role {
    final normalized = _normalizedRoleValue;
    if (normalized.contains('institution') || normalized.contains('museum') || normalized.contains('gallery') || normalized.contains('org')) {
      return DAOReviewRole.institution;
    }
    if (normalized.contains('artist') || normalized.contains('creator')) {
      return DAOReviewRole.artist;
    }
    return DAOReviewRole.general;
  }

  bool get isArtistApplication => role == DAOReviewRole.artist || role == DAOReviewRole.general;
  bool get isInstitutionApplication => role == DAOReviewRole.institution;

  bool get isApproved => status.toLowerCase() == 'approved';
  bool get isPending => status.toLowerCase() == 'pending';
  bool get isRejected => status.toLowerCase() == 'rejected';
}

class Proposal {
  final String id;
  final String title;
  final String description;
  final ProposalType type;
  final ProposalStatus status;
  final String proposer;
  final DateTime createdAt;
  final DateTime? votingStartDate;
  final DateTime? votingEndDate;
  final int yesVotes;
  final int noVotes;
  final int abstainVotes;
  final double quorumRequired;
  final double supportRequired;
  final List<String> supportingDocuments;
  final Map<String, dynamic> metadata;

  Proposal({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.status,
    required this.proposer,
    required this.createdAt,
    this.votingStartDate,
    this.votingEndDate,
    this.yesVotes = 0,
    this.noVotes = 0,
    this.abstainVotes = 0,
    this.quorumRequired = 0.1, // 10%
    this.supportRequired = 0.5, // 50%
    this.supportingDocuments = const [],
    this.metadata = const {},
  });

  int get totalVotes => yesVotes + noVotes + abstainVotes;
  double get supportPercentage => totalVotes > 0 ? yesVotes / totalVotes : 0;
  bool get hasQuorum => totalVotes >= (quorumRequired * 100000); // Assuming 100k total voters
  bool get isPassing => supportPercentage >= supportRequired;
  bool get isActive => status == ProposalStatus.active || status == ProposalStatus.voting;
  
  String get timeLeft {
    if (votingEndDate == null) return 'TBD';
    final now = DateTime.now();
    if (now.isAfter(votingEndDate!)) return 'Ended';
    
    final difference = votingEndDate!.difference(now);
    if (difference.inDays > 0) return '${difference.inDays} days';
    if (difference.inHours > 0) return '${difference.inHours} hours';
    return '${difference.inMinutes} minutes';
  }

  String get formattedVotes {
    if (totalVotes >= 1000) {
      return '${(totalVotes / 1000).toStringAsFixed(1)}K';
    }
    return totalVotes.toString();
  }

  factory Proposal.fromJson(Map<String, dynamic> json) {
    return Proposal(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      type: ProposalType.values.firstWhere((e) => e.name == json['type']),
      status: ProposalStatus.values.firstWhere((e) => e.name == json['status']),
      proposer: json['proposer'],
      createdAt: DateTime.parse(json['createdAt']),
      votingStartDate: json['votingStartDate'] != null 
          ? DateTime.parse(json['votingStartDate']) 
          : null,
      votingEndDate: json['votingEndDate'] != null 
          ? DateTime.parse(json['votingEndDate']) 
          : null,
      yesVotes: json['yesVotes'] ?? 0,
      noVotes: json['noVotes'] ?? 0,
      abstainVotes: json['abstainVotes'] ?? 0,
      quorumRequired: json['quorumRequired']?.toDouble() ?? 0.1,
      supportRequired: json['supportRequired']?.toDouble() ?? 0.5,
      supportingDocuments: List<String>.from(json['supportingDocuments'] ?? []),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.name,
      'status': status.name,
      'proposer': proposer,
      'createdAt': createdAt.toIso8601String(),
      'votingStartDate': votingStartDate?.toIso8601String(),
      'votingEndDate': votingEndDate?.toIso8601String(),
      'yesVotes': yesVotes,
      'noVotes': noVotes,
      'abstainVotes': abstainVotes,
      'quorumRequired': quorumRequired,
      'supportRequired': supportRequired,
      'supportingDocuments': supportingDocuments,
      'metadata': metadata,
    };
  }
}

class Vote {
  final String id;
  final String proposalId;
  final String voter;
  final VoteChoice choice;
  final int votingPower;
  final DateTime timestamp;
  final String? reason;

  Vote({
    required this.id,
    required this.proposalId,
    required this.voter,
    required this.choice,
    required this.votingPower,
    required this.timestamp,
    this.reason,
  });

  factory Vote.fromJson(Map<String, dynamic> json) {
    return Vote(
      id: json['id'],
      proposalId: json['proposalId'],
      voter: json['voter'],
      choice: VoteChoice.values.firstWhere((e) => e.name == json['choice']),
      votingPower: json['votingPower'],
      timestamp: DateTime.parse(json['timestamp']),
      reason: json['reason'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'proposalId': proposalId,
      'voter': voter,
      'choice': choice.name,
      'votingPower': votingPower,
      'timestamp': timestamp.toIso8601String(),
      'reason': reason,
    };
  }
}

class Delegate {
  final String id;
  final String name;
  final String description;
  final String address;
  final int votingPower;
  final int delegatorCount;
  final double participationRate;
  final List<String> supportedCategories;
  final String? avatarUrl;
  final DateTime joinedAt;

  Delegate({
    required this.id,
    required this.name,
    required this.description,
    required this.address,
    required this.votingPower,
    required this.delegatorCount,
    required this.participationRate,
    this.supportedCategories = const [],
    this.avatarUrl,
    required this.joinedAt,
  });

  String get formattedPower {
    if (votingPower >= 1000) {
      return '${(votingPower / 1000).toStringAsFixed(1)}K';
    }
    return votingPower.toString();
  }

  String get formattedDelegators {
    if (delegatorCount >= 1000) {
      return '${(delegatorCount / 1000).toStringAsFixed(1)}K';
    }
    return delegatorCount.toString();
  }

  String get formattedParticipation => '${(participationRate * 100).toStringAsFixed(1)}%';

  factory Delegate.fromJson(Map<String, dynamic> json) {
    return Delegate(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      address: json['address'],
      votingPower: json['votingPower'],
      delegatorCount: json['delegatorCount'],
      participationRate: json['participationRate'].toDouble(),
      supportedCategories: List<String>.from(json['supportedCategories'] ?? []),
      avatarUrl: json['avatarUrl'],
      joinedAt: DateTime.parse(json['joinedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'address': address,
      'votingPower': votingPower,
      'delegatorCount': delegatorCount,
      'participationRate': participationRate,
      'supportedCategories': supportedCategories,
      'avatarUrl': avatarUrl,
      'joinedAt': joinedAt.toIso8601String(),
    };
  }
}

class DAOTransaction {
  final String id;
  final String type; // 'treasury', 'proposal_execution', 'delegate_reward'
  final String description;
  final double amount;
  final String currency;
  final String? recipient;
  final String? relatedProposalId;
  final DateTime timestamp;
  final String txHash;
  final String status; // 'pending', 'confirmed', 'failed'

  DAOTransaction({
    required this.id,
    required this.type,
    required this.description,
    required this.amount,
    required this.currency,
    this.recipient,
    this.relatedProposalId,
    required this.timestamp,
    required this.txHash,
    required this.status,
  });

  String get formattedAmount {
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K $currency';
    }
    return '${amount.toStringAsFixed(2)} $currency';
  }

  factory DAOTransaction.fromJson(Map<String, dynamic> json) {
    return DAOTransaction(
      id: json['id'],
      type: json['type'],
      description: json['description'],
      amount: json['amount'].toDouble(),
      currency: json['currency'],
      recipient: json['recipient'],
      relatedProposalId: json['relatedProposalId'],
      timestamp: DateTime.parse(json['timestamp']),
      txHash: json['txHash'],
      status: json['status'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'description': description,
      'amount': amount,
      'currency': currency,
      'recipient': recipient,
      'relatedProposalId': relatedProposalId,
      'timestamp': timestamp.toIso8601String(),
      'txHash': txHash,
      'status': status,
    };
  }
}
