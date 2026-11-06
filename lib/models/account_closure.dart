import 'dart:convert';

final _operationIdPattern = RegExp(r'^[a-fA-F0-9-]{36}$');
final _statusTokenPattern = RegExp(r'^[a-f0-9]{64}$');

/// A narrow status-only capability. Never place it in a URL or analytics.
///
/// It is bound to [accountId], the account key of the session that requested
/// the closure. Only that account may recover it while signed in.
class AccountClosureReceipt {
  const AccountClosureReceipt({
    required this.operationId,
    required this.statusToken,
    required this.accountId,
  });

  final String operationId;
  final String statusToken;
  final String accountId;

  /// Parses a receipt from a JSON object with all three fields.
  factory AccountClosureReceipt.fromJson(Map<String, dynamic> value) {
    final receipt = tryFromJson(value);
    if (receipt == null) {
      throw const FormatException('Invalid account closure receipt');
    }
    return receipt;
  }

  /// Parses the prepare response for [accountId], the session that asked.
  factory AccountClosureReceipt.fromPrepared(
    Map<String, dynamic> value, {
    required String accountId,
  }) {
    final receipt = tryFromJson({
      ...value,
      'accountId': accountId,
    });
    if (receipt == null) {
      throw const FormatException('Invalid account closure receipt');
    }
    return receipt;
  }

  /// Returns null for any receipt that is malformed or unbound.
  static AccountClosureReceipt? tryFromJson(Map<String, dynamic> value) {
    final operation = value['operationId']?.toString() ?? '';
    final token = value['statusToken']?.toString() ?? '';
    final account = value['accountId']?.toString().trim() ?? '';
    if (!_operationIdPattern.hasMatch(operation) ||
        !_statusTokenPattern.hasMatch(token) ||
        account.isEmpty ||
        account.length > 128) {
      return null;
    }
    return AccountClosureReceipt(
      operationId: operation,
      statusToken: token,
      accountId: account,
    );
  }

  /// Decodes a stored receipt. Returns null when the stored value is not a
  /// valid, account-bound receipt. Callers then purge it.
  static AccountClosureReceipt? tryDecodeStored(String raw) {
    try {
      final parsed = jsonDecode(raw);
      if (parsed is! Map) return null;
      return tryFromJson(Map<String, dynamic>.from(parsed));
    } catch (_) {
      return null;
    }
  }

  Map<String, String> toJson() => {
        'operationId': operationId,
        'statusToken': statusToken,
        'accountId': accountId,
      };

  String encode() => jsonEncode(toJson());
}

enum AccountClosureState {
  received,
  processing,
  reviewRequired,
  completedManaged
}

/// How far a client-side account closure got. A failure before [deleting]
/// means the server was never asked to delete. A failure at or after
/// [deleting] may still have committed, so only status recovery can say,
/// except for [refused], where the server definitively declined DELETE.
enum AccountClosureStage {
  /// Session pinned; the status receipt is being requested and stored.
  preparing,

  /// The receipt is stored and DELETE /api/auth/me is about to be sent.
  deleting,

  /// The server definitively refused DELETE (a client error that cannot mean
  /// the account was already deleted). The receipt has been discarded.
  refused,

  /// The server confirmed deletion; only local sign-out remains.
  committed,
}

class AccountClosureStatus {
  const AccountClosureStatus(
      {required this.state, required this.lawfulRetention});
  final AccountClosureState state;
  final bool lawfulRetention;

  factory AccountClosureStatus.fromJson(Map<String, dynamic> value) {
    final state = switch (value['state']) {
      'received' => AccountClosureState.received,
      'processing' => AccountClosureState.processing,
      'review_required' => AccountClosureState.reviewRequired,
      'completed_managed' => AccountClosureState.completedManaged,
      _ => throw const FormatException('Unknown account closure state'),
    };
    return AccountClosureStatus(
        state: state, lawfulRetention: value['lawfulRetention'] == true);
  }
}
