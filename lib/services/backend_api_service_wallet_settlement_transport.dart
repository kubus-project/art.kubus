part of 'backend_api_service.dart';

class BackendWalletFeeSplitterProgramConfigDto {
  const BackendWalletFeeSplitterProgramConfigDto({
    required this.programId,
    required this.configAccount,
    required this.vaultAuthority,
  });

  final String programId;
  final String configAccount;
  final String vaultAuthority;

  factory BackendWalletFeeSplitterProgramConfigDto.fromJson(
    Map<String, dynamic> json,
  ) {
    return BackendWalletFeeSplitterProgramConfigDto(
      programId: (json['programId'] ?? '').toString().trim(),
      configAccount: (json['configAccount'] ?? '').toString().trim(),
      vaultAuthority: (json['vaultAuthority'] ?? '').toString().trim(),
    );
  }

  bool get isValid =>
      programId.isNotEmpty &&
      configAccount.isNotEmpty &&
      vaultAuthority.isNotEmpty;
}

class BackendWalletFeeSplitterConfigDto {
  const BackendWalletFeeSplitterConfigDto({
    required this.enabled,
    required this.mode,
    required this.effectiveMode,
    required this.feeVaultOwnerAddress,
    required this.teamWalletAddress,
    required this.treasuryWalletAddress,
    required this.teamFeePct,
    required this.treasuryFeePct,
    required this.totalFeePct,
    required this.platformFeeBps,
    required this.teamShareBpsOfPlatformFee,
    required this.treasuryShareBpsOfPlatformFee,
    required this.requiresBackendSettlementRequest,
    required this.backendFallbackReady,
    required this.programReady,
    this.disabledReason,
    this.requestedMode,
    this.requestPath,
    this.solanaRpcUrl,
    this.program,
  });

  final bool enabled;
  final String mode;
  final String effectiveMode;
  final String feeVaultOwnerAddress;
  final String teamWalletAddress;
  final String treasuryWalletAddress;
  final double teamFeePct;
  final double treasuryFeePct;
  final double totalFeePct;
  final int platformFeeBps;
  final int teamShareBpsOfPlatformFee;
  final int treasuryShareBpsOfPlatformFee;
  final bool requiresBackendSettlementRequest;
  final bool backendFallbackReady;
  final bool programReady;
  final String? disabledReason;
  final String? requestedMode;
  final String? requestPath;
  final String? solanaRpcUrl;
  final BackendWalletFeeSplitterProgramConfigDto? program;

  bool get isProgramMode =>
      effectiveMode == 'program' && program?.isValid == true && programReady;
  bool get isBackendFallbackMode =>
      effectiveMode == 'backend_fallback' &&
      requiresBackendSettlementRequest &&
      backendFallbackReady;

  factory BackendWalletFeeSplitterConfigDto.fromJson(
      Map<String, dynamic> json) {
    final program = _backendApiMapOrNull(json['program']);
    return BackendWalletFeeSplitterConfigDto(
      enabled: json['enabled'] == true,
      mode: (json['mode'] ?? '').toString().trim(),
      effectiveMode:
          (json['effectiveMode'] ?? json['mode'] ?? '').toString().trim(),
      feeVaultOwnerAddress:
          (json['feeVaultOwnerAddress'] ?? '').toString().trim(),
      teamWalletAddress: (json['teamWalletAddress'] ?? '').toString().trim(),
      treasuryWalletAddress:
          (json['treasuryWalletAddress'] ?? '').toString().trim(),
      teamFeePct: (json['teamFeePct'] as num?)?.toDouble() ?? 0,
      treasuryFeePct: (json['treasuryFeePct'] as num?)?.toDouble() ?? 0,
      totalFeePct: (json['totalFeePct'] as num?)?.toDouble() ?? 0,
      platformFeeBps: (json['platformFeeBps'] as num?)?.toInt() ?? 0,
      teamShareBpsOfPlatformFee:
          (json['teamShareBpsOfPlatformFee'] as num?)?.toInt() ?? 0,
      treasuryShareBpsOfPlatformFee:
          (json['treasuryShareBpsOfPlatformFee'] as num?)?.toInt() ?? 0,
      requiresBackendSettlementRequest:
          json['requiresBackendSettlementRequest'] == true,
      backendFallbackReady: json['backendFallbackReady'] == true,
      programReady: json['programReady'] == true,
      disabledReason: json['disabledReason']?.toString(),
      requestedMode: json['requestedMode']?.toString(),
      requestPath: json['requestPath']?.toString(),
      solanaRpcUrl: json['solanaRpcUrl']?.toString(),
      program: program == null
          ? null
          : BackendWalletFeeSplitterProgramConfigDto.fromJson(program),
    );
  }
}

class BackendSwapFeeSettlementTransferDto {
  const BackendSwapFeeSettlementTransferDto({
    required this.transferKind,
    required this.amountRaw,
    required this.status,
    this.signature,
    this.sourceTokenAccount,
    this.destinationTokenAccount,
    this.mint,
    this.error,
  });

  final String transferKind;
  final String amountRaw;
  final String status;
  final String? signature;
  final String? sourceTokenAccount;
  final String? destinationTokenAccount;
  final String? mint;
  final String? error;

  factory BackendSwapFeeSettlementTransferDto.fromJson(
    Map<String, dynamic> json,
  ) {
    return BackendSwapFeeSettlementTransferDto(
      transferKind: (json['transferKind'] ?? '').toString().trim(),
      amountRaw: (json['amountRaw'] ?? '0').toString(),
      status: (json['status'] ?? '').toString().trim(),
      signature: json['signature']?.toString(),
      sourceTokenAccount: json['sourceTokenAccount']?.toString(),
      destinationTokenAccount: json['destinationTokenAccount']?.toString(),
      mint: json['mint']?.toString(),
      error: json['error']?.toString(),
    );
  }
}

class BackendSwapFeeSettlementStatusDto {
  const BackendSwapFeeSettlementStatusDto({
    required this.mode,
    required this.swapSignature,
    required this.status,
    required this.statusDetail,
    required this.requesterWalletAddress,
    required this.feeVaultOwnerAddress,
    required this.platformFeeAccountAddress,
    required this.outputMintAddress,
    required this.platformFeeAmountRaw,
    required this.teamFeeAmountRaw,
    required this.treasuryFeeAmountRaw,
    required this.transfers,
    this.settlementSignature,
  });

  final String mode;
  final String swapSignature;
  final String status;
  final String statusDetail;
  final String requesterWalletAddress;
  final String feeVaultOwnerAddress;
  final String platformFeeAccountAddress;
  final String outputMintAddress;
  final String platformFeeAmountRaw;
  final String teamFeeAmountRaw;
  final String treasuryFeeAmountRaw;
  final String? settlementSignature;
  final List<BackendSwapFeeSettlementTransferDto> transfers;

  bool get isPending => status == 'pending_confirmation';
  bool get isSettled => status == 'settled';

  factory BackendSwapFeeSettlementStatusDto.fromJson(
    Map<String, dynamic> json,
  ) {
    final transfers = (json['transfers'] as List? ?? const <dynamic>[])
        .whereType<Map>()
        .map(
          (entry) => BackendSwapFeeSettlementTransferDto.fromJson(
            Map<String, dynamic>.from(entry),
          ),
        )
        .toList(growable: false);
    return BackendSwapFeeSettlementStatusDto(
      mode: (json['mode'] ?? '').toString().trim(),
      swapSignature: (json['swapSignature'] ?? '').toString().trim(),
      status: (json['status'] ?? '').toString().trim(),
      statusDetail: (json['statusDetail'] ?? '').toString(),
      requesterWalletAddress:
          (json['requesterWalletAddress'] ?? '').toString().trim(),
      feeVaultOwnerAddress:
          (json['feeVaultOwnerAddress'] ?? '').toString().trim(),
      platformFeeAccountAddress:
          (json['platformFeeAccountAddress'] ?? '').toString().trim(),
      outputMintAddress: (json['outputMintAddress'] ?? '').toString().trim(),
      platformFeeAmountRaw: (json['platformFeeAmountRaw'] ?? '0').toString(),
      teamFeeAmountRaw: (json['teamFeeAmountRaw'] ?? '0').toString(),
      treasuryFeeAmountRaw: (json['treasuryFeeAmountRaw'] ?? '0').toString(),
      settlementSignature: json['settlementSignature']?.toString(),
      transfers: transfers,
    );
  }
}

extension BackendApiWalletSettlementTransport on BackendApiService {
  Future<BackendWalletFeeSplitterConfigDto>
      fetchWalletFeeSplitterConfig() async {
    const path = '/api/wallet-settlements/fee-splitter/config';
    final response = await _sendAuthRequestWithFailover(
      'GET',
      path,
      includeAuth: false,
      headers: _getHeaders(includeAuth: false),
      isIdempotent: true,
    );
    if (response.statusCode != 200) {
      throw BackendApiRequestException(
        statusCode: response.statusCode,
        path: path,
        body: response.body,
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final payload = _backendApiResponsePayload(decoded);
    return BackendWalletFeeSplitterConfigDto.fromJson(payload);
  }

  Future<BackendSwapFeeSettlementStatusDto> submitSwapFeeSettlementRequest({
    required String swapSignature,
    required String outputMintAddress,
    required String platformFeeAmountRaw,
    required String teamFeeAmountRaw,
    required String treasuryFeeAmountRaw,
    String? platformFeeAccountAddress,
  }) async {
    const path = '/api/wallet-settlements/swap-fees';
    final response = await _sendAuthRequestWithFailover(
      'POST',
      path,
      includeAuth: true,
      headers: _getHeaders(),
      body: jsonEncode({
        'swapSignature': swapSignature.trim(),
        'outputMintAddress': outputMintAddress.trim(),
        'platformFeeAmountRaw': platformFeeAmountRaw,
        'teamFeeAmountRaw': teamFeeAmountRaw,
        'treasuryFeeAmountRaw': treasuryFeeAmountRaw,
        if ((platformFeeAccountAddress ?? '').trim().isNotEmpty)
          'platformFeeAccountAddress': platformFeeAccountAddress!.trim(),
      }),
    );
    if (response.statusCode != 200 && response.statusCode != 202) {
      throw BackendApiRequestException(
        statusCode: response.statusCode,
        path: path,
        body: response.body,
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final payload = _backendApiResponsePayload(decoded);
    return BackendSwapFeeSettlementStatusDto.fromJson(payload);
  }

  Future<BackendSwapFeeSettlementStatusDto> fetchSwapFeeSettlementStatus(
    String swapSignature,
  ) async {
    final normalizedSignature = swapSignature.trim();
    final path = '/api/wallet-settlements/swap-fees/$normalizedSignature';
    final response = await _sendAuthRequestWithFailover(
      'GET',
      path,
      includeAuth: true,
      headers: _getHeaders(),
      isIdempotent: true,
    );
    if (response.statusCode != 200) {
      throw BackendApiRequestException(
        statusCode: response.statusCode,
        path: path,
        body: response.body,
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final payload = _backendApiResponsePayload(decoded);
    return BackendSwapFeeSettlementStatusDto.fromJson(payload);
  }
}

class BackendWalletSettlementTransport {
  const BackendWalletSettlementTransport(this._service);

  final BackendApiService _service;

  Future<BackendWalletFeeSplitterConfigDto> getFeeSplitterConfig() {
    return _service.fetchWalletFeeSplitterConfig();
  }

  Future<BackendSwapFeeSettlementStatusDto> submitSwapFees({
    required String swapSignature,
    required String outputMintAddress,
    required String platformFeeAmountRaw,
    required String teamFeeAmountRaw,
    required String treasuryFeeAmountRaw,
    String? platformFeeAccountAddress,
  }) {
    return _service.submitSwapFeeSettlementRequest(
      swapSignature: swapSignature,
      outputMintAddress: outputMintAddress,
      platformFeeAmountRaw: platformFeeAmountRaw,
      teamFeeAmountRaw: teamFeeAmountRaw,
      treasuryFeeAmountRaw: treasuryFeeAmountRaw,
      platformFeeAccountAddress: platformFeeAccountAddress,
    );
  }

  Future<BackendSwapFeeSettlementStatusDto> getSwapFeeSettlementStatus(
    String swapSignature,
  ) {
    return _service.fetchSwapFeeSettlementStatus(swapSignature);
  }
}
