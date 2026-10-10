import 'package:art_kubus/utils/media_url_resolver.dart';
import 'package:art_kubus/widgets/community/community_search_institution_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// One institution row exactly as the migrated backend sends it.
Map<String, dynamic> _row({
  Object? institutionType,
  Object? location = 'Ljubljana',
  Object? bannerUrl,
  Object? logoUrl,
  Object? artworkCount,
  Object? name = 'Moderna galerija',
}) =>
    {
      'type': 'institution',
      'id': 'inst-moderna',
      'name': name,
      'description': 'Contemporary art',
      'institutionType': institutionType,
      'website': null,
      'location': location,
      'coordinates': null,
      'logoUrl': logoUrl,
      'bannerUrl': bannerUrl,
      'artworkCount': artworkCount,
    };

Future<void> _pump(
  WidgetTester tester,
  Map<String, dynamic> row, {
  VoidCallback? onTap,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: CommunitySearchInstitutionTile(
          institution: row,
          accentColor: const Color(0xFF00897B),
          fallbackName: 'Institution',
          onTap: onTap ?? () {},
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('shows the name and the location, never the kind literal',
      (tester) async {
    await _pump(tester, _row());

    expect(find.text('Moderna galerija'), findsOneWidget);
    expect(find.text('Ljubljana'), findsOneWidget);
    expect(find.text('institution'), findsNothing);
  });

  testWidgets('joins a present institution type with the location',
      (tester) async {
    await _pump(tester, _row(institutionType: 'museum'));

    expect(find.text('museum - Ljubljana'), findsOneWidget);
  });

  testWidgets('tolerates null institutionType and artworkCount',
      (tester) async {
    await _pump(
      tester,
      _row(institutionType: null, artworkCount: null, location: null),
    );

    expect(find.text('Moderna galerija'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('falls back to the fallback name when the name is blank',
      (tester) async {
    await _pump(tester, _row(name: '   '));

    expect(find.text('Institution'), findsOneWidget);
  });

  testWidgets('renders the banner cover through MediaUrlResolver',
      (tester) async {
    const banner = '/uploads/institutions/inst-moderna/banner.jpg';
    await _pump(tester, _row(bannerUrl: banner, logoUrl: '/logo.png'));

    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as NetworkImage;
    expect(
      provider.url,
      MediaUrlResolver.resolveDisplayUrl(banner) ??
          MediaUrlResolver.resolve(banner),
    );
  });

  testWidgets('falls back to the logo, then to the kind icon', (tester) async {
    const logo = '/uploads/institutions/inst-moderna/logo.png';
    await _pump(tester, _row(bannerUrl: null, logoUrl: logo));
    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as NetworkImage).url,
      MediaUrlResolver.resolveDisplayUrl(logo) ??
          MediaUrlResolver.resolve(logo),
    );

    await _pump(tester, _row(bannerUrl: null, logoUrl: null));
    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.location_city), findsOneWidget);
  });

  testWidgets('tapping the row calls onTap', (tester) async {
    var taps = 0;
    await _pump(tester, _row(), onTap: () => taps++);

    await tester.tap(find.text('Moderna galerija'));
    expect(taps, 1);
  });
}
