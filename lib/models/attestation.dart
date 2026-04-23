enum AttestationType {
  attendance,
  approval,
  participationProof,
  curatorial,
  institutional,
  collectibleProof,
}

AttestationType _attestationTypeFromValue(String? value) {
  final normalized = (value ?? '').trim().toLowerCase();
  switch (normalized) {
    case 'attendance':
      return AttestationType.attendance;
    case 'approval':
      return AttestationType.approval;
    case 'participation_proof':
    case 'participationproof':
      return AttestationType.participationProof;
    case 'curatorial':
      return AttestationType.curatorial;
    case 'institutional':
      return AttestationType.institutional;
    case 'collectible_proof':
    case 'collectibleproof':
      return AttestationType.collectibleProof;
    default:
      return AttestationType.participationProof;
  }
}

enum AttestationMintPolicy {
  none,
  optional,
  required,
}

AttestationMintPolicy _attestationMintPolicyFromValue(String? value) {
  final normalized = (value ?? '').trim().toLowerCase();
  switch (normalized) {
    case 'required':
      return AttestationMintPolicy.required;
    case 'optional':
      return AttestationMintPolicy.optional;
    case 'none':
    default:
      return AttestationMintPolicy.none;
  }
}

class AttestationMintDetails {
  const AttestationMintDetails({
    required this.eligible,
    required this.policy,
    required this.status,
    this.reason,
    this.mintAddress,
    this.txSignature,
  });

  final bool eligible;
  final AttestationMintPolicy policy;
  final String status;
  final String? reason;
  final String? mintAddress;
  final String? txSignature;

  factory AttestationMintDetails.fromJson(Map<String, dynamic> json) {
    return AttestationMintDetails(
      eligible: json['eligible'] == true,
      policy: _attestationMintPolicyFromValue(json['policy']?.toString()),
      status: (json['status'] ?? '').toString(),
      reason: json['reason']?.toString(),
      mintAddress: json['mintAddress']?.toString(),
      txSignature: json['txSignature']?.toString(),
    );
  }
}

class UnifiedAttestation {
  const UnifiedAttestation({
    required this.id,
    required this.type,
    required this.subjectType,
    required this.subjectId,
    required this.status,
    required this.usage,
    required this.mint,
    required this.metadata,
    this.holderWalletAddress,
    this.issuedAt,
    this.issuer,
  });

  final String id;
  final AttestationType type;
  final String subjectType;
  final String subjectId;
  final String status;
  final List<String> usage;
  final AttestationMintDetails mint;
  final Map<String, dynamic> metadata;
  final String? holderWalletAddress;
  final DateTime? issuedAt;
  final Map<String, dynamic>? issuer;

  factory UnifiedAttestation.fromJson(Map<String, dynamic> json) {
    final usageRaw = json['usage'];
    final usage = usageRaw is List
        ? usageRaw.map((item) => item.toString()).toList(growable: false)
        : const <String>[];
    final mintRaw = json['mint'];
    final mint = mintRaw is Map<String, dynamic>
        ? AttestationMintDetails.fromJson(mintRaw)
        : AttestationMintDetails.fromJson(const <String, dynamic>{});
    final metadataRaw = json['metadata'];

    return UnifiedAttestation(
      id: (json['id'] ?? '').toString(),
      type: _attestationTypeFromValue(json['type']?.toString()),
      subjectType: (json['subjectType'] ?? json['subject_type'] ?? '').toString(),
      subjectId: (json['subjectId'] ?? json['subject_id'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      usage: usage,
      mint: mint,
      metadata: metadataRaw is Map<String, dynamic>
          ? Map<String, dynamic>.from(metadataRaw)
          : const <String, dynamic>{},
      holderWalletAddress: (json['holderWalletAddress'] ??
              json['holder_wallet_address'])
          ?.toString(),
      issuedAt: DateTime.tryParse(
          (json['issuedAt'] ?? json['issued_at'] ?? '').toString()),
      issuer: json['issuer'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['issuer'] as Map<String, dynamic>)
          : null,
    );
  }
}