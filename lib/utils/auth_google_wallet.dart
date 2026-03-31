import 'dart:convert';

import '../services/backend_api_service.dart';
import '../services/google_auth_service.dart';

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

Future<Map<String, dynamic>> loginWithGoogleWalletRecovery({
  required BackendApiService api,
  required GoogleAuthResult googleResult,
  required String? walletAddress,
  required Future<String?> Function() createSignerBackedWallet,
}) async {
  try {
    return await api.loginWithGoogle(
      idToken: googleResult.idToken,
      code: googleResult.serverAuthCode,
      email: googleResult.email,
      username: null,
      walletAddress: walletAddress,
      displayName: googleResult.displayName,
    );
  } catch (error) {
    if (!isWalletRequiredForNewGoogleAccount(error)) {
      rethrow;
    }

    final provisionedWallet = (await createSignerBackedWallet())?.trim();
    if (provisionedWallet == null || provisionedWallet.isEmpty) {
      throw Exception('Signer-backed wallet provisioning failed');
    }

    return api.loginWithGoogle(
      idToken: googleResult.idToken,
      code: googleResult.serverAuthCode,
      email: googleResult.email,
      username: null,
      walletAddress: provisionedWallet,
      displayName: googleResult.displayName,
    );
  }
}
