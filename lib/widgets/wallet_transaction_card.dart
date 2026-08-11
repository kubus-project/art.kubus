import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/wallet.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:art_kubus/widgets/wallet/kubus_token_identity.dart';
import 'package:art_kubus/widgets/wallet/kubus_wallet_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class WalletTransactionCard extends StatefulWidget {
  const WalletTransactionCard({
    super.key,
    required this.transaction,
    this.compact = false,
    this.margin,
    this.initiallyExpanded = false,
  });

  final WalletTransaction transaction;
  final bool compact;
  final EdgeInsetsGeometry? margin;
  final bool initiallyExpanded;

  @override
  State<WalletTransactionCard> createState() => _WalletTransactionCardState();
}

class _WalletTransactionCardState extends State<WalletTransactionCard> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final roles = KubusColorRoles.of(context);
    final tx = widget.transaction;
    final isCompact = widget.compact;
    final primaryChange = tx.primaryAssetChange;
    final secondaryChange = _resolveSecondarySwapChange(tx);
    final feeSettlementMode = tx.metadata['feeSettlementMode']?.toString();
    final feeSettlementStatus = tx.metadata['feeSettlementStatus']?.toString();
    final feeSettlementDetail = tx.metadata['feeSettlementDetail']?.toString();
    final feeSettlementSignature =
        tx.metadata['feeSettlementSignature']?.toString();

    return LiquidGlassCard(
      margin: widget.margin,
      padding: EdgeInsets.all(isCompact ? KubusSpacing.md : KubusSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(KubusRadius.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TransactionIconBadge(
                  icon: _iconForTransaction(tx),
                  color: _colorForTransaction(roles, tx),
                  tokenSymbol: tx.token,
                  compact: isCompact,
                ),
                const SizedBox(width: KubusSpacing.md),
                // Title and amount share one line, status chips get their own,
                // meta pills get a third. Nothing competes for width inside a
                // single row, so no label ever breaks mid-word.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              _titleForTransaction(l10n, tx),
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: (isCompact
                                      ? KubusTextStyles.detailCardTitle
                                      : KubusTextStyles.sectionTitle)
                                  .copyWith(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(width: KubusSpacing.sm),
                          Expanded(
                            flex: 2,
                            child: _TransactionAmount(
                              transaction: tx,
                              secondaryChange: secondaryChange,
                              amountColor:
                                  _colorForTransaction(roles, tx),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: KubusSpacing.xs),
                      Text(
                        _subtitleForTransaction(l10n, tx),
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: KubusTextStyles.detailCaption.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.72),
                        ),
                      ),
                      const SizedBox(height: KubusSpacing.sm),
                      Wrap(
                        spacing: KubusSpacing.xs,
                        runSpacing: KubusSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _StatusChip(
                            label: _statusLabel(l10n, tx.status),
                            color: _statusColor(roles, tx.status),
                          ),
                          if (tx.confirmationCount != null)
                            _StatusChip(
                              label: l10n.walletTransactionConfirmationsLabel(
                                tx.confirmationCount!,
                              ),
                              color: roles.statTeal,
                            )
                          else if (tx.finality !=
                              WalletTransactionFinality.unknown)
                            _StatusChip(
                              label: _finalityLabel(l10n, tx.finality),
                              color: theme.colorScheme.outline,
                            ),
                        ],
                      ),
                      const SizedBox(height: KubusSpacing.xs),
                      Wrap(
                        spacing: KubusSpacing.xs,
                        runSpacing: KubusSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _DetailPill(
                            label: tx.shortSignature,
                            onTap: () => _copySignature(context, tx.signature),
                            icon: Icons.copy_rounded,
                          ),
                          if (tx.explorerUrl != null &&
                              tx.explorerUrl!.trim().isNotEmpty)
                            _DetailPill(
                              label: l10n.walletTransactionExplorerAction,
                              onTap: () =>
                                  _openExplorer(context, tx.explorerUrl!),
                              icon: Icons.open_in_new_rounded,
                            ),
                          _DetailPill(
                            label: _formatTimestamp(context, tx.timestamp),
                            icon: Icons.schedule_rounded,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: KubusSpacing.sm),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.66),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: KubusSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: KubusSpacing.md),
                  _DetailGrid(
                    compact: isCompact,
                    rows: [
                      _DetailRowData(
                        label: l10n.walletTransactionSignatureLabel,
                        value: tx.signature,
                        onTap: () => _copySignature(context, tx.signature),
                      ),
                      if ((tx.fromAddress ?? '').trim().isNotEmpty)
                        _DetailRowData(
                          label: l10n.walletTransactionFromLabel,
                          value: tx.fromAddress!,
                        ),
                      if ((tx.toAddress ?? '').trim().isNotEmpty)
                        _DetailRowData(
                          label: l10n.walletTransactionToLabel,
                          value: tx.toAddress!,
                        ),
                      if ((tx.primaryCounterparty ?? '').trim().isNotEmpty)
                        _DetailRowData(
                          label: l10n.walletTransactionCounterpartyLabel,
                          value: tx.primaryCounterparty!,
                        ),
                      if (tx.slot != null)
                        _DetailRowData(
                          label: l10n.walletTransactionSlotLabel,
                          value: tx.slot.toString(),
                        ),
                      if (tx.finality != WalletTransactionFinality.unknown)
                        _DetailRowData(
                          label: l10n.walletTransactionFinalityLabel,
                          value: _finalityLabel(l10n, tx.finality),
                        ),
                      if (tx.feeAmount != null)
                        _DetailRowData(
                          label: l10n.walletTransactionNetworkFeeLabel,
                          value:
                              '${tx.feeAmount!.toStringAsFixed(6)} ${tx.feeToken}',
                        ),
                      if (tx.type == TransactionType.swap &&
                          (feeSettlementMode ?? '').trim().isNotEmpty)
                        _DetailRowData(
                          label: 'Fee settlement mode',
                          value: feeSettlementMode!,
                        ),
                      if (tx.type == TransactionType.swap &&
                          (feeSettlementStatus ?? '').trim().isNotEmpty)
                        _DetailRowData(
                          label: 'Fee settlement status',
                          value: feeSettlementStatus!,
                        ),
                      if (tx.type == TransactionType.swap &&
                          (feeSettlementDetail ?? '').trim().isNotEmpty)
                        _DetailRowData(
                          label: 'Fee settlement detail',
                          value: feeSettlementDetail!,
                        ),
                      if (tx.type == TransactionType.swap &&
                          (feeSettlementSignature ?? '').trim().isNotEmpty)
                        _DetailRowData(
                          label: 'Settlement signature',
                          value: feeSettlementSignature!,
                          onTap: () =>
                              _copySignature(context, feeSettlementSignature),
                        ),
                    ],
                  ),
                  if (primaryChange != null &&
                      tx.type != TransactionType.swap) ...[
                    const SizedBox(height: KubusSpacing.md),
                    Text(
                      l10n.walletTransactionAssetChangesLabel,
                      style: KubusTextStyles.detailLabel.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.72),
                      ),
                    ),
                    const SizedBox(height: KubusSpacing.sm),
                    ...tx.assetChanges.map(
                      (change) => Padding(
                        padding: const EdgeInsets.only(bottom: KubusSpacing.xs),
                        child: _AssetChangeRow(change: change),
                      ),
                    ),
                  ],
                  if (tx.relatedTransactions.isNotEmpty) ...[
                    const SizedBox(height: KubusSpacing.md),
                    Text(
                      l10n.walletTransactionRelatedActionsLabel,
                      style: KubusTextStyles.detailLabel.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.72),
                      ),
                    ),
                    const SizedBox(height: KubusSpacing.sm),
                    ...tx.relatedTransactions.map(
                      (related) => Padding(
                        padding: const EdgeInsets.only(bottom: KubusSpacing.sm),
                        child: _RelatedTransactionRow(
                          related: related,
                          statusLabel: _statusLabel(l10n, related.status),
                          statusColor:
                              _statusColor(roles, related.status),
                          onCopy: () =>
                              _copySignature(context, related.signature),
                          onOpen: related.explorerUrl == null
                              ? null
                              : () => _openExplorer(
                                    context,
                                    related.explorerUrl!,
                                  ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }

  Future<void> _copySignature(BuildContext context, String signature) async {
    await Clipboard.setData(ClipboardData(text: signature));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(AppLocalizations.of(context)!.walletTransactionCopiedToast),
      ),
    );
  }

  Future<void> _openExplorer(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !await canLaunchUrl(uri)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!
                .walletTransactionExplorerUnavailableToast,
          ),
        ),
      );
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  IconData _iconForTransaction(WalletTransaction tx) {
    if (tx.metadata['isFeeTransfer'] == true) {
      return Icons.toll_outlined;
    }
    switch (tx.type) {
      case TransactionType.send:
        return tx.direction == WalletTransactionDirection.self
            ? Icons.compare_arrows_rounded
            : Icons.arrow_upward_rounded;
      case TransactionType.receive:
        return Icons.arrow_downward_rounded;
      case TransactionType.swap:
        return Icons.swap_horiz_rounded;
      case TransactionType.stake:
        return Icons.lock_outline_rounded;
      case TransactionType.unstake:
        return Icons.lock_open_rounded;
      case TransactionType.governanceVote:
        return Icons.how_to_vote_outlined;
    }
  }

  /// Value leaving is warm, value arriving is positive, everything else is a
  /// distinct neutral — the same mapping the wallet action cards use, so a
  /// send card and a send transaction read as the same thing.
  Color _colorForTransaction(KubusColorRoles roles, WalletTransaction tx) {
    if (tx.metadata['isFeeTransfer'] == true) {
      return roles.statAmber;
    }
    switch (tx.type) {
      case TransactionType.send:
        return roles.negativeAction;
      case TransactionType.receive:
        return roles.positiveAction;
      case TransactionType.swap:
        return roles.statBlue;
      case TransactionType.stake:
        return roles.statPurple;
      case TransactionType.unstake:
        return roles.statTeal;
      case TransactionType.governanceVote:
        return roles.statBlue;
    }
  }

  String _titleForTransaction(AppLocalizations l10n, WalletTransaction tx) {
    if (tx.metadata['isFeeTransfer'] == true) {
      return l10n.walletTransactionFeeTransferTitle;
    }
    switch (tx.type) {
      case TransactionType.send:
        return tx.direction == WalletTransactionDirection.self
            ? l10n.walletTransactionMovedTitle
            : l10n.settingsTxSentLabel;
      case TransactionType.receive:
        return l10n.settingsTxReceivedLabel;
      case TransactionType.swap:
        return l10n.walletHomeTxSwapLabel;
      case TransactionType.stake:
        return l10n.walletHomeTxStakeLabel;
      case TransactionType.unstake:
        return l10n.walletHomeTxUnstakeLabel;
      case TransactionType.governanceVote:
        return l10n.walletHomeTxGovernanceVoteLabel;
    }
  }

  String _subtitleForTransaction(AppLocalizations l10n, WalletTransaction tx) {
    if (tx.type == TransactionType.swap &&
        tx.swapToToken != null &&
        tx.swapToAmount != null) {
      return l10n.walletTransactionSwapSubtitle(
        tx.token,
        tx.swapToToken!,
      );
    }
    final counterpart = (tx.primaryCounterparty ?? tx.shortAddress).trim();
    if (counterpart.isEmpty) {
      return tx.shortSignature;
    }
    return counterpart;
  }

  String _statusLabel(AppLocalizations l10n, TransactionStatus status) {
    switch (status) {
      case TransactionStatus.submitted:
        return l10n.walletTransactionStatusSubmitted;
      case TransactionStatus.pending:
        return l10n.walletTransactionStatusPending;
      case TransactionStatus.confirmed:
        return l10n.walletTransactionStatusConfirmed;
      case TransactionStatus.finalized:
        return l10n.walletTransactionStatusFinalized;
      case TransactionStatus.failed:
        return l10n.walletTransactionStatusFailed;
    }
  }

  String _finalityLabel(
    AppLocalizations l10n,
    WalletTransactionFinality finality,
  ) {
    switch (finality) {
      case WalletTransactionFinality.unknown:
        return l10n.walletTransactionFinalityUnknown;
      case WalletTransactionFinality.processed:
        return l10n.walletTransactionFinalityProcessed;
      case WalletTransactionFinality.confirmed:
        return l10n.walletTransactionFinalityConfirmed;
      case WalletTransactionFinality.finalized:
        return l10n.walletTransactionFinalityFinalized;
    }
  }

  /// Settlement reads as a progression: in flight (blue) → landing (amber) →
  /// on chain (teal) → irreversible (green), with failure in red.
  Color _statusColor(KubusColorRoles roles, TransactionStatus status) {
    switch (status) {
      case TransactionStatus.submitted:
        return roles.statBlue;
      case TransactionStatus.pending:
        return roles.warningAction;
      case TransactionStatus.confirmed:
        return roles.statTeal;
      case TransactionStatus.finalized:
        return roles.positiveAction;
      case TransactionStatus.failed:
        return roles.negativeAction;
    }
  }

  String _formatTimestamp(BuildContext context, DateTime timestamp) {
    final localizations = MaterialLocalizations.of(context);
    final localTime = timestamp.toLocal();
    return '${localizations.formatMediumDate(localTime)} ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(localTime), alwaysUse24HourFormat: true)}';
  }

  WalletTransactionAssetChange? _resolveSecondarySwapChange(
    WalletTransaction tx,
  ) {
    if (tx.type != TransactionType.swap) {
      return null;
    }

    for (final change in tx.assetChanges) {
      if (!change.isFee && change.amount > 0) {
        return change;
      }
    }

    final swapToToken = tx.swapToToken;
    final swapToAmount = tx.swapToAmount;
    if (swapToToken != null &&
        swapToToken.trim().isNotEmpty &&
        swapToAmount != null &&
        swapToAmount > 0) {
      return WalletTransactionAssetChange(
        symbol: swapToToken,
        amount: swapToAmount,
        direction: WalletTransactionDirection.incoming,
      );
    }

    return null;
  }
}

/// Direction icon carrying the asset's own mark as a corner badge, so a row
/// says both *what happened* and *which token* before you read a word.
class _TransactionIconBadge extends StatelessWidget {
  const _TransactionIconBadge({
    required this.icon,
    required this.color,
    required this.tokenSymbol,
    required this.compact,
  });

  final IconData icon;
  final Color color;
  final String tokenSymbol;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final box =
        compact ? KubusSizes.walletActionIconBox : KubusSizes.tokenAvatarLg;
    final overhang = KubusSizes.tokenAvatarXs / 2;

    return SizedBox(
      width: box + overhang,
      height: box + overhang,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Container(
            width: box,
            height: box,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(KubusRadius.md),
              border: KubusBorders.accentTint(color),
            ),
            child: Icon(
              icon,
              size: compact
                  ? KubusSizes.walletActionIcon
                  : KubusChromeMetrics.navIcon,
              color: color,
            ),
          ),
          if (tokenSymbol.trim().isNotEmpty)
            Positioned(
              right: 0,
              bottom: 0,
              child: KubusTokenAvatar(
                symbol: tokenSymbol,
                size: KubusTokenAvatarSize.xs,
                filled: true,
                ringColor: scheme.surface,
              ),
            ),
        ],
      ),
    );
  }
}

/// Amount block: one line for transfers, two for swaps. Always right-aligned
/// and always single-line per figure so it can never push the title around.
class _TransactionAmount extends StatelessWidget {
  const _TransactionAmount({
    required this.transaction,
    required this.secondaryChange,
    required this.amountColor,
  });

  final WalletTransaction transaction;
  final WalletTransactionAssetChange? secondaryChange;
  final Color amountColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tx = transaction;
    final isSwap = tx.type == TransactionType.swap &&
        secondaryChange != null &&
        secondaryChange!.symbol.isNotEmpty;

    Widget figure(String text, Color color, {bool emphasized = true}) {
      return Text(
        text,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.end,
        style: (emphasized
                ? KubusTextStyles.detailCardTitle
                : KubusTextStyles.detailCaption)
            .copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    if (isSwap) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          figure(
            '-${tx.amount.toStringAsFixed(4)} ${tx.token}',
            theme.colorScheme.onSurface,
          ),
          const SizedBox(height: KubusSpacing.xxs),
          figure(
            '+${secondaryChange!.absoluteAmount.toStringAsFixed(4)} ${secondaryChange!.symbol}',
            theme.colorScheme.tertiary,
            emphasized: false,
          ),
        ],
      );
    }

    final sign = tx.direction == WalletTransactionDirection.incoming
        ? '+'
        : tx.direction == WalletTransactionDirection.outgoing
            ? '-'
            : '';
    return figure(
      '$sign${tx.amount.toStringAsFixed(4)} ${tx.token}',
      amountColor,
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return KubusWalletMetaPill(
      label: label,
      tintColor: color,
      tone: KubusWalletPillTone.accent,
      emphasized: true,
      dense: true,
    );
  }
}

class _DetailPill extends StatelessWidget {
  const _DetailPill({
    required this.label,
    this.icon,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return KubusWalletMetaPill(
      label: label,
      icon: icon,
      tintColor: Theme.of(context).colorScheme.outline,
      dense: true,
      onTap: onTap,
      maxLabelWidth: KubusSizes.addressValueMaxWidth,
    );
  }
}

class _DetailGrid extends StatelessWidget {
  const _DetailGrid({
    required this.rows,
    required this.compact,
  });

  final List<_DetailRowData> rows;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: rows
          .map(
            (row) => Padding(
              padding: EdgeInsets.only(
                bottom: compact ? KubusSpacing.xs : KubusSpacing.sm,
              ),
              child: _DetailRow(row: row),
            ),
          )
          .toList(),
    );
  }
}

class _DetailRowData {
  const _DetailRowData({
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.row,
  });

  final _DetailRowData row;

  /// Signatures and addresses are unbreakable strings — wrapping them tears a
  /// hash across three ragged lines. Show head and tail on one monospaced
  /// line instead; the full value stays available on tap (copy) and hover.
  static const int _monoTruncateThreshold = 22;

  bool get _isHashLike =>
      row.value.length > _monoTruncateThreshold && !row.value.contains(' ');

  String get _displayValue {
    if (!_isHashLike) return row.value;
    return '${row.value.substring(0, 8)}…${row.value.substring(row.value.length - 8)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueStyle = _isHashLike
        ? KubusTypography.mono(
            fontSize: KubusChromeMetrics.navMetaLabel,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          )
        : KubusTextStyles.detailBody.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          );

    Widget value = Text(
      _displayValue,
      textAlign: TextAlign.end,
      maxLines: _isHashLike ? 1 : 2,
      softWrap: !_isHashLike,
      overflow: TextOverflow.ellipsis,
      style: valueStyle,
    );
    if (_isHashLike) {
      value = Tooltip(message: row.value, child: value);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Text(
            row.label,
            style: KubusTextStyles.detailCaption.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
            ),
          ),
        ),
        const SizedBox(width: KubusSpacing.md),
        Expanded(
          flex: 4,
          child: GestureDetector(
            onTap: row.onTap,
            child: value,
          ),
        ),
      ],
    );
  }
}

class _AssetChangeRow extends StatelessWidget {
  const _AssetChangeRow({
    required this.change,
  });

  final WalletTransactionAssetChange change;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amountColor = change.amount >= 0
        ? theme.colorScheme.tertiary
        : theme.colorScheme.onSurface;
    return Row(
      children: [
        KubusTokenAvatar(
          symbol: change.symbol,
          size: KubusTokenAvatarSize.xs,
        ),
        const SizedBox(width: KubusSpacing.sm),
        Expanded(
          child: Text(
            change.label ?? change.symbol,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: KubusTextStyles.detailCaption.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.74),
            ),
          ),
        ),
        const SizedBox(width: KubusSpacing.sm),
        Text(
          '${change.amount >= 0 ? '+' : '-'}${change.absoluteAmount.toStringAsFixed(4)} ${change.symbol}',
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: KubusTextStyles.detailBody.copyWith(
            color: amountColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _RelatedTransactionRow extends StatelessWidget {
  const _RelatedTransactionRow({
    required this.related,
    required this.statusLabel,
    required this.statusColor,
    required this.onCopy,
    this.onOpen,
  });

  final WalletRelatedTransaction related;
  final String statusLabel;
  final Color statusColor;
  final VoidCallback onCopy;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(KubusSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(KubusRadius.sm),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: KubusSpacing.xs,
                  runSpacing: KubusSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      related.label,
                      style: KubusTextStyles.detailCaption.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    _StatusChip(
                      label: statusLabel,
                      color: statusColor,
                    ),
                  ],
                ),
                const SizedBox(height: KubusSpacing.xs),
                Text(
                  related.signature,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: KubusTypography.mono(
                    fontSize: KubusChromeMetrics.navBadgeLabel,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
          if (related.amount != null && related.token != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: KubusSpacing.sm,
              ),
              child: Text(
                '${related.amount!.toStringAsFixed(4)} ${related.token}',
                maxLines: 1,
                softWrap: false,
                style: KubusTextStyles.detailCaption.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          IconButton(
            onPressed: onCopy,
            visualDensity: VisualDensity.compact,
            iconSize: KubusSizes.walletActionIcon,
            icon: const Icon(Icons.copy_rounded),
            tooltip: AppLocalizations.of(context)!
                .walletTransactionCopySignatureTooltip,
          ),
          if (onOpen != null)
            IconButton(
              onPressed: onOpen,
              visualDensity: VisualDensity.compact,
              iconSize: KubusSizes.walletActionIcon,
              icon: const Icon(Icons.open_in_new_rounded),
              tooltip:
                  AppLocalizations.of(context)!.walletTransactionExplorerAction,
            ),
        ],
      ),
    );
  }
}
