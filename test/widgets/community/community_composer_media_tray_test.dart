import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:art_kubus/community/community_composer_media.dart';
import 'package:art_kubus/community/community_post_text_limits.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/widgets/community/community_composer_character_counter.dart';
import 'package:art_kubus/widgets/community/community_composer_media_tray.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

final AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));

CommunityComposerPickedMedia _image(String name) =>
    CommunityComposerPickedMedia(
      file: XFile.fromData(_png, path: name, mimeType: 'image/png'),
      kind: CommunityComposerMediaKind.image,
      imageBytes: _png,
    );

CommunityComposerPickedMedia _video(String name) =>
    CommunityComposerPickedMedia(
      file: XFile.fromData(
        Uint8List.fromList(<int>[0, 0, 0]),
        path: name,
        mimeType: 'video/mp4',
      ),
      kind: CommunityComposerMediaKind.video,
    );

Widget _harness(CommunityComposerMediaController controller) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 420,
          child: CommunityComposerMediaTray(
            controller: controller,
            onAddPhotos: () {},
            onAddVideo: () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('empty composer shows the zero count and both add actions',
      (tester) async {
    final controller = CommunityComposerMediaController();
    await tester.pumpWidget(_harness(controller));

    expect(find.text('0 of 10 selected'), findsOneWidget);
    expect(find.text(_l10n.communityComposerMediaAddPhotos), findsOneWidget);
    expect(find.text(_l10n.communityComposerMediaAddVideo), findsOneWidget);
    expect(find.byTooltip(_l10n.commonRemove), findsNothing);
  });

  testWidgets('lists images and videos in order with a running count',
      (tester) async {
    final controller = CommunityComposerMediaController()
      ..add([_image('one.png'), _video('clip.mp4'), _image('two.png')]);
    await tester.pumpWidget(_harness(controller));
    await tester.pumpAndSettle();

    expect(find.text('3 of 10 selected'), findsOneWidget);
    expect(find.byTooltip(_l10n.commonRemove), findsNWidgets(3));
    expect(find.text('clip.mp4'), findsOneWidget);
  });

  testWidgets('removing an item updates the composer', (tester) async {
    final controller = CommunityComposerMediaController()
      ..add([_image('one.png'), _image('two.png')]);
    await tester.pumpWidget(_harness(controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(_l10n.commonRemove).first);
    await tester.pumpAndSettle();

    expect(controller.length, 1);
    expect(controller.items.single.name, 'two.png');
    expect(find.text('1 of 10 selected'), findsOneWidget);
  });

  testWidgets('move-later nudges an item one place down the order',
      (tester) async {
    final controller = CommunityComposerMediaController()
      ..add([_image('first.png'), _image('second.png'), _image('third.png')]);
    await tester.pumpWidget(_harness(controller));
    await tester.pumpAndSettle();

    await tester
        .tap(find.byTooltip(_l10n.communityComposerMediaMoveLater).first);
    await tester.pumpAndSettle();

    expect(
      controller.items.map((item) => item.name).toList(),
      ['second.png', 'first.png', 'third.png'],
    );
  });

  testWidgets('a full composer shows the limit and disables adding',
      (tester) async {
    final controller = CommunityComposerMediaController()
      ..add([for (var i = 0; i < 10; i++) _image('img$i.png')]);
    await tester.pumpWidget(_harness(controller));
    await tester.pumpAndSettle();

    expect(find.text('10 of 10 selected'), findsOneWidget);
    expect(
      find.text(_l10n.communityComposerMediaLimitReached(10)),
      findsOneWidget,
    );
    final photosButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, _l10n.communityComposerMediaAddPhotos),
    );
    final videoButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, _l10n.communityComposerMediaAddVideo),
    );
    expect(photosButton.onPressed, isNull);
    expect(videoButton.onPressed, isNull);
  });

  testWidgets('the add actions call back when the composer has room',
      (tester) async {
    var photos = 0;
    var videos = 0;
    final controller = CommunityComposerMediaController();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: CommunityComposerMediaTray(
            controller: controller,
            onAddPhotos: () => photos++,
            onAddVideo: () => videos++,
          ),
        ),
      ),
    );

    await tester.tap(find.text(_l10n.communityComposerMediaAddPhotos));
    await tester.tap(find.text(_l10n.communityComposerMediaAddVideo));
    await tester.pump();

    expect(photos, 1);
    expect(videos, 1);
  });

  testWidgets(
      'a delayed create keeps every media control locked until it settles',
      (tester) async {
    final controller = CommunityComposerMediaController()
      ..add([_image('one.png'), _image('two.png')]);
    final create = Completer<String>();
    final publishing = controller.publish<String>(
      upload: (item) async => '/uploads/${item.name}',
      submit: (urls) => create.future,
    );
    await tester.pumpWidget(_harness(controller));
    await tester.pump();

    // Every upload has finished; only the create call is still running.
    expect(controller.uploadedUrls, hasLength(2));
    expect(_tileButtons(tester).every((button) => button.onPressed == null),
        isTrue);
    expect(
      tester
          .widget<TextButton>(_addButton(_l10n.communityComposerMediaAddPhotos))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(_addButton(_l10n.communityComposerMediaAddVideo))
          .onPressed,
      isNull,
    );

    create.complete('post-1');
    await publishing;
    await tester.pump();

    expect(find.text('0 of 10 selected'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(_addButton(_l10n.communityComposerMediaAddPhotos))
          .onPressed,
      isNotNull,
    );
  });

  counterTests();
}

Finder _addButton(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(TextButton));

Iterable<IconButton> _tileButtons(WidgetTester tester) =>
    tester.widgetList<IconButton>(find.byType(IconButton));

// The counter sits under the same composer text field, so it is covered here.
void counterTests() {
  testWidgets('character counter is silent until the text nears the limit',
      (tester) async {
    final controller = TextEditingController(text: 'short post');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: CommunityComposerCharacterCounter(controller: controller),
        ),
      ),
    );
    expect(find.textContaining('characters left'), findsNothing);

    controller.text = 'a' * (kCommunityPostMaxCharacters - 50);
    await tester.pump();
    expect(find.text('50 characters left'), findsOneWidget);

    controller.text = 'a' * (kCommunityPostMaxCharacters + 1);
    await tester.pump();
    expect(
      find.text(_l10n.communityComposerCharacterLimitExceeded(
          kCommunityPostMaxCharacters)),
      findsOneWidget,
    );
  });
}
