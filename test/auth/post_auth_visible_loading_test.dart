import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:art_kubus/screens/auth/sign_in_screen.dart';
import 'package:art_kubus/widgets/auth_methods_panel.dart';
import 'package:art_kubus/widgets/auth/post_auth_loading_screen.dart';
import 'package:art_kubus/services/auth_redirect_controller.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/providers/cache_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/saved_items_provider.dart';

void main() {
  group('Post-Auth Visible Loading UX', () {
    late MockWalletProvider mockWalletProvider;
    late MockCacheProvider mockCacheProvider;
    late MockProfileProvider mockProfileProvider;
    late MockSavedItemsProvider mockSavedItemsProvider;

    setUp(() {
      mockWalletProvider = MockWalletProvider();
      mockCacheProvider = MockCacheProvider();
      mockProfileProvider = MockProfileProvider();
      mockSavedItemsProvider = MockSavedItemsProvider();
    });

    testWidgets(
      'SignInScreen shows PostAuthLoadingScreen after email auth success',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<WalletProvider>(
                create: (_) => mockWalletProvider,
              ),
              ChangeNotifierProvider<CacheProvider>(
                create: (_) => mockCacheProvider,
              ),
              ChangeNotifierProvider<ProfileProvider>(
                create: (_) => mockProfileProvider,
              ),
              ChangeNotifierProvider<SavedItemsProvider>(
                create: (_) => mockSavedItemsProvider,
              ),
            ],
            child: MaterialApp(
              home: SignInScreen(
                embedded: true, // Skip shell for unit test
              ),
            ),
          ),
        );

        // Initial state: auth form should be visible
        expect(find.byType(SignInScreen), findsOneWidget);
        expect(find.byType(PostAuthLoadingScreen), findsNothing);

        // Simulate auth success by triggering the handler directly
        final state =
            tester.state<_SignInScreenState>(find.byType(SignInScreen));

        final authPayload = {
          'data': {
            'user': {
              'id': 'test-user-id',
              'walletAddress': 'test-wallet-address',
            }
          }
        };

        // Trigger auth success
        await state._handleAuthSuccess(
          authPayload,
          origin: AuthOrigin.emailPassword,
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<WalletProvider>(
                create: (_) => mockWalletProvider,
              ),
              ChangeNotifierProvider<CacheProvider>(
                create: (_) => mockCacheProvider,
              ),
              ChangeNotifierProvider<ProfileProvider>(
                create: (_) => mockProfileProvider,
              ),
              ChangeNotifierProvider<SavedItemsProvider>(
                create: (_) => mockSavedItemsProvider,
              ),
            ],
            child: MaterialApp(
              home: SignInScreen(
                embedded: true,
              ),
            ),
          ),
        );

        // After auth success, loading screen should be visible
        // and login form should NOT be visible
        expect(
          find.byType(PostAuthLoadingScreen),
          findsOneWidget,
          reason: 'PostAuthLoadingScreen should be visible after auth success',
        );
      },
    );

    testWidgets(
      'AuthMethodsPanel shows PostAuthLoadingScreen after wallet auth success',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<WalletProvider>(
                create: (_) => mockWalletProvider,
              ),
              ChangeNotifierProvider<CacheProvider>(
                create: (_) => mockCacheProvider,
              ),
              ChangeNotifierProvider<ProfileProvider>(
                create: (_) => mockProfileProvider,
              ),
              ChangeNotifierProvider<SavedItemsProvider>(
                create: (_) => mockSavedItemsProvider,
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: AuthMethodsPanel(
                  embedded: true,
                ),
              ),
            ),
          ),
        );

        // Initial state: auth methods should be visible
        expect(find.byType(AuthMethodsPanel), findsOneWidget);
        expect(find.byType(PostAuthLoadingScreen), findsNothing);

        // Get the state and trigger auth success
        final state = tester.state<_AuthMethodsPanelState>(
          find.byType(AuthMethodsPanel),
        );

        final authPayload = {
          'data': {
            'user': {
              'id': 'test-wallet-user',
              'walletAddress': 'wallet-address-from-connect',
            }
          }
        };

        await state._handleAuthSuccess(
          authPayload,
          origin: AuthOrigin.wallet,
        );

        // Pump to rebuild
        await tester.pump();

        // After auth success, loading screen should be visible
        expect(
          find.byType(PostAuthLoadingScreen),
          findsOneWidget,
          reason: 'PostAuthLoadingScreen should be visible after wallet auth',
        );
      },
    );

    testWidgets(
      'Post-auth loading screen is never invisible',
      (WidgetTester tester) async {
        // This test ensures that between auth success and coordinator completion,
        // the loading screen is always visible - the login form never stays visible

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<WalletProvider>(
                create: (_) => mockWalletProvider,
              ),
              ChangeNotifierProvider<CacheProvider>(
                create: (_) => mockCacheProvider,
              ),
              ChangeNotifierProvider<ProfileProvider>(
                create: (_) => mockProfileProvider,
              ),
              ChangeNotifierProvider<SavedItemsProvider>(
                create: (_) => mockSavedItemsProvider,
              ),
            ],
            child: MaterialApp(
              home: SignInScreen(
                embedded: true,
              ),
            ),
          ),
        );

        // Get state and simulate rapid auth success calls
        final state =
            tester.state<_SignInScreenState>(find.byType(SignInScreen));

        for (int i = 0; i < 3; i++) {
          await state._handleAuthSuccess(
            {
              'data': {
                'user': {
                  'id': 'test-user-$i',
                  'walletAddress': 'test-wallet-$i',
                }
              }
            },
            origin: AuthOrigin.emailPassword,
          );

          await tester.pump();

          // After each auth success, loading screen should be immediately visible
          expect(
            find.byType(PostAuthLoadingScreen),
            findsOneWidget,
            reason:
                'PostAuthLoadingScreen must be visible immediately after auth (iteration $i)',
          );

          // Reset for next iteration
          state._postAuthActive = false;
          await tester.pump();
        }
      },
    );
  });
}

// Mock providers for testing
class MockWalletProvider extends ChangeNotifier {
  String? currentWalletAddress;
}

class MockCacheProvider extends ChangeNotifier {}

class MockProfileProvider extends ChangeNotifier {
  User? currentUser;
}

class MockSavedItemsProvider extends ChangeNotifier {}

class User {
  final String id;
  final String? walletAddress;

  User({required this.id, this.walletAddress});
}
