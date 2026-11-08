import 'dart:convert';
import 'dart:typed_data';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/l10n/app_localizations_en.dart';
import 'package:art_kubus/models/map_marker_subject.dart';
import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/utils/map_marker_subject_loader.dart';
import 'package:art_kubus/widgets/forms/kubus_form.dart';
import 'package:art_kubus/widgets/map/panels/kubus_marker_form_content.dart';
import 'package:art_kubus/widgets/map_marker_dialog.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';

/// "I am the creator" on the street-art marker form, mirroring the artwork
/// create and edit forms: the box fills the artist field with the signed-in
/// profile name, makes it read-only, and only then does the result carry the
/// bare `authoredBySelf` flag.
const _profileId = '8c03b35a-a4d6-4c08-95fc-503c879fbc45';

final _l10n = AppLocalizationsEn();

ProfileProvider _signedIn({String displayName = 'Damjan Stevovic'}) =>
    ProfileProvider()
      ..setCurrentUser(
        UserProfile(
          id: _profileId,
          // Walletless: the declaration speaks for the account, not a wallet.
          walletAddress: '',
          username: 'damjan_stevovic',
          displayName: displayName,
          bio: '',
          avatar: '',
          createdAt: DateTime(2020),
          updatedAt: DateTime(2020),
        ),
      );

/// A decodable 1x1 PNG: the form previews the picked cover.
final Uint8List _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

class _PickedCover extends FilePicker with MockPlatformInterfaceMixin {
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    dynamic onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    return FilePickerResult([
      PlatformFile(
        name: 'cover.png',
        size: _onePixelPng.length,
        bytes: _onePixelPng,
      ),
    ]);
  }
}

Future<void> _open(
  WidgetTester tester, {
  required ProfileProvider? profile,
  required List<MapMarkerFormResult> submitted,
}) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  FilePicker.platform = _PickedCover();

  Widget scope(Widget child) => profile == null
      ? child
      : ChangeNotifierProvider<ProfileProvider>.value(
          value: profile,
          child: child,
        );

  await tester.pumpWidget(
    scope(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: KubusMarkerFormContent(
            subjectData: const MarkerSubjectData(
              artworks: [],
              exhibitions: [],
              institutions: [],
              events: [],
              delegates: [],
            ),
            onRefreshSubjects: ({bool force = false}) async => null,
            initialPosition: const LatLng(46.05, 14.5),
            initialSubjectType: MarkerSubjectType.streetArt,
            allowedSubjectTypes: const {MarkerSubjectType.streetArt},
            showHeader: false,
            onSubmit: submitted.add,
            onCancel: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

/// The field framed by [label] (the label is a separate frame text, not an
/// input decoration).
Finder _field(String label) => find.descendant(
      of: find.byWidgetPredicate(
        (widget) => widget is KubusFieldFrame && widget.label == label,
      ),
      matching: find.byType(TextFormField),
    );

Future<void> _fillRequired(WidgetTester tester) async {
  await tester.enterText(_field(_l10n.mapMarkerDialogMarkerTitleLabel), 'Fox');
  await tester.enterText(
    _field(_l10n.mapMarkerDialogDescriptionLabel),
    'A fox painted on the river wall.',
  );
  await tester.enterText(
    _field(_l10n.mapMarkerDialogImageAuthorLabel),
    'Photographer',
  );
  await tester.enterText(
    _field(_l10n.mapMarkerDialogImageLicenseLabel),
    'CC BY 4.0',
  );
  await tester.tap(find.text(_l10n.mapMarkerDialogUploadCover));
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _submit(WidgetTester tester) async {
  final button = find.text(_l10n.mapMarkerDialogCreateButton);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump(const Duration(milliseconds: 100));
}

Finder get _toggle => find.text(_l10n.artworkAuthoredBySelfLabel);

bool _checked(WidgetTester tester) =>
    tester.widget<Checkbox>(find.byType(Checkbox)).value ?? false;

bool _artistReadOnly(WidgetTester tester) => tester
    .widget<TextField>(
      find.descendant(
        of: _field(_l10n.mapMarkerDialogArtistNameLabel),
        matching: find.byType(TextField),
      ),
    )
    .readOnly;

void main() {
  testWidgets('ticking fills the artist field, locks it and sends the flag',
      (tester) async {
    final submitted = <MapMarkerFormResult>[];
    await _open(tester, profile: _signedIn(), submitted: submitted);

    expect(_checked(tester), isFalse);
    expect(_artistReadOnly(tester), isFalse);

    await tester.ensureVisible(_toggle);
    await tester.tap(_toggle);
    await tester.pump();

    expect(_checked(tester), isTrue);
    expect(_artistReadOnly(tester), isTrue);
    expect(find.text('Damjan Stevovic'), findsOneWidget);

    await _fillRequired(tester);
    await _submit(tester);

    expect(submitted, hasLength(1));
    expect(submitted.single.authoredBySelf, isTrue);
    expect(submitted.single.artistName, 'Damjan Stevovic');
    expect(submitted.single.subjectType, MarkerSubjectType.streetArt);
  });

  testWidgets('unticking makes the field editable and drops the flag',
      (tester) async {
    final submitted = <MapMarkerFormResult>[];
    await _open(tester, profile: _signedIn(), submitted: submitted);

    await tester.ensureVisible(_toggle);
    await tester.tap(_toggle);
    await tester.pump();
    await tester.tap(_toggle);
    await tester.pump();

    expect(_checked(tester), isFalse);
    expect(_artistReadOnly(tester), isFalse);

    await _fillRequired(tester);
    await _submit(tester);

    expect(submitted, hasLength(1));
    expect(submitted.single.authoredBySelf, isFalse);
  });

  testWidgets('an untouched box sends no declaration', (tester) async {
    final submitted = <MapMarkerFormResult>[];
    await _open(tester, profile: _signedIn(), submitted: submitted);

    await _fillRequired(tester);
    await tester.enterText(
      _field(_l10n.mapMarkerDialogArtistNameLabel),
      'Somebody else',
    );
    await _submit(tester);

    expect(submitted.single.authoredBySelf, isFalse);
    expect(submitted.single.artistName, 'Somebody else');
  });

  testWidgets('a guest or a profile without a name cannot tick it',
      (tester) async {
    for (final profile in <ProfileProvider?>[
      null,
      _signedIn(displayName: ' '),
    ]) {
      final submitted = <MapMarkerFormResult>[];
      await _open(tester, profile: profile, submitted: submitted);

      await tester.ensureVisible(_toggle);
      await tester.tap(_toggle);
      await tester.pump();

      expect(_checked(tester), isFalse);
      expect(_artistReadOnly(tester), isFalse);
      expect(find.text(_l10n.artworkAuthoredBySelfUnavailable), findsOneWidget);

      await _fillRequired(tester);
      await _submit(tester);
      expect(submitted.single.authoredBySelf, isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
