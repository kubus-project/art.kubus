import 'dart:async';

import 'package:art_kubus/community/community_interactions.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/profile_identity_data.dart';
import 'package:art_kubus/providers/community_interactions_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/widgets/community/community_post_delete.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _DeleteApi implements BackendApiService {
  int deleteCalls = 0;
  Object? error;
  Completer<void>? gate;

  @override
  Future<void> deleteCommunityPost(String postId) async {
    deleteCalls += 1;
    final g = gate;
    if (g != null) await g.future;
    final e = error;
    if (e != null) throw e;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CommunityPost _post() => CommunityPost(
      id: 'post-1',
      authorIdentityData: ProfileIdentityData.fromCompactAuthor(
        const {
          'displayName': 'Owner',
          'username': 'owner',
          'walletAddress': 'owner-wallet',
        },
        fallbackLabel: 'Unknown author',
      ),
      content: 'Disposable post',
      timestamp: DateTime.utc(2026, 6, 14),
    );

class _Harness {
  _Harness(this.api, {this.width = 1440, this.onDeleted});
  final _DeleteApi api;
  final double width;
  final VoidCallback? onDeleted;
  int cleanups = 0;
  bool? result;

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final provider = CommunityInteractionsProvider(api: api);
    await tester.pumpWidget(
      ChangeNotifierProvider<CommunityInteractionsProvider>.value(
        value: provider,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () async {
                    result = await confirmAndDeleteCommunityPost(
                      context: context,
                      post: _post(),
                      onDeleted: () {
                        cleanups += 1;
                        onDeleted?.call();
                      },
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }
}

Finder get _panel => find.descendant(
      of: find.byType(KubusAlertDialog),
      matching: find.byType(LiquidGlassPanel),
    );

Finder get _deleteButton => find.widgetWithText(ElevatedButton, 'Delete');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('success closes the dialog, runs cleanup and confirms',
      (tester) async {
    final h = _Harness(_DeleteApi());
    await h.pump(tester);
    await h.open(tester);
    expect(find.text('Delete post'), findsOneWidget);

    await tester.tap(_deleteButton);
    await tester.pumpAndSettle();

    expect(h.api.deleteCalls, 1);
    expect(h.cleanups, 1);
    expect(h.result, isTrue);
    expect(find.text('Delete post'), findsNothing);
    expect(find.text('Post deleted'), findsOneWidget);
  });

  testWidgets('a throwing local cleanup never turns success into failure',
      (tester) async {
    final h = _Harness(
      _DeleteApi(),
      onDeleted: () => throw UnsupportedError(
        'Cannot remove from a fixed-length list',
      ),
    );
    await h.pump(tester);
    await h.open(tester);
    await tester.tap(_deleteButton);
    await tester.pumpAndSettle();

    expect(h.result, isTrue);
    expect(find.text('Delete post'), findsNothing);
    expect(find.text('Failed to delete post.'), findsNothing);
    expect(find.text('Post deleted'), findsOneWidget);
  });

  testWidgets('404 means already deleted and is treated as success',
      (tester) async {
    final api = _DeleteApi()
      ..error = const BackendApiRequestException(
        statusCode: 404,
        path: '/api/community/posts/post-1',
      );
    final h = _Harness(api);
    await h.pump(tester);
    await h.open(tester);
    await tester.tap(_deleteButton);
    await tester.pumpAndSettle();

    expect(h.result, isTrue);
    expect(h.cleanups, 1);
    expect(find.text('Delete post'), findsNothing);
  });

  for (final c in <(int, String)>[
    (401, 'Your session has expired. Sign in again to delete this post.'),
    (403, 'You can only delete your own posts.'),
    (
      409,
      "This post can't be deleted right now. Refresh the feed and try again."
    ),
    (500, 'Failed to delete post.'),
  ]) {
    testWidgets('${c.$1} keeps the dialog open with an actionable message',
        (tester) async {
      final api = _DeleteApi()
        ..error = BackendApiRequestException(
          statusCode: c.$1,
          path: '/api/community/posts/post-1',
        );
      final h = _Harness(api);
      await h.pump(tester);
      await h.open(tester);
      await tester.tap(_deleteButton);
      await tester.pumpAndSettle();

      expect(find.text(c.$2), findsOneWidget);
      expect(h.cleanups, 0);
      // Controls are restored: the user can retry or cancel.
      final retry = tester.widget<ElevatedButton>(_deleteButton);
      expect(retry.onPressed, isNotNull);

      api.error = null;
      await tester.tap(_deleteButton);
      await tester.pumpAndSettle();
      expect(h.result, isTrue);
      expect(find.text('Delete post'), findsNothing);
      expect(api.deleteCalls, 2);
    });
  }

  testWidgets('network failure is reported and Cancel still works',
      (tester) async {
    final api = _DeleteApi()..error = TimeoutException('slow');
    final h = _Harness(api);
    await h.pump(tester);
    await h.open(tester);
    await tester.tap(_deleteButton);
    await tester.pumpAndSettle();
    expect(
      find.text(
          "Couldn't reach art.kubus. Check your connection and try again."),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(ElevatedButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(h.result, isFalse);
    expect(find.text('Delete post'), findsNothing);
    expect(h.cleanups, 0);
  });

  testWidgets('pending state blocks duplicates and dismissal', (tester) async {
    final api = _DeleteApi()..gate = Completer<void>();
    final h = _Harness(api);
    await h.pump(tester);
    await h.open(tester);

    await tester.tap(_deleteButton);
    await tester.pump();
    expect(api.deleteCalls, 1);

    // A second tap on the (now loading) button must not issue a request.
    await tester.tap(find.byType(ElevatedButton).last, warnIfMissed: false);
    await tester.pump();
    expect(api.deleteCalls, 1);

    // Escape / back must not dismiss while pending.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('Delete post'), findsOneWidget);

    api.gate!.complete();
    await tester.pumpAndSettle();
    expect(h.result, isTrue);
    expect(api.deleteCalls, 1);
  });

  testWidgets('desktop confirmation is width-contained', (tester) async {
    final h = _Harness(_DeleteApi(), width: 1920);
    await h.pump(tester);
    await h.open(tester);
    final box = tester.getSize(_panel);
    expect(box.width, lessThanOrEqualTo(KubusDialogSize.compact.maxWidth));
  });

  testWidgets('mobile confirmation uses the available width', (tester) async {
    final h = _Harness(_DeleteApi(), width: 320);
    await h.pump(tester);
    await h.open(tester);
    final box = tester.getSize(_panel);
    expect(box.width, greaterThan(250));
    expect(box.width, lessThanOrEqualTo(320));
  });

  test('deleteCommunityPost surfaces the HTTP status', () async {
    final api = BackendApiService();
    api.setAuthTokenForTesting(null);
    for (final status in <int>[200, 204]) {
      api.setHttpClient(MockClient((_) async => http.Response('', status)));
      await api.deleteCommunityPost('p');
    }
    for (final status in <int>[401, 403, 404, 409, 500]) {
      api.setHttpClient(
        MockClient((_) async => http.Response('{"success":false}', status)),
      );
      await expectLater(
        api.deleteCommunityPost('p'),
        throwsA(
          isA<BackendApiRequestException>()
              .having((e) => e.statusCode, 'statusCode', status),
        ),
      );
    }
  });

  test('classification maps statuses and transport errors', () {
    CommunityPostDeleteFailure? c(Object e) =>
        classifyCommunityPostDeleteError(e);
    BackendApiRequestException http(int s) =>
        BackendApiRequestException(statusCode: s, path: '/x');
    expect(c(http(404)), isNull);
    expect(c(http(401)), CommunityPostDeleteFailure.sessionExpired);
    expect(c(http(403)), CommunityPostDeleteFailure.notAllowed);
    expect(c(http(409)), CommunityPostDeleteFailure.conflict);
    expect(c(http(503)), CommunityPostDeleteFailure.server);
    expect(c(TimeoutException('x')), CommunityPostDeleteFailure.network);
    expect(c(StateError('boom')), CommunityPostDeleteFailure.server);
  });
}
