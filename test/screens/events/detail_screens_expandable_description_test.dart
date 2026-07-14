import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/collab_invite.dart';
import 'package:art_kubus/models/collab_member.dart';
import 'package:art_kubus/models/event.dart';
import 'package:art_kubus/models/exhibition.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/collab_provider.dart';
import 'package:art_kubus/providers/events_provider.dart';
import 'package:art_kubus/providers/exhibitions_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/screens/events/event_detail_screen.dart';
import 'package:art_kubus/screens/events/exhibition_detail_screen.dart';
import 'package:art_kubus/screens/events/exhibition_list_screen.dart';
import 'package:art_kubus/services/collab_api.dart';
import 'package:art_kubus/widgets/detail/expandable_detail_text.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeCollabApi implements CollabApi {
  @override
  String? getAuthToken() => null;

  @override
  Future<List<CollabMember>> listCollaborators(
          String entityType, String entityId) async =>
      const <CollabMember>[];

  @override
  Future<List<CollabInvite>> listMyCollabInvites() async =>
      const <CollabInvite>[];

  @override
  Future<CollabInvite?> inviteCollaborator(String entityType, String entityId,
      String invitedIdentifier, String role) {
    throw UnimplementedError();
  }

  @override
  Future<void> acceptInvite(String inviteId) {
    throw UnimplementedError();
  }

  @override
  Future<void> declineInvite(String inviteId) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateCollaboratorRole(
      String entityType, String entityId, String memberUserId, String role) {
    throw UnimplementedError();
  }

  @override
  Future<void> removeCollaborator(
      String entityType, String entityId, String memberUserId) {
    throw UnimplementedError();
  }
}

final String _longDescription = List.generate(
  40,
  (i) =>
      'Paragraph $i of a long curatorial description outlining the themes, '
      'artists, and program of this presentation in considerable depth.',
).join('\n');

Widget _wrap({
  required Widget child,
  List<SingleChildWidget> extraProviders = const <SingleChildWidget>[],
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ExhibitionsProvider()),
      ChangeNotifierProvider(create: (_) => EventsProvider()),
      ChangeNotifierProvider(create: (_) => ProfileProvider()),
      ChangeNotifierProvider(create: (_) => WalletProvider(deferInit: true)),
      ChangeNotifierProvider(create: (_) => ArtworkProvider()),
      ChangeNotifierProvider(create: (_) => CollabProvider(api: _FakeCollabApi())),
      ...extraProviders,
    ],
    child: MaterialApp(
      // InkSparkle's fragment shader cannot load in the widget-test
      // environment.
      theme: ThemeData(splashFactory: InkSplash.splashFactory),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

/// Pump enough fake time for post-frame loads to run their course. Each
/// BackendApiService call chains several 800ms secure-storage timeouts in the
/// fake-async zone, so the window must cover all of them or the test fails
/// with pending timers.
Future<void> _settleNetwork(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 850));
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
      'ExhibitionDetailScreen clamps a long description and expands it',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final exhibition = Exhibition(
      id: 'ex-1',
      title: 'Long Form Exhibition',
      description: _longDescription,
    );

    await tester.pumpWidget(
      _wrap(
        child: ExhibitionDetailScreen(
          exhibitionId: 'ex-1',
          initialExhibition: exhibition,
          embedded: true,
        ),
      ),
    );
    await _settleNetwork(tester);

    final l10n = AppLocalizations.of(
        tester.element(find.byType(ExhibitionDetailScreen)))!;

    expect(find.byType(ExpandableDetailText), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text(l10n.detailShowMore),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text(l10n.detailShowMore), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(l10n.detailShowLess), findsOneWidget);
    await _settleNetwork(tester);
  });

  testWidgets('EventDetailScreen clamps a long description and expands it',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final event = KubusEvent(
      id: 'ev-1',
      title: 'Long Form Event',
      description: _longDescription,
    );

    await tester.pumpWidget(
      _wrap(
        child: EventDetailScreen(eventId: 'ev-1', initialEvent: event),
      ),
    );
    await _settleNetwork(tester);

    final l10n =
        AppLocalizations.of(tester.element(find.byType(EventDetailScreen)))!;

    expect(find.byType(ExpandableDetailText), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text(l10n.detailShowMore),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text(l10n.detailShowMore), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(l10n.detailShowLess), findsOneWidget);
    await _settleNetwork(tester);
  });

  testWidgets('ExhibitionListScreen create header uses a LiquidGlass surface',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        extraProviders: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: const ExhibitionListScreen(embedded: true, canCreate: true),
      ),
    );
    await _settleNetwork(tester);

    expect(find.byType(LiquidGlassCard), findsWidgets);
  });
}
