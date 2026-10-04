import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/screens/art/artwork_edit_screen.dart';
import 'package:art_kubus/screens/desktop/desktop_shell_scope.dart';
import 'package:art_kubus/utils/artwork_edit_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Exactly one owner of the editor's screen chrome.
///
/// The desktop Artist Studio used to produce two titles and two back buttons
/// for one artwork: the shell wrapped the editor in a `DesktopSubScreen`
/// header, and the editor — seeing a wide window — built its own
/// `DesktopCreatorShell` header inside it. The ownership is now an explicit
/// [ArtworkEditChrome] decision made by the caller, so this is a guard against
/// anything inferring it from screen width again.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget host({
    required Widget Function(BuildContext context) builder,
    required void Function(Widget screen) onPush,
    Size size = const Size(1440, 900),
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<ArtworkProvider>(
            create: (_) => ArtworkProvider()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: DesktopShellScope(
            pushScreen: onPush,
            popScreen: () {},
            navigateToRoute: (_) {},
            openNotifications: () {},
            openFunctionsPanel: (_, {content}) {},
            setFunctionsPanelContent: (_) {},
            closeFunctionsPanel: () {},
            canPop: true,
            child: Scaffold(body: Builder(builder: builder)),
          ),
        ),
      ),
    );
  }

  testWidgets(
      'opening the editor inside the desktop shell pushes it bare, so the '
      'editor is the only chrome owner', (tester) async {
    Widget? pushed;

    await tester.pumpWidget(
      host(
        onPush: (screen) => pushed = screen,
        builder: (context) => ElevatedButton(
          onPressed: () => openArtworkEditor(context, 'artwork-1'),
          child: const Text('Edit'),
        ),
      ),
    );

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    // Not wrapped in a second header. This is the whole regression: a
    // DesktopSubScreen here means two titles and two back buttons.
    expect(pushed, isNotNull);
    expect(pushed, isNot(isA<DesktopSubScreen>()));
    expect(pushed, isA<ArtworkEditScreen>());
    expect(
      (pushed! as ArtworkEditScreen).chrome,
      ArtworkEditChrome.workspace,
    );
  });

  testWidgets('chrome ownership is explicit, never inferred from width',
      (tester) async {
    // The same screen at the same width reports different ownership purely
    // from its typed parameter.
    const workspace = ArtworkEditScreen(
      artworkId: 'a',
      chrome: ArtworkEditChrome.workspace,
    );
    const bodyOnly = ArtworkEditScreen(
      artworkId: 'a',
      chrome: ArtworkEditChrome.bodyOnly,
    );
    const standalone = ArtworkEditScreen(artworkId: 'a');

    expect(workspace.isEmbedded, isTrue);
    expect(bodyOnly.isEmbedded, isTrue);
    expect(standalone.isEmbedded, isFalse);
    expect(standalone.chrome, ArtworkEditChrome.standalone);
  });
}
