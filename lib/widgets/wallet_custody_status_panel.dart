import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:flutter/material.dart';

class WalletCustodyStatusPanel extends StatelessWidget {
  const WalletCustodyStatusPanel({
    super.key,
    required this.authority,
    this.onRestoreSigner,
    this.onConnectExternalWallet,
    this.compact = false,
  });

  final WalletAuthoritySnapshot authority;
  final VoidCallback? onRestoreSigner;
  final VoidCallback? onConnectExternalWallet;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final stateColor = _stateColor(scheme);

    return LiquidGlassCard(
      padding: EdgeInsets.all(compact ? KubusSpacing.md : KubusSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: compact
                    ? KubusSizes.walletActionIconBox
                    : KubusSizes.tokenAvatarLg,
                height: compact
                    ? KubusSizes.walletActionIconBox
                    : KubusSizes.tokenAvatarLg,
                decoration: BoxDecoration(
                  color: stateColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(KubusRadius.md),
                  border: KubusBorders.accentTint(stateColor),
                ),
                child: Icon(
                  _stateIcon(),
                  color: stateColor,
                  size: compact
                      ? KubusSizes.walletActionIcon
                      : KubusChromeMetrics.navIcon,
                ),
              ),
              const SizedBox(width: KubusSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.walletSecurityStatusTitle,
                      style: KubusTextStyles.sectionTitle.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: KubusSpacing.sm),
                    // The state pill sits on its own line: it carries a full
                    // sentence ("Wallet access ready on this device") and
                    // must not be squeezed by the title beside it.
                    Align(
                      alignment: Alignment.centerLeft,
                      child: WalletStatusChip(
                        label: _stateLabel(l10n),
                        icon: _stateIcon(),
                        color: stateColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? KubusSpacing.md : KubusSpacing.lg),
          Divider(
            height: KubusSizes.hairline,
            thickness: KubusSizes.hairline,
            color: scheme.outline.withValues(alpha: 0.18),
          ),
          SizedBox(height: compact ? KubusSpacing.md : KubusSpacing.lg),
          _WalletStatusRow(
            icon: Icons.login_outlined,
            label: l10n.walletSecuritySignInMethodLabel,
            value: _signInMethodLabel(l10n),
          ),
          _WalletStatusRow(
            icon: Icons.account_balance_wallet_outlined,
            label: l10n.walletSecurityWalletAddressLabel,
            value: _walletAddressLabel(l10n),
            monospaceValue: (authority.walletAddress ?? '').trim().isNotEmpty,
          ),
          _WalletStatusRow(
            icon: Icons.draw_outlined,
            label: l10n.walletSecuritySignerStatusLabel,
            value: _signerStatusLabel(l10n),
            valueColor: authority.canTransact ? scheme.tertiary : scheme.error,
          ),
          _WalletStatusRow(
            icon: Icons.phone_iphone_outlined,
            label: l10n.walletSecurityLocalSignerLabel,
            value: authority.hasLocalSigner
                ? l10n.walletSecurityLocalSignerReadyValue
                : l10n.walletSecurityLocalSignerMissingValue,
          ),
          _WalletStatusRow(
            icon: Icons.wallet_outlined,
            label: l10n.walletSecurityExternalWalletLabel,
            value: _externalWalletLabel(l10n),
          ),
          _WalletStatusRow(
            icon: Icons.cloud_done_outlined,
            label: l10n.walletSecurityEncryptedBackupLabel,
            value: _encryptedBackupLabel(l10n),
          ),
          _WalletStatusRow(
            icon: Icons.fingerprint,
            label: l10n.walletSecurityPasskeyLabel,
            value: authority.hasPasskeyProtection
                ? l10n.walletSecurityConfigured
                : l10n.walletSecurityNotConfigured,
          ),
          _WalletStatusRow(
            icon: Icons.health_and_safety_outlined,
            label: l10n.walletSecurityRecoveryNeededLabel,
            value: authority.recoveryNeeded
                ? l10n.walletSecurityRecoveryNeededValue
                : l10n.walletSecurityRecoveryNotNeededValue,
            valueColor: authority.recoveryNeeded ? scheme.error : null,
            isLast: true,
          ),
          const SizedBox(height: KubusSpacing.md),
          Text(
            l10n.walletSecurityBackendBackupClarifier,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.72),
                  height: 1.35,
                ),
          ),
          if (_showActions) ...<Widget>[
            const SizedBox(height: KubusSpacing.md),
            Wrap(
              spacing: KubusSpacing.sm,
              runSpacing: KubusSpacing.sm,
              children: <Widget>[
                if (authority.canRestoreFromEncryptedBackup &&
                    onRestoreSigner != null)
                  FilledButton.tonalIcon(
                    onPressed: onRestoreSigner,
                    icon: const Icon(Icons.login_outlined),
                    label: Text(l10n.walletSecurityRestoreSignerAction),
                  ),
                if (!authority.canTransact && onConnectExternalWallet != null)
                  OutlinedButton.icon(
                    onPressed: onConnectExternalWallet,
                    icon: const Icon(Icons.wallet_outlined),
                    label: Text(l10n.walletSecurityConnectExternalAction),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  bool get _showActions =>
      (authority.canRestoreFromEncryptedBackup && onRestoreSigner != null) ||
      (!authority.canTransact && onConnectExternalWallet != null);

  Color _stateColor(ColorScheme scheme) {
    switch (authority.state) {
      case WalletAuthorityState.localSignerReady:
      case WalletAuthorityState.externalWalletReady:
        return scheme.tertiary;
      case WalletAuthorityState.recoveryNeeded:
        return scheme.error;
      case WalletAuthorityState.encryptedBackupAvailableSignerMissing:
      case WalletAuthorityState.walletReadOnly:
        return scheme.primary;
      case WalletAuthorityState.accountShellOnly:
        return scheme.secondary;
      case WalletAuthorityState.signedOut:
        return scheme.outline;
    }
  }

  IconData _stateIcon() {
    switch (authority.state) {
      case WalletAuthorityState.localSignerReady:
        return Icons.key_outlined;
      case WalletAuthorityState.externalWalletReady:
        return Icons.wallet_outlined;
      case WalletAuthorityState.encryptedBackupAvailableSignerMissing:
        return Icons.cloud_done_outlined;
      case WalletAuthorityState.recoveryNeeded:
        return Icons.warning_amber_rounded;
      case WalletAuthorityState.walletReadOnly:
        return Icons.visibility_outlined;
      case WalletAuthorityState.accountShellOnly:
        return Icons.person_outline;
      case WalletAuthorityState.signedOut:
        return Icons.logout_outlined;
    }
  }

  String _stateLabel(AppLocalizations l10n) {
    switch (authority.state) {
      case WalletAuthorityState.signedOut:
        return l10n.walletSessionAccountSignedOut;
      case WalletAuthorityState.accountShellOnly:
        return l10n.walletSessionStateAccountShellOnly;
      case WalletAuthorityState.walletReadOnly:
        return l10n.walletSessionStateWalletReadOnly;
      case WalletAuthorityState.localSignerReady:
        return l10n.walletSessionStateLocalSignerReady;
      case WalletAuthorityState.externalWalletReady:
        return l10n.walletSessionStateExternalWalletReady;
      case WalletAuthorityState.encryptedBackupAvailableSignerMissing:
        return l10n.walletSessionStateEncryptedBackupAvailable;
      case WalletAuthorityState.recoveryNeeded:
        return l10n.walletSessionStateRecoveryNeeded;
    }
  }

  String _signInMethodLabel(AppLocalizations l10n) {
    if (!authority.accountSignedIn) {
      return l10n.walletSecuritySignedOutMethod;
    }
    switch (authority.signInMethod) {
      case AuthSignInMethod.email:
        return authority.accountEmail?.trim().isNotEmpty == true
            ? l10n.walletSecuritySignInMethodEmailWithAddress(
                authority.accountEmail!.trim(),
              )
            : l10n.walletSecuritySignInMethodEmail;
      case AuthSignInMethod.google:
        return authority.accountEmail?.trim().isNotEmpty == true
            ? l10n.walletSecuritySignInMethodGoogleWithAddress(
                authority.accountEmail!.trim(),
              )
            : l10n.walletSecuritySignInMethodGoogle;
      case AuthSignInMethod.wallet:
        return l10n.walletSecuritySignInMethodWallet;
      case AuthSignInMethod.passkey:
        return l10n.authContinueWithPasskey;
      case AuthSignInMethod.unknown:
        return l10n.walletSecuritySignInMethodUnknown;
    }
  }

  String _walletAddressLabel(AppLocalizations l10n) {
    final address = (authority.walletAddress ?? '').trim();
    if (address.isEmpty) {
      return l10n.walletSecurityNotAvailable;
    }
    if (address.length <= 16) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 6)}';
  }

  String _signerStatusLabel(AppLocalizations l10n) {
    switch (authority.signerSource) {
      case WalletSignerSource.local:
        return l10n.walletSecuritySignerLocalReadyValue;
      case WalletSignerSource.external:
        return l10n.walletSecuritySignerExternalReadyValue;
      case WalletSignerSource.none:
        if (authority.canRestoreFromEncryptedBackup) {
          return l10n.walletSecuritySignerRestoreAvailableValue;
        }
        return l10n.walletSecuritySignerMissingValue;
    }
  }

  String _externalWalletLabel(AppLocalizations l10n) {
    if (!authority.hasExternalSigner) {
      return l10n.walletSecurityDisconnected;
    }
    final name = (authority.externalWalletName ?? '').trim();
    if (name.isEmpty) {
      return l10n.walletSecurityConnected;
    }
    return l10n.walletSecurityExternalWalletConnectedValue(name);
  }

  String _encryptedBackupLabel(AppLocalizations l10n) {
    if (authority.hasEncryptedBackup) {
      return l10n.walletSecurityAvailable;
    }
    if (!authority.encryptedBackupStatusKnown) {
      return l10n.walletSecurityUnknown;
    }
    return l10n.walletSecurityUnavailable;
  }
}

/// Full-width state banner for the wallet's custody state.
///
/// This carries a whole sentence ("Wallet access ready on this device"), so it
/// stretches instead of shrink-wrapping — a pill that narrow would break the
/// sentence into scraps.
class WalletStatusChip extends StatelessWidget {
  const WalletStatusChip({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: KubusSizes.chipMinHeight),
      padding: const EdgeInsets.symmetric(
        horizontal: KubusSpacing.sm,
        vertical: KubusSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(KubusRadius.sm),
        border: KubusBorders.accentTint(color),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: KubusHeaderMetrics.actionIcon, color: color),
          const SizedBox(width: KubusSpacing.sm),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: KubusTextStyles.detailLabel.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletStatusRow extends StatelessWidget {
  const _WalletStatusRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.monospaceValue = false,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  /// Addresses read as data, not prose — set for hash-like values.
  final bool monospaceValue;

  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final valueStyle = monospaceValue
        ? KubusTypography.mono(
            fontSize: KubusChromeMetrics.navMetaLabel,
            fontWeight: FontWeight.w600,
            color: valueColor ?? scheme.onSurface,
          )
        : KubusTextStyles.detailLabel.copyWith(
            color: valueColor ?? scheme.onSurface,
            fontWeight: FontWeight.w700,
            height: 1.3,
          );

    return Padding(
      padding: EdgeInsets.only(
        bottom: isLast ? KubusSpacing.none : KubusSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            icon,
            size: KubusSizes.chipIcon,
            color: scheme.onSurface.withValues(alpha: 0.52),
          ),
          const SizedBox(width: KubusSpacing.sm),
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: KubusTextStyles.detailCaption.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.66),
              ),
            ),
          ),
          const SizedBox(width: KubusSpacing.sm),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: valueStyle,
            ),
          ),
        ],
      ),
    );
  }
}
