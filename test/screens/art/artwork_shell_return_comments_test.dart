import 'dart:async';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/models/artwork_comment.dart';
import 'package:art_kubus/models/saved_item.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/attendance_provider.dart';
import 'package:art_kubus/providers/main_tab_provider.dart';
import 'package:art_kubus/providers/map_deep_link_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/saved_items_provider.dart';
import 'package:art_kubus/providers/task_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/screens/art/art_detail_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/saved_items_repository.dart';
import 'package:art_kubus/services/share/share_deep_link_parser.dart';
import 'package:art_kubus/services/share/share_types.dart';
import 'package:art_kubus/utils/artwork_navigation.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/utils/share_deep_link_navigation.dart';
import 'package:art_kubus/widgets/detail/subject_action_group.dart';
import 'package:art_kubus/widgets/navigation/kubus_mobile_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _artworkId = 'ffffffff-ffff-4fff-8fff-ffffffffffff';

Artwork _artwork() => Artwork(
      id: _artworkId,
      title: 'Return-state artwork',
      artist: 'Test artist',
      description: 'A long description used by the detail scroll view.',
      position: const LatLng(0, 0),
      rewards: 0,
      createdAt: DateTime(2020),
    );

class _FakeArtworkApi implements ArtworkBackendApi {
  _FakeArtworkApi(this.artwork, {this.commentsFuture});

  final Artwork artwork;
  final Future<List<ArtworkComment>> Function()? commentsFuture;

  @override
  Future<Artwork> getArtwork(String artworkId) async => artwork;

  @override
  Future<int?> recordArtworkView(String artworkId) async => null;

  @override
  Future<List<ArtworkComment>> getArtworkComments({
    required String artworkId,
    int page = 1,
    int limit = 50,
  }) async =>
      await commentsFuture?.call() ?? const <ArtworkComment>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopSavedItemsRepository extends SavedItemsRepository {
  @override
  Future<bool> hasBackendSession() async => false;

  @override
  Future<Map<String, bool>> getSavedBatchStatus(
    Iterable<SavedItemRecord> items,
  ) async =>
      const <String, bool>{};
}

class _TestTab extends StatefulWidget {
  const _TestTab({super.key, required this.index, required this.onOpen});

  final int index;
  final Future<void> Function(BuildContext context) onOpen;

  @override
  State<_TestTab> createState() => _TestTabState();
}

class _TestTabState extends State<_TestTab> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('tab-${widget.index}-count-$_count'),
          TextButton(
            key: ValueKey('increment-${widget.index}'),
            onPressed: () => setState(() => _count++),
            child: const Text('Increment'),
          ),
          TextButton(
            key: ValueKey('open-${widget.index}'),
            onPressed: () => unawaited(widget.onOpen(context)),
            child: const Text('Open artwork'),
          ),
        ],
      ),
    );
  }
}

class _TestMobileShell extends StatelessWidget {
  const _TestMobileShell({required this.openArtworkFromTab});

  final Future<void> Function(BuildContext context, int index)
      openArtworkFromTab;

  static const _destinations = <KubusMobileNavigationDestination>[
    KubusMobileNavigationDestination(
      icon: Icons.explore_outlined,
      selectedIcon: Icons.explore,
      label: 'Map',
    ),
    KubusMobileNavigationDestination(
      icon: Icons.view_in_ar_outlined,
      selectedIcon: Icons.view_in_ar,
      label: 'AR',
    ),
    KubusMobileNavigationDestination(
      icon: Icons.people_outline,
      selectedIcon: Icons.people,
      label: 'Community',
    ),
    KubusMobileNavigationDestination(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: 'Home',
    ),
    KubusMobileNavigationDestination(
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<MainTabProvider>(
      builder: (context, tabs, _) => Scaffold(
        body: IndexedStack(
          index: tabs.index,
          children: [
            for (var index = 0; index < _destinations.length; index++)
              _TestTab(
                key: ValueKey('tab-$index'),
                index: index,
                onOpen: (context) => openArtworkFromTab(context, index),
              ),
          ],
        ),
        bottomNavigationBar: KubusMobileNavigationBar(
          destinations: _destinations,
          selectedIndex: tabs.index,
          onSelected: tabs.setIndex,
        ),
      ),
    );
  }
}

Widget _appHarness({
  required ArtworkProvider artworkProvider,
  required MainTabProvider tabs,
  required Widget home,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: artworkProvider),
      ChangeNotifierProvider.value(value: ProfileProvider()),
      ChangeNotifierProvider(
        create: (_) =>
            SavedItemsProvider(repository: _NoopSavedItemsRepository()),
      ),
      ChangeNotifierProvider(create: (_) => WalletProvider(deferInit: true)),
      ChangeNotifierProvider(create: (_) => TaskProvider()),
      ChangeNotifierProvider(create: (_) => AttendanceProvider()),
      ChangeNotifierProvider.value(value: tabs),
      ChangeNotifierProvider(create: (_) => MapDeepLinkProvider()),
    ],
    child: MaterialApp(
      theme: ThemeData(extensions: [KubusColorRoles.light]),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  for (final entry in const <int, String>{
    0: 'map',
    2: 'community',
    4: 'profile',
  }.entries) {
    testWidgets(
      'artwork opened from ${entry.value} returns to that shell tab',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final artwork = _artwork();
        final artworkProvider = ArtworkProvider(
          backendApi: _FakeArtworkApi(artwork),
        )..addOrUpdateArtwork(artwork);
        final tabs = MainTabProvider()..setIndex(entry.key);

        await tester.pumpWidget(
          _appHarness(
            artworkProvider: artworkProvider,
            tabs: tabs,
            home: _TestMobileShell(
              openArtworkFromTab: (context, _) =>
                  openArtwork(context, _artworkId, source: 'test_shell_entry'),
            ),
          ),
        );
        await tester.tap(find.byKey(ValueKey('increment-${entry.key}')));
        await tester.pump();
        await tester.tap(find.byKey(ValueKey('open-${entry.key}')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.byType(ArtDetailScreen), findsOneWidget);
        expect(tabs.index, entry.key);

        Navigator.of(tester.element(find.byType(ArtDetailScreen))).pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(tabs.index, entry.key);
        expect(find.byType(KubusMobileNavigationBar), findsOneWidget);
        expect(
          tester
              .widget<KubusMobileNavigationBar>(
                find.byType(KubusMobileNavigationBar),
              )
              .selectedIndex,
          entry.key,
        );
        expect(find.text('tab-${entry.key}-count-1'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('artwork deep link preserves the current tab and newer choices', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final artwork = _artwork();
    final artworkProvider = ArtworkProvider(
      backendApi: _FakeArtworkApi(artwork),
    )..addOrUpdateArtwork(artwork);
    final tabs = MainTabProvider()..setIndex(2);

    await tester.pumpWidget(
      _appHarness(
        artworkProvider: artworkProvider,
        tabs: tabs,
        home: _TestMobileShell(
          openArtworkFromTab: (context, _) => ShareDeepLinkNavigation.open(
            context,
            const ShareDeepLinkTarget(
              type: ShareEntityType.artwork,
              id: _artworkId,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open-2')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(ArtDetailScreen), findsOneWidget);
    expect(tabs.index, 2);

    // A newer navigation choice must not be undone when the detail route pops.
    tabs.setIndex(4);
    Navigator.of(tester.element(find.byType(ArtDetailScreen))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(tabs.index, 4);
    expect(
      tester
          .widget<KubusMobileNavigationBar>(
            find.byType(KubusMobileNavigationBar),
          )
          .selectedIndex,
      4,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('comments open scrolls to async-loaded comment content', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final artwork = _artwork();
    final commentsCompleter = Completer<List<ArtworkComment>>();
    final artworkProvider = ArtworkProvider(
      backendApi: _FakeArtworkApi(
        artwork,
        commentsFuture: () => commentsCompleter.future,
      ),
    )..addOrUpdateArtwork(artwork);

    await tester.pumpWidget(
      _appHarness(
        artworkProvider: artworkProvider,
        tabs: MainTabProvider(),
        home: ArtDetailScreen(artworkId: _artworkId),
      ),
    );
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find
          .byKey(const ValueKey('art-detail-comments-heading'))
          .evaluate()
          .isNotEmpty) {
        break;
      }
    }

    final l10n = AppLocalizations.of(
      tester.element(find.byType(ArtDetailScreen)),
    )!;
    final commentsAction = find.text(l10n.commonComments).first;
    await tester.scrollUntilVisible(
      commentsAction,
      420,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(commentsAction);
    await tester.pump();
    await tester.tap(commentsAction);
    await tester.pump();

    expect(artworkProvider.isLoading('load_comments_$_artworkId'), isTrue);

    final heading = find.byKey(const ValueKey('art-detail-comments-heading'));
    for (var frame = 0; frame < 12; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(heading, findsOneWidget);
    final headingRect = tester.getRect(heading);
    final scrollViewRect = tester.getRect(find.byType(CustomScrollView));
    expect(scrollViewRect.overlaps(headingRect), isTrue);

    commentsCompleter.complete([
      ArtworkComment(
        id: 'server-comment',
        artworkId: _artworkId,
        userId: '',
        userName: 'Mira',
        content: 'The asynchronously loaded comment is visible.',
        createdAt: DateTime(2024),
      ),
    ]);
    for (var frame = 0; frame < 12; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final comment = find.text('The asynchronously loaded comment is visible.');
    expect(comment, findsOneWidget);
    expect(scrollViewRect.overlaps(tester.getRect(comment)), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('closing comments before the next frame cancels pending scroll', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final artwork = _artwork();
    final commentsCompleter = Completer<List<ArtworkComment>>();
    final artworkProvider = ArtworkProvider(
      backendApi: _FakeArtworkApi(
        artwork,
        commentsFuture: () => commentsCompleter.future,
      ),
    )..addOrUpdateArtwork(artwork);

    await tester.pumpWidget(
      _appHarness(
        artworkProvider: artworkProvider,
        tabs: MainTabProvider(),
        home: ArtDetailScreen(artworkId: _artworkId),
      ),
    );
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final l10n = AppLocalizations.of(
      tester.element(find.byType(ArtDetailScreen)),
    )!;
    final commentsAction = find.text(l10n.commonComments).first;
    await tester.scrollUntilVisible(
      commentsAction,
      420,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(commentsAction);
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final scrollable = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    final startingOffset = scrollable.position.pixels;
    final commentsToggle = tester
        .widgetList<SubjectActionGroup>(find.byType(SubjectActionGroup))
        .expand((group) => group.actions)
        .singleWhere((action) => action.label == l10n.commonComments);

    // Both callbacks run before Flutter builds the open state, matching a
    // rapid open then close while the pending scroll waits for endOfFrame.
    commentsToggle.onPressed!();
    commentsToggle.onPressed!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.byKey(const ValueKey('art-detail-comments-heading')),
      findsNothing,
    );
    expect(scrollable.position.pixels, startingOffset);
    expect(artworkProvider.isLoading('load_comments_$_artworkId'), isTrue);
    expect(tester.takeException(), isNull);

    commentsCompleter.complete(const <ArtworkComment>[]);
    await tester.pump(const Duration(milliseconds: 50));
  });
}
