import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/widgets/profile/profile_people_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _ana = ProfilePersonEntry(
  wallet: 'AnaWallet1111111111111111111111111111111111',
  primary: 'Ana Kovač',
  secondary: '@ana_kovac',
  role: ProfilePersonRole.artist,
  isVerified: true,
);
const _gallery = ProfilePersonEntry(
  wallet: 'GalleryWallet22222222222222222222222222222',
  primary: 'Galerija Vžigalica',
  secondary: '@vzigalica',
  role: ProfilePersonRole.institution,
);
const _unknown = ProfilePersonEntry(
  wallet: 'PlainWallet333333333333333333333333333333333',
  primary: 'Maja',
  secondary: '@maja',
);

Future<void> _pump(
  WidgetTester tester, {
  required List<ProfilePersonEntry>? entries,
  Future<Set<String>?> Function()? loader,
  String? viewerWallet,
  bool isLoading = false,
  Object? error,
  Locale locale = const Locale('en'),
  Size size = const Size(390, 700),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeProvider().lightTheme,
    home: MediaQuery(
      data:
          MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: ProfilePeopleList(
          entries: entries,
          isLoading: isLoading,
          error: error,
          onRetry: () {},
          onOpen: (_) {},
          emptyTitle: 'No followers yet',
          emptyDescription: 'People who follow this profile appear here.',
          viewerWallet: viewerWallet,
          viewerFollowingLoader: loader ?? () async => null,
        ),
      ),
    ),
  ));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('guest viewer: identity rows, no follow toggles', (tester) async {
    await _pump(tester, entries: const [_ana, _unknown]);
    expect(find.text('Ana Kovač'), findsOneWidget);
    expect(find.text('Follow'), findsNothing);
    expect(find.text('Following'), findsNothing);
  });

  testWidgets(
      'signed-in viewer: toggle state comes from the real following set; '
      'own row has no toggle', (tester) async {
    await _pump(
      tester,
      entries: const [_ana, _gallery, _unknown],
      viewerWallet: _unknown.wallet,
      loader: () async => {_ana.wallet},
    );
    // Ana is followed, the gallery is not, the viewer's own row has none.
    expect(find.text('Following'), findsOneWidget);
    expect(find.text('Follow'), findsOneWidget);
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Maja'),
          matching: find.byType(ProfilePersonRow),
        ),
        matching: find.byType(OutlinedButton),
      ),
      findsNothing,
    );
  });

  testWidgets(
      'unavailable follow set (loader null for a signed-in viewer) shows no '
      'toggles, never "Follow" on every row', (tester) async {
    await _pump(
      tester,
      entries: const [_ana, _gallery],
      viewerWallet: _unknown.wallet,
      // What the default loader returns when the backend fails and no
      // following set was ever cached (UserService.getKnownFollowingUsers).
      loader: () async => null,
    );
    expect(find.text('Ana Kovač'), findsOneWidget);
    expect(find.text('Follow'), findsNothing);
    expect(find.text('Following'), findsNothing);
  });

  testWidgets('toggle exposes button + toggled semantics and 44 px targets',
      (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      entries: const [_ana],
      loader: () async => {_ana.wallet},
    );
    final toggle = find.widgetWithText(OutlinedButton, 'Following');
    expect(tester.getSize(toggle).height, greaterThanOrEqualTo(44));
    expect(
      tester.getSemantics(toggle),
      isSemantics(
        label: 'Follow Ana Kovač',
        isButton: true,
        hasToggledState: true,
        isToggled: true,
      ),
    );
    expect(tester.getSize(find.byType(ProfilePersonRow)).height,
        greaterThanOrEqualTo(64));
    handle.dispose();
  });

  testWidgets('role context only when known; no wallet data or stats',
      (tester) async {
    await _pump(tester, entries: const [_ana, _gallery, _unknown]);
    expect(find.textContaining('ARTIST'), findsOneWidget);
    expect(find.textContaining('INSTITUTION'), findsOneWidget);
    expect(find.textContaining('KUB8'), findsNothing);
    expect(find.textContaining('SOL'), findsNothing);
  });

  testWidgets('empty, loading and error states use the shared patterns',
      (tester) async {
    await _pump(tester, entries: const []);
    expect(find.text('No followers yet'), findsOneWidget);

    await _pump(tester, entries: null, isLoading: true);
    expect(find.bySemanticsLabel('Loading'), findsOneWidget);

    await _pump(tester, entries: const [], error: Exception('boom'));
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('boom'), findsNothing);
  });

  testWidgets('SL at 320 px with 2x text does not overflow', (tester) async {
    await _pump(
      tester,
      entries: const [_ana, _gallery],
      loader: () async => {_ana.wallet},
      locale: const Locale('sl'),
      size: const Size(320, 700),
      textScale: 2.0,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Sledim'), findsNothing,
        reason: 'uses the shared commonFollowing copy');
  });
}
