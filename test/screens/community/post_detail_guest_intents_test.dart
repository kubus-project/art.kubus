import 'package:art_kubus/community/community_interactions.dart';
import 'package:art_kubus/models/pending_action_intent.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/pending_action_provider.dart';
import 'package:art_kubus/providers/saved_items_provider.dart';
import 'package:art_kubus/screens/community/post_detail_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/pending_action_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/product_surface_harness.dart';

CommunityPost _post() => CommunityPost(
      id: 'post-1',
      authorName: 'Ana Umetnica',
      content: 'A mural on the riverside wall.',
      timestamp: DateTime(2026, 10, 1, 12),
      likeCount: 3,
    );

/// Pumps the real post detail as a guest. The product-surface harness
/// installs its own `FlutterError.onError` until teardown, so it is put back
/// straight away: a failing expect under the harness would otherwise hang the
/// run instead of failing it (see the harness memory note).
Future<void> _pumpGuestPost(
  WidgetTester tester, {
  List<SingleChildWidget> extraProviders = const <SingleChildWidget>[],
}) async {
  final prior = FlutterError.onError;
  await pumpProductSurface(
    tester,
    child: PostDetailScreen(post: _post()),
    extraProviders: extraProviders,
    settle: const Duration(milliseconds: 500),
  );
  FlutterError.onError = prior;
}

void main() {
  setUp(() {
    BackendApiService().setAuthTokenForTesting(null);
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('guest on post detail', () {
    testWidgets('liking asks for an account and keeps the like for after it',
        (tester) async {
      await _pumpGuestPost(tester);

      await tester.tap(find.byIcon(Icons.favorite_border).first);
      await tester.pumpAndSettle();

      expect(find.text('Like this post'), findsOneWidget);

      final captured = await const PendingActionService().read();
      expect(captured, isNotNull);
      expect(captured!.actionType, PendingActionType.like);
      expect(captured.targetType, PendingActionTargetType.post);
      expect(captured.targetId, 'post-1');

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
    });

    testWidgets('cancelling the like gate leaves nothing pending',
        (tester) async {
      await _pumpGuestPost(tester);

      await tester.tap(find.byIcon(Icons.favorite_border).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(await const PendingActionService().read(), isNull);
      expect(find.byIcon(Icons.favorite_border), findsWidgets);
    });

    testWidgets('a typed comment survives the gate and is not sent',
        (tester) async {
      await _pumpGuestPost(tester);

      final field = find.byType(TextField).last;
      await tester.enterText(field, 'Lovely wall');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Write your comment?'), findsNothing);
      expect(find.text('Join this discussion'), findsOneWidget);

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      final remaining = tester.widget<TextField>(field).controller!.text;
      expect(remaining, 'Lovely wall');
    });
  });

  testWidgets('a restored comment puts the cursor back in the composer',
      (tester) async {
    final pending = PendingActionProvider();
    await _pumpGuestPost(tester, extraProviders: <SingleChildWidget>[
      ChangeNotifierProvider<PendingActionProvider>.value(value: pending),
    ]);

    await pending.capture(PendingActionIntent.create(
      actionType: PendingActionType.comment,
      targetType: PendingActionTargetType.post,
      targetId: 'post-1',
      returnRoute: '/p/post-1',
      sourceScreen: 'post_detail',
    )!);
    await pending.restore();
    await pending.confirm(
      artworkProvider: ArtworkProvider(),
      savedItemsProvider: SavedItemsProvider(),
    );
    await tester.pumpAndSettle();

    final composer = tester.widget<TextField>(find.byType(TextField).last);
    expect(composer.focusNode!.hasFocus, isTrue);

    // A focused field keeps a cursor-blink timer alive; release it so the
    // test does not end with a timer still pending.
    composer.focusNode!.unfocus();
    await tester.pumpAndSettle();
  });

  test('the like intent identity is per post', () {
    final a = PendingActionIntent.create(
      actionType: PendingActionType.like,
      targetType: PendingActionTargetType.post,
      targetId: 'post-1',
      returnRoute: '/p/post-1',
      sourceScreen: 'community_feed',
    );
    final b = PendingActionIntent.create(
      actionType: PendingActionType.like,
      targetType: PendingActionTargetType.post,
      targetId: 'post-2',
      returnRoute: '/p/post-2',
      sourceScreen: 'community_feed',
    );
    expect(a!.identityKey, isNot(b!.identityKey));
  });
}
