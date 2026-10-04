import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/profile/profile_cover_field.dart';
import 'package:art_kubus/widgets/profile/profile_identity_hero.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _avatarKey = ValueKey<String>('test-avatar');
const _actionsKey = ValueKey<String>('test-actions');
const _mountKey = ValueKey<String>('profile-hero-avatar-mount');

Widget _harness(
  Widget child, {
  double width = 1200,
  double textScale = 1,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData.dark().copyWith(extensions: const [KubusColorRoles.dark]),
    home: MediaQuery(
      data: MediaQueryData(
        size: Size(width, 900),
        textScaler: TextScaler.linear(textScale),
      ),
      child: Scaffold(
        body: SingleChildScrollView(
          child: Center(child: SizedBox(width: width, child: child)),
        ),
      ),
    ),
  );
}

ProfileIdentityHero _hero({
  String name = 'Rok',
  String handle = 'rok',
  bool isArtist = true,
  bool isInstitution = false,
  String? roleLabel = 'Artist profile',
  bool withActions = true,
}) {
  return ProfileIdentityHero(
    displayName: name,
    handle: handle,
    isArtist: isArtist,
    isInstitution: isInstitution,
    roleLabel: roleLabel,
    avatarRadius: 44,
    avatar:
        Container(key: _avatarKey, width: 88, height: 88, color: Colors.red),
    actions: withActions
        ? const SizedBox(key: _actionsKey, height: 44, child: Placeholder())
        : null,
  );
}

void main() {
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize =
        const Size(2000, 1400);
    binding.platformDispatcher.views.first.devicePixelRatio = 1;
  });
  tearDown(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  testWidgets('the identity plate shrinks to its content on desktop',
      (tester) async {
    await tester.pumpWidget(_harness(_hero()));
    await tester.pump();

    final avatar = tester.getRect(find.byKey(_avatarKey));
    final actions = tester.getRect(find.byKey(_actionsKey));
    final heroWidth = tester.getSize(find.byType(ProfileIdentityHero)).width;
    // 0.8.0: Expanded(plate) pushed the actions to the far right edge.
    final plateWidth = actions.left - avatar.right;
    expect(plateWidth, lessThan(heroWidth * 0.5),
        reason: 'a short name must not get a page-wide slab');
    expect(
      plateWidth,
      lessThanOrEqualTo(
        ProfileIdentityHero.plateMaxWidth + 64,
      ),
    );
    // Actions follow the plate and share its top band (one composition).
    expect(actions.right, lessThan(heroWidth - 200));
    expect((actions.top - avatar.top).abs(), lessThan(40));
  });

  testWidgets('a long name grows the plate up to its cap, then wraps',
      (tester) async {
    await tester.pumpWidget(
      _harness(
        _hero(
          name: 'Muzej sodobne umetnosti Metelkova in Moderna galerija '
              'Ljubljana Slovenija',
          handle: 'muzej_sodobne_umetnosti_metelkova_moderna_galerija',
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    final avatar = tester.getRect(find.byKey(_avatarKey));
    final actions = tester.getRect(find.byKey(_actionsKey));
    expect(
      actions.left - avatar.right,
      lessThanOrEqualTo(ProfileIdentityHero.plateMaxWidth + 64),
    );
    // The full handle is present, never truncated with an ellipsis.
    expect(
      find.textContaining('muzej_sodobne_umetnosti_metelkova_moderna_galerija'),
      findsOneWidget,
    );
  });

  testWidgets('an artist shows one role signal, not eyebrow + badge',
      (tester) async {
    await tester.pumpWidget(_harness(_hero()));
    await tester.pump();
    expect(find.text('ARTIST PROFILE'), findsNothing);
  });

  testWidgets('an institution shows one role signal too', (tester) async {
    await tester.pumpWidget(
      _harness(
        _hero(
          isArtist: false,
          isInstitution: true,
          roleLabel: 'Institution profile',
        ),
      ),
    );
    await tester.pump();
    expect(find.text('INSTITUTION PROFILE'), findsNothing);
  });

  testWidgets('an account without a role badge keeps its role eyebrow',
      (tester) async {
    await tester.pumpWidget(
      _harness(_hero(isArtist: false, roleLabel: 'Profile')),
    );
    await tester.pump();
    expect(find.text('PROFILE'), findsOneWidget);
  });

  testWidgets('the avatar has no extra frame or padding around it',
      (tester) async {
    await tester.pumpWidget(_harness(_hero()));
    await tester.pump();
    final mount = tester.getRect(find.byKey(_mountKey));
    final avatar = tester.getRect(find.byKey(_avatarKey));
    expect(mount, avatar, reason: 'mount must be the avatar, no padding');
    final box = tester.widget<DecoratedBox>(find.byKey(_mountKey));
    final decoration = box.decoration as BoxDecoration;
    expect(decoration.border, isNull);
    expect(decoration.color, isNull);
  });

  testWidgets('phone width stacks avatar, identity and actions',
      (tester) async {
    await tester.pumpWidget(_harness(_hero(), width: 360));
    await tester.pump();
    final avatar = tester.getRect(find.byKey(_avatarKey));
    final actions = tester.getRect(find.byKey(_actionsKey));
    expect(actions.top, greaterThan(avatar.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('200% text keeps the composition unclipped', (tester) async {
    for (final width in <double>[360, 768, 1200]) {
      await tester.pumpWidget(
        _harness(
          _hero(name: 'Rok Černezel', handle: 'rok_cernezel_studio'),
          width: width,
          textScale: 2,
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'width=$width');
    }
  });

  testWidgets('the fallback cover field has no texture layer', (tester) async {
    await tester.pumpWidget(
      _harness(
        const SizedBox(
          height: 200,
          child: ProfileCoverField(isArtist: true, isInstitution: false),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('profile_cover_field')), findsOneWidget);
    expect(
        find.descendant(
          of: find.byKey(const ValueKey('profile_cover_field')),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
        reason: 'no procedural texture painter in a fallback cover');
  });
}
