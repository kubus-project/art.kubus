import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/screens/community/community_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/socket_service.dart';
import 'package:art_kubus/widgets/community/community_composer_media_tray.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
// ignore: depend_on_referenced_packages
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/product_surface_harness.dart';
import '../support/product_v5_qa_fixtures.dart';

/// Mock-authenticated integration test of the real mobile Community composer.
///
/// Authentication uses two seams that already exist: `ProfileProvider
/// .setCurrentUser` and `BackendApiService.setAuthTokenForTesting`. The HTTP
/// client and the platform image picker are faked. This is not browser QA and
/// does not prove a real session works. It proves the composer's publish flow
/// against scripted API behaviour.
/// Multi-item tests describe the enabled mode. Under
/// `--dart-define=COMMUNITY_MULTI_MEDIA_ENABLED=false` they are skipped, and
/// the single-attachment test below runs instead.
final bool _skipUnlessMulti = !AppConfig.enableCommunityMultiMedia;
final _l10n = lookupAppLocalizations(const Locale('en'));
final _wallet = qaOwner().walletAddress;

String _jwt() {
  String b64(Map<String, Object?> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp = DateTime.now().add(const Duration(hours: 1));
  return '${b64({'alg': 'none'})}.'
      '${b64({
        'walletAddress': _wallet,
        'exp': exp.millisecondsSinceEpoch ~/ 1000,
      })}.sig';
}

class _FakePicker extends ImagePickerPlatform {
  List<XFile> files = <XFile>[];

  /// image_picker routes a limit of one (one slot left, or the switch off)
  /// through the single-image call.
  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async =>
      files.isEmpty ? null : files.first;

  @override
  Future<List<XFile>> getMultiImageWithOptions({
    MultiImagePickerOptions options = const MultiImagePickerOptions(),
  }) async =>
      files;
}

final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

class _Api {
  /// Upload file names that must fail, with how many more times to fail.
  final Map<String, int> failUpload = <String, int>{};
  int createFailures = 0;
  Completer<void>? holdCreate;
  final List<String> uploads = <String>[];
  final List<Map<String, dynamic>> creates = <Map<String, dynamic>>[];
  int created = 0;

  http.StreamedResponse _json(int status, Object body) => http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(body))),
        status,
        headers: const {'content-type': 'application/json'},
      );

  Future<http.StreamedResponse> handle(
    http.BaseRequest request,
    http.ByteStream body,
  ) async {
    final path = request.url.path;
    final bytes = await body.toBytes();
    if (request.method == 'POST' && path == '/api/upload') {
      final text = latin1.decode(bytes);
      final match = RegExp(r'filename="([^"]+)"').firstMatch(text);
      final name = match!.group(1)!;
      final remaining = failUpload[name] ?? 0;
      if (remaining > 0) {
        failUpload[name] = remaining - 1;
        return _json(500, {'success': false, 'error': 'Upload failed'});
      }
      uploads.add(name);
      return _json(200, {
        'success': true,
        'data': {'relativeUrl': '/uploads/profiles/posts/$name'},
      });
    }
    if (request.method == 'POST' && path == '/api/community/posts') {
      final payload = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      creates.add(payload);
      await holdCreate?.future;
      if (createFailures > 0) {
        createFailures--;
        return _json(500, {'success': false, 'error': 'create failed'});
      }
      created++;
      return _json(201, {
        'success': true,
        'data': {
          'id': 'post-${creates.length}',
          'content': payload['content'],
          'postType': payload['postType'],
          'mediaUrls': payload['mediaUrls'],
          'createdAt': DateTime(2026, 10, 8).toIso8601String(),
          'author': {
            'walletAddress': _wallet,
            'username': 'ana_kovac',
            'displayName': 'Ana Kovač',
          },
          'stats': <String, dynamic>{},
        },
      });
    }
    return _json(200, {'success': true, 'data': <dynamic>[]});
  }
}

Future<void> _settle(WidgetTester tester, [int steps = 20]) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late _Api api;
  late _FakePicker picker;

  Future<void> openComposer(WidgetTester tester, int photoCount) async {
    picker.files = <XFile>[
      for (var i = 0; i < photoCount; i++)
        XFile.fromData(_png, path: 'photo-$i.png', mimeType: 'image/png'),
    ];
    final prior = FlutterError.onError;
    await pumpProductSurface(
      tester,
      child: const CommunityScreen(),
      signedInProfile: qaOwner(),
    );
    // The harness collects render errors; restore the handler so a failing
    // expect reports instead of hanging the test.
    FlutterError.onError = prior;
    await tester.tap(find.byType(FloatingActionButton).first);
    await _settle(tester);
    expect(find.text(_l10n.communityComposerTitle), findsOneWidget,
        reason:
            'the signed-in user reaches the composer, not the sign-in gate');
    await tester.tap(find.text(_l10n.communityComposerMediaAddPhotos).first);
    await _settle(tester);
  }

  Finder postButton() => find.widgetWithText(
      ElevatedButton, _l10n.communityComposerSubmitPostButton);

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{'wallet': _wallet});
    api = _Api();
    picker = _FakePicker();
    ImagePickerPlatform.instance = picker;
    BackendApiService()
      ..setHttpClient(MockClient.streaming(api.handle))
      ..setAuthTokenForTesting(_jwt());
  });

  tearDown(() => BackendApiService().setAuthTokenForTesting(null));

  Future<void> flush(WidgetTester tester) async {
    // The real providers open a socket and reconnect on a timer. Disconnect
    // after it has been created, then let the timers run out.
    for (var round = 0; round < 3; round++) {
      SocketService().disconnect();
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
    }
  }

  testWidgets('ten photos publish in order with one create request',
      (tester) async {
    await openComposer(tester, 10);
    expect(find.text('10 of 10 selected'), findsOneWidget);

    await tester.tap(postButton());
    await _settle(tester, 60);

    expect(api.creates, hasLength(1));
    expect(api.creates.single['mediaUrls'], [
      for (var i = 0; i < 10; i++) '/uploads/profiles/posts/photo-$i.png',
    ]);
    expect(api.creates.single['postType'], 'image');
    expect(api.creates.single['content'],
        _l10n.desktopCommunitySharedPhotoFallbackContent);
    await flush(tester);
  }, skip: _skipUnlessMulti, timeout: const Timeout(Duration(seconds: 120)));

  testWidgets('an eleventh photo is not added', (tester) async {
    await openComposer(tester, 11);
    expect(find.text('10 of 10 selected'), findsOneWidget);
    await flush(tester);
  }, skip: _skipUnlessMulti, timeout: const Timeout(Duration(seconds: 120)));

  testWidgets('a failed third upload keeps the draft and a retry resumes there',
      (tester) async {
    api.failUpload['photo-2.png'] =
        1000; // the client retries 5xx, so fail persistently
    await openComposer(tester, 5);

    await tester.tap(postButton());
    await _settle(tester, 60);

    expect(api.uploads, ['photo-0.png', 'photo-1.png']);
    expect(api.creates, isEmpty);
    expect(find.text('5 of 10 selected'), findsOneWidget);
    expect(find.text(_l10n.communityComposerTitle), findsOneWidget);

    api.failUpload.clear();
    await tester.tap(postButton());
    await _settle(tester, 60);

    expect(api.uploads, [for (var i = 0; i < 5; i++) 'photo-$i.png'],
        reason: 'photo-0 and photo-1 are not uploaded twice');
    expect(api.created, 1);
    expect(api.creates.single['mediaUrls'], [
      for (var i = 0; i < 5; i++) '/uploads/profiles/posts/photo-$i.png',
    ]);
    await flush(tester);
  }, skip: _skipUnlessMulti, timeout: const Timeout(Duration(seconds: 120)));

  testWidgets(
      'a failed create unlocks the composer and retry reuses every upload',
      (tester) async {
    api
      ..createFailures = 1000 // the client retries 5xx, so fail persistently
      ..holdCreate = Completer<void>();
    await openComposer(tester, 3);

    await tester.tap(postButton());
    await _settle(tester, 30);

    // Uploads done, create pending: the tray is locked.
    expect(api.uploads, hasLength(3));
    expect(api.creates, hasLength(1));
    final tray = find.byType(CommunityComposerMediaTray);
    final buttons = tester.widgetList<IconButton>(
      find.descendant(of: tray, matching: find.byType(IconButton)),
    );
    expect(buttons, isNotEmpty);
    expect(buttons.every((b) => b.onPressed == null), isTrue);

    api.holdCreate!.complete();
    await _settle(tester, 30);

    expect(find.text('3 of 10 selected'), findsOneWidget,
        reason: 'the draft survives a failed create');
    final unlocked = tester.widgetList<IconButton>(
      find.descendant(of: tray, matching: find.byType(IconButton)),
    );
    expect(unlocked.any((b) => b.onPressed != null), isTrue);

    expect(api.created, 0);
    api
      ..holdCreate = null
      ..createFailures = 0;
    await tester.tap(postButton());
    await _settle(tester, 60);

    expect(api.uploads, hasLength(3), reason: 'no upload is repeated');
    expect(api.created, 1, reason: 'exactly one post is finally created');
    expect(api.creates.last['mediaUrls'], api.creates.first['mediaUrls']);
    await flush(tester);
  }, skip: _skipUnlessMulti, timeout: const Timeout(Duration(seconds: 120)));

  testWidgets('a double tap sends exactly one create request', (tester) async {
    await openComposer(tester, 2);

    await tester.tap(postButton());
    await tester.tap(postButton(), warnIfMissed: false);
    await _settle(tester, 60);

    expect(api.creates, hasLength(1));
    expect(api.uploads, hasLength(2));
    await flush(tester);
  }, skip: _skipUnlessMulti, timeout: const Timeout(Duration(seconds: 120)));
  testWidgets('the sheet closes when idle and stays open while publishing',
      (tester) async {
    api.holdCreate = Completer<void>();
    await openComposer(tester, 2);

    await tester.tap(postButton());
    await _settle(tester, 30);
    expect(api.creates, hasLength(1), reason: 'create is pending');

    await tester.tap(find.byTooltip(_l10n.commonClose));
    await _settle(tester);
    expect(find.text(_l10n.communityComposerTitle), findsOneWidget,
        reason: 'close is refused while the post is being sent');

    api.holdCreate!.complete();
    await _settle(tester, 60);
    expect(api.created, 1);
    expect(find.text(_l10n.communityComposerTitle), findsNothing,
        reason: 'the sheet closes itself after a successful post');

    await tester.tap(find.byType(FloatingActionButton).first);
    await _settle(tester);
    expect(find.text(_l10n.communityComposerTitle), findsOneWidget);
    await tester.tap(find.byTooltip(_l10n.commonClose));
    await _settle(tester);
    expect(find.text(_l10n.communityComposerTitle), findsNothing,
        reason: 'an idle composer can always be closed');
    await flush(tester);
  }, skip: _skipUnlessMulti, timeout: const Timeout(Duration(seconds: 120)));
  testWidgets(
      'with multi-media off, one attachment publishes and a second is refused',
      (tester) async {
    await openComposer(tester, 3);
    expect(find.text('1 of 1 selected'), findsOneWidget);

    await tester.tap(postButton());
    await _settle(tester, 60);

    expect(api.created, 1);
    expect(api.creates.single['mediaUrls'],
        ['/uploads/profiles/posts/photo-0.png']);
    await flush(tester);
  },
      skip: AppConfig.enableCommunityMultiMedia,
      timeout: const Timeout(Duration(seconds: 120)));
}
