import 'dart:convert';

import 'package:art_kubus/models/user.dart';
import 'package:art_kubus/models/pending_action_intent.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/saved_items_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/pending_action_executor.dart';
import 'package:art_kubus/services/public_action_outbox_service.dart';
import 'package:art_kubus/services/public_fallback_service.dart';
import 'package:art_kubus/services/solana_wallet_service.dart';
import 'package:art_kubus/services/user_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _actor = 'WalletTest111111111111111111111111111111';
const _target = 'WalletTarget11111111111111111111111111111';

class _FakeWalletService extends SolanaWalletService {
  @override
  bool get hasActiveKeyPair => true;

  @override
  String? get activePublicKey => _actor;

  @override
  Future<String> signMessageBase64(String messageBase64) async =>
      base64Encode(utf8.encode('sig:$messageBase64'));
}

User _targetProfile({bool isFollowing = false}) => User(
      id: _target,
      name: 'Target',
      username: 'target',
      bio: '',
      followersCount: 17,
      followingCount: 5,
      postsCount: 1,
      isFollowing: isFollowing,
      isVerified: false,
      joinedDate: 'Joined recently',
    );

String _followingPreferenceKey() => 'following_users_$_actor';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BackendApiService api;
  late PublicActionOutboxService outbox;

  setUp(() async {
    api = BackendApiService();
    outbox = PublicActionOutboxService();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'wallet_address': _actor,
    });
    await PublicFallbackService().resetForTesting();
    await outbox.resetForTesting();
    outbox.bindSigner(
      walletService: _FakeWalletService(),
      walletAddressResolver: () => _actor,
    );
    await outbox.initialize();
    api.setPreferredWalletAddress(null);
    api.setAuthTokenForTesting(null);
    BackendApiService.disableHttpFailureDiagnosticsForTesting = true;
    UserService.setUsersInCacheAuthoritative([_targetProfile()]);
  });

  tearDown(() async {
    api.setHttpClient(http.Client());
    api.setPreferredWalletAddress(null);
    api.setAuthTokenForTesting(null);
    BackendApiService.disableHttpFailureDiagnosticsForTesting = false;
    await outbox.resetForTesting();
    await PublicFallbackService().resetForTesting();
    await UserService.clearCache();
  });

  test(
    'queued transient follow does not mutate confirmed state or counters',
    () async {
      api.setHttpClient(
        MockClient(
          (_) async => http.Response(
            jsonEncode(<String, Object?>{
              'success': false,
              'isFollowing': true,
              'followersCount': 99,
            }),
            503,
          ),
        ),
      );

      final result = await UserService.setFollowState(
        _target,
        shouldFollow: true,
      );

      expect(result.pending, isTrue);
      expect(result.requestedIsFollowing, isTrue);
      expect(result.isFollowing, isFalse);
      expect(UserService.getCachedUser(_target)?.isFollowing, isFalse);
      expect(UserService.getCachedUser(_target)?.followersCount, 17);
      expect(outbox.queuedActionCount, 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_followingPreferenceKey()), isNull);
    },
  );

  test(
    'a 2xx success=false response is rejected without cache mutation',
    () async {
      api.setHttpClient(
        MockClient(
          (_) async => http.Response(
            jsonEncode(<String, Object?>{
              'success': false,
              'isFollowing': true,
              'followersCount': 99,
            }),
            200,
          ),
        ),
      );

      await expectLater(
        UserService.setFollowState(_target, shouldFollow: true),
        throwsA(isA<BackendApiRequestException>()),
      );

      expect(UserService.getCachedUser(_target)?.isFollowing, isFalse);
      expect(UserService.getCachedUser(_target)?.followersCount, 17);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_followingPreferenceKey()), isNull);
    },
  );

  test(
    'an unchanged confirmed follow does not increment cached followers',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'wallet_address': _actor,
        _followingPreferenceKey(): jsonEncode(<String>[_target]),
      });
      api.setHttpClient(
        MockClient(
          (_) async => http.Response(
            jsonEncode(<String, Object?>{
              'success': true,
              'isFollowing': true,
              'changed': false,
            }),
            200,
          ),
        ),
      );

      final result = await UserService.setFollowState(
        _target,
        shouldFollow: true,
      );

      expect(result.pending, isFalse);
      expect(result.isFollowing, isTrue);
      expect(UserService.getCachedUser(_target)?.followersCount, 17);
    },
  );

  test(
    'a pending follow is not completed from the local pre-request state',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _followingPreferenceKey(),
        jsonEncode(<String>[_target]),
      );
      UserService.setUsersInCacheAuthoritative([
        _targetProfile(isFollowing: true),
      ]);
      api.setHttpClient(
        MockClient(
          (_) async => http.Response(
            jsonEncode(<String, Object?>{
              'success': false,
              'isFollowing': true,
            }),
            503,
          ),
        ),
      );

      final result = await const PendingActionExecutor().execute(
        intent: PendingActionIntent.create(
          actionType: PendingActionType.follow,
          targetType: PendingActionTargetType.user,
          targetId: _target,
          returnRoute: '/profile/target',
          sourceScreen: 'profile',
        )!,
        artworkProvider: ArtworkProvider(backendApi: api),
        savedItemsProvider: SavedItemsProvider(),
      );

      expect(result.outcome, PendingActionOutcome.failed);
      expect(result.didSucceed, isFalse);
      expect(outbox.queuedActionCount, 1);
    },
  );
}
