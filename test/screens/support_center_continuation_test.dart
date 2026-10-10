import 'dart:convert';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/pending_action_intent.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/pending_action_provider.dart';
import 'package:art_kubus/providers/saved_items_provider.dart';
import 'package:art_kubus/providers/support_center_provider.dart';
import 'package:art_kubus/screens/support_center_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:art_kubus/widgets/auth/pending_action_continuation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shape-only session token; the backend is faked, so only presence matters.
const _authToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
    'eyJleHAiOjQ3MzM4NTYwMDAsIndhbGxldEFkZHJlc3MiOiJXYWxsZXRUZXN0MTExMTExMTExMTExMTExMTExMTExMTExMTExMSJ9.'
    'signature';

BackendApiService get api => BackendApiService();

http.Response _ok(Object? data, {int status = 200}) => http.Response(
      jsonEncode(<String, Object?>{'success': true, 'data': data}),
      status,
      headers: {'content-type': 'application/json'},
    );

Map<String, Object?> _ticket({String id = 'ticket-1'}) => <String, Object?>{
      'id': id,
      'subject': 'Login help',
      'message': 'I cannot sign in on Android.',
      'kind': 'support',
      'status': 'open',
      'priority': 'normal',
      'created_at': '2026-10-10T09:00:00.000Z',
      'updated_at': '2026-10-10T09:00:00.000Z',
      'messages': <Map<String, Object?>>[
        <String, Object?>{
          'id': null,
          'sender_type': 'user',
          'message': 'I cannot sign in on Android.',
          'created_at': '2026-10-10T09:00:00.000Z',
        },
      ],
    };

/// Stands in for the sign-in route. Completing it establishes the session and
/// then does what PostAuthCoordinator does: restore the interrupted intent and
/// return to its route with the intent's arguments.
class _FakeSignIn extends StatelessWidget {
  const _FakeSignIn({required this.pending});

  final PendingActionProvider pending;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () async {
            api.setAuthTokenForTesting(_authToken);
            await pending.restore();
            final args =
                pending.pending?.returnArguments ?? const <String, String>{};
            if (!context.mounted) return;
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/support',
              (_) => false,
              arguments: args,
            );
          },
          child: const Text('Complete sign-in'),
        ),
      ),
    );
  }
}

Widget _app({
  required GlobalKey<NavigatorState> navKey,
  required SupportCenterProvider support,
  required PendingActionProvider pending,
  required ArtworkProvider artworks,
  required SavedItemsProvider saved,
  required Widget home,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SupportCenterProvider>.value(value: support),
      ChangeNotifierProvider<PendingActionProvider>.value(value: pending),
      ChangeNotifierProvider<ArtworkProvider>.value(value: artworks),
      ChangeNotifierProvider<SavedItemsProvider>.value(value: saved),
    ],
    child: MaterialApp(
      navigatorKey: navKey,
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      builder: (context, child) => PendingActionContinuationHost(
        navigatorKey: navKey,
        child: child ?? const SizedBox.shrink(),
      ),
      routes: <String, WidgetBuilder>{
        '/sign-in': (_) => _FakeSignIn(pending: pending),
      },
      // Same mapping as main.dart's '/support' route.
      onGenerateRoute: (settings) {
        if (settings.name != '/support') return null;
        final args = settings.arguments;
        final map = args is Map ? args : const <Object?, Object?>{};
        final section =
            SupportSection.values.asNameMap()[map['section']?.toString()] ??
                SupportSection.faq;
        final ticketId = map['ticketId']?.toString();
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => SupportCenterScreen(
            initialSection: section,
            resumeInterrupted: true,
            resumeTicketId: ticketId,
          ),
        );
      },
      home: home,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> requests;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    api.setAuthTokenForTesting(null);
    requests = <http.Request>[];
  });

  tearDown(() {
    api.setAuthTokenForTesting(null);
    api.setHttpClient(createPlatformHttpClient());
  });

  void fakeBackend(Future<http.Response> Function(http.Request) handler) {
    api.setHttpClient(MockClient((request) async {
      requests.add(request);
      return handler(request);
    }));
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  String fieldText(WidgetTester tester, String label) =>
      tester.widget<TextFormField>(field(label)).controller!.text;

  testWidgets(
      'a guest request survives sign-in, is restored, and is sent only once '
      'the visitor confirms and sends it', (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    fakeBackend((request) async {
      if (request.method == 'POST') return _ok(_ticket(), status: 201);
      return _ok(<Object?>[]);
    });

    final support = SupportCenterProvider(supportEnabled: true);
    final pending = PendingActionProvider();
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_app(
      navKey: navKey,
      support: support,
      pending: pending,
      artworks: ArtworkProvider(),
      saved: SavedItemsProvider(),
      home: const SupportCenterScreen(initialSection: SupportSection.contact),
    ));
    await settle(tester);

    // 1. The guest fills the form and sends it. The gate interrupts.
    await tester.enterText(field('Subject'), 'Login help');
    await tester.enterText(field('Message'), 'I cannot sign in on Android.');
    await tester.tap(find.text('Send request'));
    await settle(tester);
    expect(
      find.text('Create a free account to send a support request'),
      findsOneWidget,
    );
    await tester.tap(find.text('Already have an account? Sign in'));
    await settle(tester);

    // The interrupted action is captured with its route and section only.
    final captured = pending.pending;
    expect(captured?.actionType, PendingActionType.supportContact);
    expect(captured?.returnRoute, '/support');
    expect(captured?.returnArguments, <String, String>{'section': 'contact'});
    expect(
      requests.where((r) => r.method == 'POST'),
      isEmpty,
      reason: 'nothing is sent before sign-in',
    );

    // 2. Sign-in completes. The redirect replaces the Support screen.
    await tester.tap(find.text('Complete sign-in'));
    await settle(tester);
    await settle(tester);

    // The draft is back in the form on the returned screen.
    expect(fieldText(tester, 'Subject'), 'Login help');
    expect(fieldText(tester, 'Message'), 'I cannot sign in on Android.');

    // 3. The continuation asks before anything goes out, then restores only.
    await tester.pump(PendingActionContinuationHost.settleDelay);
    await settle(tester);
    expect(find.text('Continue your support request?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await settle(tester);
    expect(pending.pending, isNull);
    expect(
      requests.where((r) => r.method == 'POST'),
      isEmpty,
      reason: 'confirming the continuation does not send the request',
    );

    // 4. The visitor sends the restored request. It goes out exactly once.
    await tester.tap(find.text('Send request'));
    await settle(tester);
    final posts = requests.where((r) => r.method == 'POST').toList();
    expect(posts, hasLength(1));
    final body = jsonDecode(posts.single.body) as Map<String, dynamic>;
    expect(body['subject'], 'Login help');
    expect(body['message'], 'I cannot sign in on Android.');
    expect(body['kind'], 'support');
  });

  testWidgets('an ordinary open never restores a draft the gate interrupted',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    fakeBackend((_) async => _ok(<Object?>[]));

    final support = SupportCenterProvider(supportEnabled: true);
    support.stashDraft(const SupportDraft(
      section: 'contact',
      fields: <String, String>{'subject': 'Old', 'message': 'Old text'},
    ));
    await tester.pumpWidget(_app(
      navKey: GlobalKey<NavigatorState>(),
      support: support,
      pending: PendingActionProvider(),
      artworks: ArtworkProvider(),
      saved: SavedItemsProvider(),
      home: const SupportCenterScreen(initialSection: SupportSection.contact),
    ));
    await settle(tester);

    expect(fieldText(tester, 'Subject'), isEmpty);
    expect(fieldText(tester, 'Message'), isEmpty);
    // The stash is still there for the continuation that may follow.
    expect(
      support.takeDraft(section: 'contact', currentUserId: null)?.fields,
      containsPair('subject', 'Old'),
    );
  });

  testWidgets('an interrupted reply reopens its request with the text restored',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    api.setAuthTokenForTesting(_authToken);
    fakeBackend((request) async {
      if (request.url.path.endsWith('/tickets/ticket-1')) {
        return _ok(_ticket());
      }
      return _ok(<Object?>[_ticket()]);
    });

    final support = SupportCenterProvider(supportEnabled: true);
    support.stashDraft(const SupportDraft(
      section: 'requests',
      ticketId: 'ticket-1',
      fields: <String, String>{'reply': 'Still broken after the update'},
    ));
    await tester.pumpWidget(_app(
      navKey: GlobalKey<NavigatorState>(),
      support: support,
      pending: PendingActionProvider(),
      artworks: ArtworkProvider(),
      saved: SavedItemsProvider(),
      home: const SupportCenterScreen(
        initialSection: SupportSection.requests,
        resumeInterrupted: true,
        resumeTicketId: 'ticket-1',
      ),
    ));
    await settle(tester);
    await settle(tester);

    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Reply'))
          .controller!
          .text,
      'Still broken after the update',
    );
    expect(
      requests.any((r) => r.url.path.endsWith('/tickets/ticket-1')),
      isTrue,
      reason: 'the interrupted request is reopened',
    );
    expect(
      requests.where((r) => r.method == 'POST'),
      isEmpty,
      reason: 'restoring a reply does not send it',
    );
  });
}
