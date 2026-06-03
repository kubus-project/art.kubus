import 'dart:convert';

import '../services/backend_api_service.dart';
import '../services/google_auth_service.dart';

const String _walletRequiredForNewGoogleAccountCode =
    'WALLET_REQUIRED_FOR_NEW_ACCOUNT';

bool _isLinkedAuthPlaceholderWallet(String? walletAddress) {
  final normalized = (walletAddress ?? '').trim().toLowerCase();
  return normalized.startsWith('linked_auth:');
}

String? signerBackedGoogleWalletAddress({
  required bool hasSigner,
  String? currentWalletAddress,
}) {
  final normalizedWallet = (currentWalletAddress ?? '').trim();
  if (!hasSigner ||
      normalizedWallet.isEmpty ||
      _isLinkedAuthPlaceholderWallet(normalizedWallet)) {
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
  String origin = 'signin',
}) async {
  final normalizedWallet = (walletAddress ?? '').trim();
  final realWallet = normalizedWallet.isNotEmpty &&
          !_isLinkedAuthPlaceholderWallet(normalizedWallet)
      ? normalizedWallet
      : null;

  Future<Map<String, dynamic>> login({String? wallet}) {
    return api.loginWithGoogle(
      idToken: googleResult.idToken,
      code: googleResult.serverAuthCode,
      email: googleResult.email,
      username: null,
      walletAddress: wallet,
      displayName: googleResult.displayName,
      origin: origin,
    );
  }

  try {
    return await login(wallet: realWallet);
  } catch (error) {
    if (!isWalletRequiredForNewGoogleAccount(error)) {
      rethrow;
    }

    final provisionedWallet = (await createSignerBackedWallet())?.trim() ?? '';
    if (provisionedWallet.isEmpty ||
        _isLinkedAuthPlaceholderWallet(provisionedWallet)) {
      throw Exception('Signer-backed wallet provisioning failed');
    }

    return login(wallet: provisionedWallet);
  }
}
