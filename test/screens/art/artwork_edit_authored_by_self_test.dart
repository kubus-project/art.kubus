import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/providers/app_refresh_provider.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/collab_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/screens/art/artwork_edit_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

const _artworkId = 'artwork-1';
const _profileId = '8c03b35a-a4d6-4c08-95fc-503c879fbc45';
const _otherProfileId = '11111111-1111-4111-8111-111111111111';

Artwork _artwork({String? authorProfileId, String artist = 'Someone'}) =>
    Artwork(
      id: _artworkId,
      walletAddress: '0xabc',
      title: 'Original title',
      artist: artist,
      authorProfile: authorProfileId == null
          ? null
          : ArtworkAuthorProfile(
              profileId: authorProfileId,
              username: 'damjan_stevovic',
              displayName: 'Damjan Stevovic',
            ),
      description: 'Original description',
      position: const LatLng(46.05, 14.5),
      rewards: 0,
      createdAt: DateTime(2026, 1, 1),
    );

class _FakeApi implements ArtworkBackendApi {
  final List<Map<String, dynamic>> putBodies = <Map<String, dynamic>>[];

  @override
  Future<Artwork?> updateArtwork(
    String artworkId,
    Map<String, dynamic> updates,
  ) async {
    putBodies.add(Map<String, dynamic>.from(updates));
    return _artwork();
  }

  @override
  Future<Artwork> getArtwork(String artworkId) async => _artwork();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
        '${invocation.memberName} is not used by the save flow',
      );
}

ProfileProvider _signedInProfile({String displayName = 'Damjan Stevovic'}) {
  return ProfileProvider()
    ..setCurrentUser(
      UserProfile(
        id: _profileId,
        walletAddress: '0xabc',
        username: 'damjan_stevovic',
        displayName: displayName,
        bio: '',
        avatar: '',
        createdAt: DateTime(2020, 1, 1),
        updatedAt: DateTime(2020, 1, 1),
      ),
    );
}

/// The editor keeps ambient animations alive, so a bounded run of frames
/// replaces pumpAndSettle.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Route<void> _route(RouteSettings settings) => MaterialPageRoute<void>(
      builder: (_) => const Scaffold(
        body: ArtworkEditScreen(
          artworkId: _artworkId,
          chrome: ArtworkEditChrome.workspace,
        ),
      ),
    );

Future<_FakeApi> _open(
  WidgetTester tester, {
  required Artwork artwork,
  required ProfileProvider profile,
}) async {
  final api = _FakeApi();
  final artworks = ArtworkProvider(backendApi: api)
    ..addOrUpdateArtwork(artwork);
  // The collaboration sidebar overflows by a few pixels under the Ahem font;
  // that is a font-metrics artefact unrelated to authorship.
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.toString();
    if (text.contains('RenderFlex overflowed') && text.contains('inviteRole')) {
      return;
    }
    previous?.call(details);
  };
  addTearDown(() => FlutterError.onError = previous);

  tester.view.physicalSize = const Size(1440, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<ArtworkProvider>.value(value: artworks),
        ChangeNotifierProvider<ProfileProvider>.value(value: profile),
        ChangeNotifierProvider<AppRefreshProvider>(
          create: (_) => AppRefreshProvider(),
        ),
        ChangeNotifierProvider<CollabProvider>(create: (_) => CollabProvider()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Navigator(onGenerateRoute: _route),
      ),
    ),
  );
  await _settle(tester);
  return api;
}

Finder get _toggle => find.text('I am the creator');
Finder get _checkbox => find.byType(Checkbox);
Finder get _saveButton => find.widgetWithText(FilledButton, 'Save');

TextField _artistTextField(WidgetTester tester) {
  return tester.widget<TextField>(find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.labelText == 'Artist / author',
  ));
}

/// Runs [body], then unmounts the editor and lets any one-shot timer it started
/// (invite polling, profile hydration) fire so the test ends clean.
void _editorTest(
  String description,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(description, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(minutes: 2));
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  _editorTest(
      'an artwork attributed to the signed-in profile opens ticked with a '
      'read-only artist field', (tester) async {
    await _open(
      tester,
      artwork: _artwork(authorProfileId: _profileId),
      profile: _signedInProfile(),
    );
    expect(tester.widget<Checkbox>(_checkbox).value, isTrue);
    final field = _artistTextField(tester);
    expect(field.readOnly, isTrue);
    // The recorded cultural credit is shown as recorded, never replaced by the
    // profile's current display name.
    expect(field.controller!.text, 'Someone');
  });

  _editorTest(
      'a recorded pseudonym survives an unrelated save of a self-attributed '
      'artwork', (tester) async {
    final api = await _open(
      tester,
      artwork: _artwork(authorProfileId: _profileId, artist: 'turrdl'),
      profile: _signedInProfile(),
    );
    expect(tester.widget<Checkbox>(_checkbox).value, isTrue);
    expect(_artistTextField(tester).controller!.text, 'turrdl');
    await tester.enterText(
      find.widgetWithText(TextField, 'Original title'),
      'New title',
    );
    await tester.pump();
    await tester.ensureVisible(_saveButton);
    await tester.tap(_saveButton);
    await _settle(tester);

    expect(api.putBodies, hasLength(1));
    final body = api.putBodies.single;
    expect(body['title'], 'New title');
    expect(body.containsKey('artistName'), isFalse);
    expect(body.containsKey('authoredBySelf'), isFalse);
  });

  _editorTest(
      'a self-attributed artwork without a recorded name shows the profile '
      'name but does not write it on an unrelated save', (tester) async {
    final api = await _open(
      tester,
      artwork: _artwork(authorProfileId: _profileId, artist: ''),
      profile: _signedInProfile(),
    );
    expect(_artistTextField(tester).controller!.text, 'Damjan Stevovic');
    await tester.enterText(
      find.widgetWithText(TextField, 'Original title'),
      'New title',
    );
    await tester.pump();
    await tester.ensureVisible(_saveButton);
    await tester.tap(_saveButton);
    await _settle(tester);

    expect(api.putBodies, hasLength(1));
    expect(api.putBodies.single.containsKey('artistName'), isFalse);
  });

  _editorTest('an artwork attributed to someone else opens unticked',
      (tester) async {
    await _open(
      tester,
      artwork: _artwork(authorProfileId: _otherProfileId),
      profile: _signedInProfile(),
    );
    expect(tester.widget<Checkbox>(_checkbox).value, isFalse);
    final field = _artistTextField(tester);
    expect(field.readOnly, isFalse);
    expect(field.controller!.text, 'Someone');
  });

  _editorTest('ticking fills the profile name, locks the field and sends true',
      (tester) async {
    final api = await _open(
      tester,
      artwork: _artwork(),
      profile: _signedInProfile(),
    );
    await tester.ensureVisible(_toggle);
    await tester.tap(_toggle);
    await tester.pump();

    expect(tester.widget<Checkbox>(_checkbox).value, isTrue);
    final field = _artistTextField(tester);
    expect(field.readOnly, isTrue);
    expect(field.controller!.text, 'Damjan Stevovic');

    await tester.ensureVisible(_saveButton);
    await tester.tap(_saveButton);
    await _settle(tester);

    expect(api.putBodies, hasLength(1));
    final body = api.putBodies.single;
    expect(body['authoredBySelf'], isTrue);
    expect(body['artistName'], 'Damjan Stevovic');
    // No account identity is ever sent.
    for (final key in body.keys) {
      expect(key.toLowerCase(), isNot(contains('profile')));
      expect(key.toLowerCase(), isNot(contains('userid')));
      expect(key.toLowerCase(), isNot(contains('wallet')));
    }
    expect(body.values.map((v) => '$v'), isNot(contains(_profileId)));
  });

  _editorTest('unticking a previous declaration and saving sends false',
      (tester) async {
    final api = await _open(
      tester,
      artwork: _artwork(authorProfileId: _profileId, artist: 'Damjan Stevovic'),
      profile: _signedInProfile(),
    );
    await tester.ensureVisible(_toggle);
    await tester.tap(_toggle);
    await tester.pump();
    expect(tester.widget<Checkbox>(_checkbox).value, isFalse);
    expect(_artistTextField(tester).readOnly, isFalse);

    await tester.ensureVisible(_saveButton);
    await tester.tap(_saveButton);
    await _settle(tester);

    expect(api.putBodies, hasLength(1));
    expect(api.putBodies.single['authoredBySelf'], isFalse);
  });

  _editorTest('an untouched box sends no authoredBySelf entry', (tester) async {
    final api = await _open(
      tester,
      artwork: _artwork(authorProfileId: _profileId, artist: 'Damjan Stevovic'),
      profile: _signedInProfile(),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Original title'),
      'New title',
    );
    await tester.pump();
    await tester.ensureVisible(_saveButton);
    await tester.tap(_saveButton);
    await _settle(tester);

    expect(api.putBodies, hasLength(1));
    expect(api.putBodies.single.containsKey('authoredBySelf'), isFalse);
  });

  _editorTest('a profile without a display name cannot tick the box',
      (tester) async {
    await _open(
      tester,
      artwork: _artwork(),
      profile: _signedInProfile(displayName: '  '),
    );
    expect(tester.widget<Checkbox>(_checkbox).onChanged, isNull);
    await tester.ensureVisible(_toggle);
    await tester.tap(_toggle);
    await tester.pump();
    expect(tester.widget<Checkbox>(_checkbox).value, isFalse);
    expect(_artistTextField(tester).readOnly, isFalse);
    expect(
      find.textContaining('add a display name to your profile'),
      findsOneWidget,
    );
  });

  _editorTest('a guest cannot tick the box', (tester) async {
    await _open(tester, artwork: _artwork(), profile: ProfileProvider());
    expect(tester.widget<Checkbox>(_checkbox).onChanged, isNull);
    await tester.ensureVisible(_toggle);
    await tester.tap(_toggle);
    await tester.pump();
    expect(tester.widget<Checkbox>(_checkbox).value, isFalse);
  });
}
