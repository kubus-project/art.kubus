import 'package:art_kubus/models/pending_action_intent.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/saved_items_provider.dart';
import 'package:art_kubus/services/pending_action_executor.dart';
import 'package:flutter_test/flutter_test.dart';

PendingActionIntent _postLike({String postId = 'post-1'}) =>
    PendingActionIntent.create(
      actionType: PendingActionType.like,
      targetType: PendingActionTargetType.post,
      targetId: postId,
      returnRoute: '/p/$postId',
      sourceScreen: 'community_feed',
    )!;

void main() {
  group('post like continuation is idempotent', () {
    late List<String> likedPostIds;
    late ArtworkProvider artworks;
    late SavedItemsProvider saved;

    setUp(() {
      likedPostIds = <String>[];
      artworks = ArtworkProvider();
      saved = SavedItemsProvider();
    });

    Future<PendingActionExecutionResult> run(
      PendingActionExecutor executor,
      PendingActionIntent intent,
    ) =>
        executor.execute(
          intent: intent,
          artworkProvider: artworks,
          savedItemsProvider: saved,
        );

    test('likes a post the account has not liked yet', () async {
      final executor = PendingActionExecutor(
        loadPostLiked: (postId) async => (isLiked: false, likeCount: 3),
        likePost: (postId) async {
          likedPostIds.add(postId);
          return 4;
        },
      );

      final result = await run(executor, _postLike());

      expect(result.outcome, PendingActionOutcome.completed);
      expect(likedPostIds, <String>['post-1']);
      expect(result.postLike, (isLiked: true, likeCount: 4));
    });

    test('an already liked post is left liked: no like call, no unlike',
        () async {
      final executor = PendingActionExecutor(
        loadPostLiked: (postId) async => (isLiked: true, likeCount: 3),
        likePost: (postId) async {
          likedPostIds.add(postId);
          return 4;
        },
      );

      final result = await run(executor, _postLike());

      expect(result.outcome, PendingActionOutcome.completed);
      expect(likedPostIds, isEmpty);
      expect(result.postLike, (isLiked: true, likeCount: 3));
    });

    test('a post that no longer exists is reported unavailable', () async {
      final executor = PendingActionExecutor(
        loadPostLiked: (postId) async => null,
        likePost: (postId) async {
          likedPostIds.add(postId);
          return 4;
        },
      );

      final result = await run(executor, _postLike());

      expect(result.outcome, PendingActionOutcome.targetUnavailable);
      expect(likedPostIds, isEmpty);
    });

    test('a rejected state read is classified, never retried as a toggle',
        () async {
      final executor = PendingActionExecutor(
        loadPostLiked: (postId) async => throw Exception('401 unauthorized'),
        likePost: (postId) async {
          likedPostIds.add(postId);
          return 4;
        },
      );

      final result = await run(executor, _postLike());

      expect(result.outcome, PendingActionOutcome.unauthorized);
      expect(likedPostIds, isEmpty);
    });
  });
}
