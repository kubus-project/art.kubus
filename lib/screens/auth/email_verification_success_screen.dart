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
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/widgets/app_logo.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:art_kubus/widgets/kubus_button.dart';
import 'package:flutter/material.dart';
import '../../widgets/inline_loading.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmailVerificationSuccessScreen extends StatefulWidget {
  const EmailVerificationSuccessScreen({
    super.key,
    this.email,
    this.autoContinue = false,
    this.sessionEstablished = false,
    this.autoContinueDelay = const Duration(seconds: 5),
  });

  final String? email;

  /// When true, the screen automatically continues into the logged-in app
  /// after [autoContinueDelay] (with a manual "Continue now" button as a skip).
  final bool autoContinue;

  /// True when a backend session token was already persisted from the
  /// verification response, so continuation must never fall back to /sign-in.
  final bool sessionEstablished;

  final Duration autoContinueDelay;

  @override
  State<EmailVerificationSuccessScreen> createState() =>
      _EmailVerificationSuccessScreenState();
}

class _EmailVerificationSuccessScreenState
    extends State<EmailVerificationSuccessScreen> {
  bool _continuing = false;
  String? _error;
  Timer? _autoContinueTimer;

  @override
  void initState() {
    super.initState();
    if (widget.autoContinue) {
      _autoContinueTimer = Timer(widget.autoContinueDelay, () {
        if (!mounted) return;
        unawaited(_continue());
      });
    }
  }

  @override
  void dispose() {
    _autoContinueTimer?.cancel();
    super.dispose();
  }

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
    _autoContinueTimer?.cancel();
    setState(() {
      _continuing = true;
      _error = null;
    });

    try {
      final navigator = Navigator.of(context);
      final isDesktop = DesktopBreakpoints.isDesktop(context);
      final prefs = await SharedPreferences.getInstance();
      // When the verification response already persisted a backend session,
      // continuation is authenticated and must never fall back to /sign-in.
      final hasSession =
          widget.sessionEstablished || await _hasValidSession(prefs);
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
        _error = AppLocalizations.of(context)!.authVerifyEmailSessionFailed;
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
    final l10n = AppLocalizations.of(context)!;
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
                        l10n.authVerifyEmailSuccessTitle,
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: scheme.onSurface,
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(height: KubusSpacing.sm),
                      Text(
                        widget.autoContinue
                            ? (email.isEmpty
                                ? l10n.authVerifyEmailSuccessBodyAutoContinue
                                : l10n.authVerifyEmailSuccessBodyAutoContinueWithEmail(email))
                            : (email.isEmpty
                                ? l10n.authVerifyEmailSuccessBodyManual
                                : l10n.authVerifyEmailSuccessBodyManualWithEmail(email)),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.74),
                              height: 1.42,
                            ),
                      ),
                      if (widget.autoContinue) ...[
                        const SizedBox(height: KubusSpacing.lg),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(KubusRadius.sm),
                          child: InlineLoading(height: 4, borderRadius: BorderRadius.circular(2), color: scheme.primary),
                        ),
                      ],
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
                        label: widget.autoContinue ? l10n.authVerifyEmailContinueNow : l10n.authVerifyEmailContinue,
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
