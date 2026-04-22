import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:solana/solana.dart' show Ed25519HDPublicKey;
import '../../../utils/design_tokens.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../../providers/platform_provider.dart';
import '../../../widgets/inline_loading.dart';
import '../../../widgets/wallet_custody_status_panel.dart';
import '../../../widgets/glass_components.dart';
import '../../../widgets/kubus_action_sidebar.dart';
import '../../../widgets/wallet/kubus_wallet_shell.dart';
import '../../../config/api_keys.dart';
import '../../../models/qr_scan_result.dart';
import '../../../models/wallet.dart';
import '../../../utils/wallet_action_guard.dart';
import 'qr_scanner_screen.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';

class SendTokenScreen extends StatefulWidget {
  const SendTokenScreen({super.key});

  @override
  State<SendTokenScreen> createState() => _SendTokenScreenState();
}

class _SendTokenScreenState extends State<SendTokenScreen>
    with TickerProviderStateMixin {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  String _selectedToken = 'KUB8';
  bool _isLoading = false;
  String _addressError = '';
  String _amountError = '';
  double _estimatedGas = 0.0;

  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _estimateGasFee();
    _animationController.forward();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _amountController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final walletProvider = context.watch<WalletProvider>();
    final authority = walletProvider.authority;
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
          l10n.sendTokenTitle,
          style: KubusTypography.inter(
            fontSize: KubusHeaderMetrics.screenTitle,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          Consumer<PlatformProvider>(
            builder: (context, platformProvider, child) {
              return IconButton(
                icon: Icon(
                  platformProvider.getQRScannerIcon(),
                  color: platformProvider.supportsQRScanning
                      ? Theme.of(context).colorScheme.onSurface
                      : platformProvider.getUnsupportedFeatureColor(context),
                ),
                onPressed: platformProvider.supportsQRScanning
                    ? _scanQRCode
                    : () => _showUnsupportedFeature(context, platformProvider),
                tooltip: platformProvider.supportsQRScanning
                    ? l10n.sendTokenScanQrTooltip
                    : l10n.sendTokenQrScannerUnavailableTooltip,
              );
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (authority.hasWalletIdentity && !authority.canTransact) {
            return _buildSignerRequiredState(walletProvider, l10n);
          }
          final isLargeComposer = constraints.maxWidth >= 1380;

          return SlideTransition(
            position: _slideAnimation,
            child: KubusWalletResponsiveShell(
              wideBreakpoint: 1100,
              mainChildren: <Widget>[
                _buildSendOverviewCard(walletProvider),
                const SizedBox(height: KubusSpacing.lg),
                KubusWalletSectionCard(
                  child: _buildTokenSelector(),
                ),
                const SizedBox(height: KubusSpacing.lg),
                if (isLargeComposer)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: KubusWalletSectionCard(
                          child: _buildAddressInput(),
                        ),
                      ),
                      const SizedBox(width: KubusSpacing.lg),
                      Expanded(
                        child: KubusWalletSectionCard(
                          child: _buildAmountInput(),
                        ),
                      ),
                    ],
                  )
                else ...<Widget>[
                  KubusWalletSectionCard(
                    child: _buildAddressInput(),
                  ),
                  const SizedBox(height: KubusSpacing.lg),
                  KubusWalletSectionCard(
                    child: _buildAmountInput(),
                  ),
                ],
                const SizedBox(height: KubusSpacing.lg),
                KubusWalletSectionCard(
                  child: _buildTransactionSummary(),
                ),
                const SizedBox(height: KubusSpacing.lg),
                KubusWalletSectionCard(
                  child: _buildSendButton(),
                ),
              ],
              sideChildren: <Widget>[
                _buildSendSidebar(walletProvider),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSignerRequiredState(
    WalletProvider walletProvider,
    AppLocalizations l10n,
  ) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(KubusSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                WalletCustodyStatusPanel(
                  authority: walletProvider.authority,
                  onRestoreSigner: walletProvider
                          .authority.canRestoreFromEncryptedBackup
                      ? () => WalletActionGuard.ensureSignerAccess(
                            context: context,
                            profileProvider: context.read<ProfileProvider>(),
                            walletProvider: walletProvider,
                          )
                      : null,
                  onConnectExternalWallet: !walletProvider.canTransact
                      ? () => Navigator.of(context).pushNamed('/connect-wallet')
                      : null,
                ),
                const SizedBox(height: KubusSpacing.lg),
                FilledButton.icon(
                  onPressed: () => WalletActionGuard.ensureSignerAccess(
                    context: context,
                    profileProvider: context.read<ProfileProvider>(),
                    walletProvider: walletProvider,
                  ),
                  icon: const Icon(Icons.lock_open_outlined),
                  label: Text(l10n.commonReconnect),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSendOverviewCard(WalletProvider walletProvider) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final roles = KubusColorRoles.of(context);
    final amount = _amountController.text.trim().isEmpty
        ? '0'
        : _amountController.text.trim();
    final recipient = _addressController.text.trim();
    final shortRecipient = recipient.length > 14
        ? '${recipient.substring(0, 6)}...${recipient.substring(recipient.length - 6)}'
        : recipient;

    return LiquidGlassCard(
      padding: const EdgeInsets.all(KubusSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.sendTokenTitle,
            style: KubusTextStyles.screenTitle.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: KubusSpacing.xs),
          Text(
            l10n.sendTokenNetworkFeeNote,
            style: KubusTextStyles.screenSubtitle.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: KubusSpacing.md),
          Wrap(
            spacing: KubusSpacing.sm,
            runSpacing: KubusSpacing.sm,
            children: <Widget>[
              _SendOverviewPill(
                label: l10n.sendTokenSelectTokenTitle,
                value: _selectedToken,
              ),
              _SendOverviewPill(
                label: l10n.sendTokenAvailableLabel(
                  _getTokenBalance(_selectedToken),
                  _selectedToken,
                ),
                value: amount,
              ),
              _SendOverviewPill(
                label: l10n.sendTokenSummaryNetworkFeeLabel,
                value: '${_estimatedGas.toStringAsFixed(6)} SOL',
              ),
              KubusWalletMetaPill(
                label: walletProvider.currentSolanaNetwork,
                icon: Icons.lan_outlined,
                tintColor: roles.statBlue,
              ),
              KubusWalletMetaPill(
                label: walletProvider.authority.canTransact
                    ? l10n.walletSecuritySignerLocalReadyValue
                    : walletProvider.authority.canRestoreFromEncryptedBackup
                        ? l10n.walletSecuritySignerRestoreAvailableValue
                        : l10n.walletSecuritySignerMissingValue,
                icon: walletProvider.authority.canTransact
                    ? Icons.lock_open_outlined
                    : Icons.visibility_outlined,
                tintColor: walletProvider.authority.canTransact
                    ? roles.positiveAction
                    : roles.warningAction,
                emphasized: !walletProvider.authority.canTransact,
              ),
              if (shortRecipient.isNotEmpty)
                _SendOverviewPill(
                  label: l10n.sendTokenRecipientAddressTitle,
                  value: shortRecipient,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSendSidebar(WalletProvider walletProvider) {
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    final recipients = _recentRecipients(walletProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        KubusWalletSectionCard(
          title: l10n.sendTokenSidebarRecipientsTitle,
          subtitle: l10n.sendTokenSidebarRecipientsSubtitle,
          child: recipients.isEmpty
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.sendTokenSidebarNoRecipientsTitle,
                      style: KubusTextStyles.detailCardTitle.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: KubusSpacing.xs),
                    Text(
                      l10n.sendTokenSidebarNoRecipientsDescription,
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
                  children: recipients
                      .map(
                        (recipient) => KubusActionSidebarTile(
                          title: _shortAddress(recipient.address),
                          subtitle: l10n.sendTokenSidebarRecipientSubtitle(
                            recipient.token,
                            _formatScannedAmount(recipient.amount),
                            _formatSidebarTime(recipient.timestamp),
                          ),
                          icon: Icons.north_east_rounded,
                          semantic: KubusActionSemantic.view,
                          onTap: () =>
                              _applyRecentRecipient(walletProvider, recipient),
                        ),
                      )
                      .toList(),
                ),
        ),
        const SizedBox(height: KubusSpacing.lg),
        KubusWalletSectionCard(
          title: l10n.sendTokenSidebarSummaryTitle,
          subtitle: l10n.sendTokenSidebarSummarySubtitle,
          child: Wrap(
            spacing: KubusSpacing.sm,
            runSpacing: KubusSpacing.sm,
            children: <Widget>[
              KubusWalletMetaPill(
                label: l10n.sendTokenAvailableLabel(
                  _getTokenBalance(_selectedToken),
                  _selectedToken,
                ),
                icon: Icons.savings_outlined,
                tintColor: roles.statAmber,
              ),
              KubusWalletMetaPill(
                label: '${_estimatedGas.toStringAsFixed(6)} SOL',
                icon: Icons.bolt_outlined,
                tintColor: roles.warningAction,
              ),
              if (_addressController.text.trim().isNotEmpty)
                KubusWalletMetaPill(
                  label: _shortAddress(_addressController.text.trim()),
                  icon: Icons.person_pin_circle_outlined,
                  tintColor: roles.statBlue,
                ),
            ],
          ),
        ),
        const SizedBox(height: KubusSpacing.lg),
        KubusWalletSectionCard(
          title: l10n.walletSecurityStatusTitle,
          subtitle: l10n.sendTokenSidebarSecuritySubtitle,
          child: WalletCustodyStatusPanel(
            authority: walletProvider.authority,
            compact: true,
            onRestoreSigner:
                walletProvider.authority.canRestoreFromEncryptedBackup
                    ? () => WalletActionGuard.ensureSignerAccess(
                          context: context,
                          profileProvider: context.read<ProfileProvider>(),
                          walletProvider: walletProvider,
                        )
                    : null,
            onConnectExternalWallet: !walletProvider.canTransact
                ? () => Navigator.of(context).pushNamed('/connect-wallet')
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildTokenSelector() {
    final l10n = AppLocalizations.of(context)!;
    return Consumer<WalletProvider>(
      builder: (context, walletProvider, child) {
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
              _estimateGasFee();
            });
          });
        }

        final theme = Theme.of(context);
        final accent = KubusColorRoles.of(context).negativeAction;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.sendTokenSelectTokenTitle,
              style: KubusTypography.inter(
                fontSize: KubusHeaderMetrics.sectionTitle,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: KubusSpacing.md),
            Wrap(
              spacing: KubusSpacing.md,
              runSpacing: KubusSpacing.md,
              children: tokens.map((token) {
                final isSelected = token.symbol == _selectedToken;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedToken = token.symbol;
                      _estimateGasFee();
                      _validateAmount(_amountController.text);
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: KubusSpacing.md,
                      vertical: KubusSpacing.sm + KubusSpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? accent.withValues(alpha: 0.15)
                          : theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(KubusRadius.md),
                      border: Border.all(
                        color: isSelected ? accent : theme.colorScheme.outline,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildTokenAvatar(token, isSelected: isSelected),
                        const SizedBox(
                            width: KubusSpacing.sm + KubusSpacing.xxs),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              token.symbol,
                              style: KubusTypography.inter(
                                fontSize: KubusHeaderMetrics.sectionSubtitle,
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
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAddressInput() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final roles = KubusColorRoles.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.sendTokenRecipientAddressTitle,
          style: KubusTypography.inter(
            fontSize: KubusHeaderMetrics.sectionTitle,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: KubusSpacing.md),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(KubusRadius.md),
            border: Border.all(
              color: _addressError.isNotEmpty
                  ? theme.colorScheme.error
                  : theme.colorScheme.outline.withValues(alpha: 0.18),
            ),
          ),
          child: TextField(
            controller: _addressController,
            style: KubusTypography.inter(color: theme.colorScheme.onSurface),
            onChanged: _validateAddress,
            decoration: InputDecoration(
              hintText: l10n.sendTokenRecipientAddressHint,
              hintStyle: KubusTypography.inter(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(KubusSpacing.md),
              suffixIcon: Consumer<PlatformProvider>(
                builder: (context, platformProvider, child) {
                  return IconButton(
                    icon: Icon(
                      platformProvider.getQRScannerIcon(),
                      color: platformProvider.supportsQRScanning
                          ? roles.statBlue
                          : platformProvider
                              .getUnsupportedFeatureColor(context),
                    ),
                    onPressed: platformProvider.supportsQRScanning
                        ? _scanQRCode
                        : () =>
                            _showUnsupportedFeature(context, platformProvider),
                    tooltip: platformProvider.supportsQRScanning
                        ? l10n.sendTokenScanQrTooltip
                        : l10n.sendTokenQrScannerUnavailableTooltip,
                  );
                },
              ),
            ),
          ),
        ),
        if (_addressError.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            _addressError,
            style: KubusTypography.inter(
              fontSize: 12,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAmountInput() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final roles = KubusColorRoles.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.sendTokenAmountTitle,
              style: KubusTypography.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            GestureDetector(
              onTap: _setMaxAmount,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: roles.negativeAction.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: roles.negativeAction.withValues(alpha: 0.28),
                  ),
                ),
                child: Text(
                  l10n.sendTokenMaxButton,
                  style: KubusTypography.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: roles.negativeAction,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(KubusRadius.md),
            border: Border.all(
              color: _amountError.isNotEmpty
                  ? theme.colorScheme.error
                  : theme.colorScheme.outline.withValues(alpha: 0.18),
            ),
          ),
          child: TextField(
            controller: _amountController,
            style: KubusTypography.inter(
                color: theme.colorScheme.onSurface, fontSize: 18),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: _validateAmount,
            decoration: InputDecoration(
              hintText: l10n.sendTokenAmountPlaceholder,
              hintStyle: KubusTypography.inter(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 18),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(KubusSpacing.md),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    _selectedToken,
                    style: KubusTypography.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: roles.negativeAction,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_amountError.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            _amountError,
            style: KubusTypography.inter(
              fontSize: 12,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          l10n.sendTokenAvailableLabel(
              _getTokenBalance(_selectedToken), _selectedToken),
          style: KubusTypography.inter(
            fontSize: 14,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionSummary() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final usdValue = _calculateUSDValue(amount);
    final projectFee = amount > 0 ? _calculateProjectFee(amount) : 0.0;
    final totalTokenDebit = amount + projectFee;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.sendTokenTransactionSummaryTitle,
          style: KubusTypography.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: KubusSpacing.md),
        _buildSummaryRow(
          l10n.sendTokenSummaryAmountLabel,
          '${amount.toStringAsFixed(4)} $_selectedToken',
        ),
        if (projectFee > 0) ...[
          const SizedBox(height: KubusSpacing.sm),
          _buildSummaryRow(
            l10n.sendTokenSummaryFeesLabel(
                _projectFeePercent.toStringAsFixed(1)),
            '${projectFee.toStringAsFixed(4)} $_selectedToken',
          ),
        ],
        const SizedBox(height: KubusSpacing.sm),
        _buildSummaryRow(
          l10n.sendTokenSummaryEstimatedDebitLabel,
          '${totalTokenDebit.toStringAsFixed(4)} $_selectedToken',
          isTotal: true,
        ),
        const SizedBox(height: KubusSpacing.md),
        Divider(color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
        const SizedBox(height: KubusSpacing.md),
        _buildSummaryRow(
          l10n.sendTokenSummaryUsdValueLabel,
          '\$${usdValue.toStringAsFixed(2)}',
        ),
        const SizedBox(height: KubusSpacing.sm),
        _buildSummaryRow(
          l10n.sendTokenSummaryNetworkFeeLabel,
          '${_estimatedGas.toStringAsFixed(6)} SOL',
        ),
        const SizedBox(height: KubusSpacing.sm),
        Text(
          l10n.sendTokenNetworkFeeNote,
          style: KubusTypography.inter(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: KubusTypography.inter(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        Text(
          value,
          style: KubusTypography.inter(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
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
          const SizedBox(width: KubusSpacing.md),
          Expanded(
            child: Text(
              l10n.sendTokenNoTokensMessage,
              style: KubusTypography.inter(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
            ),
          ),
        ],
      ),
    );
  }

  bool _tokenExists(List<Token> tokens, String symbol) {
    return tokens.any((token) => token.symbol == symbol);
  }

  Widget _buildTokenAvatar(Token token, {bool isSelected = false}) {
    final theme = Theme.of(context);
    final accent = KubusColorRoles.of(context).negativeAction;
    final background = isSelected
        ? accent.withValues(alpha: 0.25)
        : theme.colorScheme.surfaceContainerHighest;

    if (token.logoUrl != null && token.logoUrl!.isNotEmpty) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(KubusRadius.lg),
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
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(KubusRadius.lg),
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

  Widget _buildSendButton() {
    return Consumer<WalletProvider>(
      builder: (context, walletProvider, _) {
        final l10n = AppLocalizations.of(context)!;
        final isValid = _addressController.text.isNotEmpty &&
            _amountController.text.isNotEmpty &&
            _addressError.isEmpty &&
            _amountError.isEmpty &&
            walletProvider.canTransact;

        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isValid && !_isLoading ? _sendTransaction : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: KubusColorRoles.of(context).negativeAction,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(KubusRadius.md),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: InlineLoading(
                      shape: BoxShape.circle,
                      tileSize: 4.0,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  )
                : Text(
                    l10n.sendTokenButtonLabel(_selectedToken),
                    style: KubusTypography.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
          ),
        );
      },
    );
  }

  void _validateAddress(String value) {
    final trimmed = value.trim();
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      if (trimmed.isEmpty) {
        _addressError = l10n.sendTokenAddressRequiredError;
      } else if (!_isValidSolanaAddress(trimmed)) {
        _addressError = l10n.sendTokenAddressInvalidError;
      } else {
        _addressError = '';
      }
    });
  }

  void _validateAmount(String value) {
    final l10n = AppLocalizations.of(context)!;
    final amount = double.tryParse(value);
    final balance =
        double.tryParse(_getTokenBalance(_selectedToken).replaceAll(',', '')) ??
            0.0;

    setState(() {
      if (value.isEmpty) {
        _amountError = l10n.sendTokenAmountRequiredError;
      } else if (amount == null || amount <= 0) {
        _amountError = l10n.sendTokenAmountGreaterThanZeroError;
      } else if (amount > balance) {
        _amountError = l10n.sendTokenInsufficientBalanceError;
      } else {
        _amountError = '';
      }
      _estimateGasFee();
    });
  }

  void _setMaxAmount() {
    final l10n = AppLocalizations.of(context)!;
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final token = walletProvider.getTokenBySymbol(_selectedToken);
    final balance = token?.balance ??
        double.tryParse(_getTokenBalance(_selectedToken)) ??
        0.0;
    if (balance <= 0) {
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(
          content: Text(l10n.sendTokenNoBalanceToast),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final feeMultiplier =
        1 + (ApiKeys.kubusTeamFeePct + ApiKeys.kubusTreasuryFeePct);
    final maxSendable = balance / feeMultiplier;
    if (maxSendable <= 0) {
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(
          content: Text(l10n.sendTokenMaxAmountComputeFailedToast),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final decimals = token?.decimals ?? 3;
    final displayPrecision = decimals < 2 ? 2 : (decimals > 6 ? 6 : decimals);
    _amountController.text = maxSendable.toStringAsFixed(displayPrecision);
    _validateAmount(_amountController.text);
  }

  String _getTokenBalance(String token) {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    switch (token) {
      case 'KUB8':
        final kub8Tokens = walletProvider.tokens
            .where((t) => t.symbol.toUpperCase() == 'KUB8');
        return kub8Tokens.isNotEmpty
            ? kub8Tokens.first.balance.toStringAsFixed(2)
            : '0.00';
      case 'SOL':
        final solTokens =
            walletProvider.tokens.where((t) => t.symbol.toUpperCase() == 'SOL');
        return solTokens.isNotEmpty
            ? solTokens.first.balance.toStringAsFixed(3)
            : '0.000';
      default:
        return '0.00';
    }
  }

  double get _projectFeePercent =>
      (ApiKeys.kubusTeamFeePct + ApiKeys.kubusTreasuryFeePct) * 100;

  double _calculateProjectFee(double amount) {
    final totalFeeFraction =
        ApiKeys.kubusTeamFeePct + ApiKeys.kubusTreasuryFeePct;
    return amount * totalFeeFraction;
  }

  double _calculateUSDValue(double amount) {
    final rate =
        {'KUB8': 0.20, 'SOL': 150.0, 'USDC': 1.0}[_selectedToken] ?? 0.0;
    return amount * rate;
  }

  bool _isValidSolanaAddress(String value) {
    try {
      Ed25519HDPublicKey.fromBase58(value);
      return true;
    } catch (_) {
      return false;
    }
  }

  String _mapSendError(AppLocalizations l10n, Object error) {
    if (kDebugMode) {
      debugPrint('SendTokenScreen: send error: $error');
    }

    final message = error.toString();
    if (message.contains('Insufficient balance')) {
      return l10n.sendTokenInsufficientAfterFeesToast;
    }
    if (message.contains('keypair')) {
      return l10n.sendTokenNoKeypairToast;
    }
    if (message.contains('valid Solana address')) {
      return l10n.sendTokenInvalidAddressBeforeSendToast;
    }
    if (message.contains('Connect wallet')) {
      return l10n.sendTokenConnectWalletBeforeSendToast;
    }
    return l10n.sendTokenSendFailedToast;
  }

  void _estimateGasFee() {
    // Estimate gas fees for different tokens
    final fees = {
      'KUB8': 0.001, // SOL fee for SPL token
      'SOL': 0.000005, // Base SOL fee
      'USDC': 0.001, // SOL fee for SPL token
    };

    setState(() {
      _estimatedGas = fees[_selectedToken] ?? 0.001;
    });
  }

  void _showUnsupportedFeature(
      BuildContext context, PlatformProvider platformProvider) {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showKubusSnackBar(
      SnackBar(
        content: Text(_qrScannerUnsupportedMessage(l10n, platformProvider)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.tertiary,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _qrScannerUnsupportedMessage(
      AppLocalizations l10n, PlatformProvider platformProvider) {
    if (platformProvider.isWeb) return l10n.sendTokenQrScannerUnsupportedWeb;
    if (platformProvider.isDesktop) {
      return l10n.sendTokenQrScannerUnsupportedDesktop;
    }
    return l10n.sendTokenQrScannerUnsupportedPlatform;
  }

  String _formatScannedAmount(double amount) {
    final formatted =
        amount >= 1 ? amount.toStringAsFixed(4) : amount.toStringAsFixed(8);
    final trimmed = formatted
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    return trimmed.isEmpty ? '0' : trimmed;
  }

  String _shortAddress(String address) {
    if (address.length <= 14) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 6)}';
  }

  String _formatSidebarTime(DateTime timestamp) {
    final localizations = MaterialLocalizations.of(context);
    return localizations.formatShortDate(timestamp.toLocal());
  }

  List<_RecentRecipientEntry> _recentRecipients(WalletProvider walletProvider) {
    final sendTransactions = List<WalletTransaction>.from(
      walletProvider.getTransactionsByType(TransactionType.send),
    )..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final seenAddresses = <String>{};
    final recipients = <_RecentRecipientEntry>[];

    for (final transaction in sendTransactions) {
      if (transaction.metadata['isFeeTransfer'] == true) {
        continue;
      }
      final address =
          (transaction.toAddress ?? transaction.primaryCounterparty ?? '')
              .trim();
      if (address.isEmpty || !seenAddresses.add(address)) {
        continue;
      }
      recipients.add(
        _RecentRecipientEntry(
          address: address,
          token: transaction.token,
          amount: transaction.amount,
          timestamp: transaction.timestamp,
        ),
      );
      if (recipients.length >= 4) {
        break;
      }
    }

    return recipients;
  }

  void _applyRecentRecipient(
    WalletProvider walletProvider,
    _RecentRecipientEntry recipient,
  ) {
    setState(() {
      _addressController.text = recipient.address;
      if (walletProvider.getTokenBySymbol(recipient.token) != null) {
        _selectedToken = recipient.token;
      }
    });
    _validateAddress(recipient.address);
    _validateAmount(_amountController.text);
    _estimateGasFee();
  }

  void _scanQRCode() async {
    final l10n = AppLocalizations.of(context)!;
    final platformProvider =
        Provider.of<PlatformProvider>(context, listen: false);
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);

    // Check if platform supports QR scanning
    if (!platformProvider.supportsQRScanning) {
      _showUnsupportedFeature(context, platformProvider);
      return;
    }

    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const QRScannerScreen(),
        ),
      );
      if (!mounted) return;
      if (result == null) return;

      QRScanResult? structured;
      String? fallbackAddress;

      if (result is QRScanResult) {
        structured = result;
      } else if (result is String && result.trim().isNotEmpty) {
        fallbackAddress = result.trim();
        structured = QRScanResult.tryParse(fallbackAddress);
      } else {
        ScaffoldMessenger.of(context).showKubusSnackBar(
          SnackBar(
            content: Text(l10n.sendTokenQrUnreadableToast),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }

      final address = structured?.address ?? fallbackAddress;
      if (address == null || address.isEmpty) {
        ScaffoldMessenger.of(context).showKubusSnackBar(
          SnackBar(
            content: Text(l10n.sendTokenQrInvalidAddressToast),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }

      final Token? detectedToken = structured?.tokenMint != null
          ? walletProvider.getTokenByMint(structured!.tokenMint!)
          : null;
      final bool hasAmount = structured?.hasAmount ?? false;
      final String? amountText =
          hasAmount ? _formatScannedAmount(structured!.amount!) : null;

      setState(() {
        _addressController.text = address;
        if (detectedToken != null) {
          _selectedToken = detectedToken.symbol;
        }
        if (amountText != null) {
          _amountController.text = amountText;
        }
      });

      _validateAddress(address);
      if (amountText != null) {
        _validateAmount(amountText);
      }
      _estimateGasFee();

      final snackSegments = <String>[l10n.sendTokenQrScannedAddressLabel];
      if (detectedToken != null) {
        snackSegments
            .add(l10n.sendTokenQrScannedTokenLabel(detectedToken.symbol));
      }
      if (amountText != null) {
        snackSegments.add(l10n.sendTokenQrScannedAmountLabel(amountText));
      }

      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(
          content: Text(snackSegments.join(' • ')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.tertiary,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SendTokenScreen: QR scan error: $e');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(
          content: Text(l10n.sendTokenQrScanErrorToast),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _sendTransaction() async {
    final l10n = AppLocalizations.of(context)!;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final walletProvider =
          Provider.of<WalletProvider>(context, listen: false);
      final profileProvider =
          Provider.of<ProfileProvider>(context, listen: false);
      final canProceed = await WalletActionGuard.ensureSignerAccess(
        context: context,
        profileProvider: profileProvider,
        walletProvider: walletProvider,
      );
      if (!mounted || !canProceed) {
        return;
      }
      final amount = double.tryParse(_amountController.text.trim()) ?? 0;
      final toAddress = _addressController.text.trim();

      if (amount <= 0) {
        throw Exception('invalid_amount');
      }
      if (!_isValidSolanaAddress(toAddress)) {
        throw Exception('invalid_address');
      }

      final result = await walletProvider.sendTransaction(
        token: _selectedToken,
        amount: amount,
        toAddress: toAddress,
      );

      await walletProvider.refreshData();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(
          content: Text(
            l10n.sendTokenSendSuccessWithSignatureToast(
              amount.toStringAsFixed(4),
              _selectedToken,
              result.primarySignature,
            ),
          ),
          backgroundColor: Theme.of(context).colorScheme.tertiary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(
          content: Text(_mapSendError(l10n, e)),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

class _SendOverviewPill extends StatelessWidget {
  const _SendOverviewPill({
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

class _RecentRecipientEntry {
  const _RecentRecipientEntry({
    required this.address,
    required this.token,
    required this.amount,
    required this.timestamp,
  });

  final String address;
  final String token;
  final double amount;
  final DateTime timestamp;
}
