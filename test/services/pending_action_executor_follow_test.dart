import 'dart:convert';

import 'package:art_kubus/models/pending_action_intent.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/saved_items_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:art_kubus/services/pending_action_executor.dart';
import 'package:art_kubus/services/user_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _accountUuid = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const _wallet = 'G1mUnv6Yv3xq8mzbwb9c8rD2zYw3Lk5nVq4tJ7yHp2Ar';
const _authToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
    'eyJleHAiOjQ3MzM4NTYwMDAsIndhbGxldEFkZHJlc3MiOiJXYWxsZXRUZXN0MTExMTExMTExMTExMTExMTExMTExMTExMTExMSJ9.'
    'signature';

PendingActionIntent _follow(String targetId) => PendingActionIntent.create(
      actionType: PendingActionType.follow,
      targetType: PendingActionTargetType.user,
      targetId: targetId,
      returnRoute: '/main',
      sourceScreen: 'institution_detail',
    )!;

/// Records each follow the executor sends, and answers with [following].
FollowStateSetter _recording(
  List<String> log, {
  bool following = true,
  bool pending = false,
}) =>
    (targetId, {required shouldFollow}) async {
      log.add('$targetId:$shouldFollow');
      return UserFollowMutationResult(
        isFollowing: following,
        targetWallet: targetId,
        pending: pending,
        requestedIsFollowing: shouldFollow,
      );
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a follow continuation routes by target kind', () {
    late ArtworkProvider artworks;
    late SavedItemsProvider saved;
    late List<String> accountCalls;
    late List<String> walletCalls;

    setUp(() {
      artworks = ArtworkProvider();
      saved = SavedItemsProvider();
      accountCalls = <String>[];
      walletCalls = <String>[];
    });

    Future<PendingActionExecutionResult> run(
      PendingActionExecutor executor,
      String targetId,
    ) =>
        executor.execute(
          intent: _follow(targetId),
          artworkProvider: artworks,
          savedItemsProvider: saved,
        );

    PendingActionExecutor executor({
      bool following = true,
      bool pending = false,
    }) =>
        PendingActionExecutor(
          setAccountFollow: _recording(
            accountCalls,
            following: following,
            pending: pending,
          ),
          setWalletFollow: _recording(
            walletCalls,
            following: following,
            pending: pending,
          ),
        );

    test('an account UUID replays through the account-id route only', () async {
      final result = await run(executor(), _accountUuid);

      expect(result.outcome, PendingActionOutcome.completed);
      expect(accountCalls, ['$_accountUuid:true']);
      expect(walletCalls, isEmpty,
          reason: 'an account id is never sent to the wallet route');
    });

    test('a wallet target keeps the wallet route', () async {
      final result = await run(executor(), _wallet);

      expect(result.outcome, PendingActionOutcome.completed);
      expect(walletCalls, ['$_wallet:true']);
      expect(accountCalls, isEmpty);
    });

    test('an upper-case account UUID is canonicalised before it is sent',
        () async {
      final result = await run(executor(), _accountUuid.toUpperCase());

      expect(result.outcome, PendingActionOutcome.completed);
      expect(accountCalls, ['$_accountUuid:true']);
      expect(walletCalls, isEmpty);
    });

    test('a pending account follow stays retryable', () async {
      final result = await run(executor(pending: true), _accountUuid);

      expect(result.outcome, PendingActionOutcome.failed);
      expect(result.didSucceed, isFalse);
    });

    test('a follow the server does not confirm is not completed', () async {
      final result = await run(executor(following: false), _accountUuid);

      expect(result.outcome, PendingActionOutcome.failed);
    });
  });

  group('the default account route', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      BackendApiService().setAuthTokenForTesting(_authToken);
    });

    tearDown(() {
      BackendApiService().setAuthTokenForTesting(null);
      BackendApiService().setHttpClient(createPlatformHttpClient());
    });

    test('posts to /api/community/follow/account/:userId for an account id',
        () async {
      final paths = <String>[];
      BackendApiService().setHttpClient(MockClient((request) async {
        paths.add('${request.method} ${request.url.path}');
        return http.Response(
          jsonEncode({
            'success': true,
            'isFollowing': true,
            'followCreated': true,
            'targetUserId': _accountUuid,
          }),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }));

      final result = await PendingActionExecutor().execute(
        intent: _follow(_accountUuid),
        artworkProvider: ArtworkProvider(),
        savedItemsProvider: SavedItemsProvider(),
      );

      expect(result.outcome, PendingActionOutcome.completed);
      expect(
        paths.where((p) => p.contains('/follow')),
        ['POST /api/community/follow/account/$_accountUuid'],
      );
    });
  });
}
