import 'package:art_kubus/screens/community/profile_section_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the public profile reads identity to closing stats', () {
    expect(publicProfileSections, <ProfileSection>[
      ProfileSection.identity,
      ProfileSection.work,
      ProfileSection.publicArt,
      ProfileSection.activity,
      ProfileSection.recognition,
      ProfileSection.stats,
    ]);
    expect(publicProfileSections, isNot(contains(ProfileSection.ownerTools)));
  });

  test('"My profile" is the public sequence, then the owner tools', () {
    expect(
      ownerProfileSections.take(publicProfileSections.length),
      publicProfileSections,
    );
    expect(ownerProfileSections.last, ProfileSection.ownerTools);
    expect(ownerProfileSections.length, publicProfileSections.length + 1);
  });

  test('account management never interrupts the person\'s own narrative', () {
    final tools = ownerProfileSections.indexOf(ProfileSection.ownerTools);
    for (final section in publicProfileSections) {
      expect(ownerProfileSections.indexOf(section), lessThan(tools),
          reason: '$section must come before the owner tools');
    }
    expect(ownerProfileSections.first, ProfileSection.identity);
  });
}
