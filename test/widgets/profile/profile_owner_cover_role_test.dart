import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/common/kubus_atmosphere.dart';
import 'package:art_kubus/widgets/profile/profile_cover_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/profile_fixtures.dart';
import '../../support/product_v5_qa_fixtures.dart';
import '../../support/profile_screen_harness.dart';

Future<ProfileCoverField> _pumpOwnerCover(
  WidgetTester tester, {
  bool userIsArtist = false,
  bool userIsInstitution = false,
  String? approvedRole,
}) async {
  await pumpProfileSurface(
    tester,
    surface: ProfileSurface.mobileOwner,
    user: ProfileFixtures.user(
      isArtist: userIsArtist,
      isInstitution: userIsInstitution,
    ),
    daoProvider:
        approvedRole == null ? null : QaApprovedRoleDAOProvider(approvedRole),
  );
  await tester.pump(const Duration(milliseconds: 600));
  final finder = find.byType(ProfileCoverField);
  expect(finder, findsOneWidget, reason: 'image-less owner cover');
  return tester.widget<ProfileCoverField>(finder);
}

void _expectCoverRole(
  WidgetTester tester,
  ProfileCoverField cover, {
  required bool isArtist,
  required bool isInstitution,
}) {
  expect(cover.isArtist, isArtist, reason: 'cover artist role');
  expect(cover.isInstitution, isInstitution, reason: 'cover institution role');

  // The painted field carries the same role colour.
  final roles = KubusColorRoles.of(
    tester.element(find.byType(ProfileCoverField)),
  );
  final glyph = tester.widget<KubusGhostGlyph>(
    find.descendant(
      of: find.byKey(const ValueKey<String>('profile_cover_field')),
      matching: find.byType(KubusGhostGlyph),
    ),
  );
  expect(
    glyph.color,
    ProfileCoverField.accentFor(
      roles,
      isArtist: isArtist,
      isInstitution: isInstitution,
    ),
  );
}

void main() {
  group('mobile owner cover uses the resolved role', () {
    testWidgets('ordinary account keeps the generic field', (tester) async {
      final cover = await _pumpOwnerCover(tester);
      _expectCoverRole(tester, cover, isArtist: false, isInstitution: false);
    });

    testWidgets('artist flag on currentUser', (tester) async {
      final cover = await _pumpOwnerCover(tester, userIsArtist: true);
      _expectCoverRole(tester, cover, isArtist: true, isInstitution: false);
    });

    testWidgets('institution flag on currentUser', (tester) async {
      final cover = await _pumpOwnerCover(tester, userIsInstitution: true);
      _expectCoverRole(tester, cover, isArtist: false, isInstitution: true);
    });

    testWidgets(
        'approved artist review before currentUser.isArtist synchronises',
        (tester) async {
      final cover = await _pumpOwnerCover(
        tester,
        approvedRole: 'artist',
      );
      _expectCoverRole(tester, cover, isArtist: true, isInstitution: false);
    });

    testWidgets(
        'approved institution review before currentUser.isInstitution '
        'synchronises', (tester) async {
      final cover = await _pumpOwnerCover(
        tester,
        approvedRole: 'institution',
      );
      _expectCoverRole(tester, cover, isArtist: false, isInstitution: true);
    });
  });
}
