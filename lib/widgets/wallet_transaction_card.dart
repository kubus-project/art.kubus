import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/wallet.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/widgets/glass_components.dart';
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
    final tx = widget.transaction;
    final isCompact = widget.compact;
    final primaryChange = tx.primaryAssetChange;
    final secondaryChange = tx.type == TransactionType.swap
        ? tx.assetChanges.firstWhere(
            (change) => !change.isFee && change.amount > 0,
            orElse: () => const WalletTransactionAssetChange(
              symbol: '',
              amount: 0,
            ),
          )
        : null;

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
                  color: _colorForTransaction(theme.colorScheme, tx),
                  compact: isCompact,
                ),
                const SizedBox(width: KubusSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: KubusSpacing.sm,
                        runSpacing: KubusSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            _titleForTransaction(l10n, tx),
                            style: (isCompact
                                    ? KubusTextStyles.detailCardTitle
                                    : KubusTextStyles.sectionTitle)
                                .copyWith(
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          _StatusChip(
                            label: _statusLabel(l10n, tx.status),
                            color: _statusColor(theme.colorScheme, tx.status),
                          ),
                          if (tx.confirmationCount != null)
                            _StatusChip(
                              label: l10n.walletTransactionConfirmationsLabel(
                                tx.confirmationCount!,
                              ),
                              color: theme.colorScheme.secondary,
                            )
                          else
                            _StatusChip(
                              label: _finalityLabel(l10n, tx.finality),
                              color: theme.colorScheme.outline,
                            ),
                        ],
                      ),
                      const SizedBox(height: KubusSpacing.xs),
                      Text(
                        _subtitleForTransaction(l10n, tx),
                        style: KubusTextStyles.detailCaption.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.72),
                        ),
                      ),
                      const SizedBox(height: KubusSpacing.xs),
                      Wrap(
                        spacing: KubusSpacing.sm,
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
                const SizedBox(width: KubusSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (tx.type == TransactionType.swap &&
                        secondaryChange != null &&
                        secondaryChange.symbol.isNotEmpty) ...[
                      Text(
                        '-${tx.amount.toStringAsFixed(4)} ${tx.token}',
                        style: KubusTextStyles.detailCardTitle.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: KubusSpacing.xs),
                      Text(
                        '+${secondaryChange.absoluteAmount.toStringAsFixed(4)} ${secondaryChange.symbol}',
                        style: KubusTextStyles.detailCaption.copyWith(
                          color: theme.colorScheme.tertiary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ] else ...[
                      Text(
                        '${tx.direction == WalletTransactionDirection.incoming ? '+' : tx.direction == WalletTransactionDirection.outgoing ? '-' : ''}${tx.amount.toStringAsFixed(4)} ${tx.token}',
                        style: KubusTextStyles.detailCardTitle.copyWith(
                          color: _colorForTransaction(theme.colorScheme, tx),
                        ),
                      ),
                    ],
                    const SizedBox(height: KubusSpacing.xs),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.66),
                    ),
                  ],
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
                    ],
                  ),
                  if (primaryChange != null &&
                      tx.type != TransactionType.swap) ...[
                    const SizedBox(height: KubusSpacing.md),
                    Text(
                      l10n.walletTransactionAssetChangesLabel,
                      style: KubusTextStyles.detailLabel.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.72),
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
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.72),
                      ),
                    ),
                    const SizedBox(height: KubusSpacing.sm),
                    ...tx.relatedTransactions.map(
                      (related) => Padding(
                        padding: const EdgeInsets.only(bottom: KubusSpacing.sm),
                        child: _RelatedTransactionRow(
                          related: related,
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

  Color _colorForTransaction(ColorScheme scheme, WalletTransaction tx) {
    if (tx.metadata['isFeeTransfer'] == true) {
      return scheme.secondary;
    }
    switch (tx.type) {
      case TransactionType.send:
        return scheme.error;
      case TransactionType.receive:
        return scheme.tertiary;
      case TransactionType.swap:
        return scheme.primary;
      case TransactionType.stake:
        return scheme.secondary;
      case TransactionType.unstake:
        return scheme.primary;
      case TransactionType.governanceVote:
        return scheme.primary;
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

  Color _statusColor(ColorScheme scheme, TransactionStatus status) {
    switch (status) {
      case TransactionStatus.submitted:
        return scheme.secondary;
      case TransactionStatus.pending:
        return scheme.primary;
      case TransactionStatus.confirmed:
        return scheme.tertiary;
      case TransactionStatus.finalized:
        return scheme.tertiary;
      case TransactionStatus.failed:
        return scheme.error;
    }
  }

  String _formatTimestamp(BuildContext context, DateTime timestamp) {
    final localizations = MaterialLocalizations.of(context);
    final localTime = timestamp.toLocal();
    return '${localizations.formatMediumDate(localTime)} ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(localTime), alwaysUse24HourFormat: true)}';
  }
}

class _TransactionIconBadge extends StatelessWidget {
  const _TransactionIconBadge({
    required this.icon,
    required this.color,
    required this.compact,
  });

  final IconData icon;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 42 : 48,
      height: compact ? 42 : 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(KubusRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Icon(icon, size: compact ? 20 : 22, color: color),
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
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KubusSpacing.sm,
        vertical: KubusSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(KubusRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: KubusTextStyles.compactBadge.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
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
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KubusRadius.xl),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: KubusSpacing.sm,
            vertical: KubusSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(KubusRadius.xl),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                const SizedBox(width: KubusSpacing.xs),
              ],
              Text(
                label,
                style: KubusTextStyles.compactBadge.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.74),
                ),
              ),
            ],
          ),
        ),
      ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            row.label,
            style: KubusTextStyles.detailCaption.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
            ),
          ),
        ),
        const SizedBox(width: KubusSpacing.md),
        Flexible(
          flex: 2,
          child: GestureDetector(
            onTap: row.onTap,
            child: Text(
              row.value,
              textAlign: TextAlign.end,
              style: KubusTextStyles.detailBody.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
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
        Expanded(
          child: Text(
            change.label ?? change.symbol,
            style: KubusTextStyles.detailCaption.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.74),
            ),
          ),
        ),
        Text(
          '${change.amount >= 0 ? '+' : '-'}${change.absoluteAmount.toStringAsFixed(4)} ${change.symbol}',
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
    required this.onCopy,
    this.onOpen,
  });

  final WalletRelatedTransaction related;
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
                Text(
                  related.label,
                  style: KubusTextStyles.detailCaption.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: KubusSpacing.xs),
                Text(
                  related.signature,
                  style: KubusTextStyles.compactBadge.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
          if (related.amount != null && related.token != null)
            Padding(
              padding: const EdgeInsets.only(right: KubusSpacing.sm),
              child: Text(
                '${related.amount!.toStringAsFixed(4)} ${related.token}',
                style: KubusTextStyles.detailCaption.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          IconButton(
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded),
            tooltip:
                AppLocalizations.of(context)!.walletTransactionCopySignatureTooltip,
          ),
          if (onOpen != null)
            IconButton(
              onPressed: onOpen,
              icon: const Icon(Icons.open_in_new_rounded),
              tooltip:
                  AppLocalizations.of(context)!.walletTransactionExplorerAction,
            ),
        ],
      ),
    );
  }
}
