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

/// Answers the state reads in order, then repeats the last answer. A like is
/// verified by reading the state before and after the request.
class _Reads {
  _Reads(this.answers);

  final List<PostLikeSnapshot?> answers;
  int calls = 0;

  Future<PostLikeSnapshot?> call(String postId) async {
    final answer = answers[calls < answers.length ? calls : answers.length - 1];
    calls += 1;
    return answer;
  }
}

void main() {
  group('post like continuation confirms what the server holds', () {
    late ArtworkProvider artworks;
    late SavedItemsProvider saved;
    late List<String> likeRequests;

    setUp(() {
      artworks = ArtworkProvider();
      saved = SavedItemsProvider();
      likeRequests = <String>[];
    });

    Future<PendingActionExecutionResult> run(
      PendingActionExecutor executor,
    ) =>
        executor.execute(
          intent: _postLike(),
          artworkProvider: artworks,
          savedItemsProvider: saved,
        );

    test('a post the account does not like yet is liked once', () async {
      final reads = _Reads(<PostLikeSnapshot?>[
        (isLiked: false, likeCount: 3),
        (isLiked: true, likeCount: 4),
      ]);
      final executor = PendingActionExecutor(
        loadPostLiked: reads.call,
        likePost: (postId) async {
          likeRequests.add(postId);
          return 4;
        },
      );

      final result = await run(executor);

      expect(result.outcome, PendingActionOutcome.completed);
      expect(result.postLike, (isLiked: true, likeCount: 4));
      expect(likeRequests, <String>['post-1']);
    });

    test('a post already liked by the account is left liked, never toggled',
        () async {
      final executor = PendingActionExecutor(
        loadPostLiked: _Reads(<PostLikeSnapshot?>[
          (isLiked: true, likeCount: 3),
        ]).call,
        likePost: (postId) async {
          likeRequests.add(postId);
          return 9;
        },
      );

      final result = await run(executor);

      expect(result.outcome, PendingActionOutcome.completed);
      expect(result.postLike, (isLiked: true, likeCount: 3));
      expect(likeRequests, isEmpty);
    });

    test('a post that no longer exists is reported unavailable', () async {
      final executor = PendingActionExecutor(
        loadPostLiked: _Reads(<PostLikeSnapshot?>[null]).call,
        likePost: (postId) async {
          likeRequests.add(postId);
          return 4;
        },
      );

      final result = await run(executor);

      expect(result.outcome, PendingActionOutcome.targetUnavailable);
      expect(likeRequests, isEmpty);
    });

    test('a like the route recorded before failing is a success', () async {
      // The browser run: the server counted the like, then answered 500.
      final reads = _Reads(<PostLikeSnapshot?>[
        (isLiked: false, likeCount: 3),
        (isLiked: true, likeCount: 4),
      ]);
      final executor = PendingActionExecutor(
        loadPostLiked: reads.call,
        likePost: (postId) async {
          likeRequests.add(postId);
          throw Exception('Internal server error');
        },
      );

      final result = await run(executor);

      expect(result.outcome, PendingActionOutcome.completed);
      expect(result.postLike, (isLiked: true, likeCount: 4));
      expect(likeRequests, hasLength(1));
    });

    test('a like the server does not hold after a failure is reported failed',
        () async {
      final executor = PendingActionExecutor(
        loadPostLiked: _Reads(<PostLikeSnapshot?>[
          (isLiked: false, likeCount: 3),
        ]).call,
        likePost: (postId) async => throw Exception('Internal server error'),
      );

      final result = await run(executor);

      expect(result.outcome, PendingActionOutcome.failed);
      expect(result.postLike, isNull);
    });

    test('a rejected session is classified as unauthorized', () async {
      final executor = PendingActionExecutor(
        loadPostLiked: _Reads(<PostLikeSnapshot?>[
          (isLiked: false, likeCount: 3),
        ]).call,
        likePost: (postId) async => throw Exception('401 unauthorized'),
      );

      final result = await run(executor);

      expect(result.outcome, PendingActionOutcome.unauthorized);
    });

    test('a request that succeeded stands when the state cannot be read',
        () async {
      final reads = _Reads(<PostLikeSnapshot?>[
        (isLiked: false, likeCount: 3),
        null,
      ]);
      final executor = PendingActionExecutor(
        loadPostLiked: (postId) async {
          // The first read answers; the verifying read throws.
          if (reads.calls >= 1) throw Exception('state unavailable');
          return reads.call(postId);
        },
        likePost: (postId) async => 4,
      );

      final result = await run(executor);

      expect(result.outcome, PendingActionOutcome.completed);
      expect(result.postLike, (isLiked: true, likeCount: 4));
    });
  });
}
