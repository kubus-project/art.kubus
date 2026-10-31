import 'dart:async';

import 'package:art_kubus/services/account_cache_store.dart';
import 'package:art_kubus/services/socket_service.dart';
import 'package:flutter_test/flutter_test.dart';

// Widget and unit tests never open a real socket. Credential restoration now completes promptly, so screens that
// call SocketService.connect() in initState would otherwise leave a six second connect timer pending and fail
// the test-end invariant. Tests that exercise the connect path set the flag explicitly.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  SocketService.debugDisableConnect = true;
  // A previous test may have ended with account-cache IO pending in a zone that
  // no longer runs; that must not hold up this test's cache reads and writes.
  setUp(AccountCacheStore.discardQueueForTesting);
  await testMain();
}
