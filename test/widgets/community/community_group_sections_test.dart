import 'dart:async';
import 'dart:convert';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/community_hub_provider.dart';
import 'package:art_kubus/services/account_identity.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/widgets/community/community_group_card.dart';
import 'package:art_kubus/widgets/community/community_group_sections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/secure_storage_absent.dart';

const _account = '6f1c1d2e-3a4b-4c5d-8e9f-0a1b2c3d4e5f';

final _l10n = lookupAppLocalizations(const Locale('en'));

Map<String, Object?> _groupJson(
  String id, {
  bool isMember = false,
  int memberCount = 3,
}) {
  return {
    'id': id,
    'name': 'Group $id',
    'isPublic': true,
    'ownerWallet': '',
    'memberCount': memberCount,
    'isMember': isMember,
    'isOwner': false,
  };
}

http.Response _json(Object body, {int status = 200}) => http.Response(
      jsonEncode(body),
      status,
      headers: const {'content-type': 'application/json'},
    );

String _jwt(String userId) {
  String b64(Map<String, Object?> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp = DateTime.now().add(const Duration(hours: 1));
  return '${b64({'alg': 'none'})}.'
      '${b64({
        'user_id': userId,
        'exp': exp.millisecondsSinceEpoch ~/ 1000
      })}.sig';
}

/// Serves the group list and join endpoints from [joinStatus] / [joinBody].
MockClient _api({int joinStatus = 200, Map<String, Object?>? joinBody}) {
  return MockClient((request) async {
    if (request.method == 'POST' && request.url.path.endsWith('/join')) {
      return _json(
        joinBody ??
            {
              'success': true,
              'joined': true,
              'message': 'Joined',
              'data': _groupJson('g-open', isMember: true, memberCount: 4),
            },
        status: joinStatus,
      );
    }
    return _json({
      'success': true,
      'page': 1,
      'count': 2,
      'total': 2,
      'data': [
        _groupJson('g-open'),
        _groupJson('g-joined', isMember: true, memberCount: 5),
      ],
    });
  });
}

/// The Groups list as the mobile tab builds it: the sections widget with a card
/// whose Join action goes through the real hub. A failed join is caught here
/// as the screen's handler does, so the list keeps its last state.
Widget _host(CommunityHubProvider hub) {
  return ChangeNotifierProvider<CommunityHubProvider>.value(
    value: hub,
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Consumer<CommunityHubProvider>(
          builder: (context, hub, _) => ListView(
            children: [
              CommunityGroupSections(
                joinedGroups: hub.joinedGroups,
                discoverableGroups: hub.discoverableGroups,
                cardBuilder: (group) => CommunityGroupCard(
                  group: group,
                  accentColor: Colors.teal,
                  variant: CommunityGroupCardVariant.mobile,
                  onOpenGroupFeed: () {},
                  onToggleMembership: () {
                    unawaited(
                        hub.joinGroup(group.id).catchError((Object _) {}));
                  },
                  timeAgoBuilder: (_) => '',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  installEmptySecureStorage();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AccountIdentity.setAccountKey(_account);
    BackendApiService()
      ..setPreferredWalletAddress(null, persist: false)
      ..setAuthTokenForTesting(_jwt(_account));
  });

  tearDown(() {
    AccountIdentity.setAccountKey('');
    BackendApiService()
      ..setAuthTokenForTesting(null)
      ..setPreferredWalletAddress(null, persist: false);
  });

  Future<CommunityHubProvider> loadedHub(MockClient client) async {
    final hub = CommunityHubProvider(
      apiService: BackendApiService()..setHttpClient(client),
    );
    await hub.loadGroups();
    return hub;
  }

  testWidgets(
      'public groups not joined are listed under a discover heading with a Join action',
      (tester) async {
    final hub = await loadedHub(_api());
    addTearDown(hub.dispose);

    await tester.pumpWidget(_host(hub));
    await tester.pumpAndSettle();

    expect(
        find.text(_l10n.communityGroupsDiscoverSectionTitle), findsOneWidget);
    expect(find.text(_l10n.communityGroupsJoinedSectionTitle), findsOneWidget);
    expect(find.text('Group g-open'), findsOneWidget);
    expect(find.text(_l10n.commonJoin), findsOneWidget);
    expect(find.text(_l10n.commonJoined), findsOneWidget);
  });

  testWidgets(
      'a successful join moves the group under Your groups with the new member count',
      (tester) async {
    final hub = await loadedHub(_api());
    addTearDown(hub.dispose);
    await tester.pumpWidget(_host(hub));
    await tester.pumpAndSettle();

    await tester.tap(find.text(_l10n.commonJoin));
    await tester.pumpAndSettle();

    expect(find.text(_l10n.communityGroupsDiscoverSectionTitle), findsNothing);
    expect(find.text(_l10n.commonJoin), findsNothing);
    expect(find.text(_l10n.commonJoined), findsNWidgets(2));
    expect(find.text(_l10n.commonMembersCount(4)), findsOneWidget);
    expect(find.text(_l10n.commonMembersCount(5)), findsOneWidget);
  });

  testWidgets(
      'a failed join keeps the group under discover with its Join action',
      (tester) async {
    final hub = await loadedHub(_api(
      joinStatus: 403,
      joinBody: {'success': false, 'error': 'Forbidden'},
    ));
    addTearDown(hub.dispose);
    await tester.pumpWidget(_host(hub));
    await tester.pumpAndSettle();

    await tester.tap(find.text(_l10n.commonJoin));
    await tester.pumpAndSettle();

    expect(
        find.text(_l10n.communityGroupsDiscoverSectionTitle), findsOneWidget);
    expect(find.text(_l10n.commonJoin), findsOneWidget);
    expect(find.text(_l10n.commonMembersCount(3)), findsOneWidget);
  });
}
