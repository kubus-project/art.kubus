import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/screens/web3/wallet/connectwallet_screen.dart';
import 'package:art_kubus/services/google_auth_service.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/email_registration_form.dart';
import 'package:art_kubus/widgets/google_sign_in_button.dart';
import 'package:art_kubus/widgets/google_sign_in_web_button.dart';
import 'package:art_kubus/widgets/kubus_button.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AuthMethodsPanelRegistrationMethods extends StatelessWidget {
  const AuthMethodsPanelRegistrationMethods({
    super.key,
    required this.embedded,
    required this.colorScheme,
    required this.roles,
    required this.showCompactEmailForm,
    required this.showInlineWalletFlow,
    required this.compactLayout,
    required this.enableWallet,
    required this.enableEmail,
    required this.enableGoogle,
    required this.isGoogleSubmitting,
    required this.emailFormShell,
    required this.inlineWalletSurface,
    required this.onShowCompactEmailForm,
    required this.onShowConnectWalletModal,
    required this.onGooglePressed,
    required this.onWebGoogleAuthResult,
    required this.onWebGoogleAuthError,
  });

  final bool embedded;
  final ColorScheme colorScheme;
  final KubusColorRoles roles;
  final bool showCompactEmailForm;
  final bool showInlineWalletFlow;
  final bool compactLayout;
  final bool enableWallet;
  final bool enableEmail;
  final bool enableGoogle;
  final bool isGoogleSubmitting;
  final Widget emailFormShell;
  final Widget inlineWalletSurface;
  final VoidCallback onShowCompactEmailForm;
  final VoidCallback onShowConnectWalletModal;
  final VoidCallback onGooglePressed;
  final Future<void> Function(GoogleAuthResult googleResult)
      onWebGoogleAuthResult;
  final ValueChanged<Object> onWebGoogleAuthError;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showSectionCopy = !embedded && !compactLayout;
    final emailSurface = Color.lerp(
      colorScheme.surface,
      colorScheme.primary,
      isDark ? 0.18 : 0.10,
    )!;
    final walletSurface = Color.lerp(
      colorScheme.surface,
      roles.web3MarketplaceAccent,
      isDark ? 0.24 : 0.14,
    )!;

    final registerMethods = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showSectionCopy) ...[
          Text(
            showCompactEmailForm ? l10n.authOrUseEmail : l10n.authRegisterSubtitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: KubusSpacing.xs),
          Text(
            showCompactEmailForm
                ? l10n.authRegisterSubtitle
                : l10n.authHighlightOptionalWeb3,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.66),
                  height: 1.45,
                ),
          ),
          SizedBox(height: compactLayout ? KubusSpacing.md : KubusSpacing.lg),
        ],
        if (!showCompactEmailForm && enableGoogle) ...[
          if (kIsWeb)
            GoogleSignInWebButton(
              colorScheme: colorScheme,
              isLoading: isGoogleSubmitting,
              onAuthResult: onWebGoogleAuthResult,
              onAuthError: onWebGoogleAuthError,
            )
          else
            GoogleSignInButton(
              onPressed: () async => onGooglePressed(),
              isLoading: isGoogleSubmitting,
              colorScheme: colorScheme,
            ),
          SizedBox(height: compactLayout ? KubusSpacing.xs : KubusSpacing.sm),
        ],
        if (!showCompactEmailForm && enableEmail) ...[
          KubusButton(
            onPressed: onShowCompactEmailForm,
            icon: Icons.email_outlined,
            label: l10n.authContinueWithEmail,
            variant: KubusButtonVariant.secondary,
            backgroundColor: emailSurface,
            foregroundColor: colorScheme.onSurface,
            isFullWidth: true,
          ),
          SizedBox(height: compactLayout ? KubusSpacing.xs : KubusSpacing.sm),
        ],
        if (!showCompactEmailForm && enableWallet) ...[
          if (showSectionCopy)
            const AuthMethodsPanelMethodDivider(),
          SizedBox(height: compactLayout ? KubusSpacing.xs : KubusSpacing.sm),
          KubusButton(
            onPressed: onShowConnectWalletModal,
            icon: Icons.account_balance_wallet_outlined,
            label: l10n.authConnectWalletButton,
            variant: KubusButtonVariant.secondary,
            backgroundColor: walletSurface,
            foregroundColor: colorScheme.onSurface,
            isFullWidth: true,
          ),
        ],
        if (showCompactEmailForm) ...[
          emailFormShell,
        ],
      ],
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: KeyedSubtree(
        key: ValueKey<String>(
          showInlineWalletFlow
              ? 'register-wallet-inline'
              : 'register-auth-forms',
        ),
        child: showInlineWalletFlow ? inlineWalletSurface : registerMethods,
      ),
    );
  }
}

class AuthMethodsPanelEmailFormShell extends StatelessWidget {
  const AuthMethodsPanelEmailFormShell({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.usernameController,
    required this.requireUsername,
    required this.emailError,
    required this.passwordError,
    required this.confirmPasswordError,
    required this.usernameError,
    required this.onSubmit,
    required this.isSubmitting,
    required this.compact,
    required this.onBack,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final TextEditingController usernameController;
  final bool requireUsername;
  final String? emailError;
  final String? passwordError;
  final String? confirmPasswordError;
  final String? usernameError;
  final VoidCallback onSubmit;
  final bool isSubmitting;
  final bool compact;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EmailRegistrationForm(
          emailController: emailController,
          passwordController: passwordController,
          confirmPasswordController: confirmPasswordController,
          usernameController: usernameController,
          requireUsername: requireUsername,
          showUsernameInCompact: requireUsername,
          emailError: emailError,
          passwordError: passwordError,
          confirmPasswordError: confirmPasswordError,
          usernameError: usernameError,
          onSubmit: onSubmit,
          isSubmitting: isSubmitting,
          compact: compact,
          autofocusEmail: true,
          submitLabel: l10n.authContinueWithEmail,
          submittingLabel: l10n.commonWorking,
        ),
        const SizedBox(height: KubusSpacing.sm),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: onBack,
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.82),
            ),
            child: Text(l10n.commonBack),
          ),
        ),
      ],
    );
  }
}

class AuthMethodsPanelInlineWalletSurface extends StatelessWidget {
  const AuthMethodsPanelInlineWalletSurface({
    super.key,
    required this.initialStep,
    required this.requiredWalletAddress,
    required this.onRequestClose,
    required this.onFlowComplete,
  });

  final int initialStep;
  final String? requiredWalletAddress;
  final VoidCallback onRequestClose;
  final ValueChanged<Object?> onFlowComplete;

  @override
  Widget build(BuildContext context) {
    return ConnectWallet(
      embedded: true,
      authInline: true,
      initialStep: initialStep,
      telemetryAuthFlow: 'signup',
      requiredWalletAddress: requiredWalletAddress,
      onRequestClose: onRequestClose,
      onFlowComplete: onFlowComplete,
    );
  }
}

class AuthMethodsPanelMethodDivider extends StatelessWidget {
  const AuthMethodsPanelMethodDivider({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resolvedLabel = label ?? AppLocalizations.of(context)!.authHighlightOptionalWeb3;

    return Row(
      children: [
        Expanded(
          child: Divider(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
            height: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: KubusSpacing.sm),
          child: Text(
            resolvedLabel,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.56),
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        Expanded(
          child: Divider(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
            height: 1,
          ),
        ),
      ],
    );
  }
}
