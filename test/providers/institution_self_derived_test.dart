import 'package:art_kubus/models/institution.dart';
import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/providers/institution_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/utils/map_marker_subject_loader.dart';
import 'package:flutter_test/flutter_test.dart';

const _wallet = 'WalletSelfDerived1111111111111111111111111';

Institution _directoryInstitution() {
  return Institution(
    id: 'inst-directory-1',
    name: 'Zvezda Gallery',
    description: 'Public directory entry',
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
}

UserProfile _institutionUser() {
  return UserProfile(
    id: 'user-self-derived',
    walletAddress: _wallet,
    username: 'zvezda',
    displayName: 'Zvezda Gallery',
    bio: '',
    avatar: '',
    isInstitution: true,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  test('the wallet-derived institution is the event creator default only', () {
    final profiles = ProfileProvider()..setCurrentUser(_institutionUser());
    final provider = InstitutionProvider()..bindProfileProvider(profiles);

    // Event creator defaults to institutions.first; the derived entry leads.
    expect(provider.institutions, isNotEmpty);
    final derived = provider.institutions.first;
    expect(derived.id, _wallet);
    expect(derived.isSelfDerivedFromWallet, isTrue);

    // It is not offered as a map marker subject.
    expect(markerSubjectInstitutions(provider.institutions), isEmpty);
  });

  test('directory institutions remain marker subjects and are not flagged', () {
    final directory = _directoryInstitution();
    expect(directory.isSelfDerivedFromWallet, isFalse);
    expect(markerSubjectInstitutions(<Institution>[directory]), [directory]);
  });
}
