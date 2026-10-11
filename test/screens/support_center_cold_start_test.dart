import 'dart:convert';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/pending_action_provider.dart';
import 'package:art_kubus/providers/saved_items_provider.dart';
import 'package:art_kubus/providers/support_center_provider.dart';
import 'package:art_kubus/screens/support_center_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shape-only session token; the backend is faked, so only presence matters.
const _authToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
    'eyJleHAiOjQ3MzM4NTYwMDAsIndhbGxldEFkZHJlc3MiOiJXYWxsZXRUZXN0MTExMTExMTExMTExMTExMTExMTExMTExMTExMSJ9.'
    'signature';

const _gateTitle = 'Create a free account to send a support request';

/// The secure-storage channel answers at once with nothing stored. Unmocked, a
/// guest's session read waits out its timeout in widget tests.
const _secureStorage =
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

BackendApiService get api => BackendApiService();

http.Response _ok(Object? data, {int status = 200}) => http.Response(
      jsonEncode(<String, Object?>{'success': true, 'data': data}),
      status,
      headers: {'content-type': 'application/json'},
    );

Map<String, Object?> _ticket() => <String, Object?>{
      'id': 'ticket-1',
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

/// Mounts the Support screen as a cold entry: no AppInitializer, no prior
/// session in memory. Only the stored preferences decide signed in or guest.
Widget _coldApp(SupportSection section) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SupportCenterProvider>(
        create: (_) => SupportCenterProvider(supportEnabled: true),
      ),
      ChangeNotifierProvider<PendingActionProvider>(
        create: (_) => PendingActionProvider(),
      ),
      ChangeNotifierProvider<ArtworkProvider>(
        create: (_) => ArtworkProvider(),
      ),
      ChangeNotifierProvider<SavedItemsProvider>(
        create: (_) => SavedItemsProvider(),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      home: SupportCenterScreen(initialSection: section),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> requests;
  late AppLocalizations l10n;

  setUp(() async {
    api.setAuthTokenForTesting(null);
    requests = <http.Request>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorage, (call) async => null);
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  tearDown(() {
    api.setAuthTokenForTesting(null);
    api.setHttpClient(createPlatformHttpClient());
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorage, null);
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

  bool hasAuthorization(http.Request request) =>
      request.headers.keys.any((k) => k.toLowerCase() == 'authorization');

  Iterable<http.Request> ticketListCalls() => requests.where(
        (r) => r.method == 'GET' && r.url.path == '/api/support/tickets',
      );

  Iterable<http.Request> posts() => requests.where((r) => r.method == 'POST');

  Future<void> fillContactForm(WidgetTester tester) async {
    await tester.enterText(field('Subject'), 'Login help');
    await tester.enterText(field('Message'), 'I cannot sign in on Android.');
  }

  testWidgets(
      'a cold open with a stored session loads the requests as signed in',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{
      'jwt_token': _authToken,
    });
    fakeBackend((_) async => _ok(<Object?>[_ticket()]));

    await tester.pumpWidget(_coldApp(SupportSection.requests));
    // The first frame is the loading state, never the guest sign-in card.
    expect(find.text(l10n.supportSignInTitle), findsNothing);

    await settle(tester);
    expect(find.text(l10n.supportSignInTitle), findsNothing);
    expect(find.text('Login help'), findsWidgets);
    expect(ticketListCalls(), hasLength(1));
    expect(hasAuthorization(ticketListCalls().single), isTrue);
  });

  testWidgets('a cold open with no stored session stays a guest',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    fakeBackend((_) async => _ok(<Object?>[]));

    await tester.pumpWidget(_coldApp(SupportSection.requests));
    await settle(tester);

    expect(find.text(l10n.supportSignInTitle), findsOneWidget);
    expect(ticketListCalls(), isEmpty);
  });

  testWidgets(
      'a cold Send with a stored session goes out without the guest gate',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{
      'jwt_token': _authToken,
    });
    fakeBackend((request) async {
      if (request.method == 'POST') return _ok(_ticket(), status: 201);
      return _ok(<Object?>[]);
    });

    await tester.pumpWidget(_coldApp(SupportSection.contact));
    await settle(tester);
    await fillContactForm(tester);
    await tester.tap(find.text('Send request'));
    await settle(tester);
    await settle(tester);

    expect(find.text(_gateTitle), findsNothing);
    expect(posts(), hasLength(1));
    expect(hasAuthorization(posts().single), isTrue);
  });

  testWidgets(
      'a Send tapped before the stored session has loaded is still sent as signed in',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{
      'jwt_token': _authToken,
    });
    fakeBackend((request) async {
      if (request.method == 'POST') return _ok(_ticket(), status: 201);
      return _ok(<Object?>[]);
    });

    await tester.pumpWidget(_coldApp(SupportSection.contact));
    await tester.pump();
    await fillContactForm(tester);
    await tester.tap(find.text('Send request'));
    await settle(tester);
    await settle(tester);

    expect(find.text(_gateTitle), findsNothing);
    expect(posts(), hasLength(1));
  });

  testWidgets(
      'a cold Send with no stored session meets the guest gate and sends nothing',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    fakeBackend((_) async => _ok(<Object?>[]));

    await tester.pumpWidget(_coldApp(SupportSection.contact));
    await settle(tester);
    await fillContactForm(tester);
    await tester.tap(find.text('Send request'));
    await settle(tester);

    expect(find.text(_gateTitle), findsOneWidget);
    expect(posts(), isEmpty);
  });
}
