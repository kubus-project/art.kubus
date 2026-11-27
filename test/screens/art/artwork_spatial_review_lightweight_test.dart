import 'dart:convert';
import 'dart:typed_data';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/kubus_node_models.dart';
import 'package:art_kubus/models/spatial_upload_draft.dart';
import 'package:art_kubus/providers/kubus_node_provider.dart';
import 'package:art_kubus/screens/spatial/artwork_spatial_review_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/spatial_device_class.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/account_session_fixture.dart';

/// Stands in for the spatial viewer: it asks for the private bytes exactly as
/// the real viewer does and shows what came back.
class _FakeViewer extends StatefulWidget {
  const _FakeViewer({
    required this.content,
    required this.privateBytes,
    required this.poster,
  });

  final SpatialContent content;
  final Future<Uint8List> Function() privateBytes;
  final String? poster;

  @override
  State<_FakeViewer> createState() => _FakeViewerState();
}

class _FakeViewerState extends State<_FakeViewer> {
  String _text = 'loading';

  @override
  void initState() {
    super.initState();
    widget.privateBytes().then((bytes) {
      if (mounted) setState(() => _text = 'loaded ${bytes.length}');
    }, onError: (Object _) {
      if (mounted) setState(() => _text = 'viewer failed');
    });
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(_text),
        Text('poster ${widget.poster}'),
        Text('variant ${widget.content.variants.single.sizeBytes}'),
      ]);
}

void main() {
  final api = BackendApiService();
  // GET responses are reused by URL, so every test gets its own draft id.
  var runs = 0;
  late String draftId;
  String base() => '/api/publications/spatial/drafts/artwork-1/$draftId';
  final fullBytes = Uint8List.fromList(List<int>.filled(64, 1));
  final lightBytes = Uint8List.fromList(List<int>.filled(16, 2));

  String sha(Uint8List bytes) => crypto.sha256.convert(bytes).toString();

  Map<String, dynamic> draftJson(String id, Uint8List bytes) => {
        'id': id,
        'artworkId': 'artwork-1',
        'origin': 'reconstruction',
        'fileName': 'reconstruction.ply',
        'format': 'ply',
        'sizeBytes': bytes.length,
        'receivedBytes': bytes.length,
        'sha256': sha(bytes),
        'state': 'ready',
        'chunkSizeBytes': 4194304,
      };

  SpatialUploadDraft candidate({bool withLightweight = true}) =>
      SpatialUploadDraft.fromJson({
        ...draftJson(draftId, fullBytes),
        if (withLightweight)
          'lightweight': draftJson('$draftId-light', lightBytes),
      });

  http.Response ok(Object data) =>
      http.Response(jsonEncode({'success': true, 'data': data}), 200);

  final details = {
    'submission': null,
    'markers': <Object>[],
    'attributions': <Object>[],
    'artworkTitle': 'Mural',
    'ownerAccountId': 'owner-1',
    'requiredScopes': <String, Object>{},
    'grant': null,
  };

  late List<Uri> previews;
  var failPreview = false;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // A fresh credential store per test, so one test's pending storage read
    // cannot hold up the next test's requests.
    api.resetCredentialStoreForTesting();
    api.setAuthTokenForTesting(
        AccountSessionFixture.jwt(accountId: 'review-owner'));
    draftId = 'draft-${runs++}';
    previews = <Uri>[];
    failPreview = false;
    api.setHttpClient(MockClient((request) async {
      if (request.url.path == '${base()}/submission') return ok(details);
      if (request.url.path == '${base()}/preview') {
        previews.add(request.url);
        if (failPreview) return http.Response('nope', 500);
        return http.Response.bytes(
          request.url.queryParameters['variant'] == 'lightweight'
              ? lightBytes
              : fullBytes,
          200,
        );
      }
      return http.Response('{}', 404);
    }));
  });

  tearDown(() {
    api.setAuthTokenForTesting(null);
    SpatialDeviceClass.debugSignals = null;
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
  }

  Future<void> mount(WidgetTester tester, SpatialUploadDraft draft) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChangeNotifierProvider<KubusNodeProvider?>.value(
          value: KubusNodeProvider(),
          child: ArtworkSpatialReviewScreen(
            draft: draft,
            posterUrl: 'https://example.test/poster.jpg',
            viewerBuilder: (content, node, privateBytes, poster) => _FakeViewer(
                content: content, privateBytes: privateBytes, poster: poster),
          ),
        ),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await settle(tester);
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text(text));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox.shrink());

  testWidgets(
      'a constrained device previews the lightweight and loads the full on '
      'request', (tester) async {
    SpatialDeviceClass.debugSignals =
        const SpatialDeviceSignals(nativeMobile: true);
    await mount(tester, candidate());
    await tapText(tester, 'Open private preview');

    expect(previews.single.queryParameters['variant'], 'lightweight');
    expect(find.text('loaded 16'), findsOneWidget);
    expect(find.text('variant 16'), findsOneWidget);
    expect(find.text('poster https://example.test/poster.jpg'), findsOneWidget);
    expect(find.text('Showing a lighter preview suited to this device.'),
        findsOneWidget);
    expect(find.textContaining('Load full quality'), findsOneWidget);

    await tapText(tester, 'Load full quality (64 B)');

    expect(previews, hasLength(2));
    expect(previews.last.queryParameters.containsKey('variant'), isFalse);
    expect(find.text('loaded 64'), findsOneWidget);
    expect(find.textContaining('Load full quality'), findsNothing);
    expect(find.text('Showing a lighter preview suited to this device.'),
        findsNothing);
    await unmount(tester);
  });

  testWidgets('a desktop device previews the full file straight away',
      (tester) async {
    SpatialDeviceClass.debugSignals =
        const SpatialDeviceSignals(viewportWidth: 1440, deviceMemoryGb: 8);
    await mount(tester, candidate());
    await tapText(tester, 'Open private preview');

    expect(previews.single.queryParameters.containsKey('variant'), isFalse);
    expect(find.text('loaded 64'), findsOneWidget);
    expect(find.textContaining('Load full quality'), findsNothing);
    await unmount(tester);
  });

  testWidgets(
      'without a lightweight a constrained device keeps today\'s '
      'behaviour', (tester) async {
    SpatialDeviceClass.debugSignals =
        const SpatialDeviceSignals(nativeMobile: true);
    await mount(tester, candidate(withLightweight: false));
    await tapText(tester, 'Open private preview');

    expect(previews.single.queryParameters.containsKey('variant'), isFalse);
    expect(find.text('loaded 64'), findsOneWidget);
    expect(find.textContaining('Load full quality'), findsNothing);
    await unmount(tester);
  });

  testWidgets(
      'a failed preview leaves a clear state and the full-quality '
      'action', (tester) async {
    SpatialDeviceClass.debugSignals =
        const SpatialDeviceSignals(nativeMobile: true);
    failPreview = true;
    await mount(tester, candidate());
    await tapText(tester, 'Open private preview');

    expect(find.text('viewer failed'), findsOneWidget);
    expect(find.text('The preview could not be loaded. You can try again.'),
        findsOneWidget);
    expect(find.text('poster https://example.test/poster.jpg'), findsOneWidget);

    failPreview = false;
    await tapText(tester, 'Load full quality (64 B)');
    expect(find.text('loaded 64'), findsOneWidget);
    expect(find.text('The preview could not be loaded. You can try again.'),
        findsNothing);
    await unmount(tester);
  });
}
