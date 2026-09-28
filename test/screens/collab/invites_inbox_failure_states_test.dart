import 'dart:io';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/collab_invite.dart';
import 'package:art_kubus/providers/collab_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/screens/collab/invites_inbox_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/collab_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Invite list API that fails with whatever [failure] holds, or returns
/// [inbox]. Only the inbox calls are exercised here.
class _ScriptedCollabApi implements CollabApi {
  Object? failure;
  List<CollabInvite> inbox = const <CollabInvite>[];
  int listCalls = 0;

  @override
  String? getAuthToken() => 'token';

  @override
  Future<List<CollabInvite>> listMyCollabInvites() async {
    listCalls++;
    final error = failure;
    if (error != null) throw error;
    return List<CollabInvite>.from(inbox);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

const _invite = CollabInvite(
  id: 'inv-1',
  entityType: 'exhibitions',
  entityId: 'ex-1',
  invitedUserId: 'u-me',
  invitedByUserId: 'u-ana',
  role: 'editor',
  status: 'pending',
);

BackendApiRequestException _status(int code) => BackendApiRequestException(
      statusCode: code,
      path: '/api/collab/invites',
      // Raw backend text that must never reach the screen.
      body: '{"error":"raw-backend-detail $code"}',
    );

Future<(CollabProvider, _ScriptedCollabApi, List<String>)> _pumpInbox(
  WidgetTester tester, {
  Object? failure,
  List<CollabInvite> inbox = const <CollabInvite>[],
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final api = _ScriptedCollabApi()
    ..failure = failure
    ..inbox = inbox;
  final provider = CollabProvider(api: api);
  addTearDown(provider.dispose);
  _live.add(provider);
  final pushed = <String>[];
  tester.view.physicalSize = const Size(390, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ChangeNotifierProvider<CollabProvider>.value(
      value: provider,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeProvider().lightTheme,
        onGenerateRoute: (settings) {
          pushed.add(settings.name ?? '');
          return MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('sign-in route')),
          );
        },
        home: const Scaffold(body: InvitesInboxScreen(embedded: true)),
      ),
    ),
  );
  // Post-frame refresh, then the async failure settles.
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  return (provider, api, pushed);
}

final List<CollabProvider> _live = <CollabProvider>[];

/// A load starts the provider's real invite polling timer; stop it before
/// flutter_test verifies that no timers are pending (teardown runs later).
void _inboxTest(String description, Future<void> Function(WidgetTester) body) {
  testWidgets(description, (tester) async {
    try {
      await body(tester);
    } finally {
      for (final provider in _live) {
        provider.stopInvitePolling();
      }
      _live.clear();
    }
  });
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(InvitesInboxScreen)))!;

void _expectNoRawFailureText() {
  expect(find.textContaining('raw-backend-detail'), findsNothing);
  expect(find.textContaining('BackendApiRequestException'), findsNothing);
  expect(find.textContaining('SocketException'), findsNothing);
  expect(find.textContaining('Invites temporarily unavailable'), findsNothing);
}

void main() {
  group('invite inbox failure taxonomy', () {
    _inboxTest('401 renders authentication with a Sign in action',
        (tester) async {
      final (provider, _, pushed) =
          await _pumpInbox(tester, failure: _status(401));
      final l10n = _l10n(tester);
      expect(provider.invitesError, isA<BackendApiRequestException>());
      expect(find.text(l10n.stateAuthTitle), findsOneWidget);
      expect(find.text(l10n.stateNetworkTitle), findsNothing);
      expect(find.text(l10n.commonRetry), findsNothing);
      _expectNoRawFailureText();

      await tester.tap(find.text(l10n.commonSignIn));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(pushed, contains('/sign-in'));
    });

    _inboxTest('403 renders permission with no retry loop', (tester) async {
      await _pumpInbox(tester, failure: _status(403));
      final l10n = _l10n(tester);
      expect(find.text(l10n.statePermissionTitle), findsOneWidget);
      expect(find.text(l10n.stateNetworkTitle), findsNothing);
      expect(find.text(l10n.commonRetry), findsNothing);
      expect(find.text(l10n.commonSignIn), findsNothing);
      _expectNoRawFailureText();
    });

    _inboxTest('503 renders server with Retry that reloads', (tester) async {
      final (provider, api, _) =
          await _pumpInbox(tester, failure: _status(503));
      final l10n = _l10n(tester);
      expect(find.text(l10n.stateServerTitle), findsOneWidget);
      expect(find.text(l10n.stateNetworkTitle), findsNothing);
      _expectNoRawFailureText();

      final before = api.listCalls;
      api.failure = null;
      await tester.tap(find.text(l10n.commonRetry));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(api.listCalls, before + 1);
      expect(provider.invitesError, isNull);
      expect(find.text(l10n.stateServerTitle), findsNothing);
      expect(find.text(l10n.collabEmptyTitle), findsOneWidget);
    });

    _inboxTest('socket failure renders network with Retry', (tester) async {
      await _pumpInbox(
        tester,
        failure: const SocketException('Connection refused'),
      );
      final l10n = _l10n(tester);
      expect(find.text(l10n.stateNetworkTitle), findsOneWidget);
      expect(find.text(l10n.commonRetry), findsOneWidget);
      _expectNoRawFailureText();
    });

    _inboxTest('host lookup failure renders offline with Retry',
        (tester) async {
      await _pumpInbox(
        tester,
        failure: const SocketException('Failed host lookup: api.kubus.site'),
      );
      final l10n = _l10n(tester);
      expect(find.text(l10n.stateOfflineTitle), findsOneWidget);
      expect(find.text(l10n.commonRetry), findsOneWidget);
      _expectNoRawFailureText();
    });

    _inboxTest('empty inbox stays the empty state, not an error',
        (tester) async {
      final (provider, _, _) = await _pumpInbox(tester);
      final l10n = _l10n(tester);
      expect(provider.invitesError, isNull);
      expect(find.text(l10n.collabEmptyTitle), findsOneWidget);
      expect(find.text(l10n.stateNetworkTitle), findsNothing);
    });

    _inboxTest('loaded invites stay visible; a later 403 is a compact state',
        (tester) async {
      final (provider, api, _) =
          await _pumpInbox(tester, inbox: const <CollabInvite>[_invite]);
      final l10n = _l10n(tester);
      expect(find.byType(InviteRow), findsOneWidget);

      api.failure = _status(403);
      await provider.refreshInvites();
      await tester.pump();
      expect(find.byType(InviteRow), findsOneWidget);
      expect(find.text(l10n.statePermissionTitle), findsOneWidget);
      expect(find.text(l10n.stateNetworkTitle), findsNothing);
      _expectNoRawFailureText();
    });
  });
}
