import 'dart:async';

import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/core/shell_routes.dart';
import 'package:art_kubus/models/user_persona.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/screens/desktop/desktop_shell.dart';
import 'package:art_kubus/screens/onboarding/onboarding_flow_screen.dart';
import 'package:art_kubus/services/auth_gating_service.dart';
import 'package:art_kubus/services/auth_onboarding_service.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/onboarding_state_service.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/widgets/app_logo.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:art_kubus/widgets/kubus_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmailVerificationSuccessScreen extends StatefulWidget {
  const EmailVerificationSuccessScreen({
    super.key,
    this.email,
  });

  final String? email;

  @override
  State<EmailVerificationSuccessScreen> createState() =>
      _EmailVerificationSuccessScreenState();
}

class _EmailVerificationSuccessScreenState
    extends State<EmailVerificationSuccessScreen> {
  bool _continuing = false;
  String? _error;

  Future<bool> _hasValidSession(SharedPreferences prefs) async {
    await BackendApiService().loadAuthToken();
    final inMemoryToken = BackendApiService().getAuthToken();
    if (inMemoryToken != null &&
        inMemoryToken.trim().isNotEmpty &&
        AuthGatingService.isAccessTokenValid(inMemoryToken)) {
      return true;
    }
    final status = AuthGatingService.evaluateStoredSession(prefs: prefs);
    if (status == StoredSessionStatus.valid) return true;
    if (status == StoredSessionStatus.refreshRequired) {
      try {
        return await BackendApiService().restoreExistingSession(
          allowRefresh: false,
        );
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  Future<void> _continue() async {
    if (_continuing) return;
    setState(() {
      _continuing = true;
      _error = null;
    });

    try {
      final navigator = Navigator.of(context);
      final isDesktop = DesktopBreakpoints.isDesktop(context);
      final prefs = await SharedPreferences.getInstance();
      final hasSession = await _hasValidSession(prefs);
      final guardActive =
          OnboardingStateService.hasActiveGoogleOnboardingRegistrationGuardSync(
                prefs,
              ) ||
              OnboardingStateService.hasActiveAccountLinkGuardSync(prefs);

      if (!mounted) return;
      if (!hasSession && !guardActive) {
        navigator.pushNamedAndRemoveUntil('/sign-in', (_) => false);
        return;
      }

      final profileProvider = context.read<ProfileProvider>();
      final walletProvider = context.read<WalletProvider>();
      if (hasSession) {
        try {
          await profileProvider
              .loadAuthenticatedProfile()
              .timeout(const Duration(seconds: 6));
        } catch (error) {
          AppConfig.debugPrint(
            'EmailVerificationSuccessScreen: profile refresh failed: $error',
          );
        }
      }

      final walletAddress = (profileProvider.currentUser?.walletAddress ??
              walletProvider.currentWalletAddress ??
              '')
          .trim();
      final userId = (profileProvider.currentUser?.userId ??
              profileProvider.currentUser?.id ??
              prefs.getString('user_id') ??
              '')
          .trim();
      final scopeKey = OnboardingStateService.buildAuthOnboardingScopeKey(
        walletAddress: walletAddress.isEmpty ? null : walletAddress,
        userId: userId.isEmpty ? null : userId,
      );
      final hasPendingAuthOnboarding =
          OnboardingStateService.hasPendingAuthOnboardingSync(
        prefs,
        scopeKey: scopeKey,
      );

      if (guardActive || hasPendingAuthOnboarding) {
        String initialStepId = 'account';
        if (hasSession) {
          if (walletAddress.isEmpty) {
            initialStepId = 'walletConnect';
          } else {
            final requiresWalletBackup =
                AppConfig.isFeatureEnabled('walletBackupOnboarding')
                    ? await walletProvider.isMnemonicBackupRequired(
                        walletAddress: walletAddress,
                      )
                    : false;
            final resume =
                await AuthOnboardingService.resolveStructuredOnboardingResume(
              prefs: prefs,
              hasPendingAuthOnboarding: true,
              hasAuthenticatedSession: true,
              hasHydratedProfile: profileProvider.hasHydratedProfile,
              requiresWalletBackup: requiresWalletBackup,
              heuristicNextStepId:
                  profileProvider.nextStructuredOnboardingStepId,
              persona: profileProvider.userPersona?.storageValue,
              flowScopeKey: scopeKey,
            );
            initialStepId = resume.nextStepId ?? 'role';
          }
        }
        if (!mounted) return;
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => OnboardingFlowScreen(
              forceDesktop: isDesktop,
              initialStepId: initialStepId,
            ),
            settings: const RouteSettings(name: '/onboarding'),
          ),
          (_) => false,
        );
        return;
      }

      if (!mounted) return;
      navigator.pushNamedAndRemoveUntil(
        ShellRoutes.main,
        (_) => false,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not continue from verification. Try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _continuing = false;
        });
      } else {
        _continuing = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final email = (widget.email ?? '').trim();

    return AnimatedGradientBackground(
      duration: const Duration(seconds: 10),
      intensity: 0.18,
      colors: [
        scheme.primary.withValues(alpha: 0.48),
        KubusColors.successDark.withValues(alpha: 0.46),
        scheme.primary.withValues(alpha: 0.48),
      ],
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(KubusSpacing.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: LiquidGlassCard(
                  padding: const EdgeInsets.all(KubusSpacing.xl),
                  borderRadius: BorderRadius.circular(KubusRadius.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: AppLogo(width: 54, height: 54)),
                      const SizedBox(height: KubusSpacing.lg),
                      Icon(
                        Icons.mark_email_read_outlined,
                        color: scheme.primary,
                        size: 54,
                      ),
                      const SizedBox(height: KubusSpacing.md),
                      Text(
                        'Email confirmed',
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: scheme.onSurface,
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(height: KubusSpacing.sm),
                      Text(
                        email.isEmpty
                            ? 'Your email address is verified. Continue to finish your art.kubus setup.'
                            : '$email is verified. Continue to finish your art.kubus setup.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.74),
                              height: 1.42,
                            ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: KubusSpacing.md),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ],
                      const SizedBox(height: KubusSpacing.lg),
                      KubusButton(
                        onPressed: _continuing
                            ? null
                            : () {
                                unawaited(_continue());
                              },
                        isLoading: _continuing,
                        icon: _continuing ? null : Icons.arrow_forward_rounded,
                        label: 'Continue',
                        isFullWidth: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
