import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/collab_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/screens/activity/view_history_screen.dart';
import 'package:art_kubus/screens/collab/invites_inbox_screen.dart';
import 'package:art_kubus/services/collab_api.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/models/collab_invite.dart';
import 'package:art_kubus/models/collab_member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeCollabApi implements CollabApi {
  @override
  Future<void> acceptInvite(String inviteId) async {}

  @override
  Future<void> declineInvite(String inviteId) async {}

  @override
  String? getAuthToken() => 'test-token';

  @override
  Future<CollabInvite?> inviteCollaborator(
    String entityType,
    String entityId,
    String invitedIdentifier,
    String role,
  ) async =>
      null;

  @override
  Future<List<CollabMember>> listCollaborators(
    String entityType,
    String entityId,
  ) async =>
      const <CollabMember>[];

  @override
  Future<List<CollabInvite>> listMyCollabInvites() async =>
      const <CollabInvite>[];

  @override
  Future<void> removeCollaborator(
    String entityType,
    String entityId,
    String memberUserId,
  ) async {}

  @override
  Future<void> updateCollaboratorRole(
    String entityType,
    String entityId,
    String memberUserId,
    String role,
  ) async {}
}

Widget _wrapWithApp(Widget child) {
  return ChangeNotifierProvider(
    create: (_) => ThemeProvider(),
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
      'ViewHistoryScreen uses shared title sizing and hides chrome when embedded',
      (tester) async {
    final provider = ArtworkProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider<ArtworkProvider>.value(
        value: provider,
        child: _wrapWithApp(const ViewHistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final title = tester.widget<Text>(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('View history'),
      ),
    );
    expect(title.style?.fontSize, KubusHeaderMetrics.screenTitle);
    expect(find.byType(AppBar), findsOneWidget);

    await tester.pumpWidget(
      ChangeNotifierProvider<ArtworkProvider>.value(
        value: provider,
        child: _wrapWithApp(const ViewHistoryScreen(embedded: true)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets(
      'InvitesInboxScreen uses shared title sizing and suppresses standalone chrome when embedded',
      (tester) async {
    final provider = CollabProvider(api: _FakeCollabApi());

    await tester.pumpWidget(
      ChangeNotifierProvider<CollabProvider>.value(
        value: provider,
        child: _wrapWithApp(const InvitesInboxScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final title = tester.widget<Text>(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Invites'),
      ),
    );
    expect(title.style?.fontSize, KubusHeaderMetrics.screenTitle);
    expect(find.byType(AppBar), findsOneWidget);

    await tester.pumpWidget(
      ChangeNotifierProvider<CollabProvider>.value(
        value: provider,
        child: _wrapWithApp(const InvitesInboxScreen(embedded: true)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsNothing);
    expect(find.text('Collaboration invites'), findsNothing);
  });
}
