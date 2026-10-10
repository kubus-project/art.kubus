import 'package:art_kubus/community/community_interactions.dart';
import 'package:art_kubus/models/pending_action_intent.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/pending_action_provider.dart';
import 'package:art_kubus/providers/saved_items_provider.dart';
import 'package:art_kubus/services/pending_action_executor.dart';
import 'package:art_kubus/widgets/community/post_like_settlement.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

CommunityPost _post({bool isLiked = false, int likeCount = 3}) => CommunityPost(
      id: 'post-1',
      authorName: 'Ana Umetnica',
      content: 'A mural on the riverside wall.',
      timestamp: DateTime(2026, 10, 1, 12),
      isLiked: isLiked,
      likeCount: likeCount,
    );

/// Returns a fixed outcome for every intent, so the provider settles without
/// touching the network.
class _FixedExecutor implements PendingActionExecutor {
  _FixedExecutor(this.result);

  final PendingActionExecutionResult result;

  @override
  Future<PendingActionExecutionResult> execute({
    required PendingActionIntent intent,
    required ArtworkProvider artworkProvider,
    required SavedItemsProvider savedItemsProvider,
  }) async =>
      result;
}

PendingActionIntent _postLike({String postId = 'post-1'}) =>
    PendingActionIntent.create(
      actionType: PendingActionType.like,
      targetType: PendingActionTargetType.post,
      targetId: postId,
      returnRoute: '/p/$postId',
      sourceScreen: 'community_feed',
    )!;

PendingActionIntent _comment() => PendingActionIntent.create(
      actionType: PendingActionType.comment,
      targetType: PendingActionTargetType.post,
      targetId: 'post-1',
      returnRoute: '/p/post-1',
      sourceScreen: 'community_feed',
    )!;

Future<void> _settle(
  PendingActionProvider provider,
  PendingActionIntent intent,
) async {
  await provider.capture(intent);
  await provider.restore();
  await provider.confirm(
    artworkProvider: ArtworkProvider(),
    savedItemsProvider: SavedItemsProvider(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('applyConfirmedPostLike', () {
    test('a fresh like fills the heart and takes the confirmed count', () {
      final post = _post();
      applyConfirmedPostLike(post, (isLiked: true, likeCount: 4));

      expect(post.isLiked, isTrue);
      expect(post.likeCount, 4);
    });

    test('without a confirmed count, a fresh like adds exactly one', () {
      final post = _post();
      applyConfirmedPostLike(post, (isLiked: true, likeCount: null));

      expect(post.isLiked, isTrue);
      expect(post.likeCount, 4);
    });

    test('a post already liked stays liked and its count does not move', () {
      final post = _post(isLiked: true);
      applyConfirmedPostLike(post, (isLiked: true, likeCount: null));

      expect(post.isLiked, isTrue);
      expect(post.likeCount, 3);
    });

    test('applying the same confirmation twice changes nothing more', () {
      final post = _post();
      const snapshot = (isLiked: true, likeCount: null);
      applyConfirmedPostLike(post, snapshot);
      applyConfirmedPostLike(post, snapshot);

      expect(post.isLiked, isTrue);
      expect(post.likeCount, 4);
    });
  });

  group('PostLikeSettlementWatcher', () {
    test('a like confirmed after attaching is reported once', () async {
      final provider = PendingActionProvider(
        executor: _FixedExecutor(
          const PendingActionExecutionResult(
            PendingActionOutcome.completed,
            postLike: (isLiked: true, likeCount: 4),
          ),
        ),
      );
      final reported = <(String, int?)>[];
      final watcher = PostLikeSettlementWatcher(
        (postId, snapshot) => reported.add((postId, snapshot.likeCount)),
      )..attach(provider);

      await _settle(provider, _postLike());
      provider.notifyListeners();

      expect(reported, <(String, int?)>[('post-1', 4)]);
      watcher.detach();
    });

    test('a like confirmed before the screen attached is not replayed',
        () async {
      final provider = PendingActionProvider(
        executor: _FixedExecutor(
          const PendingActionExecutionResult(
            PendingActionOutcome.completed,
            postLike: (isLiked: true, likeCount: 4),
          ),
        ),
      );
      await _settle(provider, _postLike());

      var calls = 0;
      final watcher = PostLikeSettlementWatcher((_, __) => calls++)
        ..attach(provider);
      provider.notifyListeners();

      expect(calls, 0);
      watcher.detach();
    });

    test('comments and other outcomes are not reported as like changes',
        () async {
      final provider = PendingActionProvider(
        executor: _FixedExecutor(
          const PendingActionExecutionResult(
              PendingActionOutcome.entryRestored),
        ),
      );
      var calls = 0;
      final watcher = PostLikeSettlementWatcher((_, __) => calls++)
        ..attach(provider);

      await _settle(provider, _comment());

      expect(calls, 0);
      watcher.detach();
    });

    test('detaching stops further reports', () async {
      final provider = PendingActionProvider(
        executor: _FixedExecutor(
          const PendingActionExecutionResult(
            PendingActionOutcome.completed,
            postLike: (isLiked: true, likeCount: 4),
          ),
        ),
      );
      var calls = 0;
      final watcher = PostLikeSettlementWatcher((_, __) => calls++)
        ..attach(provider)
        ..detach();

      await _settle(provider, _postLike());

      expect(calls, 0);
      watcher.detach();
    });
  });
}
