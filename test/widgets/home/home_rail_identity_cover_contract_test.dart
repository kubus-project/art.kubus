import 'package:art_kubus/models/profile_identity_data.dart';
import 'package:art_kubus/models/promotion.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/avatar_widget.dart';
import 'package:art_kubus/widgets/common/kubus_entity_card.dart';
import 'package:art_kubus/widgets/home/home_promotion_rail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Captured from GET https://api.kubus.site/api/public/home-rails?locale=en on
// 2026-10-04 (stats/promotion trimmed). The 0.8.0 backend published only
// `imageUrl` (the avatar) for identity items; the same profiles carry a cover
// on GET /api/profiles/:id. art.kubus-backend#73 adds the explicit fields.
const _avatar = '/uploads/profiles/avatars/ca4db3c0_scaled_logo_rok.jpg';
const _cover = '/uploads/profiles/cover/82ba4631_scaled_eoc5.png';
const _logo = 'https://api.kubus.site/uploads/profiles/avatars/bbf517b1.jpg';
const _institutionCover =
    '/uploads/profiles/cover/8bcbf9bb_scaled_bg_black.jpg';

Map<String, dynamic> _artistLive0800() => <String, dynamic>{
      'id': '78cFxKddXT3ZpPorgiaMy39fwbDB7CkmZaqAmskf3dPp',
      'entityType': 'profile',
      'entity_type': 'profile',
      'title': 'Rok Černezel',
      'subtitle': '@rok',
      'imageUrl': _avatar,
      'stats': <String, dynamic>{},
    };

Map<String, dynamic> _artistLive0801() => <String, dynamic>{
      ..._artistLive0800(),
      'avatarUrl': _avatar,
      'avatar_url': _avatar,
      'coverImageUrl': _cover,
      'cover_image_url': _cover,
    };

Map<String, dynamic> _institutionLive0801() => <String, dynamic>{
      'id': 'FHsXi6Rxnn2hEHhv4fQspzVPBhe5jz5nJQEXMKVNEFdM',
      'entityType': 'institution',
      'entity_type': 'institution',
      'title': 'kubus',
      'subtitle': '@kubus',
      'imageUrl': _logo,
      'avatarUrl': _logo,
      'avatar_url': _logo,
      'logoUrl': _logo,
      'logo_url': _logo,
      'coverImageUrl': _institutionCover,
      'cover_image_url': _institutionCover,
      'stats': <String, dynamic>{},
    };

Widget _harness(Widget child) => MaterialApp(
      theme: ThemeData.dark().copyWith(
        extensions: const [KubusColorRoles.dark],
      ),
      home: Scaffold(
        body: Center(child: SizedBox(width: 900, child: child)),
      ),
    );

IconData _icon(PromotionEntityType type) => Icons.person_outline;

void main() {
  group('artist rail item', () {
    test('cover_image_url becomes the card background, resolved absolute', () {
      final item = HomeRailItem.fromJson(_artistLive0801());
      final cover = resolveHomeRailIdentityCover(item);
      expect(cover, isNotNull);
      expect(cover, endsWith(_cover));
      expect(Uri.parse(cover!).hasScheme, isTrue,
          reason: 'a relative /uploads path must be normalised to the API');
    });

    test('the avatar stays the foreground mark, never the cover', () {
      final identity = ProfileIdentityData.fromHomeRailItem(
        HomeRailItem.fromJson(_artistLive0801()),
        fallbackLabel: 'Creator',
      );
      expect(identity.avatarUrl, _avatar);
    });

    test('the 0.8.0 payload (imageUrl only) still shows the real avatar', () {
      // Before #73 the avatar arrived only as imageUrl; the card fabricated a
      // wallet avatar because it read avatar fields alone.
      final item = HomeRailItem.fromJson(_artistLive0800());
      final identity = ProfileIdentityData.fromHomeRailItem(
        item,
        fallbackLabel: 'Creator',
      );
      expect(identity.avatarUrl, _avatar);
      expect(resolveHomeRailIdentityCover(item), isNull,
          reason: 'no cover in the payload: the authored field is used');
    });

    test('imageUrl that is the cover never becomes the avatar', () {
      final item = HomeRailItem.fromJson(<String, dynamic>{
        ..._artistLive0800(),
        'imageUrl': _cover,
        'coverImageUrl': _cover,
      });
      final identity = ProfileIdentityData.fromHomeRailItem(
        item,
        fallbackLabel: 'Creator',
      );
      expect(identity.avatarUrl, isNull);
      expect(resolveHomeRailIdentityCover(item), endsWith(_cover));
    });
  });

  group('institution rail item', () {
    test('institution cover is the background, logo the mark', () {
      final item = HomeRailItem.fromJson(_institutionLive0801());
      expect(resolveHomeRailIdentityCover(item), endsWith(_institutionCover));
      final identity = ProfileIdentityData.fromHomeRailItem(
        item,
        fallbackLabel: 'Institution',
      );
      expect(identity.avatarUrl, _logo);
    });

    test('no cover: no background image, the logo is not reused behind itself',
        () {
      final json = _institutionLive0801()
        ..remove('coverImageUrl')
        ..remove('cover_image_url');
      expect(resolveHomeRailIdentityCover(HomeRailItem.fromJson(json)), isNull);
    });
  });

  testWidgets('the rail card paints the cover and keeps the logo in front',
      (tester) async {
    await tester.pumpWidget(
      _harness(
        HomePromotionRailList(
          items: <HomeRailItem>[HomeRailItem.fromJson(_institutionLive0801())],
          placeholderIconBuilder: _icon,
          profileFallbackLabel: 'Institution',
        ),
      ),
    );
    await tester.pump();

    final card = tester.widget<KubusEntityCard>(find.byType(KubusEntityCard));
    expect(card.variant, KubusEntityCardVariant.identity);
    expect(card.imageUrl, endsWith(_institutionCover));
    final mark = card.leading;
    expect(mark, isA<AvatarWidget>());
    expect((mark! as AvatarWidget).avatarUrl, _logo);
    expect(card.imageUrl, isNot(contains('bbf517b1')),
        reason: 'the logo must not be painted behind itself');
    // Network images fail in tests; the card must fall back, not throw.
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });
}
