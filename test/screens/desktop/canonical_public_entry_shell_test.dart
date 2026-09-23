import 'package:art_kubus/providers/public_entity_takeover_provider.dart';
import 'package:art_kubus/screens/desktop/desktop_shell_scope.dart';
import 'package:art_kubus/services/share/share_deep_link_parser.dart';
import 'package:art_kubus/services/share/share_types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('matchesCanonicalPublicEntry', () {
    test('accepts the exact localized artwork route and stable ID', () {
      final requested = ShareDeepLinkTarget(
        type: ShareEntityType.artwork,
        id: 'artwork-1',
        localeCode: 'en',
      );

      expect(
        matchesCanonicalPublicEntry(
          seededTarget: const PublicEntityTakeoverTarget(
            type: 'artwork',
            id: 'artwork-1',
            path: '/en/artworks/artwork-1',
            browserRoute: '/en/artworks/artwork-1',
          ),
          requestedTarget: requested,
        ),
        isTrue,
      );
    });

    test('accepts Slovenian profile route but rejects a different locale path',
        () {
      final requested = ShareDeepLinkTarget(
        type: ShareEntityType.profile,
        id: 'profile-1',
        localeCode: 'sl',
      );

      expect(
        matchesCanonicalPublicEntry(
          seededTarget: const PublicEntityTakeoverTarget(
            type: 'profile',
            id: 'profile-1',
            path: '/sl/profili/profile-1',
            browserRoute: '/sl/profili/profile-1',
          ),
          requestedTarget: requested,
        ),
        isTrue,
      );
      expect(
        matchesCanonicalPublicEntry(
          seededTarget: const PublicEntityTakeoverTarget(
            type: 'profile',
            id: 'profile-1',
            path: '/en/profiles/profile-1',
            browserRoute: '/en/profiles/profile-1',
          ),
          requestedTarget: requested,
        ),
        isFalse,
      );
    });

    test('rejects a mismatched entity ID or type', () {
      const seeded = PublicEntityTakeoverTarget(
        type: 'event',
        id: 'event-1',
        path: '/en/events/event-1',
        browserRoute: '/en/events/event-1',
      );

      expect(
        matchesCanonicalPublicEntry(
          seededTarget: seeded,
          requestedTarget: const ShareDeepLinkTarget(
            type: ShareEntityType.event,
            id: 'event-2',
            localeCode: 'en',
          ),
        ),
        isFalse,
      );
      expect(
        matchesCanonicalPublicEntry(
          seededTarget: seeded,
          requestedTarget: const ShareDeepLinkTarget(
            type: ShareEntityType.exhibition,
            id: 'event-1',
            localeCode: 'en',
          ),
        ),
        isFalse,
      );
    });

    test('does not enable the public presentation for marker routes', () {
      expect(
        matchesCanonicalPublicEntry(
          seededTarget: const PublicEntityTakeoverTarget(
            type: 'marker',
            id: 'marker-1',
            path: '/en/map/marker-1',
            browserRoute: '/en/map/marker-1',
          ),
          requestedTarget: const ShareDeepLinkTarget(
            type: ShareEntityType.marker,
            id: 'marker-1',
            localeCode: 'en',
          ),
        ),
        isFalse,
      );
    });

    test('rejects non-canonical aliases even for the same entity identity', () {
      expect(
        matchesCanonicalPublicEntry(
          seededTarget: const PublicEntityTakeoverTarget(
            type: 'artwork',
            id: 'artwork-1',
            path: '/en/artworks/artwork-1',
            browserRoute: '/en/artworks/artwork-1',
          ),
          requestedTarget: const ShareDeepLinkTarget(
            type: ShareEntityType.artwork,
            id: 'artwork-1',
            localeCode: 'en',
          ),
        ),
        isTrue,
      );
      expect(
        matchesCanonicalPublicEntry(
          seededTarget: const PublicEntityTakeoverTarget(
            type: 'artwork',
            id: 'artwork-1',
            path: '/u/artwork-1',
            browserRoute: '/u/artwork-1',
          ),
          requestedTarget: const ShareDeepLinkTarget(
            type: ShareEntityType.artwork,
            id: 'artwork-1',
            localeCode: 'en',
          ),
        ),
        isFalse,
      );
    });
  });

  testWidgets(
      'public entry subscreen exposes navigation without reserving rail',
      (tester) async {
    var openCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: DesktopShellScope(
          pushScreen: (_) {},
          popScreen: () {},
          navigateToRoute: (_) {},
          openNotifications: () {},
          openFunctionsPanel: (_, {content}) {},
          setFunctionsPanelContent: (_) {},
          closeFunctionsPanel: () {},
          canPop: true,
          isCanonicalPublicEntry: true,
          onOpenPublicEntryNavigation: () => openCount += 1,
          child: const DesktopSubScreen(
            title: 'Artwork',
            child: Text('Public content'),
          ),
        ),
      ),
    );

    expect(find.text('art.kubus'), findsOneWidget);
    expect(find.text('Artwork'), findsNothing);
    expect(find.byIcon(Icons.menu), findsOneWidget);
    await tester.tap(find.byIcon(Icons.menu));
    expect(openCount, 1);
    expect(find.text('Public content'), findsOneWidget);
  });

  testWidgets('clearing public-entry state restores the ordinary shell header',
      (tester) async {
    final publicEntryMode = ValueNotifier<bool>(true);

    Widget buildShell() => MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: publicEntryMode,
            builder: (context, isPublicEntry, _) => DesktopShellScope(
              pushScreen: (_) {},
              popScreen: () {},
              navigateToRoute: (_) {},
              openNotifications: () {},
              openFunctionsPanel: (_, {content}) {},
              setFunctionsPanelContent: (_) {},
              closeFunctionsPanel: () {},
              canPop: true,
              isCanonicalPublicEntry: isPublicEntry,
              onOpenPublicEntryNavigation: () {},
              child: const DesktopSubScreen(
                title: 'Artwork',
                child: Text('Public content'),
              ),
            ),
          ),
        );

    await tester.pumpWidget(buildShell());
    expect(find.text('art.kubus'), findsOneWidget);
    expect(find.byIcon(Icons.menu), findsOneWidget);

    publicEntryMode.value = false;
    await tester.pump();

    expect(find.text('Artwork'), findsOneWidget);
    expect(find.text('art.kubus'), findsNothing);
    expect(find.byIcon(Icons.menu), findsNothing);
    expect(find.text('Public content'), findsOneWidget);
    publicEntryMode.dispose();
  });
}
