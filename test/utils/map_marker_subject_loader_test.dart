import 'package:art_kubus/models/institution.dart';
import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/providers/institution_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/utils/map_marker_subject_loader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _institutionWallet = 'LoaderInstitutionWallet11111111111111111111';

Institution _institution(String id) => Institution(
      id: id,
      name: 'Gallery $id',
      description: '',
      type: 'gallery',
      address: 'Ljubljana',
      latitude: 46.05,
      longitude: 14.5,
      contactEmail: '',
      website: '',
      stats: InstitutionStats(
        totalVisitors: 0,
        activeEvents: 0,
        artworkViews: 0,
        revenue: 0,
        visitorGrowth: 0,
        revenueGrowth: 0,
      ),
      createdAt: DateTime.utc(2026, 1, 1),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('marker subjects are the listed institutions, unchanged', () {
    final listed = [_institution('inst-1'), _institution('inst-2')];
    expect(markerSubjectInstitutions(listed).map((i) => i.id),
        ['inst-1', 'inst-2']);
  });

  test(
      'a signed-in account flagged as an institution never gets a listing made from its wallet',
      () async {
    final profiles = ProfileProvider()
      ..setCurrentUser(
        UserProfile(
          id: 'loader-account',
          walletAddress: _institutionWallet,
          username: 'loader_gallery',
          displayName: 'Loader Gallery',
          bio: '',
          avatar: '',
          isInstitution: true,
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      );
    final institutions = InstitutionProvider();
    await institutions.initialize(seedMockIfEmpty: true);

    expect(profiles.currentUser?.isInstitution, isTrue);
    expect(
      institutions.institutions.any((i) => i.id == _institutionWallet),
      isFalse,
      reason: 'authority over an institution is a membership, not a wallet',
    );
    expect(institutions.getInstitutionById(_institutionWallet), isNull);
  });
}
