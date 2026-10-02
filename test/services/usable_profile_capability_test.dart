import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/services/auth_onboarding_service.dart';
import 'package:art_kubus/services/auth_redirect_controller.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/contextual_auth_gate.dart';
import 'package:art_kubus/utils/usable_public_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A hydrated profile is not a usable one. Pre-auth, post-auth, interrupted-
/// journey recovery and pending-action return all use one predicate, so an
/// authenticated account with an empty display name cannot bypass a
/// profile-required action.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  UserProfile profile(String displayName) {
    final now = DateTime(2026, 10, 2);
    return UserProfile(
      id: 'p1',
      walletAddress: 'wallet-1',
      username: 'visitor',
      displayName: displayName,
      bio: '',
      avatar: '',
      createdAt: now,
      updatedAt: now,
    );
  }

  group('isUsablePublicProfile', () {
    test('needs hydration and a display name, nothing else', () {
      expect(isUsablePublicProfile(hydrated: true, displayName: 'Ana'), isTrue);
      expect(
          isUsablePublicProfile(hydrated: true, displayName: ' Ana '), isTrue);
      expect(isUsablePublicProfile(hydrated: true, displayName: ''), isFalse);
      expect(
          isUsablePublicProfile(hydrated: true, displayName: '   '), isFalse);
      expect(isUsablePublicProfile(hydrated: true, displayName: null), isFalse);
      expect(
          isUsablePublicProfile(hydrated: false, displayName: 'Ana'), isFalse);
    });

    test('ProfileProvider exposes the same rule', () {
      final provider = ProfileProvider();
      expect(provider.hasUsablePublicProfile, isFalse);

      provider.setCurrentUser(profile(''));
      expect(provider.hasHydratedProfile, isTrue);
      expect(provider.hasUsablePublicProfile, isFalse,
          reason: 'hydrated with an empty display name is not usable');

      provider.setCurrentUser(profile('Ana'));
      expect(provider.hasUsablePublicProfile, isTrue);
    });
  });

  group('post-auth resolution', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    Future<PostAuthRedirectResult> resolve({
      required ProtectedActionRequirements requirements,
      required bool usable,
      String? persona,
    }) async {
      final prefs = await SharedPreferences.getInstance();
      return const AuthRedirectController().resolvePostAuthRedirect(
        prefs: prefs,
        payload: const <String, dynamic>{},
        // Hydrated either way: that is exactly the case under test.
        hasHydratedProfile: true,
        hasUsableProfile: usable,
        requiresWalletBackup: false,
        userId: 'user-1',
        persona: persona,
        redirectRoute: '/u/profile-1',
        requirements: requirements,
      );
    }

    test('ACCOUNT-ONLY: an empty display name is allowed through', () async {
      final result = await resolve(
        requirements: ProtectedActionRequirements.accountOnly,
        usable: false,
      );

      expect(result.state, PostAuthRouteState.ready);
      expect(result.routeName, '/u/profile-1');
    });

    test('PROFILE-REQUIRED: hydrated but unusable needs profile completion',
        () async {
      final result = await resolve(
        requirements: ProtectedActionRequirements.participant,
        usable: false,
      );

      expect(result.state, PostAuthRouteState.onboardingRequired);
      expect(result.onboardingStepId, 'profile');
      expect(result.completionRoute, '/u/profile-1');
      expect(result.requirements, ProtectedActionRequirements.participant);
    });

    test('PROFILE-REQUIRED: a usable display name continues', () async {
      final result = await resolve(
        requirements: ProtectedActionRequirements.participant,
        usable: true,
      );

      expect(result.state, PostAuthRouteState.ready);
      expect(result.routeName, '/u/profile-1');
    });

    test('CREATOR: same profile minimum, then the role it names', () async {
      final unusable = await resolve(
        requirements: ProtectedActionRequirements.creator,
        usable: false,
        persona: 'creator',
      );
      expect(unusable.onboardingStepId, 'profile');

      final noRole = await resolve(
        requirements: ProtectedActionRequirements.creator,
        usable: true,
      );
      expect(noRole.onboardingStepId, 'role');

      final both = await resolve(
        requirements: ProtectedActionRequirements.creator,
        usable: true,
        persona: 'creator',
      );
      expect(both.state, PostAuthRouteState.ready);
    });

    test('recovery uses the same predicate as the resolver', () async {
      final prefs = await SharedPreferences.getInstance();
      final recovered =
          await AuthOnboardingService.resolveStructuredOnboardingResume(
        prefs: prefs,
        hasPendingAuthOnboarding: true,
        hasAuthenticatedSession: true,
        hasHydratedProfile: true,
        hasUsableProfile: false,
        requiresWalletBackup: false,
        heuristicNextStepId: null,
        persona: null,
        requirements: ProtectedActionRequirements.participant,
      );

      expect(recovered.requiresStructuredOnboarding, isTrue);
      expect(recovered.nextStepId, 'profile');
    });
  });

  group('pre-auth gate (authenticated visitor)', () {
    late ProfileProvider profiles;
    String? openedStep;

    setUp(() {
      openedStep = null;
      SharedPreferences.setMockInitialValues(<String, Object>{});
      BackendApiService().setAuthTokenForTesting('test-token');
      profiles = ProfileProvider()..setCurrentUser(profile(''));
    });

    tearDown(() => BackendApiService().setAuthTokenForTesting(null));

    Future<bool?> tapAction(
      WidgetTester tester,
      ProtectedActionRequirements requirements,
    ) async {
      bool? allowed;
      await tester.pumpWidget(
        ChangeNotifierProvider<ProfileProvider>.value(
          value: profiles,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routes: <String, WidgetBuilder>{
              '/onboarding': (context) {
                final args = ModalRoute.of(context)?.settings.arguments;
                openedStep = (args as Map?)?['initialStepId']?.toString();
                return const Scaffold(body: Text('onboarding'));
              },
            },
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () async => allowed =
                    await const ContextualAuthGate().ensureAuthenticated(
                  context,
                  actionLabel: 'act',
                  returnRoute: '/u/profile-1',
                  requirements: requirements,
                ),
                child: const Text('act'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('act'));
      await tester.pumpAndSettle();
      return allowed;
    }

    testWidgets('account-only proceeds with an empty display name',
        (tester) async {
      final allowed =
          await tapAction(tester, ProtectedActionRequirements.accountOnly);

      expect(allowed, isTrue);
      expect(openedStep, isNull);
    });

    testWidgets('profile-required asks for the profile step', (tester) async {
      await tapAction(tester, ProtectedActionRequirements.participant);

      expect(openedStep, 'profile');
    });

    testWidgets('profile-required proceeds once the display name exists',
        (tester) async {
      profiles.setCurrentUser(profile('Ana'));

      final allowed =
          await tapAction(tester, ProtectedActionRequirements.participant);

      expect(allowed, isTrue);
      expect(openedStep, isNull);
    });
  });
}
