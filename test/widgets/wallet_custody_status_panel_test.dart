import 'dart:async';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/services/account_identity.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/widgets/wallet_custody_status_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/account_session_fixture.dart';

WalletAuthoritySnapshot _snapshot({
  required WalletAuthorityState state,
  required WalletSignerSource signerSource,
  String? walletAddress = 'wallet-address-123',
  bool hasLocalSigner = false,
  bool hasExternalSigner = false,
  bool externalWalletConnected = false,
  String? externalWalletName,
  bool hasEncryptedBackup = false,
  bool encryptedBackupStatusKnown = true,
  bool hasPasskeyProtection = false,
  bool mnemonicBackupRequired = false,
  bool recoveryNeeded = false,
}) {
  return WalletAuthoritySnapshot(
    state: state,
    signerSource: signerSource,
    walletAddress: walletAddress,
    hasLocalSigner: hasLocalSigner,
    hasExternalSigner: hasExternalSigner,
    externalWalletConnected: externalWalletConnected,
    externalWalletName: externalWalletName,
    hasEncryptedBackup: hasEncryptedBackup,
    encryptedBackupStatusKnown: encryptedBackupStatusKnown,
    hasPasskeyProtection: hasPasskeyProtection,
    mnemonicBackupRequired: mnemonicBackupRequired,
    recoveryNeeded: recoveryNeeded,
  );
}

/// The account facts the panel shows (signed in or not, method, email) come
/// from the profile provider, the one owner of who is signed in.
ProfileProvider _signedIn({
  required AuthSignInMethod method,
  String email = 'artist@example.com',
}) {
  AccountSessionFixture.start(accountId: 'custody-account', email: email);
  unawaited(BackendApiService().setLastSignInMethod(method));
  return ProfileProvider()
    ..setCurrentUser(UserProfile(
      id: 'custody-account',
      userId: 'custody-account',
      walletAddress: '',
      username: 'artist',
      displayName: 'Artist',
      bio: '',
      avatar: '',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ));
}

Widget _wrap(
  Widget child, {
  Locale locale = const Locale('en'),
  ProfileProvider? profile,
}) {
  return ChangeNotifierProvider<ProfileProvider>.value(
    value: profile ?? ProfileProvider(),
    child: MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));
  tearDown(AccountSessionFixture.end);

  testWidgets('renders encrypted-backup signer-missing state in English',
      (tester) async {
    var restoreTapped = false;
    var connectTapped = false;

    await tester.pumpWidget(
      _wrap(
        WalletCustodyStatusPanel(
          authority: _snapshot(
            state: WalletAuthorityState.encryptedBackupAvailableSignerMissing,
            signerSource: WalletSignerSource.none,
            hasEncryptedBackup: true,
            hasPasskeyProtection: true,
          ),
          onRestoreSigner: () => restoreTapped = true,
          onConnectExternalWallet: () => connectTapped = true,
        ),
        profile: _signedIn(method: AuthSignInMethod.email),
      ),
    );
    final l10n = AppLocalizations.of(
      tester.element(find.byType(WalletCustodyStatusPanel)),
    )!;

    expect(find.text(l10n.walletSecurityStatusTitle), findsOneWidget);
    expect(
      find.text(l10n.walletSessionStateEncryptedBackupAvailable),
      findsOneWidget,
    );
    expect(find.text(l10n.walletSecuritySignInMethodLabel), findsOneWidget);
    expect(find.text('Email (artist@example.com)'), findsOneWidget);
    expect(find.text(l10n.walletSecuritySignerStatusLabel), findsOneWidget);
    expect(
      find.text(l10n.walletSecuritySignerRestoreAvailableValue),
      findsOneWidget,
    );
    expect(find.text(l10n.walletSecurityConfigured), findsOneWidget);
    expect(find.text(l10n.walletSecurityRestoreSignerAction), findsOneWidget);
    expect(find.text(l10n.walletSecurityConnectExternalAction), findsOneWidget);
    expect(
        find.text(l10n.walletSecurityBackendBackupClarifier), findsOneWidget);

    await tester.tap(find.text(l10n.walletSecurityRestoreSignerAction));
    await tester.tap(find.text(l10n.walletSecurityConnectExternalAction));

    expect(restoreTapped, isTrue);
    expect(connectTapped, isTrue);
  });

  testWidgets('renders external wallet ready state in Slovenian',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        WalletCustodyStatusPanel(
          compact: true,
          authority: _snapshot(
            state: WalletAuthorityState.externalWalletReady,
            signerSource: WalletSignerSource.external,
            hasExternalSigner: true,
            externalWalletConnected: true,
            externalWalletName: 'Phantom',
          ),
        ),
        locale: const Locale('sl'),
        profile: _signedIn(method: AuthSignInMethod.google),
      ),
    );
    final l10n = AppLocalizations.of(
      tester.element(find.byType(WalletCustodyStatusPanel)),
    )!;

    expect(find.text(l10n.walletSecurityStatusTitle), findsOneWidget);
    expect(find.text(l10n.walletSessionStateExternalWalletReady), findsWidgets);
    expect(find.text(l10n.walletSecuritySignInMethodLabel), findsOneWidget);
    expect(find.text('Google (artist@example.com)'), findsOneWidget);
    expect(find.text(l10n.walletSecuritySignerStatusLabel), findsOneWidget);
    expect(
      find.text(l10n.walletSecurityExternalWalletConnectedValue('Phantom')),
      findsOneWidget,
    );
    expect(
        find.text(l10n.walletSecurityRecoveryNotNeededValue), findsOneWidget);
  });

  testWidgets(
      'walletless account shows no wallet as a neutral state, not an error',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        WalletCustodyStatusPanel(
          authority: _snapshot(
            state: WalletAuthorityState.noWallet,
            signerSource: WalletSignerSource.none,
            walletAddress: null,
          ),
        ),
        profile: _signedIn(method: AuthSignInMethod.email),
      ),
    );
    final context = tester.element(find.byType(WalletCustodyStatusPanel));
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    expect(find.text(l10n.walletSessionStateAccountShellOnly), findsOneWidget);
    // Walletless is by design (#437): not an access failure.
    expect(find.text(l10n.walletSecuritySignerMissingValue), findsNothing);
    expect(find.text(l10n.walletSecurityLocalSignerMissingValue), findsNothing);
    final signerValue = tester.widget<Text>(
      find.text(l10n.settingsNoWalletConnected),
    );
    expect(signerValue.style?.color, isNot(scheme.error));
  });

  testWidgets(
      'a session lost in place leaves no signed-in email on the panel (S3b)',
      (tester) async {
    final profile = _signedIn(method: AuthSignInMethod.email);
    await tester.pumpWidget(
      _wrap(
        WalletCustodyStatusPanel(
          authority: _snapshot(
            state: WalletAuthorityState.localSignerReady,
            signerSource: WalletSignerSource.local,
            hasLocalSigner: true,
          ),
        ),
        profile: profile,
      ),
    );
    final l10n = AppLocalizations.of(
      tester.element(find.byType(WalletCustodyStatusPanel)),
    )!;
    expect(find.text('Email (artist@example.com)'), findsOneWidget);

    // clearAuth-only loss: the credential is gone and the identity change is
    // announced; no wallet-side sign-out runs.
    AccountSessionFixture.end();
    AccountIdentity.notifyListenersChanged();
    await tester.pump();

    expect(find.text('Email (artist@example.com)'), findsNothing);
    expect(find.text(l10n.walletSecuritySignedOutMethod), findsOneWidget);
  });

  testWidgets(
      'a stored wallet with no session shows signed out, not an account',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        WalletCustodyStatusPanel(
          authority: _snapshot(
            state: WalletAuthorityState.walletReadOnly,
            signerSource: WalletSignerSource.none,
          ),
        ),
      ),
    );
    final l10n = AppLocalizations.of(
      tester.element(find.byType(WalletCustodyStatusPanel)),
    )!;

    expect(find.text(l10n.walletSecuritySignedOutMethod), findsOneWidget);
  });
}
