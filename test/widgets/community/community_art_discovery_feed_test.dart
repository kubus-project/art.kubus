import 'package:art_kubus/community/art_discovery.dart';
import 'package:art_kubus/community/community_interactions.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/models/exhibition.dart';
import 'package:art_kubus/models/profile_identity_data.dart';
import 'package:art_kubus/providers/community_art_discovery_provider.dart';
import 'package:art_kubus/widgets/community/community_art_discovery_feed.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

final DateTime _now = DateTime.utc(2026, 10, 11, 12);

CommunityPost _post(int i) => CommunityPost(
      id: 'p$i',
      authorIdentityData: ProfileIdentityData.fromCompactAuthor(
        {'displayName': 'w$i', 'username': 'w$i', 'walletAddress': 'w$i'},
        fallbackLabel: 'x',
      ),
      content: 'post number $i',
      timestamp: _now.subtract(Duration(minutes: i)),
    );

ArtDiscoverySources _sources(int count) => ArtDiscoverySources(
      artFeed: (lat, lng, radius, {int limit = 30}) async => const [],
      publicPosts: ({int limit = 30}) async =>
          [for (var i = 0; i < count; i++) _post(i)],
      artworks: () async => const <Artwork>[],
      exhibitions: (location, radius) async => const <Exhibition>[],
      signals: () async => ArtDiscoverySignals.none,
      selectedArea: () => null,
      mapCenter: () => null,
      deviceLocation: ({required bool prompt}) async => null,
      savedLocation: () async => null,
      saveLocation: (l) async {},
      now: () => _now,
    );

Future<CommunityArtDiscoveryProvider> _pump(
  WidgetTester tester, {
  bool Function(ArtDiscoveryItem item)? Function(
          CommunityArtDiscoveryProvider provider)?
      matchesFor,
  bool Function(ArtDiscoveryItem item)? matches,
}) async {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final provider = CommunityArtDiscoveryProvider(pageSize: 12);
  await provider.refresh(_sources(40));
  await tester.pumpWidget(
    ChangeNotifierProvider<CommunityArtDiscoveryProvider>.value(
      value: provider,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CommunityArtDiscoveryFeed(
            postBuilder: (context, post) =>
                SizedBox(height: 24, child: Text(post.content)),
            onRefresh: () async {},
            onUseMyLocation: () async {},
            matches: matchesFor?.call(provider) ?? matches,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return provider;
}

void main() {
  testWidgets('the only match, ranked last, is shown and needs no paging',
      (tester) async {
    final provider = await _pump(
      tester,
      matchesFor: (p) {
        final lastKey = p.allItems.last.key;
        return (item) => item.key == lastKey;
      },
    );
    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
    final last = provider.allItems.last;
    expect(provider.items.map((i) => i.key), isNot(contains(last.key)),
        reason: 'it is beyond the first page of 12');
    expect(find.text(last.post!.content), findsOneWidget);
    expect(find.text(l10n.communityArtDiscoveryLoadMore), findsNothing);
  });

  testWidgets('more matches than one page still offer Load more',
      (tester) async {
    final provider = await _pump(
      tester,
      matches: (item) => item.post!.content.contains('post'),
    );
    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
    expect(provider.visibleItems((i) => true), hasLength(12));
    expect(find.text(l10n.communityArtDiscoveryLoadMore), findsOneWidget);
  });

  testWidgets('a search with no match says so instead of going blank',
      (tester) async {
    await _pump(tester, matches: (item) => false);
    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
    expect(find.text(l10n.commonNoResultsFound), findsOneWidget);
    expect(find.text(l10n.communityArtDiscoveryLoadMore), findsNothing);
  });
}
