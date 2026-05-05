import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/screens/onboarding/onboarding_flow_screen.dart';
import 'package:art_kubus/services/auth_redirect_controller.dart';
import 'package:art_kubus/services/post_auth_coordinator.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:flutter/material.dart';

enum PostAuthLoadingPresentation {
  fullScreen,
  shellEmbedded,
  inline,
}

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
    this.presentation = PostAuthLoadingPresentation.fullScreen,
    this.onBeforeSavedItemsSync,
    this.onAuthSuccess,
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
  final PostAuthLoadingPresentation presentation;
  final Future<void> Function()? onBeforeSavedItemsSync;
  final Future<void> Function(Map<String, dynamic> payload)? onAuthSuccess;

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
      onBeforeSavedItemsSync: widget.onBeforeSavedItemsSync,
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

    if (widget.onAuthSuccess != null) {
      try {
        await widget.onAuthSuccess!(widget.payload);
      } catch (e) {
        AppConfig.debugPrint('PostAuthLoadingScreen: onAuthSuccess failed: $e');
      }
    }

    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (result.onboardingStepId != null &&
        result.onboardingStepId!.isNotEmpty) {
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

  Future<void> _goBackToSignIn() async {
    if (!mounted) return;
    await Navigator.of(context)
        .pushNamedAndRemoveUntil('/sign-in', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final isFullScreen =
        widget.presentation == PostAuthLoadingPresentation.fullScreen;
    final content = PostAuthLoadingContent(
      stage: _stage,
      running: _running,
      error: _error,
      onRetry: _running ? null : _runFlow,
      onBackToSignIn: _goBackToSignIn,
      compact: !isFullScreen,
    );

    if (!isFullScreen) {
      return PopScope(
        canPop: false,
        child: content,
      );
    }

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
                    child: SingleChildScrollView(child: content),
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

class PostAuthLoadingContent extends StatelessWidget {
  const PostAuthLoadingContent({
    super.key,
    required this.stage,
    required this.running,
    required this.error,
    required this.onRetry,
    required this.onBackToSignIn,
    this.compact = false,
  });

  final PostAuthStage stage;
  final bool running;
  final Object? error;
  final VoidCallback? onRetry;
  final VoidCallback? onBackToSignIn;
  final bool compact;

  String _stageLabel(AppLocalizations l10n) {
    switch (stage) {
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
    switch (stage) {
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final roles = KubusColorRoles.of(context);
    final isFailed = stage == PostAuthStage.failed;
    final iconSize = compact ? 46.0 : 54.0;

    return LiquidGlassCard(
      padding: EdgeInsets.all(compact ? KubusSpacing.lg : KubusSpacing.xl),
      borderRadius:
          BorderRadius.circular(compact ? KubusRadius.lg : KubusRadius.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFailed
                      ? roles.negativeAction.withValues(alpha: 0.14)
                      : roles.positiveAction.withValues(alpha: 0.14),
                ),
                child: Icon(
                  isFailed ? Icons.error_outline : Icons.lock_outline,
                  color: isFailed ? roles.negativeAction : roles.positiveAction,
                  size: compact ? 24 : 28,
                ),
              ),
              const SizedBox(width: KubusSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isFailed ? l10n.postAuthFailedTitle : _stageLabel(l10n),
                      style: (compact
                              ? KubusTextStyles.sectionTitle
                              : KubusTextStyles.sectionTitle)
                          .copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: KubusSpacing.xs),
                    Text(
                      _stageSubtitle(l10n),
                      style: (compact
                              ? KubusTextStyles.detailBody
                              : KubusTextStyles.sectionSubtitle)
                          .copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.72),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? KubusSpacing.lg : KubusSpacing.xl),
          LinearProgressIndicator(
            minHeight: compact ? 5 : 6,
            backgroundColor: scheme.outlineVariant.withValues(alpha: 0.22),
            valueColor: AlwaysStoppedAnimation<Color>(
              isFailed ? roles.negativeAction : roles.positiveAction,
            ),
          ),
          SizedBox(height: compact ? KubusSpacing.md : KubusSpacing.lg),
          _StageList(
            activeStage: stage,
            failed: isFailed,
            compact: compact,
          ),
          if (isFailed) ...[
            SizedBox(height: compact ? KubusSpacing.md : KubusSpacing.lg),
            Text(
              (error ?? l10n.postAuthFailedBody).toString(),
              style: KubusTextStyles.detailBody.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
            SizedBox(height: compact ? KubusSpacing.md : KubusSpacing.lg),
            Wrap(
              spacing: KubusSpacing.sm,
              runSpacing: KubusSpacing.sm,
              children: [
                OutlinedButton(
                  onPressed: running ? null : onRetry,
                  child: Text(l10n.postAuthRetry),
                ),
                ElevatedButton(
                  onPressed: onBackToSignIn,
                  child: Text(l10n.postAuthBackToSignIn),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StageList extends StatelessWidget {
  const _StageList({
    required this.activeStage,
    required this.failed,
    required this.compact,
  });

  final PostAuthStage activeStage;
  final bool failed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final roles = KubusColorRoles.of(context);
    final items = <({PostAuthStage stage, String label})>[
      (
        stage: PostAuthStage.preparingSession,
        label: l10n.postAuthPreparingSession
      ),
      (stage: PostAuthStage.securingWallet, label: l10n.postAuthSecuringWallet),
      (stage: PostAuthStage.loadingProfile, label: l10n.postAuthLoadingProfile),
      (
        stage: PostAuthStage.syncingSavedItems,
        label: l10n.postAuthSyncingSavedItems
      ),
      (
        stage: PostAuthStage.checkingOnboarding,
        label: l10n.postAuthCheckingOnboarding
      ),
      (
        stage: PostAuthStage.openingWorkspace,
        label: l10n.postAuthOpeningWorkspace
      ),
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
                size: compact ? 16 : 18,
              ),
              const SizedBox(width: KubusSpacing.sm),
              Flexible(
                child: Text(
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
              ),
            ],
          ),
          if (item != items.last)
            SizedBox(height: compact ? KubusSpacing.xs : KubusSpacing.sm),
        ],
      ],
    );
  }
}
