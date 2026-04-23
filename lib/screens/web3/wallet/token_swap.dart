import 'dart:async';

import 'package:flutter/material.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../config/config.dart';
import '../../../config/api_keys.dart';
import '../../../models/swap_quote.dart';
import '../../../models/wallet.dart';
import '../../../providers/wallet_provider.dart';
import '../../../utils/design_tokens.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../../widgets/glass_components.dart';
import '../../../widgets/kubus_action_sidebar.dart';
import '../../../widgets/wallet/kubus_wallet_shell.dart';
import '../../../widgets/wallet_transaction_card.dart';
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
    if (AppConfig.isFeatureEnabled('tokenSwap')) {
      _fromController.addListener(_onAmountChanged);
    }
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
    final swapEnabled = AppConfig.isFeatureEnabled('tokenSwap');
    final swapColor = KubusColorRoles.of(context).positiveAction;
    if (!swapEnabled) {
      return _buildDisabledState(theme, swapColor, l10n);
    }
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
                  final isWide = constraints.maxWidth >= 1100;
                  return KubusWalletResponsiveShell(
                    wideBreakpoint: 1100,
                    mainChildren: <Widget>[
                      _buildSwapOverviewCard(theme, walletProvider),
                      const SizedBox(height: KubusSpacing.lg),
                      KubusWalletSectionCard(
                        child: _buildSwapCard(
                            theme, swapColor, walletProvider, tokens),
                      ),
                      if (!isWide) ...<Widget>[
                        const SizedBox(height: KubusSpacing.lg),
                        KubusWalletSectionCard(
                          child: _buildQuoteDetails(theme, swapColor),
                        ),
                      ],
                      const SizedBox(height: KubusSpacing.lg),
                      KubusWalletSectionCard(
                        child: _buildSlippageSelector(theme, swapColor),
                      ),
                      const SizedBox(height: KubusSpacing.lg),
                      KubusWalletSectionCard(
                        child:
                            _buildSwapButton(theme, swapColor, walletProvider),
                      ),
                      if (!isWide) ...<Widget>[
                        const SizedBox(height: KubusSpacing.lg),
                        KubusWalletSectionCard(
                          title: l10n.walletSwapRecentPairsTitle,
                          subtitle: l10n.walletSwapRecentPairsSubtitle,
                          child: _buildRecentSwaps(
                            theme,
                            walletProvider,
                            embedded: true,
                          ),
                        ),
                      ],
                    ],
                    sideChildren: <Widget>[
                      _buildSwapSidebar(theme, swapColor, walletProvider),
                    ],
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
      WalletAuthorityState.walletReadOnly =>
        l10n.walletSessionStateWalletReadOnly,
      WalletAuthorityState.localSignerReady =>
        l10n.walletSessionStateLocalSignerReady,
      WalletAuthorityState.externalWalletReady =>
        l10n.walletSessionStateExternalWalletReady,
      WalletAuthorityState.encryptedBackupAvailableSignerMissing =>
        l10n.walletSessionStateEncryptedBackupAvailable,
      WalletAuthorityState.recoveryNeeded =>
        l10n.walletSessionStateRecoveryNeeded,
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

  Widget _buildDisabledState(
    ThemeData theme,
    Color swapColor,
    AppLocalizations l10n,
  ) {
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
                Icon(Icons.swap_horiz, size: 64, color: swapColor),
                const SizedBox(height: KubusSpacing.lg),
                Text(
                  l10n.walletSwapTemporarilyDisabledTitle,
                  textAlign: TextAlign.center,
                  style: KubusTypography.inter(
                    fontSize: KubusHeaderMetrics.screenTitle,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: KubusSpacing.md),
                Text(
                  l10n.walletSwapTemporarilyDisabledDescription,
                  textAlign: TextAlign.center,
                  style: KubusTypography.inter(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: KubusSpacing.lg),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.commonBack),
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

  Widget _buildSwapOverviewCard(
    ThemeData theme,
    WalletProvider walletProvider,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    final routeLabel = _quote == null
        ? l10n.walletSwapEnterAmountTitle
        : l10n.walletSwapSubmitLabel(
            _fromTokenSymbol ?? '',
            _toTokenSymbol ?? '',
          );
    final secondary = _quote == null
        ? l10n.walletSwapEnterAmountDescription
        : l10n.walletSwapEstimatedOutputLabel;

    return LiquidGlassCard(
      padding: const EdgeInsets.all(KubusSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.walletSwapTitle,
            style: KubusTextStyles.screenTitle.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: KubusSpacing.xs),
          Text(
            l10n.walletSwapSearchingRouteLabel,
            style: KubusTextStyles.screenSubtitle.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: KubusSpacing.md),
          Wrap(
            spacing: KubusSpacing.sm,
            runSpacing: KubusSpacing.sm,
            children: <Widget>[
              _SwapOverviewPill(
                label: routeLabel,
                value: secondary,
              ),
              _SwapOverviewPill(
                label: l10n.walletSwapSlippageToleranceLabel,
                value: '${_slippagePercent.toStringAsFixed(2)}%',
              ),
              KubusWalletMetaPill(
                label: walletProvider.currentSolanaNetwork,
                icon: Icons.lan_outlined,
                tintColor: roles.statBlue,
              ),
              if (_quote != null)
                _SwapOverviewPill(
                  label: l10n.walletSwapEstimatedOutputLabel,
                  value:
                      '${_formatAmount(_quote!.outputAmount)} ${_toTokenSymbol ?? ''}',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSwapSidebar(
    ThemeData theme,
    Color swapColor,
    WalletProvider walletProvider,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final recentPairs = _recentSwapPairs(walletProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        KubusWalletSectionCard(
          title: l10n.walletSwapQuoteSidebarTitle,
          subtitle: l10n.walletSwapQuoteSidebarSubtitle,
          child: _buildQuoteDetails(theme, swapColor),
        ),
        const SizedBox(height: KubusSpacing.lg),
        KubusWalletSectionCard(
          title: l10n.walletSwapRecentPairsTitle,
          subtitle: l10n.walletSwapRecentPairsSubtitle,
          child: recentPairs.isEmpty
              ? Text(
                  l10n.walletSwapNoHistoryDescription,
                  style: KubusTextStyles.detailBody.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
                  ),
                )
              : Column(
                  children: recentPairs
                      .map(
                        (pair) => KubusActionSidebarTile(
                          title: '${pair.fromToken} -> ${pair.toToken}',
                          subtitle: l10n.walletSwapRecentPairSubtitle(
                            pair.amount,
                            _formatSidebarDate(pair.timestamp),
                          ),
                          icon: Icons.swap_horiz_rounded,
                          semantic: KubusActionSemantic.view,
                          onTap: () => _applyRecentPair(pair),
                        ),
                      )
                      .toList(),
                ),
        ),
        const SizedBox(height: KubusSpacing.lg),
        KubusWalletSectionCard(
          title: l10n.walletSecurityStatusTitle,
          subtitle: l10n.walletSwapSecuritySubtitle,
          child: WalletCustodyStatusPanel(
            authority: walletProvider.authority,
            compact: true,
            onRestoreSigner:
                walletProvider.authority.canRestoreFromEncryptedBackup
                    ? _handleReadOnlyReconnect
                    : null,
            onConnectExternalWallet: !walletProvider.canTransact
                ? () => Navigator.of(context).pushNamed('/connect-wallet')
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildSwapCard(
    ThemeData theme,
    Color swapColor,
    WalletProvider walletProvider,
    List<Token> tokens,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final fromToken = _fromTokenSymbol == null
        ? null
        : walletProvider.getTokenBySymbol(_fromTokenSymbol!);
    final toToken = _toTokenSymbol == null
        ? null
        : walletProvider.getTokenBySymbol(_toTokenSymbol!);

    return LiquidGlassCard(
      padding: const EdgeInsets.all(KubusSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.walletSwapQuotePreviewTitle,
            style: KubusTextStyles.sectionTitle.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: KubusSpacing.xs),
          Text(
            l10n.walletSwapSearchingRouteLabel,
            style: KubusTextStyles.sectionSubtitle.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
            ),
          ),
          const SizedBox(height: KubusSpacing.lg),
          _buildTokenInput(
            label: l10n.walletSwapYouPayLabel,
            isFrom: true,
            theme: theme,
            swapColor: swapColor,
            walletProvider: walletProvider,
            tokens: tokens,
          ),
          const SizedBox(height: KubusSpacing.md),
          Center(
            child: InkWell(
              onTap: tokens.length > 1 ? _swapDirection : null,
              borderRadius: BorderRadius.circular(KubusRadius.xl),
              child: Container(
                padding: const EdgeInsets.all(KubusSpacing.sm),
                decoration: BoxDecoration(
                  color: swapColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(KubusRadius.xl),
                  border: Border.all(
                    color: swapColor.withValues(alpha: 0.24),
                  ),
                ),
                child: Icon(
                  Icons.swap_vert_rounded,
                  color: tokens.length > 1
                      ? swapColor
                      : theme.colorScheme.onSurface.withValues(alpha: 0.32),
                ),
              ),
            ),
          ),
          const SizedBox(height: KubusSpacing.md),
          _buildTokenInput(
            label: l10n.walletSwapYouReceiveLabel,
            isFrom: false,
            theme: theme,
            swapColor: swapColor,
            walletProvider: walletProvider,
            tokens: tokens,
          ),
          const SizedBox(height: KubusSpacing.lg),
          Wrap(
            spacing: KubusSpacing.sm,
            runSpacing: KubusSpacing.sm,
            children: <Widget>[
              if (fromToken != null)
                KubusWalletMetaPill(
                  label: l10n.walletSwapBalanceLabel(
                    walletProvider
                        .getTokenBalance(fromToken.symbol)
                        .toStringAsFixed(4),
                  ),
                  icon: Icons.arrow_upward_rounded,
                  tintColor: swapColor,
                ),
              if (toToken != null)
                KubusWalletMetaPill(
                  label: '${toToken.symbol} ${toToken.formattedValue}',
                  icon: Icons.arrow_downward_rounded,
                  tintColor: KubusColorRoles.of(context).statBlue,
                ),
              KubusWalletMetaPill(
                label: l10n.walletSwapSlippageToleranceLabel,
                icon: Icons.tune_rounded,
                tintColor: KubusColorRoles.of(context).statAmber,
              ),
            ],
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
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(KubusRadius.lg),
        border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.16)),
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
                    color: swapColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                    border:
                        Border.all(color: swapColor.withValues(alpha: 0.24)),
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
                final label = step['label']?.toString() ??
                    l10n.walletSwapRouteFallbackLabel;
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
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(18),
      border:
          Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.14)),
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

  Widget _buildRecentSwaps(
    ThemeData theme,
    WalletProvider walletProvider, {
    bool embedded = false,
  }) {
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

    final items = swaps.take(4).toList();
    return ListView.separated(
      shrinkWrap: embedded,
      physics: embedded ? const NeverScrollableScrollPhysics() : null,
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: KubusSpacing.md),
      itemBuilder: (context, index) {
        final tx = items[index];
        return WalletTransactionCard(
          transaction: tx,
          compact: true,
        );
      },
    );
  }

  List<_RecentSwapPair> _recentSwapPairs(WalletProvider walletProvider) {
    final swaps = List<WalletTransaction>.from(
      walletProvider.getTransactionsByType(TransactionType.swap),
    )..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final seen = <String>{};
    final pairs = <_RecentSwapPair>[];

    for (final swap in swaps) {
      final toToken = (swap.swapToToken ?? '').trim();
      if (toToken.isEmpty) {
        continue;
      }
      final key = '${swap.token}::$toToken';
      if (!seen.add(key)) {
        continue;
      }
      pairs.add(
        _RecentSwapPair(
          fromToken: swap.token,
          toToken: toToken,
          amount: _formatAmount(swap.amount),
          timestamp: swap.timestamp,
        ),
      );
      if (pairs.length >= 4) {
        break;
      }
    }

    return pairs;
  }

  void _applyRecentPair(_RecentSwapPair pair) {
    if (!AppConfig.isFeatureEnabled('tokenSwap')) {
      return;
    }
    setState(() {
      _fromTokenSymbol = pair.fromToken;
      _toTokenSymbol = pair.toToken;
    });
    _requestQuote();
  }

  String _formatSidebarDate(DateTime timestamp) {
    final localizations = MaterialLocalizations.of(context);
    return localizations.formatShortDate(timestamp.toLocal());
  }

  void _onAmountChanged() {
    if (!AppConfig.isFeatureEnabled('tokenSwap')) {
      return;
    }
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
    if (!AppConfig.isFeatureEnabled('tokenSwap')) {
      return;
    }
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
    if (!AppConfig.isFeatureEnabled('tokenSwap')) {
      return;
    }
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
      final result = await walletProvider.swapTokens(
        fromToken: _fromTokenSymbol!,
        toToken: _toTokenSymbol!,
        fromAmount: amount,
        toAmount: _quote?.outputAmount ?? amount,
        slippage: _slippagePercent / 100,
        quote: _quote,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(
          content: Text(
            l10n.walletSwapSubmittedToastWithSignature(
              _fromTokenSymbol!,
              _toTokenSymbol!,
              result.primarySignature,
            ),
          ),
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
    if (!AppConfig.isFeatureEnabled('tokenSwap')) {
      return;
    }
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
                  subtitle: Text(AppLocalizations.of(context)!
                      .walletSwapTokenOptionSubtitle(
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
    if (!AppConfig.isFeatureEnabled('tokenSwap')) {
      return;
    }
    setState(() {
      final temp = _fromTokenSymbol;
      _fromTokenSymbol = _toTokenSymbol;
      _toTokenSymbol = temp;
    });
    _requestQuote();
  }

  void _fillMax(Token token) {
    if (!AppConfig.isFeatureEnabled('tokenSwap')) {
      return;
    }
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

class _RecentSwapPair {
  const _RecentSwapPair({
    required this.fromToken,
    required this.toToken,
    required this.amount,
    required this.timestamp,
  });

  final String fromToken;
  final String toToken;
  final String amount;
  final DateTime timestamp;
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

class _SwapOverviewPill extends StatelessWidget {
  const _SwapOverviewPill({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KubusSpacing.md,
        vertical: KubusSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(KubusRadius.xl),
        border: Border.all(
          color: scheme.outline.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: KubusTextStyles.compactBadge.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.64),
            ),
          ),
          const SizedBox(height: KubusSpacing.xs),
          Text(
            value,
            style: KubusTextStyles.detailLabel.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
