import 'dart:async';
import 'dart:convert';
import 'dart:ui' show CheckedState, SemanticsRole, Tristate;

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/support_center_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:art_kubus/screens/support_center_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _authToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
    'eyJleHAiOjQ3MzM4NTYwMDAsIndhbGxldEFkZHJlc3MiOiJXYWxsZXRUZXN0MTExMTExMTExMTExMTExMTExMTExMTExMTExMSJ9.'
    'signature';

/// Answers at once with nothing stored in secure storage. Unmocked, a guest's
/// session read waits out its timeout in widget tests.
const _secureStorage =
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

const _ticketId = 'ticket-1';

Map<String, Object?> _ticket({
  String id = _ticketId,
  String subject = 'Map does not load',
  String status = 'open',
  String kind = 'support',
  List<Map<String, Object?>>? messages,
}) {
  return <String, Object?>{
    'id': id,
    'subject': subject,
    'message': 'The map stays blank after sign-in.',
    'kind': kind,
    'status': status,
    'priority': 'normal',
    'created_at': '2026-10-08T09:00:00.000Z',
    'updated_at': '2026-10-08T10:00:00.000Z',
    if (messages != null) 'messages': messages,
  };
}

Map<String, Object?> _openingMessage() => <String, Object?>{
      'id': null,
      'sender_type': 'user',
      'message': 'The map stays blank after sign-in.',
      'created_at': '2026-10-08T09:00:00.000Z',
    };

http.Response _ok(Object? data, {int status = 200}) => http.Response(
      jsonEncode(<String, Object?>{'success': true, 'data': data}),
      status,
      headers: {'content-type': 'application/json'},
    );

http.Response _error(int status, String message, {String? retryAfter}) =>
    http.Response(
      jsonEncode(<String, Object?>{'success': false, 'error': message}),
      status,
      headers: {
        'content-type': 'application/json',
        if (retryAfter != null) 'retry-after': retryAfter,
      },
    );

typedef _Handler = Future<http.Response> Function(http.Request request);

class _Backend {
  _Backend(this.handler);

  final _Handler handler;
  final List<http.Request> requests = <http.Request>[];

  List<http.Request> requestsTo(String method, String pathSuffix) => requests
      .where((r) => r.method == method && r.url.path.endsWith(pathSuffix))
      .toList();
}

/// Stands in for the sign-in route. Completing it establishes a session, as
/// the real journey does, then returns to the screen that asked for it.
class _FakeSignInRoute extends StatelessWidget {
  const _FakeSignInRoute({this.token = _authToken});

  /// The session the journey establishes. A different token models a new sign-in.
  final String token;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () {
            api.setAuthTokenForTesting(token);
            Navigator.of(context).pop();
          },
          child: const Text('Complete sign-in'),
        ),
      ),
    );
  }
}

/// Resolved lazily so the singleton is created inside a test zone.
BackendApiService get api => BackendApiService();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorage, (call) async => null);
    api.setAuthTokenForTesting(_authToken);
  });

  tearDown(() {
    api.setAuthTokenForTesting(null);
    api.setHttpClient(createPlatformHttpClient());
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorage, null);
  });

  /// Installs a fake backend. Requests are recorded for assertions.
  _Backend backend(_Handler handler) {
    final fake = _Backend(handler);
    api.setHttpClient(MockClient((request) async {
      fake.requests.add(request);
      return fake.handler(request);
    }));
    return fake;
  }

  /// Advances the fake clock enough for futures, animations and rebuilds.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    SupportSection section = SupportSection.faq,
    Locale locale = const Locale('en'),
    double textScale = 1.0,
    Size size = const Size(800, 1000),
    bool signedIn = true,
    bool supportEnabled = true,
    bool dark = false,
    Map<String, WidgetBuilder>? routes,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    api.setAuthTokenForTesting(signedIn ? _authToken : null);
    final themes = ThemeProvider();
    await tester.pumpWidget(
      ChangeNotifierProvider<SupportCenterProvider>(
        create: (_) => SupportCenterProvider(supportEnabled: supportEnabled),
        child: MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: themes.lightTheme,
          darkTheme: themes.darkTheme,
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
          routes: routes ??
              <String, WidgetBuilder>{
                '/sign-in': (_) => const _FakeSignInRoute(),
              },
          home: SupportCenterScreen(initialSection: section),
        ),
      ),
    );
    await settle(tester);
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  Finder replyField() => find.widgetWithText(TextField, 'Reply');

  group('FAQ', () {
    testWidgets('is visible to a guest and answers expand without a request',
        (tester) async {
      final fake = backend((_) async => _ok(<Object?>[]));
      await pumpScreen(tester, signedIn: false);

      expect(find.text('What is art.kubus?'), findsOneWidget);
      await tester.tap(find.text('What is art.kubus?'));
      await settle(tester);
      expect(
        find.text(
          'An open art map for exploring artworks, exhibitions and cultural spaces.',
        ),
        findsOneWidget,
      );
      expect(fake.requests, isEmpty);
    });
  });

  group('contact and bug forms', () {
    testWidgets('empty contact form shows required errors and sends nothing',
        (tester) async {
      final fake = backend((_) async => _ok(<Object?>[]));
      await pumpScreen(tester, section: SupportSection.contact);

      await tester.tap(find.text('Send request'));
      await settle(tester);

      expect(find.text('This field is required.'), findsNWidgets(2));
      expect(fake.requestsTo('POST', '/api/support/tickets'), isEmpty);
    });

    testWidgets(
        'subject is capped at 255 characters and whitespace is required',
        (tester) async {
      backend((_) async => _ok(<Object?>[]));
      await pumpScreen(tester, section: SupportSection.contact);

      await tester.enterText(field('Subject'), 'a' * 300);
      await settle(tester);
      final subject = tester.widget<TextFormField>(field('Subject'));
      expect(subject.controller!.text.length, 255);

      await tester.enterText(field('Subject'), '     ');
      await tester.enterText(field('Message'), 'Some detail');
      await tester.tap(find.text('Send request'));
      await settle(tester);
      expect(find.text('This field is required.'), findsOneWidget);
    });

    testWidgets('contact request posts the contract body without email',
        (tester) async {
      final fake = backend((request) async {
        if (request.method == 'POST') {
          return _ok(_ticket(), status: 201);
        }
        return _ok(<Object?>[_ticket()]);
      });
      await pumpScreen(tester, section: SupportSection.contact);

      await tester.enterText(field('Subject'), '  Map does not load  ');
      await tester.enterText(
        field('Message'),
        '  The map stays blank after sign-in.  ',
      );
      await tester.tap(find.text('Send request'));
      await settle(tester);

      final posts = fake.requestsTo('POST', '/api/support/tickets');
      expect(posts, hasLength(1));
      expect(jsonDecode(posts.single.body), <String, dynamic>{
        'subject': 'Map does not load',
        'message': 'The map stays blank after sign-in.',
        'kind': 'support',
      });
      expect(find.text('Request sent to support.'), findsOneWidget);
      // Success opens the request history with the new ticket.
      expect(find.text('Map does not load'), findsOneWidget);
    });

    testWidgets('bug report exposes reproduction fields and posts kind bug',
        (tester) async {
      final fake = backend((request) async {
        if (request.method == 'POST') {
          return _ok(_ticket(kind: 'bug'), status: 201);
        }
        return _ok(<Object?>[]);
      });
      await pumpScreen(tester, section: SupportSection.bug);

      expect(find.text('Steps to reproduce'), findsOneWidget);
      expect(find.text('Expected behaviour'), findsOneWidget);
      expect(find.text('Actual behaviour'), findsOneWidget);
      expect(find.text('Include device platform'), findsOneWidget);

      await tester.enterText(field('Subject'), 'Crash on upload');
      await tester.enterText(field('What happened?'), 'The upload stops.');
      await tester.enterText(field('Steps to reproduce'), '1. Open editor');
      await tester.enterText(field('Expected behaviour'), 'Upload finishes');
      await tester.enterText(field('Actual behaviour'), 'Spinner forever');
      await tester.tap(find.text('Send bug report'));
      await settle(tester);

      final body = jsonDecode(
        fake.requestsTo('POST', '/api/support/tickets').single.body,
      ) as Map<String, dynamic>;
      expect(body['kind'], 'bug');
      expect(body['subject'], 'Crash on upload');
      expect(body['message'], contains('Steps to reproduce:\n1. Open editor'));
      expect(body['message'], contains('Actual behavior:\nSpinner forever'));
      expect(body.containsKey('email'), isFalse);
    });

    testWidgets('a composed bug report over 5000 characters is blocked',
        (tester) async {
      final fake = backend((_) async => _ok(<Object?>[]));
      await pumpScreen(tester, section: SupportSection.bug);

      await tester.enterText(field('Subject'), 'Long');
      await tester.enterText(field('What happened?'), 'a' * 3000);
      await tester.enterText(field('Steps to reproduce'), 'b' * 3000);
      await tester.enterText(field('Expected behaviour'), 'c');
      await tester.enterText(field('Actual behaviour'), 'd');
      await tester.tap(find.text('Send bug report'));
      await settle(tester);

      expect(
        find.text('The report is too long. Shorten it to 5000 characters.'),
        findsOneWidget,
      );
      expect(fake.requestsTo('POST', '/api/support/tickets'), isEmpty);
    });

    testWidgets('guest submit prompts sign-in and sends nothing',
        (tester) async {
      final fake = backend((_) async => _ok(<Object?>[]));
      await pumpScreen(tester,
          section: SupportSection.contact, signedIn: false);

      await tester.enterText(field('Subject'), 'Need help');
      await tester.enterText(field('Message'), 'Please call me back');
      await tester.tap(find.text('Send request'));
      await settle(tester);

      expect(fake.requestsTo('POST', '/api/support/tickets'), isEmpty);
      // The draft is kept for when the visitor returns from sign-in.
      expect(
        tester.widget<TextFormField>(field('Subject')).controller!.text,
        'Need help',
      );
    });

    testWidgets('429 keeps the draft and states the rate limit',
        (tester) async {
      backend((request) async {
        if (request.method == 'POST') {
          return _error(429, 'Too many requests', retryAfter: '120');
        }
        return _ok(<Object?>[]);
      });
      await pumpScreen(tester, section: SupportSection.contact);

      await tester.enterText(field('Subject'), 'Still broken');
      await tester.enterText(field('Message'), 'Details here');
      await tester.tap(find.text('Send request'));
      await settle(tester);

      expect(
        find.text('Too many requests. Try again in about an hour.'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextFormField>(field('Subject')).controller!.text,
        'Still broken',
      );
    });

    testWidgets('400 from the server shows the field-check message',
        (tester) async {
      backend((request) async {
        if (request.method == 'POST') {
          return _error(400, 'message is required');
        }
        return _ok(<Object?>[]);
      });
      await pumpScreen(tester, section: SupportSection.contact);

      await tester.enterText(field('Subject'), 'Valid subject');
      await tester.enterText(field('Message'), 'Valid message');
      await tester.tap(find.text('Send request'));
      await settle(tester);

      expect(
        find.text('Check the highlighted fields and try again.'),
        findsOneWidget,
      );
    });
  });

  group('requests', () {
    testWidgets('an empty history shows the empty state', (tester) async {
      backend((_) async => _ok(<Object?>[]));
      await pumpScreen(tester, section: SupportSection.requests);

      expect(find.text('No requests yet.'), findsOneWidget);
    });

    testWidgets('a failed load shows an error and a retry action',
        (tester) async {
      // Every origin fails (the client also fails over implicitly), so the
      // error persists until the visitor retries.
      var failing = true;
      backend((_) async {
        if (failing) return _error(500, 'boom');
        return _ok(<Object?>[_ticket()]);
      });
      await pumpScreen(tester, section: SupportSection.requests);

      expect(
        find.text(
          'Your requests could not be loaded. Check your connection and try again.',
        ),
        findsOneWidget,
      );
      failing = false;
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(find.text('Map does not load'), findsOneWidget);
    });

    testWidgets('a guest sees a sign-in prompt and no request is sent',
        (tester) async {
      final fake = backend((_) async => _ok(<Object?>[]));
      await pumpScreen(
        tester,
        section: SupportSection.requests,
        signedIn: false,
      );

      expect(find.text('Sign in to contact support'), findsOneWidget);
      expect(fake.requests, isEmpty);
    });

    testWidgets('a 401 from the history endpoint shows the sign-in prompt',
        (tester) async {
      backend((_) async => _error(401, 'Unauthorized'));
      await pumpScreen(tester, section: SupportSection.requests);

      expect(find.text('Sign in to contact support'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('a 403 without account identity explains the session problem',
        (tester) async {
      backend((_) async => _error(403, 'Account identity is required'));
      await pumpScreen(tester, section: SupportSection.requests);

      expect(
        find.text(
          'Your session cannot be used for support requests. Sign out, sign in again, then retry.',
        ),
        findsOneWidget,
      );
      expect(find.text('Sign in to contact support'), findsNothing);
    });

    testWidgets('detail shows the conversation, then a reply refreshes it',
        (tester) async {
      var replied = false;
      final fake = backend((request) async {
        if (request.method == 'POST') {
          replied = true;
          return _ok(<String, Object?>{
            'id': 'm-2',
            'sender_type': 'user',
            'message': 'Still blank on Android.',
            'created_at': '2026-10-08T11:00:00.000Z',
          }, status: 201);
        }
        if (request.url.path.endsWith('/$_ticketId')) {
          return _ok(_ticket(
            status: replied ? 'open' : 'pending',
            messages: <Map<String, Object?>>[
              _openingMessage(),
              {
                'id': 'm-1',
                'sender_type': 'admin',
                'message': 'Could you try a hard refresh?',
                'created_at': '2026-10-08T12:00:00.000Z',
              },
              if (replied)
                {
                  'id': 'm-2',
                  'sender_type': 'user',
                  'message': 'Still blank on Android.',
                  'created_at': '2026-10-08T11:00:00.000Z',
                },
            ],
          ));
        }
        return _ok(<Object?>[_ticket(status: 'pending')]);
      });
      await pumpScreen(tester, section: SupportSection.requests);

      await tester.tap(find.text('Map does not load'));
      await settle(tester);

      expect(find.text('Support team · 8.10.2026'), findsOneWidget);
      expect(find.text('Could you try a hard refresh?'), findsOneWidget);
      expect(find.textContaining('Waiting for your reply'), findsOneWidget);

      await tester.enterText(replyField(), 'Still blank on Android.');
      await tester.tap(find.text('Send reply'));
      await settle(tester);

      final posts = fake.requestsTo('POST', '/replies');
      expect(posts, hasLength(1));
      expect(jsonDecode(posts.single.body),
          {'message': 'Still blank on Android.'});
      expect(find.text('Still blank on Android.'), findsOneWidget);
    });

    testWidgets(
        'a 409 on reply reloads the request into read-only closed state',
        (tester) async {
      var closed = false;
      backend((request) async {
        if (request.method == 'POST') {
          closed = true;
          return _error(409, 'Ticket is closed');
        }
        if (request.url.path.endsWith('/$_ticketId')) {
          return _ok(_ticket(
            status: closed ? 'closed' : 'open',
            messages: <Map<String, Object?>>[_openingMessage()],
          ));
        }
        return _ok(<Object?>[_ticket()]);
      });
      await pumpScreen(tester, section: SupportSection.requests);

      await tester.tap(find.text('Map does not load'));
      await settle(tester);
      await tester.enterText(replyField(), 'One more thing');
      await tester.tap(find.text('Send reply'));
      await settle(tester);

      expect(
        find.text('This request is closed, so it cannot take a reply.'),
        findsOneWidget,
      );
      expect(find.text('This request is closed'), findsOneWidget);
      expect(
        find.text(
          'Closed requests are read-only. If you still need help, send a new request.',
        ),
        findsOneWidget,
      );
      expect(replyField(), findsNothing);
    });

    testWidgets('a closed request shows no composer and links to a new request',
        (tester) async {
      backend((request) async {
        if (request.url.path.endsWith('/$_ticketId')) {
          return _ok(_ticket(
            status: 'closed',
            messages: <Map<String, Object?>>[_openingMessage()],
          ));
        }
        return _ok(<Object?>[_ticket(status: 'closed')]);
      });
      await pumpScreen(tester, section: SupportSection.requests);

      await tester.tap(find.text('Map does not load'));
      await settle(tester);

      expect(replyField(), findsNothing);
      expect(find.text('Send reply'), findsNothing);
      await tester.tap(find.text('Send a new request'));
      await settle(tester);
      expect(find.text('Send request'), findsOneWidget);
    });

    testWidgets('user text renders as plain text and long words wrap',
        (tester) async {
      final longWord = 'x' * 400;
      backend((request) async {
        if (request.url.path.endsWith('/$_ticketId')) {
          return _ok(_ticket(
            messages: <Map<String, Object?>>[
              {
                'id': null,
                'sender_type': 'user',
                'message': '<b>bold</b> **markdown** $longWord',
                'created_at': '2026-10-08T09:00:00.000Z',
              },
            ],
          ));
        }
        return _ok(<Object?>[_ticket()]);
      });
      await pumpScreen(
        tester,
        section: SupportSection.requests,
        size: const Size(320, 640),
        textScale: 2.0,
      );

      await tester.tap(find.text('Map does not load'));
      await settle(tester);

      expect(find.textContaining('<b>bold</b> **markdown**'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a slow response for a request the visitor left is ignored',
        (tester) async {
      final slowFirst = Completer<http.Response>();
      backend((request) async {
        if (request.url.path.endsWith('/ticket-a')) return slowFirst.future;
        if (request.url.path.endsWith('/ticket-b')) {
          return _ok(_ticket(
            id: 'ticket-b',
            subject: 'Second request',
            messages: <Map<String, Object?>>[_openingMessage()],
          ));
        }
        return _ok(<Object?>[
          _ticket(id: 'ticket-a', subject: 'First request'),
          _ticket(id: 'ticket-b', subject: 'Second request'),
        ]);
      });
      await pumpScreen(tester, section: SupportSection.requests);

      await tester.tap(find.text('First request'));
      await settle(tester);
      await tester.tap(find.byTooltip('Back to all requests'));
      await settle(tester);
      await tester.tap(find.text('Second request'));
      await settle(tester);
      expect(find.text('Second request'), findsOneWidget);

      // The first request answers after the second is on screen.
      slowFirst.complete(_ok(_ticket(
        id: 'ticket-a',
        subject: 'First request',
        messages: <Map<String, Object?>>[_openingMessage()],
      )));
      await settle(tester);

      expect(find.text('First request'), findsNothing);
      expect(find.text('Second request'), findsOneWidget);
    });

    testWidgets('finishing sign-in from My requests loads the history',
        (tester) async {
      final fake = backend((_) async => _ok(<Object?>[_ticket()]));
      await pumpScreen(
        tester,
        section: SupportSection.requests,
        signedIn: false,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await settle(tester);
      // The protected-action sheet offers the existing-account path.
      await tester.tap(find.text('Already have an account? Sign in'));
      await settle(tester);
      await tester.tap(find.text('Complete sign-in'));
      await settle(tester);

      // No second tap: the history is already loaded once the session exists.
      expect(find.text('Map does not load'), findsOneWidget);
      expect(fake.requestsTo('GET', '/api/support/tickets'), hasLength(1));
    });

    testWidgets('with support switched off My requests makes no ticket calls',
        (tester) async {
      final fake = backend((_) async => _ok(<Object?>[_ticket()]));
      await pumpScreen(
        tester,
        section: SupportSection.requests,
        supportEnabled: false,
      );

      expect(
        find.text(
          'Support requests are not available right now. The FAQ is still open.',
        ),
        findsOneWidget,
      );
      expect(find.text('Map does not load'), findsNothing);
      expect(fake.requests, isEmpty);
    });

    testWidgets('the refresh control and back control expose labels',
        (tester) async {
      backend((_) async => _ok(<Object?>[_ticket()]));
      await pumpScreen(tester, section: SupportSection.requests);

      expect(find.byTooltip('Refresh'), findsOneWidget);
      await tester.tap(find.text('Map does not load'));
      await settle(tester);
      expect(find.byTooltip('Back to all requests'), findsOneWidget);
    });
  });

  group('layout matrix', () {
    final longSubject = 'Subject that keeps going ' * 12;
    final longMessage = 'Unbroken ${'m' * 300} then ordinary words. ' * 14;

    for (final width in <double>[320, 390, 820, 1440]) {
      for (final dark in <bool>[false, true]) {
        final mode = dark ? 'dark' : 'light';

        testWidgets(
            'long request detail, empty and error states fit at ${width.toInt()} wide in $mode with 2.0 text',
            (tester) async {
          var failing = false;
          var empty = false;
          backend((request) async {
            if (failing) return _error(500, 'boom');
            if (request.url.path.endsWith('/$_ticketId')) {
              return _ok(_ticket(
                subject: longSubject,
                messages: <Map<String, Object?>>[
                  {
                    'id': null,
                    'sender_type': 'user',
                    'message': longMessage,
                    'created_at': '2026-10-08T09:00:00.000Z',
                  },
                  {
                    'id': 'm-1',
                    'sender_type': 'admin',
                    'message': longMessage,
                    'created_at': '2026-10-08T12:00:00.000Z',
                  },
                ],
              ));
            }
            // The list row stays short so it can be tapped on screen; the
            // detail carries the long subject and conversation.
            if (empty) return _ok(<Object?>[]);
            return _ok(<Object?>[_ticket(subject: 'Short row')]);
          });
          await pumpScreen(
            tester,
            section: SupportSection.requests,
            size: Size(width, 900),
            textScale: 2.0,
            dark: dark,
          );

          // Error state with a retry action first.
          expect(tester.takeException(), isNull);
          failing = true;
          await tester.tap(find.byTooltip('Refresh'));
          await settle(tester);
          expect(find.text('Try again'), findsOneWidget);
          expect(tester.takeException(), isNull);

          // Empty history.
          failing = false;
          empty = true;
          await tester.tap(find.byTooltip('Refresh'));
          await settle(tester);
          expect(find.text('No requests yet.'), findsOneWidget);
          expect(tester.takeException(), isNull);

          // Long content in the detail view.
          empty = false;
          await tester.tap(find.byTooltip('Refresh'));
          await settle(tester);
          await tester.tap(find.text('Short row'));
          await settle(tester);
          expect(find.byTooltip('Back to all requests'), findsOneWidget);
          expect(find.text(longSubject), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('layout and locale', () {
    for (final section in SupportSection.values) {
      testWidgets(
          '${section.name} renders at 320 width with 2.0 text scale without overflow',
          (tester) async {
        backend((_) async => _ok(<Object?>[_ticket()]));
        await pumpScreen(
          tester,
          section: section,
          size: const Size(320, 640),
          textScale: 2.0,
        );

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Slovenian locale renders Slovenian navigation and form labels',
        (tester) async {
      backend((_) async => _ok(<Object?>[]));
      await pumpScreen(
        tester,
        section: SupportSection.contact,
        locale: const Locale('sl'),
      );

      expect(find.text('Pomoč in podpora'), findsWidgets);
      expect(find.text('Zadeva'), findsOneWidget);
      expect(find.text('Sporočilo'), findsOneWidget);
      expect(find.text('Pošlji zahtevek'), findsOneWidget);
    });
  });

  group('section tabs and refused sessions', () {
    const freshToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
        'eyJleHAiOjQ3MzM4NTYwMDAsIndhbGxldEFkZHJlc3MiOiJXYWxsZXRUZXN0MjIyMjIyMjIyMjIyMjIyMjIyMjIyIn0.'
        'signature';

    /// Sign-in route for a journey that establishes [freshToken].
    Map<String, WidgetBuilder> freshSignIn() => <String, WidgetBuilder>{
          '/sign-in': (_) => const _FakeSignInRoute(token: freshToken),
        };

    testWidgets('section chips are tabs in a tab bar, not checkboxes',
        (tester) async {
      final handle = tester.ensureSemantics();
      backend((_) async => _ok(<Object?>[]));
      await pumpScreen(tester, section: SupportSection.contact);

      final tabFinder = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.role == SemanticsRole.tab,
      );
      expect(tabFinder, findsNWidgets(4));
      final selectedTab = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.role == SemanticsRole.tab &&
            w.properties.selected == true,
      );
      expect(selectedTab, findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.role == SemanticsRole.tabBar,
        ),
        findsOneWidget,
      );
      final contactTab = tester.getSemantics(find
          .ancestor(
            of: find.text('Contact support'),
            matching: find.byWidgetPredicate(
              (w) => w is Semantics && w.properties.role == SemanticsRole.tab,
            ),
          )
          .first);
      final flags = contactTab.getSemanticsData().flagsCollection;
      expect(contactTab.getSemanticsData().label, contains('Contact support'));
      expect(flags.isSelected, Tristate.isTrue);
      expect(flags.isChecked, CheckedState.none);
      handle.dispose();
    });

    testWidgets(
        'a 401 from the history opens sign-in without repeating the call',
        (tester) async {
      var calls = 0;
      backend((_) async {
        calls += 1;
        return _error(401, 'Invalid or expired token');
      });
      await pumpScreen(tester, section: SupportSection.requests);
      expect(find.text('Sign in to contact support'), findsOneWidget);
      expect(calls, 1);

      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await settle(tester);

      // The stored session was refused, so the route opens directly; the
      // protected-action gate would see a token and do nothing.
      expect(find.text('Complete sign-in'), findsOneWidget);
      expect(calls, 1, reason: 'opening sign-in must not repeat the request');
    });

    testWidgets('a fresh sign-in after a refused session reloads the history',
        (tester) async {
      final fake = backend((request) async {
        final authorised =
            request.headers['authorization'] == 'Bearer $freshToken';
        if (!authorised) return _error(401, 'Invalid or expired token');
        return _ok(<Object?>[_ticket()]);
      });
      await pumpScreen(
        tester,
        section: SupportSection.requests,
        routes: freshSignIn(),
      );
      expect(find.text('Sign in to contact support'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await settle(tester);
      await tester.tap(find.text('Complete sign-in'));
      await settle(tester);

      expect(find.text('Map does not load'), findsOneWidget);
      expect(fake.requestsTo('GET', '/api/support/tickets'), hasLength(2));
    });

    testWidgets('a 401 on an open request offers sign-in instead of a dead end',
        (tester) async {
      final fake = backend((request) async {
        if (request.url.path.endsWith('/$_ticketId')) {
          return _error(401, 'Invalid or expired token');
        }
        return _ok(<Object?>[_ticket()]);
      });
      await pumpScreen(tester, section: SupportSection.requests);

      await tester.tap(find.text('Map does not load'));
      await settle(tester);

      expect(find.text('Sign in to contact support'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
      expect(
        fake.requestsTo('GET', '/api/support/tickets/$_ticketId'),
        hasLength(1),
      );
    });

    testWidgets('an incomplete bug report scrolls to its first missing field',
        (tester) async {
      backend((_) async => _ok(<Object?>[]));
      await pumpScreen(
        tester,
        section: SupportSection.bug,
        size: const Size(390, 600),
      );
      Future<void> fill(String label, String text) async {
        await tester.ensureVisible(field(label));
        await tester.enterText(field(label), text);
        await settle(tester);
      }

      await fill('What happened?', 'Blank map');
      await fill('Steps to reproduce', 'Open the map');
      await fill('Expected behaviour', 'Markers show');
      await fill('Actual behaviour', 'Nothing');
      // Subject is left empty at the top of the form; Send is at the bottom,
      // so the field is below the fold when the submit is tapped.
      await tester.ensureVisible(find.text('Send bug report'));
      await settle(tester);
      expect(
        tester.getRect(field('Subject')).top,
        lessThan(tester.getRect(find.byType(ListView)).top),
        reason: 'the empty subject starts above the visible area',
      );
      await tester.tap(find.text('Send bug report'));
      await settle(tester);

      final list = tester.getRect(find.byType(ListView));
      final missing = tester.getRect(field('Subject'));
      expect(missing.top, greaterThanOrEqualTo(list.top));
      expect(missing.bottom, lessThanOrEqualTo(list.bottom));
      expect(find.text('This field is required.'), findsOneWidget);
    });

    testWidgets('a refused session on send opens sign-in and keeps the draft',
        (tester) async {
      backend((request) async {
        if (request.method == 'POST') return _error(401, 'Invalid token');
        return _ok(<Object?>[]);
      });
      await pumpScreen(
        tester,
        section: SupportSection.contact,
        routes: freshSignIn(),
      );
      await tester.enterText(field('Subject'), 'Kept subject');
      await tester.enterText(field('Message'), 'Kept message');
      await tester.tap(find.text('Send request'));
      await settle(tester);

      expect(find.text('Complete sign-in'), findsOneWidget);
      await tester.tap(find.text('Complete sign-in'));
      await settle(tester);

      expect(
        tester.widget<TextFormField>(field('Subject')).controller!.text,
        'Kept subject',
      );
      expect(
        tester.widget<TextFormField>(field('Message')).controller!.text,
        'Kept message',
      );
    });

    testWidgets('a refused session on reply opens sign-in for the request',
        (tester) async {
      backend((request) async {
        if (request.method == 'POST') return _error(401, 'Invalid token');
        if (request.url.path.endsWith('/$_ticketId')) {
          return _ok(_ticket(
            messages: <Map<String, Object?>>[_openingMessage()],
          ));
        }
        return _ok(<Object?>[_ticket()]);
      });
      await pumpScreen(
        tester,
        section: SupportSection.requests,
        routes: freshSignIn(),
      );
      await tester.tap(find.text('Map does not load'));
      await settle(tester);
      await tester.enterText(replyField(), 'Reply that was refused');
      await tester.tap(find.text('Send reply'));
      await settle(tester);

      expect(find.text('Complete sign-in'), findsOneWidget);
      await tester.tap(find.text('Complete sign-in'));
      await settle(tester);

      expect(find.text('Map does not load'), findsOneWidget);
      expect(
        tester.widget<TextField>(replyField()).controller!.text,
        'Reply that was refused',
      );
    });
  });
}
