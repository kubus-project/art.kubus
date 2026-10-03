import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/collab_invite.dart';
import 'package:art_kubus/models/collab_member.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/collab_provider.dart';
import 'package:art_kubus/providers/events_provider.dart';
import 'package:art_kubus/providers/exhibitions_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/saved_items_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/screens/events/event_detail_screen.dart';
import 'package:art_kubus/screens/events/exhibition_detail_screen.dart';
import 'package:art_kubus/services/collab_api.dart';
import 'package:art_kubus/widgets/unavailable_entity_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
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

Widget _wrap(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ExhibitionsProvider()),
      ChangeNotifierProvider(create: (_) => EventsProvider()),
      ChangeNotifierProvider(create: (_) => ProfileProvider()),
      ChangeNotifierProvider(create: (_) => SavedItemsProvider()),
      ChangeNotifierProvider(create: (_) => WalletProvider(deferInit: true)),
      ChangeNotifierProvider(create: (_) => ArtworkProvider()),
      ChangeNotifierProvider(
          create: (_) => CollabProvider(api: _FakeCollabApi())),
    ],
    child: MaterialApp(
      theme: ThemeData(splashFactory: InkSplash.splashFactory),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

/// Each BackendApiService call chains several 800ms secure-storage timeouts in
/// the fake-async zone; the window must cover all of them.
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
      'a missing event is reported as unavailable, not as an empty page',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(const EventDetailScreen(eventId: 'does-not-exist')),
    );
    await _settleNetwork(tester);

    expect(find.byType(UnavailableEntityScaffold), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    // The live-looking actions of a real event must not be offered.
    expect(find.text('Save'), findsNothing);
    expect(find.text('Share'), findsNothing);
  });

  testWidgets('a missing exhibition is reported as unavailable',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(const ExhibitionDetailScreen(exhibitionId: 'does-not-exist')),
    );
    await _settleNetwork(tester);

    expect(find.byType(UnavailableEntityScaffold), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Save'), findsNothing);
  });
}
