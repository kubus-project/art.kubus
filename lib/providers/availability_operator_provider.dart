import 'package:flutter/foundation.dart';

import '../config/config.dart';
import '../services/backend_api_service.dart';

const List<String> availabilityOperatorDefaultScopes = <String>[
  'availability:nodes:register',
  'availability:nodes:read',
  'availability:nodes:heartbeat',
  'availability:commitments:write',
  'availability:commitments:read',
  'availability:rewards:read',
  'availability:policy:read',
  'availability:rewardable-cids:read',
];

class AvailabilityOperatorTokenRecord {
  const AvailabilityOperatorTokenRecord({
    required this.id,
    required this.label,
    required this.walletAddress,
    required this.tokenPrefix,
    required this.scopes,
    required this.status,
    this.expiresAt,
    this.lastUsedAt,
    this.revokedAt,
    this.createdAt,
  });

  final String id;
  final String label;
  final String walletAddress;
  final String tokenPrefix;
  final List<String> scopes;
  final String status;
  final DateTime? expiresAt;
  final DateTime? lastUsedAt;
  final DateTime? revokedAt;
  final DateTime? createdAt;

  factory AvailabilityOperatorTokenRecord.fromJson(Map<String, dynamic> json) {
    return AvailabilityOperatorTokenRecord(
      id: (json['id'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      walletAddress: (json['walletAddress'] ?? '').toString(),
      tokenPrefix: (json['tokenPrefix'] ?? '').toString(),
      scopes: (json['scopes'] as List<dynamic>? ?? const <dynamic>[])
          .map((scope) => scope.toString())
          .where((scope) => scope.trim().isNotEmpty)
          .toList(growable: false),
      status: (json['status'] ?? 'active').toString(),
      expiresAt: DateTime.tryParse((json['expiresAt'] ?? '').toString()),
      lastUsedAt: DateTime.tryParse((json['lastUsedAt'] ?? '').toString()),
      revokedAt: DateTime.tryParse((json['revokedAt'] ?? '').toString()),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
    );
  }
}

class CreatedAvailabilityOperatorToken {
  const CreatedAvailabilityOperatorToken({
    required this.token,
    required this.record,
  });

  final String token;
  final AvailabilityOperatorTokenRecord record;
}

class AvailabilityOperatorProvider extends ChangeNotifier {
  AvailabilityOperatorProvider({BackendApiService? api})
      : _api = api ?? BackendApiService();

  final BackendApiService _api;

  bool _isLoading = false;
  String? _error;
  List<AvailabilityOperatorTokenRecord> _tokens =
      const <AvailabilityOperatorTokenRecord>[];
  CreatedAvailabilityOperatorToken? _createdToken;

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<AvailabilityOperatorTokenRecord> get tokens => _tokens;
  CreatedAvailabilityOperatorToken? get createdToken => _createdToken;

  Future<void> loadTokens({required String walletAddress}) async {
    await _run(() async {
      await _loadTokensInternal(walletAddress: walletAddress);
    });
  }

  Future<CreatedAvailabilityOperatorToken> createToken({
    required String label,
    required String walletAddress,
    required int expiresInDays,
  }) async {
    CreatedAvailabilityOperatorToken? created;
    await _run(() async {
      final response = await _api.createAvailabilityOperatorToken(
        label: label,
        walletAddress: walletAddress,
        expiresInDays: expiresInDays,
        scopes: availabilityOperatorDefaultScopes,
      );
      final token = (response['token'] ?? '').toString();
      final recordMap = response['record'] is Map<String, dynamic>
          ? response['record'] as Map<String, dynamic>
          : <String, dynamic>{};
      if (!token.startsWith('kubus_node_')) {
        throw StateError('Backend did not return a scoped operator token.');
      }
      created = CreatedAvailabilityOperatorToken(
        token: token,
        record: AvailabilityOperatorTokenRecord.fromJson(recordMap),
      );
      _createdToken = created;
      try {
        await _loadTokensInternal(walletAddress: walletAddress);
      } catch (e) {
        AppConfig.debugPrint(
          'AvailabilityOperatorProvider token refresh failed after create: $e',
        );
      }
    });
    return created!;
  }

  Future<void> revokeToken({
    required String tokenId,
    required String walletAddress,
  }) async {
    await _run(() async {
      await _api.revokeAvailabilityOperatorToken(
        tokenId,
        reason: 'user_revoked',
      );
      await _loadTokensInternal(walletAddress: walletAddress);
    });
  }

  void clearCreatedToken() {
    _createdToken = null;
    notifyListeners();
  }

  String buildEnvSnippet({
    required String token,
    required String walletAddress,
  }) {
    return [
      'KUBUS_API_BASE_URL=${AppConfig.baseApiUrl}',
      'KUBUS_OPERATOR_TOKEN=$token',
      'KUBUS_OPERATOR_WALLET=$walletAddress',
      'KUBUS_NODE_LABEL=kubus-availability-node-1',
      'KUBUS_NODE_ENDPOINT_URL=http://localhost:8080',
      'IPFS_RPC_URL=http://kubo:5001',
      'IPFS_GATEWAY_URL=http://127.0.0.1:8080',
    ].join('\n');
  }

  Future<void> _run(Future<void> Function() body) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await body();
    } catch (e) {
      _error = e.toString();
      AppConfig.debugPrint('AvailabilityOperatorProvider failed: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadTokensInternal({required String walletAddress}) async {
    final rows = await _api.listAvailabilityOperatorTokens(
      walletAddress: walletAddress,
    );
    _tokens = rows
        .map(AvailabilityOperatorTokenRecord.fromJson)
        .where((token) => token.id.isNotEmpty)
        .toList(growable: false);
  }
}
