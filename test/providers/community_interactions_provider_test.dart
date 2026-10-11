import 'dart:async';

import 'package:art_kubus/community/community_interactions.dart';
import 'package:art_kubus/models/community_subject.dart';
import 'package:art_kubus/models/profile_identity_data.dart';
import 'package:art_kubus/providers/community_interactions_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeBackendApiService implements BackendApiService {
  int interactionStateCalls = 0;
  int createPostCalls = 0;
  int createRepostCalls = 0;
  int deleteRepostCalls = 0;
  int deletePostCalls = 0;
  final List<String> analyticsEvents = <String>[];

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
  Future<CommunityPost> createCommunityPost({
    required String content,
    String? idempotencyKey,
    String? imageUrl,
    List<String>? mediaUrls,
    List<String>? mediaCids,
    String? artworkId,
    String? subjectType,
    String? subjectId,
    List<CommunitySubjectRef>? subjects,
    String? postType,
    String category = 'post',
    List<String>? tags,
    List<String>? mentions,
    CommunityLocation? location,
    String? locationName,
    double? locationLat,
    double? locationLng,
  }) async {
    createPostCalls += 1;
    return _post(id: 'created-post').copyWith(
      content: content,
      category: category,
      mediaUrls: mediaUrls,
      tags: tags,
      mentions: mentions,
      subjectType: subjectType,
      subjectId: subjectId,
    );
  }

  @override
  Future<CommunityPost> createRepost({
    required String originalPostId,
    String? content,
  }) async {
    createRepostCalls += 1;
    return CommunityPost(
      id: 'repost-1',
      authorIdentityData: ProfileIdentityData.fromCompactAuthor(
        const {
          'displayName': 'Reposter',
          'walletAddress': 'reposter-wallet',
        },
        fallbackLabel: 'Unknown author',
      ),
      content: content ?? '',
      timestamp: DateTime.utc(2026, 6, 15),
      postType: 'repost',
      originalPostId: originalPostId,
    );
  }

  @override
  Future<void> deleteRepost(String repostId) async {
    deleteRepostCalls += 1;
  }

  @override
  Future<void> deleteCommunityPost(String postId) async {
    deletePostCalls += 1;
  }

  @override
  Future<void> trackAnalyticsEvent({
    required String eventType,
    String? postId,
    String? targetType,
    String? targetId,
    String? eventCategory,
    Map<String, dynamic>? metadata,
  }) async {
    analyticsEvents.add(eventType);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CommunityPost _post({
  String id = 'post-1',
  bool isLiked = true,
  bool isBookmarked = true,
  int shareCount = 0,
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
    shareCount: shareCount,
    isLiked: isLiked,
    isBookmarked: isBookmarked,
  );
}

/// A state read that stays in flight until the test releases it.
class _GatedInteractionApi extends _FakeBackendApiService {
  final Completer<CommunityInteractionStateBatch> _gate =
      Completer<CommunityInteractionStateBatch>();

  @override
  Future<CommunityInteractionStateBatch> getCommunityInteractionStates({
    Iterable<String> postIds = const <String>[],
    Iterable<String> commentIds = const <String>[],
    Iterable<String> artworkIds = const <String>[],
  }) {
    interactionStateCalls += 1;
    return _gate.future;
  }

  void release(
      {required bool isLiked, required int likeCount, required String postId}) {
    _gate.complete(CommunityInteractionStateBatch(posts: {
      postId: CommunityEntityInteractionState(
        id: postId,
        isLiked: isLiked,
        likeCount: likeCount,
        commentCount: 3,
        isBookmarked: false,
      ),
    }));
  }
}

void main() {
  test('a read that was in flight does not undo a newer confirmed like',
      () async {
    final api = _GatedInteractionApi();
    final provider = CommunityInteractionsProvider(api: api);
    final post = _post(isLiked: false); // likeCount 7

    final pending = provider.refreshPostStates([post], force: true);
    // The like is confirmed while the read is still out.
    post
      ..isLiked = true
      ..likeCount = 8;
    provider.applyServerPostState(post);
    // The older read lands last and still says "not liked, 7".
    api.release(isLiked: false, likeCount: 7, postId: post.id);
    await pending;

    expect(post.isLiked, isTrue);
    expect(post.likeCount, 8);
    expect(provider.cachedPostState(post.id)!.likeCount, 8);
  });

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
      force: true,
    );

    expect(api.interactionStateCalls, 0);

    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(api.interactionStateCalls, 1);
  });

  test('createCommunityPost tracks and hydrates created post state', () async {
    final api = _FakeBackendApiService();
    final provider = CommunityInteractionsProvider(api: api);

    final created = await provider.createCommunityPost(
      content: 'Hello',
      category: 'post',
      normalizePost: (post) => post.copyWith(subjectType: 'artwork'),
    );

    expect(api.createPostCalls, 1);
    expect(created.id, 'created-post');
    expect(created.subjectType, 'artwork');
    expect(provider.cachedPostState(created.id), isNotNull);
  });

  test('createRepost updates original share count and tracks analytics',
      () async {
    final api = _FakeBackendApiService();
    final provider = CommunityInteractionsProvider(api: api);
    final original = _post(shareCount: 2);

    final repost = await provider.createRepost(
      originalPost: original,
      content: 'Worth seeing',
    );
    await Future<void>.delayed(Duration.zero);

    expect(api.createRepostCalls, 1);
    expect(repost.originalPostId, original.id);
    expect(original.shareCount, 3);
    expect(provider.cachedPostState(original.id), isNotNull);
    expect(provider.cachedPostState(repost.id), isNotNull);
    expect(api.analyticsEvents, contains('repost_created'));
  });

  test('delete mutations clear cached post state', () async {
    final api = _FakeBackendApiService();
    final provider = CommunityInteractionsProvider(api: api);
    final post = _post();
    provider.hydratePostsFromServer([post]);

    await provider.deleteCommunityPost(post);

    expect(api.deletePostCalls, 1);
    expect(provider.cachedPostState(post.id), isNull);

    final repost = _post(id: 'repost-1');
    provider.hydratePostsFromServer([repost]);
    await provider.deleteRepost(repost);
    await Future<void>.delayed(Duration.zero);

    expect(api.deleteRepostCalls, 1);
    expect(provider.cachedPostState(repost.id), isNull);
    expect(api.analyticsEvents, contains('repost_deleted'));
  });
}
