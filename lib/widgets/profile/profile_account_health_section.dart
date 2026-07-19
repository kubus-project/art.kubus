import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../utils/design_tokens.dart';
import '../secure_account_banner_card.dart';
import '../wallet_backup_banner_card.dart';

/// Builder that receives the visibility-resolution callback the section
/// wires into each notice widget.
typedef ProfileAccountNoticeBuilder = Widget Function(
  ValueChanged<bool> onVisibilityResolved,
);

/// Groups account/security notices under one compact "Account health" area
/// instead of stacking full-width banners ahead of cultural content.
///
/// Severity rules:
/// - critical notices (wallet backup required) always render inline and
///   expanded — they are never hidden or collapsed;
/// - advisory notices (add email/password) render inline when they are the
///   only notice, but collapse behind a compact "Account suggestions"
///   disclosure while a critical notice is present;
/// - when nothing fires, the section renders nothing at all (no header, no
///   reserved space).
class ProfileAccountHealthSection extends StatefulWidget {
  const ProfileAccountHealthSection({
    super.key,
    this.criticalBuilder,
    this.advisoryBuilder,
    this.bottomSpacing = 0,
  });

  /// Overrides for tests; production defaults are the wallet-backup
  /// (critical) and secure-account (advisory) banner cards.
  final ProfileAccountNoticeBuilder? criticalBuilder;
  final ProfileAccountNoticeBuilder? advisoryBuilder;
  final double bottomSpacing;

  @override
  State<ProfileAccountHealthSection> createState() =>
      _ProfileAccountHealthSectionState();
}

class _ProfileAccountHealthSectionState
    extends State<ProfileAccountHealthSection> {
  bool _criticalVisible = false;
  bool _advisoryVisible = false;
  bool _advisoryExpanded = false;

  void _resolveCritical(bool visible) {
    if (!mounted || _criticalVisible == visible) return;
    setState(() => _criticalVisible = visible);
  }

  void _resolveAdvisory(bool visible) {
    if (!mounted || _advisoryVisible == visible) return;
    setState(() => _advisoryVisible = visible);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final critical = widget.criticalBuilder?.call(_resolveCritical) ??
        WalletBackupBannerCard(onVisibilityResolved: _resolveCritical);
    final advisory = widget.advisoryBuilder?.call(_resolveAdvisory) ??
        SecureAccountBannerCard(onVisibilityResolved: _resolveAdvisory);

    final anyVisible = _criticalVisible || _advisoryVisible;
    final collapseAdvisory = _criticalVisible && _advisoryVisible;
    final advisoryOffstage = collapseAdvisory && !_advisoryExpanded;

    final section = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (anyVisible) ...[
          Row(
            children: [
              Icon(
                Icons.health_and_safety_outlined,
                size: 16,
                color: scheme.onSurface.withValues(alpha: 0.62),
              ),
              const SizedBox(width: KubusSpacing.sm),
              Text(
                l10n.profileAccountHealthTitle,
                style: KubusTextStyles.sectionTitle.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
          const SizedBox(height: KubusSpacing.sm),
        ],
        // Both notices stay mounted so their async visibility can resolve;
        // hidden ones render SizedBox.shrink on their own.
        critical,
        if (_criticalVisible && _advisoryVisible)
          const SizedBox(height: KubusSpacing.sm),
        if (collapseAdvisory)
          Semantics(
            button: true,
            expanded: _advisoryExpanded,
            child: InkWell(
              borderRadius: BorderRadius.circular(KubusRadius.sm),
              onTap: () =>
                  setState(() => _advisoryExpanded = !_advisoryExpanded),
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(
                  horizontal: KubusSpacing.md,
                  vertical: KubusSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.30),
                  borderRadius: BorderRadius.circular(KubusRadius.sm),
                  border: KubusBorders.hairline(context),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.profileAccountHealthAdvisoryLabel,
                        style: KubusTextStyles.navLabel.copyWith(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface.withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                    Icon(
                      _advisoryExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 18,
                      color: scheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (collapseAdvisory && _advisoryExpanded)
          const SizedBox(height: KubusSpacing.sm),
        Offstage(offstage: advisoryOffstage, child: advisory),
      ],
    );

    if (!anyVisible || widget.bottomSpacing <= 0) return section;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        section,
        SizedBox(height: widget.bottomSpacing),
      ],
    );
  }
}
