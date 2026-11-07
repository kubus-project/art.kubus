// DAO and Governance Models
enum ProposalType {
  platformUpdate,
  rewards,
  featureRequest,
  governance,
  community
}

enum ProposalStatus { draft, active, voting, passed, failed, executed }

enum VoteChoice { yes, no, abstain }

enum DAOSignedActionType {
  proposalCreate('proposal.create'),
  voteCast('vote.cast'),
  delegationSet('delegation.set'),
  delegationRevoke('delegation.revoke'),
  reviewSubmit('review.submit'),
  reviewDecision('review.decision');

  const DAOSignedActionType(this.apiValue);

  final String apiValue;

  static DAOSignedActionType fromApiValue(String value) {
    return DAOSignedActionType.values.firstWhere(
      (entry) => entry.apiValue == value,
    );
  }
}

class DAOSignedEnvelope {
  static const String currentVersion = 'dao-v1';

  final String version;
  final String actionId;
  final DAOSignedActionType actionType;
  final String walletAddress;
  final String publicKey;
  final DateTime timestamp;
  final String nonce;
  final Map<String, dynamic> payload;
  final Map<String, dynamic> references;
  final String signature;
  final String? referenceId;
  final String? referenceCid;

  const DAOSignedEnvelope({
    required this.version,
    required this.actionId,
    required this.actionType,
    required this.walletAddress,
    required this.publicKey,
    required this.timestamp,
    required this.nonce,
    required this.payload,
    required this.references,
    required this.signature,
    this.referenceId,
    this.referenceCid,
  });

  factory DAOSignedEnvelope.unsigned({
    required String actionId,
    required DAOSignedActionType actionType,
    required String walletAddress,
    required String publicKey,
    required DateTime timestamp,
    required String nonce,
    required Map<String, dynamic> payload,
    required Map<String, dynamic> references,
    String? referenceId,
    String? referenceCid,
  }) {
    return DAOSignedEnvelope(
      version: currentVersion,
      actionId: actionId,
      actionType: actionType,
      walletAddress: walletAddress,
      publicKey: publicKey,
      timestamp: timestamp,
      nonce: nonce,
      payload: payload,
      references: references,
      signature: '',
      referenceId: referenceId,
      referenceCid: referenceCid,
    );
  }

  factory DAOSignedEnvelope.fromJson(Map<String, dynamic> json) {
    return DAOSignedEnvelope(
      version: (json['version'] ?? currentVersion).toString(),
      actionId: (json['actionId'] ?? '').toString(),
      actionType: DAOSignedActionType.fromApiValue(
        (json['actionType'] ?? '').toString(),
      ),
      walletAddress: (json['walletAddress'] ?? '').toString(),
      publicKey: (json['publicKey'] ?? json['walletAddress'] ?? '').toString(),
      timestamp: DateTime.parse((json['timestamp'] ?? '').toString()).toUtc(),
      nonce: (json['nonce'] ?? '').toString(),
      payload: json['payload'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['payload'] as Map<String, dynamic>)
          : <String, dynamic>{},
      references: json['references'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(
              json['references'] as Map<String, dynamic>)
          : <String, dynamic>{},
      signature: (json['signature'] ?? '').toString(),
      referenceId: json['referenceId']?.toString(),
      referenceCid: json['referenceCid']?.toString(),
    );
  }

  DAOSignedEnvelope withSignature(String signedValue) {
    return DAOSignedEnvelope(
      version: version,
      actionId: actionId,
      actionType: actionType,
      walletAddress: walletAddress,
      publicKey: publicKey,
      timestamp: timestamp,
      nonce: nonce,
      payload: payload,
      references: references,
      signature: signedValue,
      referenceId: referenceId,
      referenceCid: referenceCid,
    );
  }

  Map<String, dynamic> toSigningPayloadJson() {
    return {
      'version': version,
      'actionId': actionId,
      'actionType': actionType.apiValue,
      'walletAddress': walletAddress,
      'publicKey': publicKey,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'nonce': nonce,
      'payload': payload,
      'references': references,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      ...toSigningPayloadJson(),
      if (referenceId != null && referenceId!.isNotEmpty)
        'referenceId': referenceId,
      if (referenceCid != null && referenceCid!.isNotEmpty)
        'referenceCid': referenceCid,
      'signature': signature,
    };
  }
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

  /// Not a real quorum check: the backend sends only [quorumRequired] (a
  /// fraction of voting power) and no total eligible power, so this
  /// compares against an invented 100k electorate. Never show it as a
  /// quorum status; display the requirement instead.
  @Deprecated('No backend total voting power; show quorumRequired instead.')
  bool get hasQuorum => totalVotes >= (quorumRequired * 100000);
  bool get isPassing => supportPercentage >= supportRequired;
  bool get isActive =>
      status == ProposalStatus.active || status == ProposalStatus.voting;

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

  String get formattedParticipation =>
      '${(participationRate * 100).toStringAsFixed(1)}%';

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
