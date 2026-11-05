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

UserProfile _institutionUser({
  String wallet = _wallet,
  String id = 'user-self-derived',
  String displayName = 'Zvezda Gallery',
  bool isInstitution = true,
}) {
  return UserProfile(
    id: id,
    walletAddress: wallet,
    username: 'zvezda',
    displayName: displayName,
    bio: '',
    avatar: '',
    isInstitution: isInstitution,
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

  test('switching accounts replaces the derived entry with the new wallet only',
      () {
    const walletA = 'WalletSelfDerivedA111111111111111111111111';
    const walletB = 'WalletSelfDerivedB111111111111111111111111';
    final profiles = ProfileProvider()
      ..setCurrentUser(_institutionUser(wallet: walletA, id: 'user-a'));
    final provider = InstitutionProvider()..bindProfileProvider(profiles);

    final first = provider.institutions;
    expect(first.map((i) => i.id), [walletA]);
    expect(first.single.isSelfDerivedFromWallet, isTrue);

    profiles.setCurrentUser(_institutionUser(
      wallet: walletB,
      id: 'user-b',
      displayName: 'Second Gallery',
    ));

    final second = provider.institutions;
    expect(second.map((i) => i.id), [walletB]);
    expect(second.single.isSelfDerivedFromWallet, isTrue);
    expect(second.single.name, 'Second Gallery');
    expect(provider.getInstitutionById(walletA), isNull);
    expect(markerSubjectInstitutions(second), isEmpty);
  });

  test('sign-out leaves no derived entry and no marker subject', () {
    const wallet = 'WalletSelfDerivedSignOut111111111111111111';
    final profiles = ProfileProvider()
      ..setCurrentUser(_institutionUser(wallet: wallet));
    final provider = InstitutionProvider()..bindProfileProvider(profiles);
    expect(provider.getInstitutionById(wallet), isNotNull);

    profiles.signOut();

    expect(provider.institutions, isEmpty);
    expect(provider.getInstitutionById(wallet), isNull);
    expect(markerSubjectInstitutions(provider.institutions), isEmpty);
  });

  test('an account with an empty wallet derives no institution', () {
    final profiles = ProfileProvider()
      ..setCurrentUser(_institutionUser(wallet: '   '));
    final provider = InstitutionProvider()..bindProfileProvider(profiles);

    expect(provider.institutions, isEmpty);
    expect(markerSubjectInstitutions(provider.institutions), isEmpty);
  });

  test('an email-only account without an institution profile derives nothing',
      () {
    final profiles = ProfileProvider()
      ..setCurrentUser(_institutionUser(wallet: '', isInstitution: false));
    final provider = InstitutionProvider()..bindProfileProvider(profiles);

    expect(provider.institutions, isEmpty);
    expect(markerSubjectInstitutions(provider.institutions), isEmpty);
  });
}
