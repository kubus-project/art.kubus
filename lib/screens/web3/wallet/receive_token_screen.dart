import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../utils/design_tokens.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../../providers/wallet_provider.dart';
import '../../../models/wallet.dart';
import '../../../widgets/glass_components.dart';
import '../../../widgets/kubus_action_sidebar.dart';
import '../../../widgets/wallet/kubus_wallet_shell.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';

class ReceiveTokenScreen extends StatefulWidget {
  const ReceiveTokenScreen({super.key});

  @override
  State<ReceiveTokenScreen> createState() => _ReceiveTokenScreenState();
}

class _ReceiveTokenScreenState extends State<ReceiveTokenScreen>
    with TickerProviderStateMixin {
  String _selectedToken = 'KUB8';
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final walletProvider = Provider.of<WalletProvider>(context);
    final walletAddress = walletProvider.currentWalletAddress;
    final hasWalletAddress = walletAddress != null && walletAddress.isNotEmpty;
    final selectedToken = _currentToken(walletProvider.tokens);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n.receiveTokenTitle,
          style: KubusTypography.inter(
            fontSize: KubusHeaderMetrics.screenTitle,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isLargeCanvas = constraints.maxWidth >= 1360;

          return KubusWalletResponsiveShell(
            wideBreakpoint: 1100,
            mainChildren: <Widget>[
              KubusWalletSectionCard(
                child: _buildTokenSelector(),
              ),
              const SizedBox(height: KubusSpacing.lg),
              if (isLargeCanvas)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: _buildQRCode(
                        walletAddress,
                        hasWalletAddress,
                        selectedToken,
                      ),
                    ),
                    const SizedBox(width: KubusSpacing.lg),
                    Expanded(
                      child: _buildAddressSection(
                        walletAddress,
                        hasWalletAddress,
                        selectedToken,
                      ),
                    ),
                  ],
                )
              else ...<Widget>[
                _buildQRCode(
                  walletAddress,
                  hasWalletAddress,
                  selectedToken,
                ),
                const SizedBox(height: KubusSpacing.lg),
                _buildAddressSection(
                  walletAddress,
                  hasWalletAddress,
                  selectedToken,
                ),
              ],
              const SizedBox(height: KubusSpacing.lg),
              _buildInstructions(),
            ],
            sideChildren: <Widget>[
              _buildReceiveSidebar(
                walletProvider,
                walletAddress: walletAddress,
                hasWalletAddress: hasWalletAddress,
                token: selectedToken,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTokenSelector() {
    final l10n = AppLocalizations.of(context)!;
    return Consumer<WalletProvider>(
      builder: (context, walletProvider, _) {
        final tokens = walletProvider.tokens
            .where((token) => token.type != TokenType.nft)
            .toList();

        if (tokens.isEmpty) {
          return _buildTokenSelectorEmptyState();
        }

        if (!_tokenExists(tokens, _selectedToken)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _selectedToken = tokens.first.symbol;
            });
          });
        }

        final theme = Theme.of(context);
        final accent = KubusColorRoles.of(context).statBlue;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.receiveTokenSelectTokenTitle,
              style: KubusTypography.inter(
                fontSize: KubusHeaderMetrics.sectionTitle,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: KubusSpacing.md),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: tokens.map((token) {
                  final isSelected = token.symbol == _selectedToken;
                  return Padding(
                    padding: const EdgeInsets.only(right: KubusSpacing.md),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedToken = token.symbol);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: KubusSpacing.md,
                          vertical: KubusSpacing.sm + KubusSpacing.xxs,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? accent.withValues(alpha: 0.2)
                              : theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(KubusRadius.md),
                          border: Border.all(
                            color:
                                isSelected ? accent : theme.colorScheme.outline,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildTokenAvatar(token, isSelected: isSelected),
                            const SizedBox(width: KubusSpacing.sm),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  token.symbol,
                                  style: KubusTypography.inter(
                                    fontSize:
                                        KubusHeaderMetrics.sectionSubtitle,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  l10n.receiveTokenBalanceLabel(
                                    token.balance.toStringAsFixed(
                                        token.decimals >= 3 ? 3 : 2),
                                  ),
                                  style: KubusTypography.inter(
                                    fontSize: KubusSizes.badgeCountFontSize,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQRCode(
      String? walletAddress, bool hasWalletAddress, Token? token) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final roles = KubusColorRoles.of(context);
    final tokenSymbol = token?.symbol ?? _selectedToken;
    final qrData = hasWalletAddress && walletAddress != null
        ? _buildQrPayload(walletAddress, token)
        : '';

    return ScaleTransition(
      scale: _scaleAnimation,
      child: LiquidGlassCard(
        padding: const EdgeInsets.all(KubusSpacing.lg),
        child: Column(
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(KubusRadius.md),
                border: Border.all(
                  color: roles.statBlue.withValues(alpha: 0.18),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(KubusSpacing.sm),
                child: hasWalletAddress
                    ? QrImageView(
                        data: qrData,
                        version: QrVersions.auto,
                        size: 184.0,
                        backgroundColor: theme.colorScheme.onPrimary,
                        eyeStyle:
                            QrEyeStyle(color: theme.colorScheme.onSurface),
                        dataModuleStyle: QrDataModuleStyle(
                            color: theme.colorScheme.onSurface),
                        errorStateBuilder: (cxt, err) {
                          final theme = Theme.of(cxt);
                          return Center(
                            child: Text(
                              l10n.receiveTokenQrError,
                              textAlign: TextAlign.center,
                              style: KubusTypography.inter(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      )
                    : Center(
                        child: Text(
                          l10n.receiveTokenQrRequiresWallet,
                          textAlign: TextAlign.center,
                          style: KubusTypography.inter(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: KubusSpacing.md),
            Text(
              l10n.receiveTokenScanToSend(tokenSymbol),
              style: KubusTypography.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasWalletAddress
                  ? l10n.receiveTokenAnyoneCanSend(tokenSymbol)
                  : l10n.receiveTokenFinishSetupToShare,
              style: KubusTypography.inter(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressSection(
      String? walletAddress, bool hasWalletAddress, Token? token) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final roles = KubusColorRoles.of(context);
    final accent = roles.statBlue;
    final tokenSymbol = token?.symbol ?? _selectedToken;

    return LiquidGlassCard(
      padding: const EdgeInsets.all(KubusSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.receiveTokenYourAddressTitle(tokenSymbol),
                style: KubusTypography.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    tooltip: l10n.receiveTokenShareAddressTooltip,
                    onPressed: hasWalletAddress && walletAddress != null
                        ? () => _shareAddress(walletAddress, token)
                        : null,
                    icon: Icon(
                      Icons.share_outlined,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.receiveTokenCopyAddressTooltip,
                    onPressed: hasWalletAddress
                        ? () => _copyAddress(walletAddress)
                        : null,
                    icon: Icon(
                      Icons.copy,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(KubusSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(KubusRadius.md),
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.16),
              ),
            ),
            child: hasWalletAddress
                ? SelectableText(
                    walletAddress!,
                    style: KubusTypography.inter(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  )
                : Text(
                    l10n.receiveTokenRequiresWalletToReceive,
                    style: KubusTypography.inter(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  hasWalletAddress ? () => _copyAddress(walletAddress) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(KubusRadius.md),
                ),
              ),
              icon: Icon(Icons.content_copy,
                  color: theme.colorScheme.onPrimary, size: 18),
              label: Text(
                l10n.receiveTokenCopyAddressButton,
                style: KubusTypography.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final roles = KubusColorRoles.of(context);
    return LiquidGlassCard(
      padding: const EdgeInsets.all(KubusSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: roles.statBlue,
                size: 20,
              ),
              const SizedBox(width: KubusSpacing.sm),
              Text(
                l10n.receiveTokenHowToReceiveTitle(_selectedToken),
                style: KubusTypography.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: KubusSpacing.md),
          _buildInstructionStep(
            '1',
            l10n.receiveTokenStep1Title,
            l10n.receiveTokenStep1Description(_selectedToken),
          ),
          const SizedBox(height: KubusSpacing.sm),
          _buildInstructionStep(
            '2',
            l10n.receiveTokenStep2Title,
            l10n.receiveTokenStep2Description,
          ),
          const SizedBox(height: KubusSpacing.sm),
          _buildInstructionStep(
            '3',
            l10n.receiveTokenStep3Title,
            l10n.receiveTokenStep3Description,
          ),
          const SizedBox(height: KubusSpacing.md),
          Container(
            padding: const EdgeInsets.all(KubusSpacing.sm),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(KubusRadius.sm),
              border: Border.all(
                color: theme.colorScheme.error.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_outlined,
                    color: theme.colorScheme.error, size: 20),
                const SizedBox(width: KubusSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.receiveTokenWarningOnlySend(_selectedToken),
                    style: KubusTypography.inter(
                      fontSize: 12,
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiveSidebar(
    WalletProvider walletProvider, {
    required String? walletAddress,
    required bool hasWalletAddress,
    required Token? token,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    final recentInbound = _recentInboundTransfers(walletProvider);
    final tokenSymbol = token?.symbol ?? _selectedToken;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        KubusWalletSectionCard(
          title: l10n.receiveTokenSidebarShareTitle,
          subtitle: l10n.receiveTokenSidebarShareSubtitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: KubusSpacing.sm,
                runSpacing: KubusSpacing.sm,
                children: <Widget>[
                  KubusWalletMetaPill(
                    label: tokenSymbol,
                    icon: Icons.token_outlined,
                    tintColor: roles.statAmber,
                  ),
                  KubusWalletMetaPill(
                    label: l10n.receiveTokenBalanceLabel(
                      token == null
                          ? '0'
                          : token.balance.toStringAsFixed(
                              token.decimals >= 3 ? 3 : 2,
                            ),
                    ),
                    icon: Icons.savings_outlined,
                    tintColor: roles.statBlue,
                  ),
                ],
              ),
              const SizedBox(height: KubusSpacing.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: hasWalletAddress
                          ? () => _copyAddress(walletAddress)
                          : null,
                      icon: const Icon(Icons.copy_rounded),
                      label: Text(l10n.receiveTokenCopyAddressButton),
                    ),
                  ),
                  const SizedBox(width: KubusSpacing.md),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: hasWalletAddress && walletAddress != null
                          ? () => _shareAddress(walletAddress, token)
                          : null,
                      icon: const Icon(Icons.share_outlined),
                      label: Text(l10n.receiveTokenSidebarShareAction),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: KubusSpacing.lg),
        KubusWalletSectionCard(
          title: l10n.receiveTokenSidebarActivityTitle,
          subtitle: l10n.receiveTokenSidebarActivitySubtitle,
          child: recentInbound.isEmpty
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.receiveTokenSidebarNoActivityTitle,
                      style: KubusTextStyles.detailCardTitle.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: KubusSpacing.xs),
                    Text(
                      l10n.receiveTokenSidebarNoActivityDescription,
                      style: KubusTextStyles.detailBody.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.68),
                      ),
                    ),
                  ],
                )
              : Column(
                  children: recentInbound
                      .map(
                        (entry) => KubusActionSidebarTile(
                          title: _shortAddress(entry.counterparty),
                          subtitle: l10n.receiveTokenSidebarTransferSubtitle(
                            entry.token,
                            entry.amount.toStringAsFixed(4),
                            _formatSidebarDate(entry.timestamp),
                          ),
                          icon: Icons.south_west_rounded,
                          semantic: KubusActionSemantic.view,
                          onTap: () => _copyAddress(entry.counterparty),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildInstructionStep(
      String number, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: KubusColorRoles.of(context).statBlue,
            borderRadius: BorderRadius.circular(KubusRadius.md),
          ),
          child: Center(
            child: Text(
              number,
              style: KubusTypography.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: KubusTypography.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: KubusTypography.inter(
                  fontSize: 13,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _copyAddress(String? walletAddress) {
    final l10n = AppLocalizations.of(context)!;
    if (walletAddress == null || walletAddress.isEmpty) {
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(
          content: Text(l10n.receiveTokenNoWalletAddressToast),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    Clipboard.setData(ClipboardData(text: walletAddress));
    ScaffoldMessenger.of(context).showKubusSnackBar(
      SnackBar(
        content: Text(l10n.walletHomeAddressCopiedToast),
        backgroundColor: KubusColorRoles.of(context).statBlue,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _shortAddress(String address) {
    if (address.length <= 14) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 6)}';
  }

  String _formatSidebarDate(DateTime timestamp) {
    final localizations = MaterialLocalizations.of(context);
    return localizations.formatShortDate(timestamp.toLocal());
  }

  List<_ReceiveSidebarEntry> _recentInboundTransfers(WalletProvider wallet) {
    final transactions = List<WalletTransaction>.from(
      wallet.getTransactionsByType(TransactionType.receive),
    )..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final seen = <String>{};
    final entries = <_ReceiveSidebarEntry>[];

    for (final transaction in transactions) {
      final counterparty =
          (transaction.fromAddress ?? transaction.primaryCounterparty ?? '')
              .trim();
      if (counterparty.isEmpty || !seen.add(counterparty)) {
        continue;
      }
      entries.add(
        _ReceiveSidebarEntry(
          counterparty: counterparty,
          token: transaction.token,
          amount: transaction.amount,
          timestamp: transaction.timestamp,
        ),
      );
      if (entries.length >= 4) {
        break;
      }
    }

    return entries;
  }

  Future<void> _shareAddress(String address, Token? token) async {
    final l10n = AppLocalizations.of(context)!;
    final tokenSymbol = token?.symbol ?? _selectedToken;
    final payload = _buildQrPayload(address, token);
    await SharePlus.instance.share(
      ShareParams(
          text: l10n.receiveTokenShareText(tokenSymbol, address, payload)),
    );
  }

  String _buildQrPayload(String address, Token? token) {
    if (address.isEmpty) return '';
    if (token == null ||
        token.symbol.toUpperCase() == 'SOL' ||
        token.contractAddress.toLowerCase() == 'native') {
      return 'solana:$address';
    }

    final uri = Uri(
      scheme: 'solana',
      path: address,
      queryParameters: {
        'spl-token': token.contractAddress,
        'label': token.symbol,
      },
    );
    return uri.toString();
  }

  Token? _currentToken(List<Token> tokens) {
    for (final token in tokens) {
      if (token.symbol == _selectedToken) return token;
    }
    return tokens.isNotEmpty ? tokens.first : null;
  }

  bool _tokenExists(List<Token> tokens, String symbol) {
    return tokens.any((token) => token.symbol == symbol);
  }

  Widget _buildTokenSelectorEmptyState() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(KubusSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(KubusRadius.lg),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        children: [
          Icon(Icons.account_balance_wallet_outlined,
              color: theme.colorScheme.onSurface),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.receiveTokenNoTokensMessage,
              style: KubusTypography.inter(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTokenAvatar(Token token, {bool isSelected = false}) {
    final theme = Theme.of(context);
    final accent = KubusColorRoles.of(context).statBlue;
    final background = isSelected
        ? accent.withValues(alpha: 0.25)
        : theme.colorScheme.surfaceContainerHighest;

    if (token.logoUrl != null && token.logoUrl!.isNotEmpty) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? accent : background),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          token.logoUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              _tokenInitialAvatar(token, background, theme),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return _tokenInitialAvatar(token, background, theme);
          },
        ),
      );
    }

    return _tokenInitialAvatar(token, background, theme);
  }

  Widget _tokenInitialAvatar(Token token, Color background, ThemeData theme) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(
          token.symbol.isNotEmpty
              ? token.symbol.substring(0, 1).toUpperCase()
              : '?',
          style: KubusTypography.inter(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _ReceiveSidebarEntry {
  const _ReceiveSidebarEntry({
    required this.counterparty,
    required this.token,
    required this.amount,
    required this.timestamp,
  });

  final String counterparty;
  final String token;
  final double amount;
  final DateTime timestamp;
}
