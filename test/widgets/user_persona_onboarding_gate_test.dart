import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/widgets/user_persona_onboarding_gate.dart';
import 'package:art_kubus/widgets/user_persona_onboarding_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildTestApp(ProfileProvider profileProvider) {
  return ChangeNotifierProvider<ProfileProvider>.value(
    value: profileProvider,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: UserPersonaOnboardingGate(
          child: Container(color: Colors.black),
        ),
      ),
    ),
  );
}

UserProfile _profileForWallet(String walletAddress) {
  final now = DateTime(2026, 3, 16);
  return UserProfile(
    id: 'profile_$walletAddress',
    walletAddress: walletAddress,
    username: 'legacy_user',
    displayName: 'Legacy User',
    bio: 'Existing account',
    avatar: '',
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('shows persona sheet for legacy signed-in users',
      (tester) async {
    final profileProvider = ProfileProvider();
    profileProvider.setCurrentUser(_profileForWallet('0xabc'));

    await tester.pumpWidget(_buildTestApp(profileProvider));
    await tester.pumpAndSettle();

    expect(find.byType(UserPersonaOnboardingSheet), findsOneWidget);
  });

  testWidgets('suppresses persona sheet while structured onboarding is pending',
      (tester) async {
    SharedPreferences.setMockInitialValues(
      const <String, Object>{'pending_auth_onboarding_v1': true},
    );
    final profileProvider = ProfileProvider();
    profileProvider.setCurrentUser(_profileForWallet('0xabc'));

    await tester.pumpWidget(_buildTestApp(profileProvider));
    await tester.pumpAndSettle();

    expect(find.byType(UserPersonaOnboardingSheet), findsNothing);
  });
}
