import 'package:art_kubus/providers/community_hub_provider.dart';
import 'package:art_kubus/providers/main_tab_provider.dart';
import 'package:art_kubus/services/share/share_types.dart';
import 'package:art_kubus/utils/share_create_post_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  const artworkId = '11111111-1111-4111-8111-111111111111';
  const markerId = '22222222-2222-4222-8222-222222222222';

  testWidgets('share artwork to community switches to community tab and seeds draft',
      (tester) async {
    final tabs = MainTabProvider();
    final hub = CommunityHubProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: tabs),
          ChangeNotifierProvider.value(value: hub),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () {
                      // ignore: discarded_futures
                      ShareCreatePostLauncher.openComposerForShare(
                        context,
                        ShareTarget.artwork(
                          artworkId: artworkId,
                          title: 'Sunset Cube',
                        ),
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();

    expect(tabs.index, 2);
    expect(hub.composerOpenNonce, greaterThan(0));
    expect(hub.draft.category, 'art_drop');
    expect(hub.draft.subjectType, 'artwork');
    expect(hub.draft.subjectId, artworkId);
    expect(hub.draft.artwork?.id, artworkId);
    expect(hub.draft.artwork?.title, 'Sunset Cube');
  });

  testWidgets('share marker to community seeds subject and switches tab',
      (tester) async {
    final tabs = MainTabProvider();
    final hub = CommunityHubProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: tabs),
          ChangeNotifierProvider.value(value: hub),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () {
                      // ignore: discarded_futures
                      ShareCreatePostLauncher.openComposerForShare(
                        context,
                        ShareTarget.marker(
                          markerId: markerId,
                          title: 'City Marker',
                        ),
                      );
                    },
                    child: const Text('open marker'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open marker'));
    await tester.pump();

    expect(tabs.index, 2);
    expect(hub.composerOpenNonce, greaterThan(0));
    expect(hub.draft.subjectType, 'marker');
    expect(hub.draft.subjectId, markerId);
  });
}
