import 'package:art_kubus/providers/collab_provider.dart';
import 'package:art_kubus/providers/community_hub_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/contextual_auth_gate.dart';
import 'package:art_kubus/services/socket_service.dart';
import 'package:art_kubus/widgets/community/community_compose_intent_resumer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/product_surface_harness.dart';
import '../../support/product_v5_qa_fixtures.dart' as qa;

/// Profile step a guest reaches after email sign-in when the account has no
/// usable public profile yet ("Create your profile, step 2 of 2"). Finishing it
/// saves the profile and returns to the screen the guest came from.
class _FakeOnboarding extends StatefulWidget {
  const _FakeOnboarding();

  @override
  State<_FakeOnboarding> createState() => _FakeOnboardingState();
}

class _FakeOnboardingState extends State<_FakeOnboarding> {
  @override
  void initState() {
    super.initState();
    // Email sign-in authenticates the session before the profile step opens.
    BackendApiService().setAuthTokenForTesting('test-token');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const Text('Step 2 of 2'),
          const Text('Create your profile'),
          TextButton(
            onPressed: () {
              context.read<ProfileProvider>().setCurrentUser(
                    qa.qaOwner(),
                  );
              Navigator.of(context).pop();
            },
            child: const Text('Finish profile'),
          ),
        ],
      ),
    );
  }
}

/// The screen the guest starts from: New post and Start a chat, with the same
/// compose resume the Community shell mounts.
class _Origin extends StatelessWidget {
  const _Origin();

  @override
  Widget build(BuildContext context) {
    final isSignedIn = context.select<ProfileProvider, bool>(
      (profile) => profile.isSignedIn,
    );
    return CommunityComposeIntentResumer(
      isSignedIn: isSignedIn,
      onResume: (intent) => _resumed.add(intent),
      child: Scaffold(
        body: Column(
          children: [
            Builder(
              builder: (context) => TextButton(
                onPressed: () => ensureCommunityComposeAccess(
                  context,
                  intent: CommunityComposeIntent.post,
                  actionLabel: 'write a post',
                  sourceScreen: 'community_screen',
                ),
                child: const Text('New post'),
              ),
            ),
            Builder(
              builder: (context) => TextButton(
                onPressed: () => const ContextualAuthGate().ensureAuthenticated(
                  context,
                  requirements: ProtectedActionRequirements.participant,
                  actionLabel: 'start a chat',
                  returnRoute: '/community',
                  sourceScreen: 'messages_screen',
                ),
                child: const Text('Start a chat'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Resumes the compose requests the origin receives, in order.
final List<CommunityComposeIntent> _resumed = <CommunityComposeIntent>[];

Widget _app() => Navigator(
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => settings.name == '/onboarding'
            ? const _FakeOnboarding()
            : const _Origin(),
      ),
    );

Future<void> _drain(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CollabProvider collab;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setAuthTokenForTesting(null);
    BackendApiService().setHttpClient(http.Client());
    _resumed.clear();
    collab = CollabProvider();
  });

  tearDown(() {
    collab.stopInvitePolling();
    BackendApiService().setAuthTokenForTesting(null);
    SocketService().disconnect();
  });

  Future<void> pumpOrigin(WidgetTester tester) async {
    final prior = FlutterError.onError;
    await pumpProductSurface(
      tester,
      child: _app(),
      size: const Size(390, 844),
      extraProviders: <SingleChildWidget>[
        ChangeNotifierProvider<CollabProvider>.value(value: collab),
      ],
      settle: const Duration(milliseconds: 500),
    );
    FlutterError.onError = prior;
    await _drain(tester);
  }

  /// Any element under the app's providers reads the hub, including while the
  /// profile step covers the origin.
  CommunityHubProvider hubOf(WidgetTester tester) =>
      Provider.of<CommunityHubProvider>(
        tester.element(find.byType(Scaffold).first),
        listen: false,
      );

  testWidgets(
      'New post waits through the profile step and opens the composer once',
      (tester) async {
    await pumpOrigin(tester);

    await tester.tap(find.text('New post'));
    await tester.pumpAndSettle();
    expect(find.text('Create a free account to write a post'), findsOneWidget);
    await tester.tap(find.text('Continue with email'));
    await tester.pumpAndSettle();
    expect(find.text('Create your profile'), findsOneWidget);

    // Through the profile step the request is held, not acted on.
    expect(hubOf(tester).hasPendingComposeIntent, isTrue);
    expect(_resumed, isEmpty);

    await tester.tap(find.text('Finish profile'));
    await _drain(tester);
    await tester.pumpAndSettle();

    // Back on the origin with nothing left behind: no profile step, no sheet.
    expect(find.text('Create your profile'), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
    expect(_resumed, <CommunityComposeIntent>[CommunityComposeIntent.post]);
    expect(hubOf(tester).hasPendingComposeIntent, isFalse);

    // A later request is answered normally: the account is complete, so the
    // gate is not shown again and nothing is resumed twice.
    await tester.tap(find.text('New post'));
    await _drain(tester);
    await tester.pumpAndSettle();
    expect(find.text('Create a free account to write a post'), findsNothing);
    expect(_resumed, hasLength(1));
  });

  testWidgets(
      'Start a chat leaves no request behind and the gate is not left stuck',
      (tester) async {
    await pumpOrigin(tester);

    await tester.tap(find.text('Start a chat'));
    await tester.pumpAndSettle();
    expect(find.text('Create a free account to start a chat'), findsOneWidget);
    await tester.tap(find.text('Continue with email'));
    await tester.pumpAndSettle();
    expect(find.text('Create your profile'), findsOneWidget);

    await tester.tap(find.text('Finish profile'));
    await _drain(tester);
    await tester.pumpAndSettle();

    // A chat is not replayed: nothing is captured, nothing reopens.
    expect(hubOf(tester).hasPendingComposeIntent, isFalse);
    expect(_resumed, isEmpty);
    expect(find.byType(BottomSheet), findsNothing);

    // The gate is free again: the completed account passes straight through.
    await tester.tap(find.text('Start a chat'));
    await _drain(tester);
    await tester.pumpAndSettle();
    expect(find.text('Create a free account to start a chat'), findsNothing);
  });
}
