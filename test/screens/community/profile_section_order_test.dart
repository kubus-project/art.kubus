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

  group('composeProfileSections', () {
    test('builds the sections in canonical order whatever builds them', () {
      final built = composeProfileSections<String>(
        order: publicProfileSections,
        build: (section) => [section.name],
      );
      expect(built, publicProfileSections.map((section) => section.name));
    });

    test('a section that does not apply is left out, order of the rest kept',
        () {
      final built = composeProfileSections<String>(
        order: ownerProfileSections,
        build: (section) => section == ProfileSection.work ||
                section == ProfileSection.publicArt
            ? const <String>[]
            : [section.name],
      );
      expect(built, <String>[
        'identity',
        'activity',
        'recognition',
        'stats',
        'ownerTools',
      ]);
    });

    test('gaps sit only between sections that contributed something', () {
      final built = composeProfileSections<String>(
        order: publicProfileSections,
        gap: (previous, next) => '|${previous.name}>${next.name}|',
        build: (section) => section == ProfileSection.publicArt
            ? const <String>[]
            : [section.name, '${section.name}-detail'],
      );
      expect(built.where((item) => item.startsWith('|')).toList(), <String>[
        '|identity>work|',
        '|work>activity|',
        '|activity>recognition|',
        '|recognition>stats|',
      ]);
      expect(built.first, 'identity');
      expect(built.last, 'stats-detail');
    });

    test('nothing to build yields nothing, and no stray gap', () {
      expect(
        composeProfileSections<String>(
          order: publicProfileSections,
          gap: (_, __) => 'gap',
          build: (_) => const <String>[],
        ),
        isEmpty,
      );
    });
  });
}
