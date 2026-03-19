import 'dart:convert';

import '../services/backend_api_service.dart';

const String _walletRequiredForNewGoogleAccountCode =
    'WALLET_REQUIRED_FOR_NEW_ACCOUNT';

String? signerBackedGoogleWalletAddress({
  required bool hasSigner,
  String? currentWalletAddress,
}) {
  final normalizedWallet = (currentWalletAddress ?? '').trim();
  if (!hasSigner || normalizedWallet.isEmpty) {
    return null;
  }
  return normalizedWallet;
}

bool isWalletRequiredForNewGoogleAccount(Object error) {
  if (error is! BackendApiRequestException) {
    return false;
  }

  if (error.statusCode != 400) {
    return false;
  }

  final body = (error.body ?? '').trim();
  if (body.isEmpty) {
    return false;
  }

  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      final errorCode = (decoded['errorCode'] ?? '').toString().trim();
      return errorCode == _walletRequiredForNewGoogleAccountCode;
    }
  } catch (_) {
    return false;
  }

  return false;
}
