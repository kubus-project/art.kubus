import 'dart:async';

import 'package:art_kubus/community/community_interactions.dart';
import 'package:art_kubus/providers/community_comments_provider.dart';
import 'package:art_kubus/services/account_identity.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter_test/flutter_test.dart';

Comment _comment(String id) => Comment(
      id: id,
      authorId: 'account-A',
      authorName: 'Account A',
      content: 'A comment',
      timestamp: DateTime.utc(2026, 11, 14),
      isLiked: true,
    );

class _GatedCommentsApi implements BackendApiService {
  int _calls = 0;
  final Completer<void> staleRequestStarted = Completer<void>();
  final Completer<List<Comment>> staleResponse = Completer<List<Comment>>();

  @override
  Future<List<Comment>> getComments({
    required String postId,
    int page = 1,
    int limit = 50,
  }) {
    _calls += 1;
    if (_calls == 1) {
      return Future<List<Comment>>.value([_comment('comment-A')]);
    }
    staleRequestStarted.complete();
    return staleResponse.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  tearDown(AccountIdentity.resetForTesting);

  test('walletless account change clears comments and drops stale A response',
      () async {
    AccountIdentity.setAccountKey('account-A');
    final api = _GatedCommentsApi();
    final provider = CommunityCommentsProvider(api: api);
    addTearDown(provider.dispose);
    await provider.loadComments('post-A');
    expect(provider.commentsForPost('post-A'), hasLength(1));
    expect(provider.commentsForPost('post-A').single.isLiked, isTrue);

    final pending = provider.loadComments('post-A', force: true);
    await api.staleRequestStarted.future;
    AccountIdentity.setAccountKey('account-B');
    AccountIdentity.notifyListenersChanged();
    expect(provider.commentsForPost('post-A'), isEmpty);
    expect(provider.hasLoadedComments('post-A'), isFalse);

    api.staleResponse.complete([_comment('comment-stale-A')]);
    await pending;
    expect(provider.commentsForPost('post-A'), isEmpty);
    expect(provider.hasLoadedComments('post-A'), isFalse);
  });

  test('same-account token refresh preserves loaded comments', () async {
    AccountIdentity.setAccountKey('account-A');
    final provider = CommunityCommentsProvider(api: _GatedCommentsApi());
    addTearDown(provider.dispose);
    await provider.loadComments('post-A');

    AccountIdentity.setAccountKey('account-A');

    expect(provider.commentsForPost('post-A'), hasLength(1));
  });
}
