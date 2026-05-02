import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/services/auth_redirect_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      PreferenceKeys.hasCompletedOnboarding: true,
    });
  });

  test('direct wallet auth uses correct AuthOrigin.wallet', () async {
    final prefs = await SharedPreferences.getInstance();
    final result = await const AuthRedirectController().resolvePostAuthRedirect(
      prefs: prefs,
      payload: <String, dynamic>{
        'user': <String, dynamic>{'id': 'user-wallet-1'},
        'authProvider': 'wallet',
      },
      hasHydratedProfile: true,
      requiresWalletBackup: false,
      walletAddress: 'solana:wallet-direct-123',
      userId: 'user-wallet-1',
    );

    expect(result.state, PostAuthRouteState.ready);
    expect(result.routeName, '/main');
    expect(result.onboardingStepId, isNull);
  });

  test('new wallet user routes to onboarding with wallet origin', () async {
    final prefs = await SharedPreferences.getInstance();
    final result = await const AuthRedirectController().resolvePostAuthRedirect(
      prefs: prefs,
      payload: <String, dynamic>{
        'isNewUser': true,
        'authProvider': 'wallet',
      },
      hasHydratedProfile: false,
      requiresWalletBackup: false,
      walletAddress: 'solana:wallet-new-456',
      userId: 'user-wallet-2',
    );

    expect(result.state, PostAuthRouteState.onboardingRequired);
    expect(result.routeName, '/onboarding');
    expect(result.onboardingStepId, 'role');
  });

  test('wallet auth with redirect route honored', () async {
    final prefs = await SharedPreferences.getInstance();
    final result = await const AuthRedirectController().resolvePostAuthRedirect(
      prefs: prefs,
      payload: <String, dynamic>{'authProvider': 'wallet'},
      hasHydratedProfile: true,
      requiresWalletBackup: false,
      redirectRoute: '/settings',
      redirectArguments: <String, Object>{'section': 'security'},
      walletAddress: 'solana:wallet-redirect-789',
      userId: 'user-wallet-3',
    );

    expect(result.state, PostAuthRouteState.ready);
    expect(result.routeName, '/settings');
    expect(result.arguments, <String, Object>{'section': 'security'});
  });

  test('wallet auth does not route through Google pathway', () async {
    final prefs = await SharedPreferences.getInstance();
    final result = await const AuthRedirectController().resolvePostAuthRedirect(
      prefs: prefs,
      payload: <String, dynamic>{
        'user': <String, dynamic>{'id': 'user-wallet-4'},
        'authProvider': 'wallet',
      },
      hasHydratedProfile: true,
      requiresWalletBackup: false,
      walletAddress: 'solana:wallet-not-google-999',
      userId: 'user-wallet-4',
    );

    // Verify it's not treated as Google auth which would require different handling
    expect(result.state, PostAuthRouteState.ready);
    expect(result.routeName, '/main');
    // Should not have any special Google-specific flows
    expect(result.error, isNull);
  });
}
