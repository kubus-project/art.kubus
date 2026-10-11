import 'package:art_kubus/community/community_interactions.dart';
import 'package:art_kubus/models/profile_identity_data.dart';
import 'package:art_kubus/screens/community/post_detail_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/product_surface_harness.dart';

CommunityPost _post() => CommunityPost(
      id: 'post-1',
      authorIdentityData: ProfileIdentityData.fromCompactAuthor(
        const {
          'displayName': 'Feed Author',
          'username': 'feed_author',
          'walletAddress': 'feed-author-wallet',
        },
        fallbackLabel: 'Unknown author',
      ),
      content: 'A mural on the riverside wall.',
      timestamp: DateTime.utc(2026, 9, 27, 12),
      likeCount: 12,
      commentCount: 3,
    );

/// Every request answers an empty, successful payload: the screen's comment
/// and state loads settle without network.
http.Response _empty(http.Request request) => http.Response(
      '{"success":true,"data":[]}',
      200,
      headers: const {'content-type': 'application/json'},
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setHttpClient(MockClient((r) async => _empty(r)));
  });

  tearDown(() {
    BackendApiService().setHttpClient(http.Client());
  });

  testWidgets('the comment composer is the bottom bar, not a body child',
      (tester) async {
    final prior = FlutterError.onError;
    await pumpProductSurface(
      tester,
      child: PostDetailScreen(post: _post()),
      size: const Size(390, 844),
      settle: const Duration(seconds: 2),
    );
    FlutterError.onError = prior;

    final scaffold = tester.widget<Scaffold>(
      find
          .descendant(
            of: find.byType(PostDetailScreen),
            matching: find.byType(Scaffold),
          )
          .first,
    );
    expect(scaffold.bottomNavigationBar, isNotNull);
  });

  testWidgets('a floating SnackBar sits above the composer, so Send stays free',
      (tester) async {
    final prior = FlutterError.onError;
    await pumpProductSurface(
      tester,
      child: PostDetailScreen(post: _post()),
      size: const Size(390, 844),
      settle: const Duration(seconds: 2),
    );
    FlutterError.onError = prior;

    final messenger = ScaffoldMessenger.of(
      tester.element(find.byType(PostDetailScreen)),
    );
    messenger.showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text("That didn't work. Please try again."),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final toast = tester.getRect(find.byType(SnackBar));
    final composerField = tester.getRect(find.byType(TextField).last);
    expect(
      toast.bottom,
      lessThanOrEqualTo(composerField.top),
      reason: 'the failure toast must not cover the composer or its Send',
    );
  });
}
