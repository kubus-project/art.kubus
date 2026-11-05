import 'dart:convert';

/// A narrow status-only capability. Never place it in a URL or analytics.
class AccountClosureReceipt {
  const AccountClosureReceipt(
      {required this.operationId, required this.statusToken});
  final String operationId;
  final String statusToken;

  factory AccountClosureReceipt.fromJson(Map<String, dynamic> value) {
    final operation = value['operationId']?.toString() ?? '';
    final token = value['statusToken']?.toString() ?? '';
    if (!RegExp(r'^[a-fA-F0-9-]{36}$').hasMatch(operation) ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(token)) {
      throw const FormatException('Invalid account closure receipt');
    }
    return AccountClosureReceipt(operationId: operation, statusToken: token);
  }

  Map<String, String> toJson() =>
      {'operationId': operationId, 'statusToken': statusToken};
  String encode() => jsonEncode(toJson());
}

enum AccountClosureState {
  received,
  processing,
  reviewRequired,
  completedManaged
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
