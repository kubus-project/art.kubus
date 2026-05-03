import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/services/auth_redirect_controller.dart';
import 'package:art_kubus/screens/onboarding/onboarding_flow_screen.dart';
import 'package:art_kubus/services/post_auth_coordinator.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:art_kubus/widgets/secure_account_password_prompt.dart';
import 'package:flutter/material.dart';

class PostAuthLoadingScreen extends StatefulWidget {
  const PostAuthLoadingScreen({
    super.key,
    required this.payload,
    required this.origin,
    this.coordinator = const PostAuthCoordinator(),
    this.redirectRoute,
    this.redirectArguments,
    this.walletAddress,
    this.userId,
    this.embedded = false,
    this.modalReauth = false,
    this.requiresWalletBackup = false,
  });

  final Map<String, dynamic> payload;
  final AuthOrigin origin;
  final PostAuthCoordinator coordinator;
  final String? redirectRoute;
  final Object? redirectArguments;
  final String? walletAddress;
  final Object? userId;
  final bool embedded;
  final bool modalReauth;
  final bool requiresWalletBackup;

  @override
  State<PostAuthLoadingScreen> createState() => _PostAuthLoadingScreenState();
}

class _PostAuthLoadingScreenState extends State<PostAuthLoadingScreen> {
  PostAuthStage _stage = PostAuthStage.preparingSession;
  Object? _error;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runFlow());
  }

  Future<void> _runFlow() async {
    if (_running || !mounted) return;
    setState(() {
      _running = true;
      _error = null;
      _stage = PostAuthStage.preparingSession;
    });

    final result = await widget.coordinator.complete(
      context: context,
      origin: widget.origin,
      payload: widget.payload,
      redirectRoute: widget.redirectRoute,
      redirectArguments: widget.redirectArguments,
      walletAddress: widget.walletAddress,
      userId: widget.userId,
      embedded: widget.embedded,
      modalReauth: widget.modalReauth,
      requiresWalletBackup: widget.requiresWalletBackup,
      onBeforeSavedItemsSync: () => maybeShowGooglePasswordUpgradePrompt(
        context,
        widget.payload,
      ),
      onStageChanged: (stage) {
        if (!mounted) return;
        setState(() => _stage = stage);
      },
    );

    if (!mounted) return;
    if (!result.completed) {
      setState(() {
        _running = false;
        _error = result.error ?? 'post-auth-failed';
        _stage = PostAuthStage.failed;
      });
      return;
    }

    final navigator = Navigator.of(context);
    if (result.onboardingStepId != null && result.onboardingStepId!.isNotEmpty) {
      await navigator.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => OnboardingFlowScreen(
            forceDesktop: MediaQuery.of(context).size.width >= 1024,
            initialStepId: result.onboardingStepId,
          ),
          settings: const RouteSettings(name: '/onboarding'),
        ),
        (_) => false,
      );
      return;
    }

    final routeName = result.routeName ?? '/main';
    if (result.replaceStack) {
      await navigator.pushNamedAndRemoveUntil(
        routeName,
        (_) => false,
        arguments: result.arguments,
      );
    } else {
      await navigator.pushReplacementNamed(
        routeName,
        arguments: result.arguments,
      );
    }
  }

  String _stageLabel(AppLocalizations l10n) {
    switch (_stage) {
      case PostAuthStage.preparingSession:
        return l10n.postAuthPreparingSession;
      case PostAuthStage.securingWallet:
        return l10n.postAuthSecuringWallet;
      case PostAuthStage.loadingProfile:
        return l10n.postAuthLoadingProfile;
      case PostAuthStage.syncingSavedItems:
        return l10n.postAuthSyncingSavedItems;
      case PostAuthStage.checkingOnboarding:
        return l10n.postAuthCheckingOnboarding;
      case PostAuthStage.openingWorkspace:
        return l10n.postAuthOpeningWorkspace;
      case PostAuthStage.failed:
        return l10n.postAuthFailedTitle;
    }
  }

  String _stageSubtitle(AppLocalizations l10n) {
    switch (_stage) {
      case PostAuthStage.preparingSession:
        return l10n.postAuthPreparingSessionBody;
      case PostAuthStage.securingWallet:
        return l10n.postAuthSecuringWalletBody;
      case PostAuthStage.loadingProfile:
        return l10n.postAuthLoadingProfileBody;
      case PostAuthStage.syncingSavedItems:
        return l10n.postAuthSyncingSavedItemsBody;
      case PostAuthStage.checkingOnboarding:
        return l10n.postAuthCheckingOnboardingBody;
      case PostAuthStage.openingWorkspace:
        return l10n.postAuthOpeningWorkspaceBody;
      case PostAuthStage.failed:
        return l10n.postAuthFailedBody;
    }
  }

  Future<void> _goBackToSignIn() async {
    if (!mounted) return;
    await Navigator.of(context).pushNamedAndRemoveUntil('/sign-in', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final roles = KubusColorRoles.of(context);
    final isFailed = _stage == PostAuthStage.failed;

    return PopScope(
      canPop: false,
      child: AnimatedGradientBackground(
        duration: const Duration(seconds: 12),
        intensity: 0.2,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: GlassSurface(
              borderRadius: BorderRadius.zero,
              showBorder: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(KubusSpacing.lg),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: LiquidGlassCard(
                      padding: const EdgeInsets.all(KubusSpacing.xl),
                      borderRadius: BorderRadius.circular(KubusRadius.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isFailed
                                      ? roles.negativeAction.withValues(alpha: 0.14)
                                      : roles.positiveAction.withValues(alpha: 0.14),
                                ),
                                child: Icon(
                                  isFailed ? Icons.error_outline : Icons.lock_outline,
                                  color: isFailed ? roles.negativeAction : roles.positiveAction,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: KubusSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isFailed ? l10n.postAuthFailedTitle : _stageLabel(l10n),
                                      style: KubusTextStyles.sectionTitle.copyWith(
                                        color: scheme.onSurface,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: KubusSpacing.xs),
                                    Text(
                                      _stageSubtitle(l10n),
                                      style: KubusTextStyles.sectionSubtitle.copyWith(
                                        color: scheme.onSurface.withValues(alpha: 0.72),
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: KubusSpacing.xl),
                          LinearProgressIndicator(
                            minHeight: 6,
                            backgroundColor: scheme.outlineVariant.withValues(alpha: 0.22),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isFailed ? roles.negativeAction : roles.positiveAction,
                            ),
                          ),
                          const SizedBox(height: KubusSpacing.lg),
                          _StageList(
                            activeStage: _stage,
                            failed: isFailed,
                          ),
                          if (isFailed) ...[
                            const SizedBox(height: KubusSpacing.lg),
                            Text(
                              (_error ?? l10n.postAuthFailedBody).toString(),
                              style: KubusTextStyles.detailBody.copyWith(
                                color: scheme.onSurface.withValues(alpha: 0.72),
                              ),
                            ),
                            const SizedBox(height: KubusSpacing.lg),
                            Wrap(
                              spacing: KubusSpacing.sm,
                              runSpacing: KubusSpacing.sm,
                              children: [
                                OutlinedButton(
                                  onPressed: _running ? null : _runFlow,
                                  child: Text(l10n.postAuthRetry),
                                ),
                                ElevatedButton(
                                  onPressed: _goBackToSignIn,
                                  child: Text(l10n.postAuthBackToSignIn),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
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

class _StageList extends StatelessWidget {
  const _StageList({required this.activeStage, required this.failed});

  final PostAuthStage activeStage;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final roles = KubusColorRoles.of(context);
    final items = <({PostAuthStage stage, String label})>[
      (stage: PostAuthStage.preparingSession, label: l10n.postAuthPreparingSession),
      (stage: PostAuthStage.securingWallet, label: l10n.postAuthSecuringWallet),
      (stage: PostAuthStage.loadingProfile, label: l10n.postAuthLoadingProfile),
      (stage: PostAuthStage.syncingSavedItems, label: l10n.postAuthSyncingSavedItems),
      (stage: PostAuthStage.checkingOnboarding, label: l10n.postAuthCheckingOnboarding),
      (stage: PostAuthStage.openingWorkspace, label: l10n.postAuthOpeningWorkspace),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items) ...[
          Row(
            children: [
              Icon(
                item.stage == activeStage
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: failed && item.stage == activeStage
                    ? roles.negativeAction
                    : item.stage.index <= activeStage.index
                        ? roles.positiveAction
                        : scheme.onSurface.withValues(alpha: 0.28),
                size: 18,
              ),
              const SizedBox(width: KubusSpacing.sm),
              Text(
                item.label,
                style: KubusTextStyles.detailBody.copyWith(
                  color: failed && item.stage == activeStage
                      ? roles.negativeAction
                      : item.stage.index <= activeStage.index
                          ? scheme.onSurface
                          : scheme.onSurface.withValues(alpha: 0.54),
                  fontWeight: item.stage == activeStage
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ],
          ),
          if (item != items.last) const SizedBox(height: KubusSpacing.sm),
        ],
      ],
    );
  }
}
