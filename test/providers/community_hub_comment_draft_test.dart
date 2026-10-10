import 'package:art_kubus/providers/community_hub_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('comment draft kept for the sign-in journey', () {
    test('is returned once for the post it was written on', () {
      final hub = CommunityHubProvider();
      hub.rememberCommentDraftForAuth('post-1', 'Lovely wall');

      expect(hub.takeCommentDraftForAuth('post-1'), 'Lovely wall');
      expect(hub.takeCommentDraftForAuth('post-1'), isNull);
    });

    test('is not handed to a different post', () {
      final hub = CommunityHubProvider();
      hub.rememberCommentDraftForAuth('post-1', 'Lovely wall');

      expect(hub.takeCommentDraftForAuth('post-2'), isNull);
      expect(hub.takeCommentDraftForAuth('post-1'), 'Lovely wall');
    });

    test('an abandoned draft expires instead of reappearing much later', () {
      final hub = CommunityHubProvider();
      hub.rememberCommentDraftForAuth('post-1', 'Lovely wall');

      expect(
        hub.takeCommentDraftForAuth('post-1', maxAge: Duration.zero),
        isNull,
      );
    });
  });
}
