import 'package:art_kubus/community/community_interactions.dart';
import 'package:art_kubus/models/profile_identity_data.dart';
import 'package:art_kubus/providers/community_interactions_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeBackendApiService implements BackendApiService {
  int interactionStateCalls = 0;

  @override
  Future<CommunityInteractionStateBatch> getCommunityInteractionStates({
    Iterable<String> postIds = const <String>[],
    Iterable<String> commentIds = const <String>[],
    Iterable<String> artworkIds = const <String>[],
  }) async {
    interactionStateCalls += 1;
    return CommunityInteractionStateBatch(
      posts: {
        for (final id in postIds)
          id: CommunityEntityInteractionState(
            id: id,
            isLiked: false,
            likeCount: 0,
            commentCount: 0,
            isBookmarked: false,
          ),
      },
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CommunityPost _post({
  String id = 'post-1',
  bool isLiked = true,
  bool isBookmarked = true,
}) {
  return CommunityPost(
    id: id,
    authorIdentityData: ProfileIdentityData.fromCompactAuthor(
      const {
        'displayName': 'Feed Author',
        'username': 'feed_author',
        'walletAddress': 'feed-author-wallet',
      },
      fallbackLabel: 'Unknown author',
    ),
    content: 'Feed payload post',
    timestamp: DateTime.utc(2026, 6, 14),
    likeCount: 7,
    commentCount: 3,
    isLiked: isLiked,
    isBookmarked: isBookmarked,
  );
}

void main() {
  test('prefetchForPosts hydrates feed state without immediate refresh',
      () async {
    final api = _FakeBackendApiService();
    final provider = CommunityInteractionsProvider(api: api);
    final post = _post();

    await provider.prefetchForPosts([post]);

    expect(api.interactionStateCalls, 0);
    final cached = provider.cachedPostState(post.id);
    expect(cached, isNotNull);
    expect(cached!.isLiked, isTrue);
    expect(cached.isBookmarked, isTrue);
    expect(cached.likeCount, 7);
    expect(cached.commentCount, 3);
  });

  test('prefetchForPosts can explicitly reconcile after first paint', () async {
    final api = _FakeBackendApiService();
    final provider = CommunityInteractionsProvider(api: api);
    final post = _post(id: 'post-2');

    await provider.prefetchForPosts([post], reconcile: true);
    await Future<void>.delayed(Duration.zero);

    expect(api.interactionStateCalls, 1);
  });

  test('reconcilePostStatesAfterFirstPaint delays interaction-state refresh',
      () async {
    final api = _FakeBackendApiService();
    final provider = CommunityInteractionsProvider(api: api);
    final post = _post(id: 'post-3');

    provider.hydratePostsFromServer([post]);
    provider.reconcilePostStatesAfterFirstPaint(
      [post],
      delay: const Duration(milliseconds: 20),
    );

    expect(api.interactionStateCalls, 0);

    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(api.interactionStateCalls, 1);
  });
}
