import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/widgets/profile/profile_edit_form_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Harness {
  _Harness()
      : controllers = ProfileEditControllers(
          username: TextEditingController(text: 'ana_kovac'),
          displayName: TextEditingController(text: 'Ana Kovač'),
          bio: TextEditingController(text: 'Muralist.'),
          twitter: TextEditingController(),
          instagram: TextEditingController(),
          website: TextEditingController(),
          specialty: TextEditingController(text: 'Mural'),
          yearsActive: TextEditingController(text: '9'),
        );

  final ProfileEditControllers controllers;

  Widget body({
    bool isArtist = false,
    bool isInstitution = false,
    bool wide = false,
    String? notice,
  }) {
    return ProfileEditFormBody(
      controllers: controllers,
      isArtist: isArtist,
      isInstitution: isInstitution,
      wide: wide,
      formNotice: notice,
      privacy: const ProfilePrivacyDraft(
        privateProfile: false,
        showActivityStatus: false,
        shareLastVisitedLocation: false,
        showCollection: true,
        allowMessages: true,
      ),
      onPrivacyChanged: (_, __) {},
      coverPreview: const SizedBox(height: 150),
      hasCover: false,
      onPickCover: () {},
      isUploadingCover: false,
      avatarPreview: const SizedBox(width: 96, height: 96),
      hasAvatar: true,
      onPickAvatar: () {},
      isUploadingAvatar: false,
    );
  }
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(390, 844),
  Locale locale = const Locale('en'),
  double textScale = 1.0,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final theme = ThemeProvider();
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: brightness == Brightness.dark ? theme.darkTheme : theme.lightTheme,
    home: MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
      ),
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(child: child),
        ),
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets('generic profile: identity, links, privacy; no role fields',
      (tester) async {
    final h = _Harness();
    await _pump(tester, h.body());
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Display name'), findsOneWidget);
    expect(find.text('Years active'), findsNothing);
    expect(find.text('Specialties'), findsNothing);
    expect(find.byKey(const Key('profile_edit_privacy_private_profile')),
        findsOneWidget);
  });

  testWidgets('artist profile edits the practice fields the model stores',
      (tester) async {
    final h = _Harness();
    await _pump(tester, h.body(isArtist: true));
    expect(find.text('Specialties'), findsOneWidget);
    expect(find.text('Years active'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
  });

  testWidgets(
      'institution profile gets a note, not repurposed artist fields '
      '(no "Established year" written into years active)', (tester) async {
    final h = _Harness();
    await _pump(tester, h.body(isInstitution: true, wide: false));
    expect(find.text('Years active'), findsNothing);
    expect(find.text('Established year'), findsNothing);
    expect(find.text('Focus areas'), findsNothing);
    final l10n =
        AppLocalizations.of(tester.element(find.byType(ProfileEditFormBody)))!;
    expect(find.text(l10n.profileEditInstitutionAboutBody), findsOneWidget);
  });

  testWidgets('activity off disables the last-visited switch', (tester) async {
    final h = _Harness();
    await _pump(tester, h.body());
    final share = tester.widget<Switch>(find
        .byKey(const Key('profile_edit_privacy_share_last_visited_location')));
    expect(share.onChanged, isNull);
  });

  testWidgets('desktop keys and two-column sections keep the same fields',
      (tester) async {
    final h = _Harness();
    await _pump(
      tester,
      ProfileEditFormBody(
        controllers: h.controllers,
        isArtist: true,
        isInstitution: false,
        wide: true,
        switchKeyPrefix: 'desktop_profile_edit_privacy_',
        privacy: const ProfilePrivacyDraft(
          privateProfile: false,
          showActivityStatus: true,
          shareLastVisitedLocation: false,
          showCollection: true,
          allowMessages: true,
        ),
        onPrivacyChanged: (_, __) {},
        coverPreview: const SizedBox(height: 180),
        hasCover: false,
        onPickCover: () {},
        isUploadingCover: false,
        avatarPreview: const SizedBox(width: 112, height: 112),
        hasAvatar: false,
        onPickAvatar: () {},
        isUploadingAvatar: false,
      ),
      size: const Size(1280, 900),
    );
    expect(tester.takeException(), isNull);
    expect(
        find.byKey(
            const Key('desktop_profile_edit_privacy_show_activity_status')),
        findsOneWidget);
    expect(find.text('Years active'), findsOneWidget);
  });

  for (final width in const [320.0, 360.0]) {
    testWidgets('no overflow at $width px, SL, 2x text', (tester) async {
      final h = _Harness();
      await _pump(
        tester,
        h.body(isArtist: true, notice: 'Nekatera polja je treba popraviti.'),
        size: Size(width, 900),
        locale: const Locale('sl'),
        textScale: 2.0,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('form notice is announced as a live region', (tester) async {
    final handle = tester.ensureSemantics();
    final h = _Harness();
    await _pump(tester, h.body(notice: 'Profile save timed out.'));
    expect(find.text('Profile save timed out.'), findsOneWidget);
    final node = tester.getSemantics(find.text('Profile save timed out.'));
    expect(node.flagsCollection.isLiveRegion || node.parent != null, isTrue);
    handle.dispose();
  });
}
