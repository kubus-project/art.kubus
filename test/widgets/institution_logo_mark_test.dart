import 'package:art_kubus/models/institution.dart';
import 'package:art_kubus/widgets/common/kubus_cached_image.dart';
import 'package:art_kubus/widgets/institution/institution_logo_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Institution _institution({String? cover, String? logo}) => Institution(
      id: 'i',
      name: 'Galerija Test',
      description: '',
      type: 'gallery',
      address: '',
      latitude: 0,
      longitude: 0,
      contactEmail: '',
      website: '',
      coverImageUrl: cover,
      logoUrl: logo,
      stats: InstitutionStats(
          totalVisitors: 0,
          activeEvents: 0,
          artworkViews: 0,
          revenue: 0,
          visitorGrowth: 0,
          revenueGrowth: 0),
      createdAt: DateTime(2026),
    );

void main() {
  test('a logo is never the cover; compact surfaces prefer the logo', () {
    final logoOnly =
        _institution(logo: 'https://api.kubus.site/uploads/institutions/a.png');
    expect(logoOnly.heroImageRef, isNull);
    expect(logoOnly.thumbnailRef, isNotNull);
    final both = _institution(
      cover: 'https://api.kubus.site/uploads/institutions/c.jpg',
      logo: 'https://api.kubus.site/uploads/institutions/l.png',
    );
    expect(both.heroImageRef, contains('c.jpg'));
    expect(both.thumbnailRef, contains('l.png'));
    expect(_institution().thumbnailRef, isNull);
  });

  for (final width in <double>[360, 1200]) {
    testWidgets('logo mark keeps proportions and a label at ${width.toInt()}px',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: InstitutionLogoMark(
                imageUrl: 'https://api.kubus.site/uploads/institutions/l.png',
                size: 84,
                semanticLabel: 'Logo of Galerija Test',
              ),
            ),
          ),
        ),
      );
      final image =
          tester.widget<KubusCachedImage>(find.byType(KubusCachedImage));
      expect(image.fit, BoxFit.contain);
      expect(image.semanticLabel, 'Logo of Galerija Test');
      expect(
          tester
              .getSize(find.byKey(const ValueKey('institution-profile-image'))),
          const Size(84, 84));
      expect(tester.takeException(), isNull);
    });
  }
}
