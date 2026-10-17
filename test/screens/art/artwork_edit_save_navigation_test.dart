import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/l10n/app_localizations_en.dart';
import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/providers/app_refresh_provider.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/collab_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/screens/art/artwork_edit_screen.dart';
import 'package:art_kubus/screens/desktop/desktop_shell_scope.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';

/// Pressing Save on an existing artwork must leave the app usable.
///
/// The desktop editor is pushed into the shell's own screen stack
/// (`DesktopShellScope.pushScreen`), which is not a Navigator route. Closing it
/// with `Navigator.of(context).pop()` instead pops the route that hosts the
/// whole shell, so a successful save blanked the app (the owner-reported black
/// screen on dev.kubus.site). These tests press the real Save button and assert
/// on what is left on screen, in the shell stack and on the Navigator.

const _artworkId = 'artwork-1';
const _wallet = '0xabc';

Artwork _artwork({String title = 'Original title'}) => Artwork(
      id: _artworkId,
      walletAddress: _wallet,
      title: title,
      artist: 'Artist',
      description: 'Original description',
      position: const LatLng(46.05, 14.5),
      rewards: 0,
      createdAt: DateTime(2026, 1, 1),
    );

/// A deterministic [ArtworkBackendApi]. Every behaviour is a closure so each
/// test states exactly what the backend does.
class _FakeApi implements ArtworkBackendApi {
  final List<Map<String, dynamic>> putBodies = <Map<String, dynamic>>[];
  int getCalls = 0;

  FutureOr<Artwork?> Function(Map<String, dynamic> updates)? onUpdate;
  FutureOr<Artwork> Function()? onGet;

  @override
  Future<Artwork?> updateArtwork(
    String artworkId,
    Map<String, dynamic> updates,
  ) async {
    putBodies.add(Map<String, dynamic>.from(updates));
    final handler = onUpdate;
    if (handler == null) throw StateError('onUpdate not set');
    return handler(updates);
  }

  @override
  Future<Artwork> getArtwork(String artworkId) async {
    getCalls += 1;
    final handler = onGet;
    if (handler == null) throw StateError('onGet not set');
    return handler();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
        '${invocation.memberName} is not used by the save flow',
      );
}

class _Refresh extends AppRefreshProvider {
  int portfolioTriggers = 0;

  @override
  void triggerPortfolio({bool onlyIfActive = false}) {
    portfolioTriggers += 1;
    super.triggerPortfolio(onlyIfActive: onlyIfActive);
  }
}

class _Rig {
  _Rig() {
    artworks = ArtworkProvider(backendApi: api)..addOrUpdateArtwork(_artwork());
    profile = ProfileProvider()
      ..setCurrentUser(
        UserProfile(
          id: 'user-1',
          walletAddress: _wallet,
          username: 'user',
          displayName: 'User',
          bio: '',
          avatar: '',
          createdAt: DateTime(2020, 1, 1),
          updatedAt: DateTime(2020, 1, 1),
        ),
      );
  }

  final api = _FakeApi();
  final refresh = _Refresh();

  /// The collaboration sidebar's role dropdown overflows by a few pixels under
  /// the test-only Ahem font. That is a font-metrics artefact unrelated to
  /// saving, so it is the one layout error this rig lets through; every other
  /// framework error still fails the test.
  void tolerateCollabDropdownOverflow() {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.toString();
      if (text.contains('RenderFlex overflowed') &&
          text.contains('inviteRole')) {
        return;
      }
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);
  }

  late final ArtworkProvider artworks;
  late final ProfileProvider profile;

  Widget app(Widget home) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<ArtworkProvider>.value(value: artworks),
        ChangeNotifierProvider<ProfileProvider>.value(value: profile),
        ChangeNotifierProvider<AppRefreshProvider>.value(value: refresh),
        ChangeNotifierProvider<CollabProvider>(create: (_) => CollabProvider()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );
  }
}

/// Hands the editor one picked file. The upload that follows goes to the real
/// [BackendApiService], which under the test binding answers every request
/// with HTTP 400: a deterministic upload failure with no network.
final Uint8List _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

class _PickedFile extends FilePicker with MockPlatformInterfaceMixin {
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
        name: type == FileType.image ? 'picked.png' : 'picked.glb',
        size: _onePixelPng.length,
        // A decodable image: the editor previews the picked cover.
        bytes: _onePixelPng,
      ),
    ]);
  }
}

/// Mirrors the contract of `_DesktopShellState`: screens pushed through the
/// scope live in an in-shell stack, the shell itself is a single Navigator
/// route, and its `PopScope` only intercepts *system* back, never a
/// programmatic `Navigator.pop`.
class _ShellHost extends StatefulWidget {
  const _ShellHost({required this.seed});

  /// Screens already in the stack when the host first builds, bottom first.
  final List<Widget> seed;

  @override
  State<_ShellHost> createState() => _ShellHostState();
}

class _ShellHostState extends State<_ShellHost> {
  late final List<Widget> stack = List<Widget>.of(widget.seed);

  void push(Widget screen) => setState(() => stack.add(screen));

  void pop() {
    if (stack.isEmpty) return;
    setState(() => stack.removeLast());
  }

  /// Test seam: drop the top screen the way a user navigating away would.
  void removeTop() => pop();

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: stack.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) pop();
      },
      child: DesktopShellScope(
        pushScreen: push,
        popScreen: pop,
        navigateToRoute: (_) {},
        openNotifications: () {},
        openFunctionsPanel: (_, {content}) {},
        setFunctionsPanelContent: (_) {},
        closeFunctionsPanel: () {},
        canPop: stack.isNotEmpty,
        child: Scaffold(
          key: const ValueKey<String>('shell-scaffold'),
          body: stack.isEmpty
              ? const Center(child: Text('PORTFOLIO'))
              : stack.last,
        ),
      ),
    );
  }
}

/// Root route 'ROOT' -> pushes the shell host, like the app's home route.
class _Base extends StatelessWidget {
  const _Base({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => child),
          ),
          child: const Text('OPEN'),
        ),
      ),
    );
  }
}

/// An upload that fails the way the real one does after its retries.
Future<Map<String, dynamic>> _failingUpload({
  required List<int> fileBytes,
  required String fileName,
  required String fileType,
  Map<String, String>? metadata,
}) async {
  throw _http(503);
}

const _workspaceEditor = ArtworkEditScreen(
  artworkId: _artworkId,
  chrome: ArtworkEditChrome.workspace,
  uploadFile: _failingUpload,
);

/// The editor keeps a few ambient animations alive, so `pumpAndSettle` never
/// settles; a bounded run of frames is enough for every transition here.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _setSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _openWorkspaceEditor(
  WidgetTester tester,
  _Rig rig, {
  List<Widget> below = const <Widget>[],
}) async {
  rig.tolerateCollabDropdownOverflow();
  await _setSize(tester, const Size(1440, 900));
  await tester.pumpWidget(
    rig.app(
      _Base(
        child: _ShellHost(seed: <Widget>[...below, _workspaceEditor]),
      ),
    ),
  );
  await tester.tap(find.text('OPEN'));
  await _settle(tester);
  expect(find.byType(ArtworkEditScreen), findsOneWidget);
}

Finder get _saveButton => find.widgetWithText(FilledButton, 'Save');

Future<void> _editTitle(WidgetTester tester, String value) async {
  await tester.enterText(
    find.widgetWithText(TextField, 'Original title'),
    value,
  );
  await tester.pump();
}

_ShellHostState _host(WidgetTester tester) =>
    tester.state<_ShellHostState>(find.byType(_ShellHost));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('desktop workspace editor (in-shell stack)', () {
    testWidgets(
        'a confirmed save closes only the editor: the shell stays mounted, '
        'nothing else is popped, Back still works', (tester) async {
      final rig = _Rig();
      rig.api.onUpdate = (updates) => _artwork(title: 'New title');
      await _openWorkspaceEditor(tester, rig);
      await _editTitle(tester, 'New title');

      await tester.tap(_saveButton);
      await _settle(tester);

      // The PUT carried only the changed field.
      expect(rig.api.putBodies, hasLength(1));
      expect(rig.api.putBodies.single, {'title': 'New title'});

      // No black screen: the shell host is still the visible route.
      expect(find.byType(_ShellHost), findsOneWidget);
      expect(
          find.byKey(const ValueKey<String>('shell-scaffold')), findsOneWidget);
      expect(find.text('PORTFOLIO'), findsOneWidget);
      expect(find.byType(ArtworkEditScreen), findsNothing);
      expect(_host(tester).stack, isEmpty);

      // Provider cache and the portfolio were updated, success was announced.
      expect(rig.artworks.getArtworkById(_artworkId)?.title, 'New title');
      expect(rig.refresh.portfolioTriggers, 1);
      expect(find.text('Saved'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Normal system Back now leaves the shell exactly once, to the base.
      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(find.byType(_ShellHost), findsNothing);
      expect(find.text('OPEN'), findsOneWidget);
    });

    testWidgets(
        'saving from the artwork detail returns to the detail, not to the '
        'portfolio and not to a blank shell', (tester) async {
      final rig = _Rig();
      rig.api.onUpdate = (updates) => _artwork(title: 'New title');
      await _openWorkspaceEditor(
        tester,
        rig,
        below: const <Widget>[Center(child: Text('DETAIL'))],
      );
      await _editTitle(tester, 'New title');

      await tester.tap(_saveButton);
      await _settle(tester);

      expect(find.byType(_ShellHost), findsOneWidget);
      expect(_host(tester).stack, hasLength(1));
      expect(find.text('DETAIL'), findsOneWidget);
      expect(find.byType(ArtworkEditScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'HTTP 200 acknowledged without an artwork payload and a failed '
        'read-back is a success: cache updated, editor closed', (tester) async {
      final rig = _Rig();
      rig.api.onUpdate = (updates) => null;
      rig.api.onGet = () => throw StateError('read-back unavailable');
      await _openWorkspaceEditor(tester, rig);
      await _editTitle(tester, 'New title');

      await tester.tap(_saveButton);
      await _settle(tester);

      expect(rig.artworks.getArtworkById(_artworkId)?.title, 'New title');
      expect(find.text('Saved'), findsOneWidget);
      expect(rig.refresh.portfolioTriggers, 1);
      expect(_host(tester).stack, isEmpty);
      expect(find.byType(_ShellHost), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    final l10n = AppLocalizationsEn();
    final failures = <String, ({Object error, String message})>{
      '400': (error: _http(400), message: l10n.commonActionFailedToast),
      '401': (
        error: _http(401),
        message: l10n.communityCommentAuthRequiredToast,
      ),
      '403': (
        error: _http(403),
        message: l10n.activationActionUnauthorizedToast,
      ),
      '409': (error: _http(409), message: l10n.commonActionFailedToast),
      '429': (error: _http(429), message: l10n.stateRateLimitDescription),
      '500': (error: _http(500), message: l10n.commonActionFailedToast),
      'timeout (504)': (
        error: _http(504),
        message: l10n.commonNetworkErrorToast
      ),
      'offline (0)': (error: _http(0), message: l10n.commonNetworkErrorToast),
    };
    for (final entry in failures.entries) {
      testWidgets(
          'a failed write (${entry.key}) keeps the editor and the typed '
          'values, claims nothing and never reads the old record back',
          (tester) async {
        final rig = _Rig();
        rig.api.onUpdate = (updates) => throw entry.value.error;
        // The old record is perfectly readable: the screen used to take that
        // read for proof of a save.
        rig.api.onGet = () => _artwork();
        await _openWorkspaceEditor(tester, rig);
        await _editTitle(tester, 'Edited but unsaved');

        await tester.tap(_saveButton);
        await _settle(tester);

        expect(find.byType(ArtworkEditScreen), findsOneWidget);
        expect(_host(tester).stack, hasLength(1));
        expect(find.byType(_ShellHost), findsOneWidget);
        expect(find.text('Edited but unsaved'), findsOneWidget);
        expect(find.text('Saved'), findsNothing);
        expect(find.text(entry.value.message), findsOneWidget);
        expect(rig.refresh.portfolioTriggers, 0);
        expect(rig.api.getCalls, 0);
        expect(
          rig.artworks.getArtworkById(_artworkId)?.title,
          'Original title',
        );
        // The button is usable again for a retry.
        expect(tester.widget<FilledButton>(_saveButton).onPressed, isNotNull);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
        'saving with no changed fields sends nothing and does not claim a '
        'save', (tester) async {
      final rig = _Rig();
      rig.api.onUpdate = (updates) => throw StateError('must not be called');
      await _openWorkspaceEditor(tester, rig);

      await tester.tap(_saveButton);
      await _settle(tester);

      expect(rig.api.putBodies, isEmpty);
      expect(find.text('Saved'), findsNothing);
      expect(find.byType(_ShellHost), findsOneWidget);
      expect(_host(tester).stack, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a rapid double tap sends one request and closes once',
        (tester) async {
      final rig = _Rig();
      final gate = Completer<Artwork?>();
      rig.api.onUpdate = (updates) => gate.future;
      await _openWorkspaceEditor(
        tester,
        rig,
        below: const <Widget>[Center(child: Text('DETAIL'))],
      );
      await _editTitle(tester, 'New title');

      await tester.tap(_saveButton);
      await tester.pump();
      await tester.tap(_saveButton, warnIfMissed: false);
      await tester.pump();
      expect(rig.api.putBodies, hasLength(1));

      gate.complete(_artwork(title: 'New title'));
      await _settle(tester);

      expect(rig.api.putBodies, hasLength(1));
      expect(rig.refresh.portfolioTriggers, 1);
      // One close: the editor left, the detail beneath it was not popped too.
      expect(_host(tester).stack, hasLength(1));
      expect(find.text('DETAIL'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'leaving the editor while the save is in flight neither throws nor '
        'pops anything else, and the portfolio still learns of the edit',
        (tester) async {
      final rig = _Rig();
      final gate = Completer<Artwork?>();
      rig.api.onUpdate = (updates) => gate.future;
      await _openWorkspaceEditor(tester, rig);
      await _editTitle(tester, 'New title');

      await tester.tap(_saveButton);
      await tester.pump();
      _host(tester).removeTop(); // the user pressed Back mid-request
      await _settle(tester);
      expect(find.byType(ArtworkEditScreen), findsNothing);

      gate.complete(_artwork(title: 'New title'));
      await _settle(tester);

      expect(find.byType(_ShellHost), findsOneWidget);
      expect(find.text('PORTFOLIO'), findsOneWidget);
      expect(rig.artworks.getArtworkById(_artworkId)?.title, 'New title');
      expect(rig.refresh.portfolioTriggers, 1);
      expect(tester.takeException(), isNull);
    });
  });

  group('upload failures before the write', () {
    testWidgets(
        'a cover upload that fails keeps the editor and the typed values and '
        'never issues the PUT', (tester) async {
      final rig = _Rig();
      rig.api.onUpdate = (updates) => throw StateError('must not be called');
      FilePicker.platform = _PickedFile();
      await _openWorkspaceEditor(tester, rig);
      await _editTitle(tester, 'Edited but unsaved');

      await tester.tap(find.text('Upload cover'));
      await _settle(tester);
      await tester.tap(_saveButton);
      await _settle(tester);

      expect(rig.api.putBodies, isEmpty);
      expect(find.byType(ArtworkEditScreen), findsOneWidget);
      expect(find.byType(_ShellHost), findsOneWidget);
      // It failed at the upload, with a visible error, not at a validation.
      expect(
        find.text(AppLocalizationsEn().commonActionFailedToast),
        findsOneWidget,
      );
      expect(find.text('Edited but unsaved'), findsOneWidget);
      expect(find.text('Saved'), findsNothing);
      expect(rig.refresh.portfolioTriggers, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'an AR model upload that fails keeps the editor and never issues the '
        'PUT', (tester) async {
      final rig = _Rig();
      rig.api.onUpdate = (updates) => throw StateError('must not be called');
      FilePicker.platform = _PickedFile();
      await _openWorkspaceEditor(tester, rig);
      await _editTitle(tester, 'Edited but unsaved');

      await tester.scrollUntilVisible(
        find.byType(Switch),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byType(Switch));
      await _settle(tester);
      await tester.tap(find.byIcon(Icons.upload_file));
      await _settle(tester);
      await tester.tap(_saveButton);
      await _settle(tester);

      expect(rig.api.putBodies, isEmpty);
      expect(find.byType(ArtworkEditScreen), findsOneWidget);
      expect(find.byType(_ShellHost), findsOneWidget);
      // It failed at the upload, with a visible error, not at a validation.
      expect(
        find.text(AppLocalizationsEn().commonActionFailedToast),
        findsOneWidget,
      );
      expect(find.text('Saved'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('standalone mobile editor (Navigator route)', () {
    Future<void> openStandalone(WidgetTester tester, _Rig rig) async {
      await _setSize(tester, const Size(390, 844));
      await tester.pumpWidget(
        rig.app(const _Base(child: ArtworkEditScreen(artworkId: _artworkId))),
      );
      await tester.tap(find.text('OPEN'));
      await _settle(tester);
      expect(find.byType(ArtworkEditScreen), findsOneWidget);
    }

    testWidgets('a confirmed save pops the editor route and only that',
        (tester) async {
      final rig = _Rig();
      rig.api.onUpdate = (updates) => _artwork(title: 'New title');
      await openStandalone(tester, rig);
      await _editTitle(tester, 'New title');

      await tester.tap(find.byTooltip('Save'));
      await _settle(tester);

      expect(find.byType(ArtworkEditScreen), findsNothing);
      expect(find.text('OPEN'), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);
      expect(rig.artworks.getArtworkById(_artworkId)?.title, 'New title');
      expect(rig.refresh.portfolioTriggers, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a failed save keeps the route and the typed values',
        (tester) async {
      final rig = _Rig();
      rig.api.onUpdate = (updates) => throw _http(500);
      rig.api.onGet = () => _artwork();
      await openStandalone(tester, rig);
      await _editTitle(tester, 'Edited but unsaved');

      await tester.tap(find.byTooltip('Save'));
      await _settle(tester);

      expect(find.byType(ArtworkEditScreen), findsOneWidget);
      expect(find.text('Edited but unsaved'), findsOneWidget);
      expect(find.text('Saved'), findsNothing);
      expect(rig.refresh.portfolioTriggers, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('as the only route it is never popped off the app root',
        (tester) async {
      final rig = _Rig();
      rig.api.onUpdate = (updates) => _artwork(title: 'New title');
      await _setSize(tester, const Size(390, 844));
      await tester.pumpWidget(
        rig.app(const ArtworkEditScreen(artworkId: _artworkId)),
      );
      await _settle(tester);
      await _editTitle(tester, 'New title');

      await tester.tap(find.byTooltip('Save'));
      await _settle(tester);

      expect(find.byType(ArtworkEditScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

BackendApiRequestException _http(int status) => BackendApiRequestException(
      statusCode: status,
      path: '/api/artworks/$_artworkId',
      body: 'status $status',
    );
