import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../../utils/kubus_failure.dart';

export '../../utils/kubus_failure.dart'
    show KubusFailureKind, classifyKubusFailure;
import '../inline_loading.dart';
import '../kubus_button.dart';

/// PRODUCT v5 loading and error states.
///
/// Loading is classified by scope, never one full-screen spinner for all:
///
/// * page initial load → [KubusPageLoading] (compact indicator, stable slot)
/// * section load → [KubusSectionLoading] (static layout blocks, no shimmer)
/// * pagination → [KubusPaginationLoading] (one 48 px row at the list end)
/// * button/action → `KubusButton(isLoading: true)` (keeps its width)
/// * media → the image widget's own placeholder (`KubusCachedImage`)
///
/// Failures are classified with [classifyKubusFailure] and rendered by
/// [KubusStateView] (page or section) with a recovery action matching the
/// kind: retry for network/server, sign in for authentication, an
/// explanation for permission, a way back for not found, reconnect for
/// wallet. Field validation stays inline on the field; transient
/// confirmations stay in snackbars.

/// Localized title/description for a failure kind.
class KubusFailureCopy {
  const KubusFailureCopy(this.title, this.description);

  final String title;
  final String description;

  static KubusFailureCopy of(AppLocalizations l10n, KubusFailureKind kind) {
    return switch (kind) {
      KubusFailureKind.network =>
        KubusFailureCopy(l10n.stateNetworkTitle, l10n.stateNetworkDescription),
      KubusFailureKind.offline =>
        KubusFailureCopy(l10n.stateOfflineTitle, l10n.stateOfflineDescription),
      KubusFailureKind.server =>
        KubusFailureCopy(l10n.stateServerTitle, l10n.stateServerDescription),
      KubusFailureKind.authentication =>
        KubusFailureCopy(l10n.stateAuthTitle, l10n.stateAuthDescription),
      KubusFailureKind.permission => KubusFailureCopy(
          l10n.statePermissionTitle, l10n.statePermissionDescription),
      KubusFailureKind.notFound => KubusFailureCopy(
          l10n.stateNotFoundTitle, l10n.stateNotFoundDescription),
      KubusFailureKind.validation => KubusFailureCopy(
          l10n.stateValidationTitle, l10n.stateValidationDescription),
      KubusFailureKind.rateLimit => KubusFailureCopy(
          l10n.stateRateLimitTitle, l10n.stateRateLimitDescription),
      KubusFailureKind.wallet =>
        KubusFailureCopy(l10n.stateWalletTitle, l10n.stateWalletDescription),
      KubusFailureKind.unsupported => KubusFailureCopy(
          l10n.stateUnsupportedTitle, l10n.stateUnsupportedDescription),
      KubusFailureKind.unknown =>
        KubusFailureCopy(l10n.stateUnknownTitle, l10n.stateUnknownDescription),
    };
  }
}

IconData _iconFor(KubusFailureKind kind) => switch (kind) {
      KubusFailureKind.network => Icons.sync_problem_outlined,
      KubusFailureKind.offline => Icons.wifi_off_outlined,
      KubusFailureKind.server => Icons.dns_outlined,
      KubusFailureKind.authentication => Icons.login_outlined,
      KubusFailureKind.permission => Icons.lock_outline,
      KubusFailureKind.notFound => Icons.search_off_outlined,
      KubusFailureKind.validation => Icons.rule_outlined,
      KubusFailureKind.rateLimit => Icons.hourglass_empty_outlined,
      KubusFailureKind.wallet => Icons.account_balance_wallet_outlined,
      KubusFailureKind.unsupported => Icons.block_outlined,
      KubusFailureKind.unknown => Icons.error_outline,
    };

/// Page-level or section-level failure with a kind-specific recovery.
///
/// Only actions whose callbacks are supplied are shown, so a screen never
/// offers a recovery it cannot perform. The primary action is chosen by kind:
/// retry (network, offline, server, rate limit, unknown), sign in
/// (authentication), reconnect (wallet). Permission, validation and
/// unsupported explain the restriction; not found offers the way back.
class KubusStateView extends StatelessWidget {
  const KubusStateView({
    super.key,
    required this.kind,
    this.onRetry,
    this.onSignIn,
    this.onBack,
    this.onReconnect,
    this.title,
    this.description,
    this.compact = false,
  });

  /// Convenience constructor that classifies a caught error.
  factory KubusStateView.fromError(
    Object? error, {
    Key? key,
    VoidCallback? onRetry,
    VoidCallback? onSignIn,
    VoidCallback? onBack,
    VoidCallback? onReconnect,
    bool compact = false,
  }) {
    return KubusStateView(
      key: key,
      kind: classifyKubusFailure(error),
      onRetry: onRetry,
      onSignIn: onSignIn,
      onBack: onBack,
      onReconnect: onReconnect,
      compact: compact,
    );
  }

  final KubusFailureKind kind;
  final VoidCallback? onRetry;
  final VoidCallback? onSignIn;
  final VoidCallback? onBack;
  final VoidCallback? onReconnect;

  /// Overrides for a screen that can be more specific than the kind copy.
  final String? title;
  final String? description;

  /// Section variant: left-aligned, no large icon, fits inside a list.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    final copy = KubusFailureCopy.of(l10n, kind);
    final resolvedTitle = title ?? copy.title;
    final resolvedDescription = description ?? copy.description;

    final actions = <Widget>[];
    void add(String label, VoidCallback? onPressed, KubusButtonVariant v,
        {IconData? icon}) {
      if (onPressed == null) return;
      actions.add(KubusButton(
        onPressed: onPressed,
        label: label,
        icon: icon,
        variant: actions.isEmpty ? v : KubusButtonVariant.quiet,
      ));
    }

    switch (kind) {
      case KubusFailureKind.authentication:
        add(l10n.commonSignIn, onSignIn, KubusButtonVariant.primary);
        add(l10n.commonBack, onBack, KubusButtonVariant.quiet);
      case KubusFailureKind.wallet:
        add(l10n.commonReconnect, onReconnect, KubusButtonVariant.primary);
        add(l10n.commonRetry, onRetry, KubusButtonVariant.quiet);
      case KubusFailureKind.notFound:
        add(l10n.commonBack, onBack, KubusButtonVariant.secondary);
      case KubusFailureKind.permission:
      case KubusFailureKind.unsupported:
      case KubusFailureKind.validation:
        add(l10n.commonBack, onBack, KubusButtonVariant.quiet);
      case KubusFailureKind.network:
      case KubusFailureKind.offline:
      case KubusFailureKind.server:
      case KubusFailureKind.rateLimit:
      case KubusFailureKind.unknown:
        add(l10n.commonRetry, onRetry, KubusButtonVariant.secondary,
            icon: Icons.refresh);
        add(l10n.commonBack, onBack, KubusButtonVariant.quiet);
    }

    final text = Column(
      crossAxisAlignment:
          compact ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(
            resolvedTitle,
            textAlign: compact ? TextAlign.start : TextAlign.center,
            style: (compact
                    ? KubusTextStyles.detailCardTitle
                    : KubusTextStyles.sectionTitle)
                .copyWith(color: roles.foreground, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: KubusSpacing.xs),
        Text(
          resolvedDescription,
          textAlign: compact ? TextAlign.start : TextAlign.center,
          style: KubusTextStyles.detailBody.copyWith(
            color: roles.foregroundMuted,
          ),
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: KubusSpacing.md),
          Wrap(
            alignment: compact ? WrapAlignment.start : WrapAlignment.center,
            spacing: KubusSpacing.sm,
            runSpacing: KubusSpacing.sm,
            children: actions,
          ),
        ],
      ],
    );

    final body = compact
        ? Container(
            width: double.infinity,
            padding: const EdgeInsets.all(KubusSpacing.md),
            decoration: BoxDecoration(
              color: roles.surface,
              borderRadius: BorderRadius.circular(KubusRadius.surface),
              border:
                  Border(left: BorderSide(color: roles.ruleStrong, width: 2)),
            ),
            child: text,
          )
        : Padding(
            padding: const EdgeInsets.all(KubusSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      _iconFor(kind),
                      size: 32,
                      color: roles.foregroundMuted,
                    ),
                  ),
                  const SizedBox(height: KubusSpacing.md),
                  text,
                ],
              ),
            ),
          );

    return Semantics(
      container: true,
      liveRegion: true,
      child: compact ? body : Center(child: SingleChildScrollView(child: body)),
    );
  }
}

/// Page initial load: a compact indicator in a stable slot (no splash art,
/// no full-bleed spinner) with a spoken "Loading" label.
class KubusPageLoading extends StatelessWidget {
  const KubusPageLoading({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    final text = label ?? l10n.commonLoading;
    return Semantics(
      liveRegion: true,
      label: text,
      child: ExcludeSemantics(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(KubusSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: InlineLoading(
                    expand: true,
                    shape: BoxShape.circle,
                    tileSize: 4,
                  ),
                ),
                if (label != null) ...[
                  const SizedBox(height: KubusSpacing.sm),
                  Text(
                    label!,
                    style: KubusTextStyles.detailCaption.copyWith(
                      color: roles.foregroundMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Section load: static placeholder blocks shaped like the content, so the
/// layout does not jump when data arrives. No shimmer (reduced-motion safe).
class KubusSectionLoading extends StatelessWidget {
  const KubusSectionLoading({super.key, this.rows = 3, this.rowHeight = 56});

  final int rows;
  final double rowHeight;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    return Semantics(
      label: l10n.commonLoading,
      liveRegion: true,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < rows; i++)
              Container(
                height: rowHeight,
                margin: const EdgeInsets.only(bottom: KubusSpacing.sm),
                decoration: BoxDecoration(
                  color: roles.surfaceRaised.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(KubusRadius.surface),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Pagination / infinite-list tail: one 48 px row, announced once.
class KubusPaginationLoading extends StatelessWidget {
  const KubusPaginationLoading({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    return Semantics(
      liveRegion: true,
      label: l10n.stateLoadingMore,
      child: ExcludeSemantics(
        child: SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: InlineLoading(
                  expand: true,
                  shape: BoxShape.circle,
                  tileSize: 3,
                ),
              ),
              const SizedBox(width: KubusSpacing.sm),
              Text(
                l10n.stateLoadingMore,
                style: KubusTextStyles.detailCaption.copyWith(
                  color: roles.foregroundMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
