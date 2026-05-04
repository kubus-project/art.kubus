import 'package:flutter/foundation.dart';
import '../config/config.dart';
import '../services/backend_api_service.dart';

/// Normalizes wallet auth results from various sources into a standard payload.
///
/// Handles:
/// - Direct `Map<String, dynamic>` results from wallet flow
/// - Untyped Map results that need safe casting
/// - Nested user/data structures
/// - Hydration from existing auth session
/// - Wallet-address-only fallback when profile fetch fails
///
/// Returns null only when truly unable to construct a payload.
Future<Map<String, dynamic>?> normalizeWalletAuthResult({
  required Object? routeResult,
  required BackendApiService api,
}) async {
  if (kDebugMode) {
    AppConfig.debugPrint(
      'normalizeWalletAuthResult: routeResult type=${routeResult.runtimeType}, is_map=${routeResult is Map}',
    );
  }

  // Branch 1: Direct typed Map result from wallet flow
  if (routeResult is Map<String, dynamic>) {
    if (kDebugMode) {
      AppConfig.debugPrint('normalizeWalletAuthResult: direct Map result found');
    }
    return routeResult;
  }

  // Branch 2: Untyped Map that can be cast safely
  if (routeResult is Map) {
    if (kDebugMode) {
      AppConfig.debugPrint(
        'normalizeWalletAuthResult: casting untyped Map to Map<String, dynamic>',
      );
    }
    try {
      final cast = Map<String, dynamic>.from(routeResult);
      return cast;
    } catch (e) {
      if (kDebugMode) {
        AppConfig.debugPrint(
          'normalizeWalletAuthResult: cast failed: $e',
        );
      }
      // Fall through to session hydration
    }
  }

  // Branch 3: No direct result, try to hydrate from current session
  if (kDebugMode) {
    AppConfig.debugPrint(
      'normalizeWalletAuthResult: no direct result, attempting session hydration',
    );
  }

  final authToken = (api.getAuthToken() ?? '').trim();
  if (authToken.isEmpty) {
    if (kDebugMode) {
      AppConfig.debugPrint(
        'normalizeWalletAuthResult: no auth token, cannot hydrate',
      );
    }
    return null;
  }

  // Try to fetch profile to get full user data
  try {
    final profile = await api.getMyProfile();
    final success = profile['success'] == true;
    final profileData = profile['data'];

    if (success && profileData is Map<String, dynamic>) {
      if (kDebugMode) {
        AppConfig.debugPrint(
          'normalizeWalletAuthResult: hydration via getMyProfile succeeded',
        );
      }
      return {
        'data': {'user': profileData},
      };
    }
  } catch (e) {
    if (kDebugMode) {
      AppConfig.debugPrint(
        'normalizeWalletAuthResult: getMyProfile failed: $e',
      );
    }
    // Fall through to wallet-address-only fallback
  }

  // Branch 4: Profile fetch failed, construct minimal payload from wallet address
  final walletAddress = (api.getCurrentAuthWalletAddress() ?? '').trim();
  if (walletAddress.isNotEmpty) {
    if (kDebugMode) {
      AppConfig.debugPrint(
        'normalizeWalletAuthResult: hydration via wallet address fallback',
      );
    }
    return {
      'data': {
        'user': {'walletAddress': walletAddress},
      },
    };
  }

  // No path succeeded
  if (kDebugMode) {
    AppConfig.debugPrint(
      'normalizeWalletAuthResult: all paths exhausted, returning null',
    );
  }
  return null;
}
