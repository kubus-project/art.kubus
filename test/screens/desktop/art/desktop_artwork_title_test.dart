import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/models/saved_item.dart';
import 'package:art_kubus/providers/saved_items_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/screens/desktop/art/desktop_artwork_detail_screen.dart';
import 'package:art_kubus/screens/desktop/desktop_shell_scope.dart';
import 'package:art_kubus/widgets/detail/detail_shell_primitives.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

const String _title = 'Vodnik mural';
const String _artworkId = 'title-fixture';

Artwork _artwork() => Artwork(
      id: _artworkId,
      title: _title,
      artist: 'Miron Milić',
      description: 'A mural on a wall.',
      position: const LatLng(46.0569, 14.5058),
      rewards: 0,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
      category: 'Mural',
    );

/// Saved status is read from secure storage, which does not complete under the
/// test binding; the screen only needs the hydrate call to return.
class _NoStorageSavedItems extends SavedItemsProvider {
  @override
  Future<void> hydrateSavedStatus({
    required SavedItemType type,
    required Iterable<String> ids,
  }) async {}
}

/// The comments card loads comments from its initState, and the provider
/// notifies synchronously there. That is outside this test; comments are not
/// part of the title, so the stub keeps them out of the build.
class _QuietArtworkProvider extends ArtworkProvider {
  @override
  Future<void> loadComments(String artworkId, {bool force = false}) async {}

  @override
  Future<void> incrementViewCount(String artworkId) async {}
}

/// The detail screen hosted the way the desktop shell hosts it: [host] wraps
/// it (a sub-screen for in-app navigation, or the bare screen for a raw link).
Widget _app(Widget Function(Widget screen) host) {
  final artworks = _QuietArtworkProvider()
    ..seedArtworksForTesting([_artwork()]);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ArtworkProvider>.value(value: artworks),
      ChangeNotifierProvider(create: (_) => ProfileProvider()),
      ChangeNotifierProvider(create: (_) => WalletProvider()),
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider<SavedItemsProvider>(
        create: (_) => _NoStorageSavedItems(),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: host(
          const DesktopArtworkDetailScreen(artworkId: _artworkId),
        ),
      ),
    ),
  );
}

/// The shell scope a canonical public entry sits under: its header shows the
/// brand label rather than the sub-screen title.
Widget _canonicalShell(Widget child) => DesktopShellScope(
      pushScreen: (_) {},
      popScreen: () {},
      navigateToRoute: (_) {},
      openNotifications: () {},
      openFunctionsPanel: (panel, {content}) {},
      setFunctionsPanelContent: (_) {},
      closeFunctionsPanel: () {},
      canPop: false,
      isCanonicalPublicEntry: true,
      child: child,
    );

int _textCount(String text) => find.text(text).evaluate().length;

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  Future<void> pumpAt1440(WidgetTester tester, Widget app) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app);
    // The screen hydrates saved status with real async work before its body
    // builds; let that complete in real time, then settle the frames.
    await tester.runAsync(() async {
      for (var i = 0; i < 200; i++) {
        if (find.byType(DetailIdentityBlock).evaluate().isNotEmpty) break;
        await Future<void>.delayed(const Duration(milliseconds: 25));
        await tester.pump(const Duration(milliseconds: 25));
      }
    });
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(DetailIdentityBlock), findsOneWidget);
  }

  testWidgets(
      'in-app: the sub-screen title equals the artwork title, so the title shows once',
      (tester) async {
    await pumpAt1440(
      tester,
      _app(
        (screen) => DesktopSubScreen(title: _title, child: screen),
      ),
    );

    expect(_textCount(_title), 1);
  });

  testWidgets(
      'raw deep link: the shell shows the generic label, so the body keeps the title',
      (tester) async {
    await pumpAt1440(
      tester,
      _app(
        (screen) => DesktopSubScreen(title: 'Artwork', child: screen),
      ),
    );

    expect(_textCount('Artwork'), 1);
    expect(_textCount(_title), 1);
  });

  testWidgets(
      'canonical public entry: the header shows the brand label, so the body keeps the title',
      (tester) async {
    await pumpAt1440(
      tester,
      _app(
        (screen) => _canonicalShell(
          DesktopSubScreen(title: _title, child: screen),
        ),
      ),
    );

    expect(_textCount('art.kubus'), 1);
    expect(_textCount(_title), 1);
  });
}
