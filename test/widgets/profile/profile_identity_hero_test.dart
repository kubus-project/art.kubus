import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/utils/media_failure_registry.dart';
import 'package:art_kubus/widgets/detail/profile_identity_block.dart';
import 'package:art_kubus/widgets/profile/profile_cover_field.dart';
import 'package:art_kubus/widgets/profile/profile_identity_hero.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/profile_image_http_fixture.dart';

const _avatarKey = ValueKey<String>('test-avatar');
const _actionsKey = ValueKey<String>('test-actions');
const _mountKey = ValueKey<String>('profile-hero-avatar-mount');

Future<T> _withImageFixture<T>(
  ProfileImageHttpFixture fixture,
  Future<T> Function() body,
) async {
  final previous = debugNetworkImageHttpClientProvider;
  debugNetworkImageHttpClientProvider = () => fixture.createHttpClient(null);
  try {
    return await body();
  } finally {
    debugNetworkImageHttpClientProvider = previous;
  }
}

Widget _harness(Widget child, {double width = 1200, double textScale = 1}) {
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
          child: Center(
            child: SizedBox(width: width, child: child),
          ),
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
  String? coverImageUrl,
}) {
  return ProfileIdentityHero(
    displayName: name,
    handle: handle,
    isArtist: isArtist,
    isInstitution: isInstitution,
    roleLabel: roleLabel,
    coverImageUrl: coverImageUrl,
    avatarRadius: 44,
    avatar: Container(
      key: _avatarKey,
      width: 88,
      height: 88,
      color: Colors.red,
    ),
    actions: withActions
        ? const SizedBox(key: _actionsKey, height: 44, child: Placeholder())
        : null,
  );
}

void main() {
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(
      2000,
      1400,
    );
    binding.platformDispatcher.views.first.devicePixelRatio = 1;
  });
  tearDown(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  testWidgets('the identity plate shrinks to its content on desktop', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(_hero()));
    await tester.pump();

    final avatar = tester.getRect(find.byKey(_avatarKey));
    final actions = tester.getRect(find.byKey(_actionsKey));
    final heroWidth = tester.getSize(find.byType(ProfileIdentityHero)).width;
    // 0.8.0: Expanded(plate) pushed the actions to the far right edge.
    final plateWidth = actions.left - avatar.right;
    expect(
      plateWidth,
      lessThan(heroWidth * 0.5),
      reason: 'a short name must not get a page-wide slab',
    );
    expect(
      plateWidth,
      lessThanOrEqualTo(ProfileIdentityHero.plateMaxWidth + 64),
    );
    // Actions follow the plate and share its top band (one composition).
    expect(
      actions.right,
      lessThan(heroWidth * 0.9),
      reason: 'actions follow the plate, not the far edge',
    );
    expect((actions.top - avatar.top).abs(), lessThan(40));
  });

  testWidgets('a long name grows the plate up to its cap, then wraps', (
    tester,
  ) async {
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

  testWidgets('an artist shows one role signal, not eyebrow + badge', (
    tester,
  ) async {
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

  testWidgets('an account without a role badge keeps its role eyebrow', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(_hero(isArtist: false, roleLabel: 'Profile')),
    );
    await tester.pump();
    expect(find.text('PROFILE'), findsOneWidget);
  });

  testWidgets('the avatar has no extra frame or padding around it', (
    tester,
  ) async {
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

  testWidgets('ordinary phone widths keep avatar beside wrapping identity', (
    tester,
  ) async {
    for (final width in <double>[288, 328, 361, 380, 398]) {
      await tester.pumpWidget(
        _harness(
          _hero(
            name: 'Ana Kovač Institute for Contemporary Muralism',
            handle: 'ana_kovac_contemporary_muralism',
          ),
          width: width,
        ),
      );
      await tester.pump();
      final avatar = tester.getRect(find.byKey(_avatarKey));
      final identity = tester.getRect(find.byType(ProfileIdentityBlock));
      expect(identity.left, greaterThan(avatar.right), reason: 'width=$width');
      expect(
        (identity.top - avatar.top).abs(),
        lessThan(40),
        reason: 'width=$width',
      );
      expect(tester.takeException(), isNull, reason: 'width=$width');
    }
  });

  testWidgets('mobile actions have their own full-width run', (tester) async {
    await tester.pumpWidget(_harness(_hero(), width: 328));
    await tester.pump();
    final identity = tester.getRect(find.byType(ProfileIdentityBlock));
    final actions = tester.getRect(find.byKey(_actionsKey));
    expect(actions.top, greaterThan(identity.bottom));
    expect(actions.left, lessThan(identity.left));
    expect(actions.width, 296);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed cover keeps image-present geometry and role fallback', (
    tester,
  ) async {
    const coverUrl = 'https://profile-fixture.invalid/failure.png';
    KubusMediaFailureRegistry.shared.clear();
    addTearDown(KubusMediaFailureRegistry.shared.clear);
    final fixture = ProfileImageHttpFixture();
    await _withImageFixture(fixture, () async {
      await tester.pumpWidget(
        _harness(_hero(coverImageUrl: coverUrl), width: 328),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(fixture.requests, 1);
      final avatarTop = tester.getTopLeft(find.byKey(_avatarKey)).dy;
      expect(avatarTop, 198);
      expect(find.byKey(const ValueKey('profile_cover_field')), findsOneWidget);

      // A parent refresh/rebuild keeps the authored URL and cover bounds,
      // while the shared recent-failure registry prevents another request.
      await tester.pumpWidget(
        _harness(_hero(coverImageUrl: coverUrl), width: 328),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(fixture.requests, 1);
      expect(tester.getTopLeft(find.byKey(_avatarKey)).dy, avatarTop);
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide and tall cover photos preserve source geometry and crop', (
    tester,
  ) async {
    for (final path in <String>['wide.png', 'tall.png']) {
      final fixture = ProfileImageHttpFixture();
      await tester.runAsync(fixture.prepare);
      await _withImageFixture(fixture, () async {
        await tester.pumpWidget(
          _harness(
            _hero(coverImageUrl: 'https://profile-fixture.invalid/$path'),
            width: 328,
          ),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
        expect(fixture.requests, 1, reason: path);
        expect(tester.takeException(), isNull, reason: path);

        final imageFinder = find.byType(Image).first;
        final image = tester.widget<Image>(imageFinder);
        final rawImageFinder = find.byType(RawImage);
        final renderImage = tester.renderObject<RenderImage>(rawImageFinder);
        expect(image.fit, BoxFit.cover, reason: path);
        expect(image.alignment, Alignment.center, reason: path);
        expect(renderImage.image, isNotNull, reason: path);
        expect(
          (renderImage.image!.width, renderImage.image!.height),
          path == 'wide.png' ? (960, 360) : (240, 960),
          reason: 'decode dimensions retain the $path source aspect ratio',
        );
        expect(
          tester.getSize(imageFinder),
          const Size(328, 266),
          reason: 'cover viewport stays fixed for $path',
        );
        final source = renderImage.image!;
        final renderedRect = tester.getRect(imageFinder);
        final scale = (renderedRect.width / source.width).compareTo(
                  renderedRect.height / source.height,
                ) >=
                0
            ? renderedRect.width / source.width
            : renderedRect.height / source.height;
        final sourceX =
            (((16.5 - (renderedRect.width - source.width * scale) / 2) /
                        scale) -
                    0.5)
                .round();
        final sourceY =
            (((133.5 - (renderedRect.height - source.height * scale) / 2) /
                        scale) -
                    0.5)
                .round();
        final samples = await tester.runAsync(() async {
          final sourceBytes = (await source.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          final root = tester.binding.rootElement!.renderObject!;
          final layer = root.debugLayer! as OffsetLayer;
          final painted = await layer.toImage(root.paintBounds);
          final paintedBytes = (await painted.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          final pixels = (
            _pixel(sourceBytes, source.width, sourceX, sourceY),
            _pixel(
              paintedBytes,
              painted.width,
              renderedRect.left.round() + 16,
              renderedRect.top.round() + 133,
            ),
          );
          painted.dispose();
          return pixels;
        });
        expect(samples, isNotNull, reason: 'capture painted $path pixels');
        for (var channel = 0; channel < 3; channel++) {
          expect(
            (samples!.$1[channel] - samples.$2[channel]).abs(),
            lessThanOrEqualTo(12),
            reason: 'centered BoxFit.cover paints the center source column '
                'at the cover edge for $path',
          );
        }
        expect(fixture.requests, 1);
        expect(tester.takeException(), isNull, reason: path);
      });
    }
  });

  testWidgets('200% text keeps the composition unclipped', (tester) async {
    for (final width in <double>[288, 328, 361, 380, 398, 768, 1200]) {
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
      reason: 'no procedural texture painter in a fallback cover',
    );
  });
}

List<int> _pixel(ByteData data, int width, int x, int y) {
  final offset = (y * width + x) * 4;
  return <int>[
    data.getUint8(offset),
    data.getUint8(offset + 1),
    data.getUint8(offset + 2),
  ];
}
