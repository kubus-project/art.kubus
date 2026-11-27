import 'dart:convert';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/screens/spatial/artwork_spatial_review_screen.dart';
import 'package:art_kubus/screens/spatial/artwork_spatial_source_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/account_session_fixture.dart';

void main() {
  final api = BackendApiService();
  const base = '/api/publications/spatial/drafts/artwork-1';
  const photo = 'file-photo';
  const clip = 'file-clip';

  Map<String, dynamic> file(String id, String name) => {
        'id': id,
        'fileName': name,
        'format': name.endsWith('.mp4') ? 'mp4' : 'jpeg',
        'sizeBytes': 10,
        'receivedBytes': 10,
        'sha256': id.padRight(64, 'a').substring(0, 64),
        'state': 'ready',
      };

  http.Response ok(Object data) =>
      http.Response(jsonEncode({'success': true, 'data': data}), 200);

  http.Response sources() => ok({
        'maxSourceBytes': 2147483648,
        'chunkSizeBytes': 4194304,
        'maxFiles': 256,
        'workspace': {
          'id': 'workspace-1',
          'revision': 4,
          'files': [file(photo, 'front.jpg'), file(clip, 'orbit.mp4')],
        },
      });

  Map<String, dynamic> attempt(String state,
          {Map<String, dynamic>? feedback, String? candidate}) =>
      {
        'id': 'attempt-1',
        'attempt': 1,
        'state': state,
        'stage': null,
        'cancelRequested': false,
        'problemCode': state == 'needs_more_views' ? 'sfm_failed' : null,
        'candidateDraftId': candidate,
        'feedback': feedback ?? const <String, dynamic>{},
      };

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
  }

  // Requests complete on real async work, as in the upload screen tests.
  Future<void> mount(WidgetTester tester, {String? posterUrl}) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ArtworkSpatialSourceScreen(
            artworkId: 'artwork-1', posterUrl: posterUrl),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await settle(tester);
  }

  // Unmounting cancels the status poll an active attempt schedules.
  Future<void> unmount(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox.shrink());

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    api.setAuthTokenForTesting(
        AccountSessionFixture.jwt(accountId: 'spatial-source-owner'));
  });

  tearDown(() => api.setAuthTokenForTesting(null));

  testWidgets('starts an attempt over the revision shown and locks the files',
      (tester) async {
    Map<String, dynamic>? current;
    Object? started;
    api.setHttpClient(MockClient((request) async {
      if (request.url.path == '$base/sources') return sources();
      if (request.url.path == '$base/reconstructions' &&
          request.method == 'POST') {
        started = jsonDecode(request.body);
        current = attempt('queued');
        return ok(current!);
      }
      expect(request.url.path, '$base/reconstructions');
      return ok({'remoteProcessingEnabled': true, 'reconstruction': current});
    }));
    await mount(tester);
    expect(find.textContaining('Free during the pilot'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Create reconstruction'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await settle(tester);
    expect(started, {'workspaceId': 'workspace-1', 'expectedRevision': 4});
    expect(find.text('Queued for processing.'), findsOneWidget);
    expect(find.text('Cancel reconstruction'), findsOneWidget);
    expect(find.text('Files are locked while a reconstruction runs.'),
        findsOneWidget);
    final choose = tester.widget<FilledButton>(find.ancestor(
        of: find.text('Choose files or resume upload'),
        matching: find.byWidgetPredicate((widget) => widget is FilledButton)));
    expect(choose.onPressed, isNull);
    await unmount(tester);
  });

  testWidgets('shows Waiting for a node while no provider has capacity',
      (tester) async {
    api.setHttpClient(
        MockClient((request) async => request.url.path.endsWith('/sources')
            ? sources()
            : ok({
                'remoteProcessingEnabled': true,
                'reconstruction': attempt('waiting_for_node'),
              })));
    await mount(tester);
    expect(find.textContaining('Waiting for a node'), findsOneWidget);
    expect(find.text('Create reconstruction'), findsNothing);
    await unmount(tester);
  });

  testWidgets('asks for more views and says which files were usable',
      (tester) async {
    api.setHttpClient(
        MockClient((request) async => request.url.path.endsWith('/sources')
            ? sources()
            : ok({
                'remoteProcessingEnabled': true,
                'reconstruction': attempt('needs_more_views', feedback: {
                  'usableViews': 12,
                  'requiredViews': 24,
                  'inputs': [
                    {'fileId': photo, 'usable': true, 'usableViews': 12},
                    {
                      'fileId': clip,
                      'usable': false,
                      'usableViews': 0,
                      'reason': 'frames_too_blurry',
                    },
                  ],
                }),
              })));
    await mount(tester);
    expect(find.textContaining('12 of the 24 needed'), findsOneWidget);
    expect(find.text('Add more views and retry'), findsOneWidget);
    expect(find.text('Usable views: 12'), findsOneWidget);
    expect(find.text('Not usable'), findsOneWidget);
    await unmount(tester);
  });

  for (final feedback in <Map<String, dynamic>>[
    // The backend sends no counts for an sfm_failed attempt.
    {
      'usableViews': null,
      'requiredViews': null,
      'inputs': [
        {'fileId': photo, 'usable': true, 'usableViews': 1},
        {'fileId': clip, 'usable': true, 'usableViews': 1},
      ],
    },
    // Only one of the two numbers is known: still no invented figure.
    {'usableViews': 3, 'requiredViews': null},
    {'usableViews': null, 'requiredViews': 24},
    const <String, dynamic>{},
  ]) {
    testWidgets('does not invent view counts when $feedback', (tester) async {
      api.setHttpClient(
          MockClient((request) async => request.url.path.endsWith('/sources')
              ? sources()
              : ok({
                  'remoteProcessingEnabled': true,
                  'reconstruction':
                      attempt('needs_more_views', feedback: feedback),
                })));
      await mount(tester);
      expect(find.textContaining('Too few views'), findsNothing);
      expect(find.textContaining('0 of the'), findsNothing);
      expect(find.textContaining('of the 24 needed'), findsNothing);
      expect(
        find.textContaining(
            'Add more photos or clips with good overlap, taken from different '
            'angles'),
        findsOneWidget,
      );
      expect(find.text('Add more views and retry'), findsOneWidget);
      await unmount(tester);
    });
  }

  testWidgets('the Slovenian generic copy appears when counts are null',
      (tester) async {
    api.setHttpClient(
        MockClient((request) async => request.url.path.endsWith('/sources')
            ? sources()
            : ok({
                'remoteProcessingEnabled': true,
                'reconstruction': attempt('needs_more_views'),
              })));
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('sl'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ArtworkSpatialSourceScreen(artworkId: 'artwork-1'),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await settle(tester);
    expect(find.textContaining('Dodaj več fotografij ali posnetkov'),
        findsOneWidget);
    expect(find.textContaining('0 od'), findsNothing);
    await unmount(tester);
  });

  testWidgets('renders kubus bold italic in the waiting status',
      (tester) async {
    api.setHttpClient(
        MockClient((request) async => request.url.path.endsWith('/sources')
            ? sources()
            : ok({
                'remoteProcessingEnabled': true,
                'reconstruction': attempt('waiting_for_node'),
              })));
    await mount(tester);
    final text = tester.widget<Text>(find.byWidgetPredicate((widget) =>
        widget is Text &&
        (widget.textSpan?.toPlainText() ?? '')
            .startsWith('Waiting for a node')));
    final brand = <TextSpan>[];
    text.textSpan!.visitChildren((span) {
      if (span is TextSpan && span.text == 'kubus') brand.add(span);
      return true;
    });
    expect(brand, hasLength(1));
    expect(brand.single.style?.fontStyle, FontStyle.italic);
    expect(brand.single.style?.fontWeight, FontWeight.w800);
    await unmount(tester);
  });

  for (final code in [
    'face_review_required',
    'provider_face_review_required'
  ]) {
    testWidgets('explains $code and marks the flagged file', (tester) async {
      final semantics = tester.ensureSemantics();
      api.setHttpClient(
          MockClient((request) async => request.url.path.endsWith('/sources')
              ? sources()
              : ok({
                  'remoteProcessingEnabled': true,
                  'reconstruction': {
                    ...attempt('needs_more_views', feedback: {
                      'inputs': [
                        {'fileId': photo, 'usable': true, 'usableViews': 3},
                        {
                          'fileId': clip,
                          'usable': false,
                          'reason': 'face_review',
                        },
                      ],
                    }),
                    'problemCode': code,
                  },
                })));
      await mount(tester);
      expect(find.textContaining("may show a person's face"), findsOneWidget);
      expect(find.textContaining('Too few views'), findsNothing);
      expect(find.text('May show a face'), findsOneWidget);
      expect(find.text('Usable views: 3'), findsOneWidget);
      expect(find.text('Not usable'), findsNothing);
      // The ListTile merges its subtree into one node, so the label is
      // asserted on the Semantics widget that carries it.
      expect(
          find.byWidgetPredicate((widget) =>
              widget is Semantics &&
              widget.properties.label ==
                  "orbit.mp4: may show a person's face. Remove or replace this file."),
          findsOneWidget);
      expect(find.text('Add more views and retry'), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
      semantics.dispose();
      await unmount(tester);
    });
  }

  testWidgets('failed attempt with provider face review offers a neutral retry',
      (tester) async {
    api.setHttpClient(
        MockClient((request) async => request.url.path.endsWith('/sources')
            ? sources()
            : ok({
                'remoteProcessingEnabled': true,
                'reconstruction': {
                  ...attempt('failed', feedback: {
                    'inputs': [
                      {
                        'fileId': clip,
                        'usable': false,
                        'reason': 'face_review',
                      },
                    ],
                  }),
                  'problemCode': 'provider_face_review_required',
                },
              })));
    await mount(tester);
    expect(find.textContaining("may show a person's face"), findsOneWidget);
    expect(find.textContaining('not sent'), findsNothing);
    expect(find.text('May show a face'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Add more views and retry'), findsNothing);
    await unmount(tester);
  });

  testWidgets('keeps the generic text for an unknown reason', (tester) async {
    api.setHttpClient(
        MockClient((request) async => request.url.path.endsWith('/sources')
            ? sources()
            : ok({
                'remoteProcessingEnabled': true,
                'reconstruction': attempt('needs_more_views', feedback: {
                  'inputs': [
                    {
                      'fileId': clip,
                      'usable': false,
                      'reason': 'something_new'
                    },
                  ],
                }),
              })));
    await mount(tester);
    // No counts were sent, so none are invented ("0 of the 24 needed").
    expect(find.textContaining('Too few views'), findsNothing);
    expect(find.textContaining('good overlap'), findsOneWidget);
    expect(find.text('Not usable'), findsOneWidget);
    expect(find.text('May show a face'), findsNothing);
    await unmount(tester);
  });

  testWidgets('keeps uploads available while remote processing is paused',
      (tester) async {
    api.setHttpClient(MockClient((request) async =>
        request.url.path.endsWith('/sources')
            ? sources()
            : ok({'remoteProcessingEnabled': false, 'reconstruction': null})));
    await mount(tester);
    expect(
        find.textContaining('Remote reconstruction is paused'), findsOneWidget);
    expect(find.text('Create reconstruction'), findsNothing);
    expect(find.text('Choose files or resume upload'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('opens a ready candidate for preview and submission',
      (tester) async {
    api.setHttpClient(MockClient((request) async {
      if (request.url.path.endsWith('/sources')) return sources();
      if (request.url.path.endsWith('/attempt-1/candidate')) {
        return ok({
          'id': 'draft-9',
          'artworkId': 'artwork-1',
          'origin': 'reconstruction',
          'fileName': 'reconstruction.ply',
          'format': 'ply',
          'sizeBytes': 64,
          'receivedBytes': 64,
          'sha256': 'b' * 64,
          'state': 'ready',
          'chunkSizeBytes': 4194304,
        });
      }
      if (request.url.path.endsWith('/reconstructions')) {
        return ok({
          'remoteProcessingEnabled': true,
          'reconstruction': attempt('ready', candidate: 'draft-9'),
        });
      }
      return http.Response('{}', 404);
    }));
    await mount(tester, posterUrl: 'https://example.test/cover.jpg');
    expect(find.textContaining('the published model does not change'),
        findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Preview and submit'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await settle(tester);
    expect(find.byType(ArtworkSpatialReviewScreen), findsOneWidget);
    // The artwork's poster travels with the candidate to the review screen, so
    // its viewer has something to show when the preview cannot load.
    expect(
        tester
            .widget<ArtworkSpatialReviewScreen>(
                find.byType(ArtworkSpatialReviewScreen))
            .posterUrl,
        'https://example.test/cover.jpg');
    await unmount(tester);
  });
}
