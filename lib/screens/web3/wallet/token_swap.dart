import 'dart:async';

import 'package:flutter/material.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../config/api_keys.dart';
import '../../../models/swap_quote.dart';
import '../../../models/wallet.dart';
import '../../../providers/wallet_provider.dart';
import '../../../utils/app_color_utils.dart';
import '../../../utils/design_tokens.dart';
import '../../../widgets/wallet_custody_status_panel.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import 'package:art_kubus/utils/wallet_reconnect_action.dart';

class TokenSwap extends StatefulWidget {
  const TokenSwap({super.key});

  @override
  State<TokenSwap> createState() => _TokenSwapState();
}

class _TokenSwapState extends State<TokenSwap> {
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  final FocusNode _fromFocusNode = FocusNode();

  String? _fromTokenSymbol;
  String? _toTokenSymbol;
  bool _tokensInitialized = false;

  bool _isSubmitting = false;
  bool _isFetchingQuote = false;
  SwapQuote? _quote;
  String? _amountError;
  String? _quoteError;
  double _slippagePercent = 0.5; // default 0.5%
  Timer? _quoteDebounce;

  @override
  void initState() {
    super.initState();
    _fromController.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _quoteDebounce?.cancel();
    _fromController.dispose();
    _toController.dispose();
    _fromFocusNode.dispose();
    super.dispose();
  }

  List<Token> _availableTokens(WalletProvider provider) {
    final list =
        provider.tokens.where((token) => token.type != TokenType.nft).toList();
    list.sort((a, b) => b.balance.compareTo(a.balance));
    return list;
  }

  Future<void> _handleReadOnlyReconnect() async {
    final walletProvider = context.read<WalletProvider>();
    await WalletReconnectAction.handleReadOnlyReconnect(
      context: context,
      walletProvider: walletProvider,
      refreshBackendSession: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    const swapColor = AppColorUtils.greenAccent;
    final walletProvider = context.watch<WalletProvider>();
    final authority = walletProvider.authority;
    if (!authority.canTransact) {
      return _buildAuthorityState(theme, swapColor, l10n, authority);
    }
    final tokens = _availableTokens(walletProvider);
    final hasTokens = tokens.isNotEmpty;
    final canFlip = tokens.length > 1;

    if (!_tokensInitialized && tokens.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _fromTokenSymbol = tokens.first.symbol;
          _toTokenSymbol =
              tokens.length > 1 ? tokens[1].symbol : tokens.first.symbol;
          _tokensInitialized = true;
        });
      });
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          l10n.walletSwapTitle,
          style: KubusTypography.inter(
            fontSize: KubusHeaderMetrics.screenTitle,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: l10n.walletSwapSwitchTokensTooltip,
            icon: Icon(Icons.swap_vert, color: theme.colorScheme.onSurface),
            onPressed: canFlip ? _swapDirection : null,
          ),
        ],
      ),
      body: SafeArea(
        child: hasTokens
            ? LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 720;
                  final content = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSwapCard(theme, swapColor, walletProvider, tokens),
                      const SizedBox(height: 20),
                      _buildQuoteDetails(theme, swapColor),
                      const SizedBox(height: 20),
                      _buildSlippageSelector(theme, swapColor),
                      const SizedBox(height: 24),
                      _buildSwapButton(theme, swapColor, walletProvider),
                      const SizedBox(height: 24),
                      Expanded(child: _buildRecentSwaps(theme, walletProvider)),
                    ],
                  );

                  return Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isWide
                          ? (constraints.maxWidth - 680) / 2
                          : KubusSpacing.lg,
                      vertical: KubusSpacing.lg,
                    ),
                    child: content,
                  );
                },
              )
            : _buildEmptyState(theme, swapColor, l10n),
      ),
    );
  }

  Widget _buildAuthorityState(
    ThemeData theme,
    Color swapColor,
    AppLocalizations l10n,
    WalletAuthoritySnapshot authority,
  ) {
    final canRestore = authority.canRestoreFromEncryptedBackup;
    final title = switch (authority.state) {
      WalletAuthorityState.signedOut => l10n.walletHomeSignedOutTitle,
      WalletAuthorityState.accountShellOnly => l10n.walletHomeAccountShellTitle,
      WalletAuthorityState.walletReadOnly => l10n.walletSessionStateWalletReadOnly,
      WalletAuthorityState.localSignerReady => l10n.walletSessionStateLocalSignerReady,
      WalletAuthorityState.externalWalletReady =>
        l10n.walletSessionStateExternalWalletReady,
      WalletAuthorityState.encryptedBackupAvailableSignerMissing =>
        l10n.walletSessionStateEncryptedBackupAvailable,
      WalletAuthorityState.recoveryNeeded => l10n.walletSessionStateRecoveryNeeded,
    };
    final body = switch (authority.state) {
      WalletAuthorityState.signedOut => l10n.walletActionSignInRequiredToast,
      WalletAuthorityState.accountShellOnly =>
        l10n.walletActionAccountShellNeedsWalletToast,
      WalletAuthorityState.walletReadOnly =>
        l10n.walletActionReadOnlyReconnectToast,
      WalletAuthorityState.localSignerReady =>
        l10n.walletSecurityLocalSignerReadyValue,
      WalletAuthorityState.externalWalletReady =>
        l10n.walletSecuritySignerExternalReadyValue,
      WalletAuthorityState.encryptedBackupAvailableSignerMissing =>
        l10n.walletActionEncryptedBackupRestoreToast,
      WalletAuthorityState.recoveryNeeded =>
        l10n.walletActionRecoveryNeededToast,
    };

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          l10n.walletSwapTitle,
          style: KubusTypography.inter(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(KubusSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_clock, size: 64, color: swapColor),
                const SizedBox(height: KubusSpacing.lg),
                Text(
                  title,
                  style: KubusTypography.inter(
                    fontSize: KubusHeaderMetrics.screenTitle,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: KubusSpacing.md),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: KubusTypography.inter(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: KubusSpacing.lg),
                WalletCustodyStatusPanel(
                  authority: authority,
                  compact: true,
                  onRestoreSigner: canRestore ? _handleReadOnlyReconnect : null,
                  onConnectExternalWallet: authority.hasWalletIdentity
                      ? () => Navigator.of(context).pushNamed('/connect-wallet')
                      : null,
                ),
                const SizedBox(height: KubusSpacing.lg),
                ElevatedButton(
                  onPressed: () {
                    if (canRestore) {
                      _handleReadOnlyReconnect();
                      return;
                    }
                    Navigator.of(context).pushNamed(
                      authority.state == WalletAuthorityState.signedOut
                          ? '/sign-in'
                          : '/connect-wallet',
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: swapColor,
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
                  child: Text(
                    canRestore
                        ? l10n.commonReconnect
                        : authority.state == WalletAuthorityState.signedOut
                            ? l10n.commonContinue
                            : l10n.walletSecurityConnectExternalAction,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    ThemeData theme,
    Color swapColor,
    AppLocalizations l10n,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KubusSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance_wallet_outlined,
                size: 64, color: swapColor),
            const SizedBox(height: KubusSpacing.lg),
            Text(
              l10n.walletSwapNoTokensTitle,
              style: KubusTypography.inter(
                fontSize: KubusHeaderMetrics.screenTitle,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: KubusSpacing.md),
            Text(
              l10n.walletSwapNoTokensDescription,
              textAlign: TextAlign.center,
              style: KubusTypography.inter(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwapCard(
    ThemeData theme,
    Color swapColor,
    WalletProvider walletProvider,
    List<Token> tokens,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(KubusSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(KubusRadius.xl),
        border:
            Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildTokenInput(
            label: l10n.walletSwapYouPayLabel,
            isFrom: true,
            theme: theme,
            swapColor: swapColor,
            walletProvider: walletProvider,
            tokens: tokens,
          ),
          const SizedBox(height: 16),
          _buildTokenInput(
            label: l10n.walletSwapYouReceiveLabel,
            isFrom: false,
            theme: theme,
            swapColor: swapColor,
            walletProvider: walletProvider,
            tokens: tokens,
          ),
        ],
      ),
    );
  }

  Widget _buildTokenInput({
    required String label,
    required bool isFrom,
    required ThemeData theme,
    required Color swapColor,
    required WalletProvider walletProvider,
    required List<Token> tokens,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final symbol = isFrom ? _fromTokenSymbol : _toTokenSymbol;
    final controller = isFrom ? _fromController : _toController;
    final balance = symbol != null
        ? walletProvider.getTokenBalance(symbol).toStringAsFixed(6)
        : '0';
    final token =
        symbol != null ? walletProvider.getTokenBySymbol(symbol) : null;

    return Container(
      padding: const EdgeInsets.all(KubusSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(KubusRadius.lg),
        border:
            Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: KubusTypography.inter(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              if (isFrom)
                TextButton(
                  onPressed: token == null ? null : () => _fillMax(token),
                  child: Text(l10n.walletSwapMaxAction),
                ),
            ],
          ),
          const SizedBox(height: KubusSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  focusNode: isFrom ? _fromFocusNode : null,
                  controller: controller,
                  readOnly: !isFrom,
                  showCursor: isFrom,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: KubusTypography.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: l10n.walletSwapAmountPlaceholder,
                    hintStyle: KubusTypography.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(width: KubusSpacing.md),
              GestureDetector(
                onTap: () => _selectToken(isFrom: isFrom, tokens: tokens),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: swapColor.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _TokenAvatar(
                          symbol: symbol, token: token, swapColor: swapColor),
                      const SizedBox(width: 8),
                      Text(
                        symbol ?? l10n.walletSwapSelectTokenAction,
                        style: KubusTypography.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.keyboard_arrow_down,
                          color: theme.colorScheme.onSurface),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.walletSwapBalanceLabel(balance),
                style: KubusTypography.inter(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              if (token?.value != null)
                Text(
                  token!.formattedValue,
                  style: KubusTypography.inter(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteDetails(ThemeData theme, Color swapColor) {
    final l10n = AppLocalizations.of(context)!;
    if (_amountError != null) {
      return _infoCard(
        theme,
        swapColor,
        icon: Icons.info_outline,
        iconColor: theme.colorScheme.error,
        title: l10n.walletSwapInvalidAmountTitle,
        subtitle: _amountError!,
      );
    }
    if (_quoteError != null) {
      return _infoCard(
        theme,
        swapColor,
        icon: Icons.error_outline,
        iconColor: theme.colorScheme.error,
        title: l10n.walletSwapRouteUnavailableTitle,
        subtitle: _quoteError!,
      );
    }
    if (_isFetchingQuote) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: _infoDecoration(theme),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child:
                  CircularProgressIndicator(strokeWidth: 2.4, color: swapColor),
            ),
            const SizedBox(width: 12),
            Text(
              l10n.walletSwapSearchingRouteLabel,
              style: KubusTypography.inter(color: theme.colorScheme.onSurface),
            ),
          ],
        ),
      );
    }
    if (_quote == null) {
      return _infoCard(
        theme,
        swapColor,
        icon: Icons.route,
        title: l10n.walletSwapEnterAmountTitle,
        subtitle: l10n.walletSwapEnterAmountDescription,
      );
    }

    final minReceived = _formatAmount(_quote!.minOutputAmount);
    final output = _formatAmount(_quote!.outputAmount);
    final priceImpact = (_quote!.priceImpactPct * 100).toStringAsFixed(2);
    final slippage = _quote!.slippagePercent.toStringAsFixed(2);
    final protocolFeePct =
        ((ApiKeys.kubusTeamFeePct + ApiKeys.kubusTreasuryFeePct) * 100)
            .toStringAsFixed(2);

    return Container(
      padding: const EdgeInsets.all(KubusSpacing.lg),
      decoration: _infoDecoration(theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.swap_horiz, color: swapColor),
              const SizedBox(width: 10),
              Text(
                l10n.walletSwapQuotePreviewTitle,
                style: KubusTypography.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _quoteMetric(theme, l10n.walletSwapEstimatedOutputLabel,
              '$output ${_toTokenSymbol ?? ''}'),
          const SizedBox(height: 8),
          _quoteMetric(theme, l10n.walletSwapMinReceivedLabel,
              '$minReceived ${_toTokenSymbol ?? ''}'),
          const SizedBox(height: 8),
          _quoteMetric(theme, l10n.walletSwapPriceImpactLabel, '$priceImpact%'),
          const SizedBox(height: 8),
          _quoteMetric(theme, l10n.walletSwapSlippageLabel, '$slippage%'),
          const SizedBox(height: 8),
          _quoteMetric(
            theme,
            l10n.walletSwapProtocolFeeLabel,
            l10n.walletSwapProtocolFeeValue(protocolFeePct),
          ),
          if (_quote!.routePlan.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quote!.routePlan.map((step) {
                final label =
                    step['label']?.toString() ?? l10n.walletSwapRouteFallbackLabel;
                return Chip(
                  label:
                      Text(label, style: KubusTypography.inter(fontSize: 12)),
                  backgroundColor:
                      theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoCard(
    ThemeData theme,
    Color accent, {
    required IconData icon,
    Color? iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(KubusSpacing.lg),
      decoration: _infoDecoration(theme),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor ?? accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: KubusTypography.inter(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: KubusTypography.inter(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _infoDecoration(ThemeData theme) {
    return BoxDecoration(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      border:
          Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
    );
  }

  Widget _quoteMetric(ThemeData theme, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: KubusTypography.inter(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
        ),
        Text(
          value,
          style: KubusTypography.inter(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildSlippageSelector(ThemeData theme, Color swapColor) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: _infoDecoration(theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.walletSwapSlippageToleranceLabel,
                style: KubusTypography.inter(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface),
              ),
              Text('${_slippagePercent.toStringAsFixed(2)}%',
                  style: KubusTypography.inter(color: swapColor)),
            ],
          ),
          Slider(
            value: _slippagePercent,
            min: 0.1,
            max: 3.0,
            divisions: 29,
            activeColor: swapColor,
            label: '${_slippagePercent.toStringAsFixed(2)}%',
            onChanged: (value) {
              setState(() => _slippagePercent = value);
              _requestQuote();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSwapButton(
      ThemeData theme, Color swapColor, WalletProvider walletProvider) {
    final l10n = AppLocalizations.of(context)!;
    final isDisabled = _isSubmitting ||
        _fromTokenSymbol == null ||
        _toTokenSymbol == null ||
        _fromTokenSymbol == _toTokenSymbol ||
        _quote == null;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isDisabled ? null : () => _handleSwap(walletProvider),
        style: ElevatedButton.styleFrom(
          backgroundColor: swapColor,
          foregroundColor: theme.colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _isSubmitting
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: theme.colorScheme.onPrimary, strokeWidth: 2),
              )
            : Text(
                _quote == null
                    ? l10n.walletSwapEnterAmountCta
                    : l10n.walletSwapSubmitLabel(
                        _fromTokenSymbol ?? '',
                        _toTokenSymbol ?? '',
                      ),
                style: KubusTypography.inter(fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  Widget _buildRecentSwaps(ThemeData theme, WalletProvider walletProvider) {
    final l10n = AppLocalizations.of(context)!;
    final swaps = walletProvider.getTransactionsByType(TransactionType.swap);
    if (swaps.isEmpty) {
      return _infoCard(
        theme,
        theme.colorScheme.primary,
        icon: Icons.history,
        title: l10n.walletSwapNoHistoryTitle,
        subtitle: l10n.walletSwapNoHistoryDescription,
      );
    }

    return ListView.separated(
      itemCount: swaps.length,
      separatorBuilder: (_, __) => const SizedBox(height: KubusSpacing.md),
      itemBuilder: (context, index) {
        final tx = swaps[index];
        return Container(
          padding: const EdgeInsets.all(KubusSpacing.md),
          decoration: _infoDecoration(theme),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(KubusRadius.md),
                ),
                child:
                    Icon(Icons.swap_horiz, color: theme.colorScheme.onSurface),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.token,
                      style: KubusTypography.inter(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tx.timeAgo,
                      style: KubusTypography.inter(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ),
              Text(
                tx.amount.toStringAsFixed(4),
                style: KubusTypography.inter(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface),
              ),
            ],
          ),
        );
      },
    );
  }

  void _onAmountChanged() {
    _quoteDebounce?.cancel();
    _quote = null;
    _quoteError = null;
    final value = _fromController.text.trim();
    if (value.isEmpty) {
      setState(() {
        _amountError = null;
        _toController.text = '';
      });
      return;
    }

    _quoteDebounce = Timer(const Duration(milliseconds: 350), _requestQuote);
  }

  Future<void> _requestQuote() async {
    final l10n = AppLocalizations.of(context)!;
    final walletProvider = context.read<WalletProvider>();
    final amount = double.tryParse(_fromController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() {
        _amountError = l10n.walletSwapPositiveAmountError;
        _quote = null;
        _quoteError = null;
      });
      return;
    }

    if (_fromTokenSymbol == null || _toTokenSymbol == null) {
      setState(() => _amountError = l10n.walletSwapSelectTokensError);
      return;
    }

    if (_fromTokenSymbol == _toTokenSymbol) {
      setState(() => _amountError = l10n.walletSwapDifferentTokensError);
      return;
    }

    setState(() {
      _amountError = null;
      _quoteError = null;
      _isFetchingQuote = true;
    });

    try {
      final quote = await walletProvider.previewSwapQuote(
        fromToken: _fromTokenSymbol!,
        toToken: _toTokenSymbol!,
        amount: amount,
        slippagePercent: _slippagePercent,
      );

      setState(() {
        _quote = quote;
        _toController.text = _formatAmount(quote.outputAmount);
      });
    } catch (e) {
      setState(() {
        _quote = null;
        _quoteError = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isFetchingQuote = false);
      }
    }
  }

  Future<void> _handleSwap(WalletProvider walletProvider) async {
    final l10n = AppLocalizations.of(context)!;
    final amount = double.tryParse(_fromController.text.trim()) ?? 0;
    if (amount <= 0) {
      setState(() => _amountError = l10n.walletSwapPositiveAmountDetailedError);
      return;
    }
    if (_fromTokenSymbol == null ||
        _toTokenSymbol == null ||
        _fromTokenSymbol == _toTokenSymbol) {
      setState(() => _amountError = l10n.walletSwapDifferentTokensError);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await walletProvider.swapTokens(
        fromToken: _fromTokenSymbol!,
        toToken: _toTokenSymbol!,
        fromAmount: amount,
        toAmount: _quote?.outputAmount ?? amount,
        slippage: _slippagePercent / 100,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(
          content:
              Text(l10n.walletSwapSubmittedToast(_fromTokenSymbol!, _toTokenSymbol!)),
          backgroundColor: Theme.of(context).colorScheme.tertiary,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(
          content: Text(
            l10n.walletSwapFailedToast(
              e.toString().replaceFirst('Exception: ', ''),
            ),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _selectToken(
      {required bool isFrom, required List<Token> tokens}) async {
    final currentSymbol = isFrom ? _fromTokenSymbol : _toTokenSymbol;
    final otherSymbol = isFrom ? _toTokenSymbol : _fromTokenSymbol;

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(KubusRadius.xl)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, controller) {
            return ListView.builder(
              controller: controller,
              itemCount: tokens.length,
              itemBuilder: (context, index) {
                final token = tokens[index];
                final isDisabled = isFrom
                    ? (token.balance <= 0 || token.symbol == otherSymbol)
                    : token.symbol == otherSymbol;
                return ListTile(
                  enabled: !isDisabled,
                  title: Text(token.name,
                      style:
                          KubusTypography.inter(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      AppLocalizations.of(context)!.walletSwapTokenOptionSubtitle(
                    token.symbol,
                    token.balance.toStringAsFixed(4),
                  )),
                  trailing: token.symbol == currentSymbol
                      ? Icon(Icons.check,
                          color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () => Navigator.pop(context, token.symbol),
                );
              },
            );
          },
        );
      },
    );

    if (selected == null) return;

    setState(() {
      if (isFrom) {
        _fromTokenSymbol = selected;
        _fromController.selection =
            TextSelection.collapsed(offset: _fromController.text.length);
      } else {
        _toTokenSymbol = selected;
      }
    });
    _requestQuote();
  }

  void _swapDirection() {
    setState(() {
      final temp = _fromTokenSymbol;
      _fromTokenSymbol = _toTokenSymbol;
      _toTokenSymbol = temp;
    });
    _requestQuote();
  }

  void _fillMax(Token token) {
    final balance = token.balance;
    if (balance <= 0) return;
    _fromController.text = _formatAmount(balance);
    _fromController.selection =
        TextSelection.collapsed(offset: _fromController.text.length);
    _requestQuote();
  }

  String _formatAmount(double value) {
    final formatted =
        value >= 1 ? value.toStringAsFixed(6) : value.toStringAsFixed(8);
    final trimmed = formatted
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    return trimmed.isEmpty ? '0' : trimmed;
  }
}

class _TokenAvatar extends StatelessWidget {
  const _TokenAvatar(
      {required this.symbol, required this.token, required this.swapColor});

  final String? symbol;
  final Token? token;
  final Color swapColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: token != null
            ? swapColor.withValues(alpha: 0.2)
            : theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Center(
        child: Text(
          (symbol ?? '?').substring(0, 1),
          style: KubusTypography.inter(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
