import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:art_kubus/community/community_composer_media.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/widgets/community/community_composer_media_tray.dart';
import 'package:art_kubus/screens/community/community_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/socket_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/product_surface_harness.dart';
import '../support/product_v5_qa_fixtures.dart';
import '../support/qa_font_loader.dart';

/// Opt-in screenshot QA of the real mobile Community composer.
///
/// ```
/// KUBUS_RUN_VISUAL_QA=1 flutter test test/qa/community_composer_visual_test.dart
/// ```
///
/// Authentication is the harness's ordinary `ProfileProvider.setCurrentUser`
/// seam. Only the platform image picker is faked. Output: output/qa/community-composer/.
class _FakePicker extends ImagePickerPlatform {
  _FakePicker(this.files);
  List<XFile> files;

  @override
  Future<List<XFile>> getMultiImageWithOptions({
    MultiImagePickerOptions options = const MultiImagePickerOptions(),
  }) async =>
      files;
}

Future<Uint8List> _swatch(WidgetTester tester, Color color) async {
  late Uint8List bytes;
  await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 160, 120),
      Paint()..color = Color(color.toARGB32()),
    );
    final image = await recorder.endRecording().toImage(160, 120);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    bytes = data!.buffer.asUint8List();
  });
  return bytes;
}

Future<void> _shot(WidgetTester tester, String name) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
  final boundary = tester.binding.rootElement!.renderObject!;
  final layer = boundary.debugLayer! as OffsetLayer;
  await tester.runAsync(() async {
    final image = await layer.toImage(boundary.paintBounds);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File('output/qa/community-composer/$name.png')
        .writeAsBytesSync(data!.buffer.asUint8List());
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (Platform.environment['KUBUS_RUN_VISUAL_QA'] != '1') {
    test('composer visual QA is opt-in', () {},
        skip: 'Set KUBUS_RUN_VISUAL_QA=1 to generate screenshots.');
    return;
  }

  setUpAll(() async {
    await QaFontLoader.ensureLoaded();
    Directory('output/qa/community-composer').createSync(recursive: true);
  });
  final wallet = qaOwner().walletAddress;
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{'wallet': wallet});
    String b64(Map<String, Object?> m) =>
        base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
    BackendApiService().setAuthTokenForTesting(
      '${b64({'alg': 'none'})}.${b64({
            'walletAddress': wallet,
            'exp': 4102444800
          })}.sig',
    );
  });
  tearDown(() => BackendApiService().setAuthTokenForTesting(null));

  for (final scene in const [
    (
      name: 'mobile-390-light-en',
      size: Size(390, 844),
      dark: false,
      lang: 'en',
      scale: 1.0
    ),
    (
      name: 'mobile-320-dark-sl',
      size: Size(320, 640),
      dark: true,
      lang: 'sl',
      scale: 1.0
    ),
    (
      name: 'mobile-390-light-en-x15',
      size: Size(390, 844),
      dark: false,
      lang: 'en',
      scale: 1.5
    ),
  ]) {
    testWidgets('composer ${scene.name}', (tester) async {
      final colors = List<Color>.filled(11, Colors.teal);
      final files = <XFile>[];
      for (var i = 0; i < colors.length; i++) {
        files.add(XFile.fromData(await _swatch(tester, colors[i]),
            path: 'photo-$i.png', mimeType: 'image/png'));
      }
      final picker = _FakePicker(files);
      ImagePickerPlatform.instance = picker;

      final errors = await pumpProductSurface(
        tester,
        child: const CommunityScreen(),
        size: scene.size,
        brightness: scene.dark ? Brightness.dark : Brightness.light,
        locale: Locale(scene.lang),
        textScale: scene.scale,
        signedInProfile: qaOwner(),
      );
      await _shot(tester, '${scene.name}-01-feed');

      await tester.tap(find.byType(FloatingActionButton).first);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      final l10n = lookupAppLocalizations(Locale(scene.lang));
      await _shot(tester, '${scene.name}-02-composer-open');

      final add = find.text(l10n.communityComposerMediaAddPhotos);
      if (add.evaluate().isNotEmpty) {
        await tester.tap(add.first);
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 300));
        }
        await _shot(tester, '${scene.name}-03-ten-selected');
      }
      // ignore: avoid_print
      print('${scene.name}: render errors = ${errors.toSet().toList()}');
      for (var round = 0; round < 3; round++) {
        SocketService().disconnect();
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
      }
    }, timeout: const Timeout(Duration(seconds: 150)));
  }
  // The tray in every state the composer can show, on its own. Thumbnails are
  // generated colour swatches; videos use the tile's placeholder.
  for (final scene in const [
    (
      name: 'tray-390-light-en',
      width: 390.0,
      dark: false,
      lang: 'en',
      scale: 1.0
    ),
    (
      name: 'tray-320-dark-sl-x2',
      width: 320.0,
      dark: true,
      lang: 'sl',
      scale: 2.0
    ),
    (
      name: 'tray-1440-light-en',
      width: 1440.0,
      dark: false,
      lang: 'en',
      scale: 1.0
    ),
  ]) {
    testWidgets('tray ${scene.name}', (tester) async {
      Future<CommunityComposerPickedMedia> image(int i) async =>
          CommunityComposerPickedMedia(
            file: XFile.fromData(await _swatch(tester, Colors.teal),
                path: 'photo-$i.png', mimeType: 'image/png'),
            kind: CommunityComposerMediaKind.image,
            imageBytes: await _swatch(tester, Colors.teal),
          );
      CommunityComposerPickedMedia video(int i) => CommunityComposerPickedMedia(
            file: XFile.fromData(Uint8List.fromList([0, 0, 0]),
                path: 'clip-$i.mp4', mimeType: 'video/mp4'),
            kind: CommunityComposerMediaKind.video,
          );

      // A: ten items. Items 0-1 uploaded, 2 uploading, the rest pending. Locked.
      final sending = CommunityComposerMediaController();
      sending.add([
        for (var i = 0; i < 10; i++)
          i == 4 || i == 8 ? video(i) : await image(i),
      ]);
      final hold = Completer<String>();
      unawaited(sending.publish<void>(
        upload: (item) => item.name == 'photo-2.png'
            ? hold.future
            : Future.value('/u/${item.name}'),
        submit: (_) async {},
      ));
      // B: five items, the third upload failed. Unlocked.
      final failed = CommunityComposerMediaController();
      failed.add([for (var i = 0; i < 5; i++) await image(i)]);
      await failed
          .publish<void>(
            upload: (item) async => item.name == 'photo-2.png'
                ? throw StateError('failed')
                : '/u/${item.name}',
            submit: (_) async {},
          )
          .catchError((Object _) {});

      tester.view.physicalSize =
          Size(scene.width, scene.scale > 1 ? 1100 : 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: scene.dark ? ThemeData.dark() : ThemeData.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale(scene.lang),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scene.scale)),
          child: child!,
        ),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CommunityComposerMediaTray(
                    controller: sending, onAddPhotos: () {}, onAddVideo: () {}),
                const SizedBox(height: 32),
                CommunityComposerMediaTray(
                    controller: failed, onAddPhotos: () {}, onAddVideo: () {}),
              ],
            ),
          ),
        ),
      ));
      await _shot(tester, '${scene.name}-uploading-locked-and-failed');
      hold.complete('/u/photo-2.png');
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
    });
  }
}
