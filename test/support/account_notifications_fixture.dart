import 'dart:convert';

import 'package:art_kubus/services/account_cache_store.dart';
import 'package:art_kubus/services/backend_api_service.dart';

/// Local in-app notifications belong to the signed-in account and expire after
/// seven days. Tests therefore sign in a synthetic account and store them under
/// it, with timestamps relative to now.
const String syntheticNotificationAccount =
    '33333333-3333-4333-8333-333333333333';

String syntheticAccountToken([String account = syntheticNotificationAccount]) =>
    'e30.${base64Url.encode(utf8.encode(jsonEncode({
              'id': account,
              'exp': DateTime.now()
                      .add(const Duration(hours: 1))
                      .millisecondsSinceEpoch ~/
                  1000,
            }))).replaceAll('=', '')}.synthetic';

String hoursAgo(int hours) =>
    DateTime.now().toUtc().subtract(Duration(hours: hours)).toIso8601String();

/// Signs the synthetic account in and stores [items] as its notifications.
Future<void> storeInAppNotifications(List<Map<String, dynamic>> items) async {
  BackendApiService().setAuthTokenForTesting(syntheticAccountToken());
  await AccountCacheStore.write(
    'in_app_notifications',
    items,
    account: AccountCacheStore.owner,
    generation: AccountCacheStore.generation,
  );
}
