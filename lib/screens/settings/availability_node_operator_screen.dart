import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/availability_operator_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/app_color_utils.dart';
import '../../utils/design_tokens.dart';
import '../../widgets/glass_components.dart';

class AvailabilityNodeOperatorScreen extends StatelessWidget {
  const AvailabilityNodeOperatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AvailabilityOperatorProvider>(
      create: (_) => AvailabilityOperatorProvider(),
      child: const _AvailabilityNodeOperatorBody(),
    );
  }
}

class _AvailabilityNodeOperatorBody extends StatefulWidget {
  const _AvailabilityNodeOperatorBody();

  @override
  State<_AvailabilityNodeOperatorBody> createState() =>
      _AvailabilityNodeOperatorBodyState();
}

class _AvailabilityNodeOperatorBodyState
    extends State<_AvailabilityNodeOperatorBody> {
  final TextEditingController _labelController = TextEditingController();
  int _expiresInDays = 90;
  String? _loadedWallet;
  bool _initializedDefaultLabel = false;

  AppLocalizations get l10n => AppLocalizations.of(context)!;

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedDefaultLabel && _labelController.text.trim().isEmpty) {
      _labelController.text = l10n.availabilityNodeDefaultLabel;
      _labelController.selection = TextSelection.collapsed(
        offset: _labelController.text.length,
      );
      _initializedDefaultLabel = true;
    }
    final wallet = _resolveWallet(listen: true);
    if (wallet.isNotEmpty && wallet != _loadedWallet) {
      _loadedWallet = wallet;
      unawaited(
        context
            .read<AvailabilityOperatorProvider>()
            .loadTokens(walletAddress: wallet)
            .catchError((_) {}),
      );
    }
  }

  String _resolveWallet({bool listen = false}) {
    final walletProvider = Provider.of<WalletProvider>(
      context,
      listen: listen,
    );
    final profileProvider = Provider.of<ProfileProvider>(
      context,
      listen: listen,
    );
    return (walletProvider.currentWalletAddress ??
            profileProvider.currentUser?.walletAddress ??
            '')
        .trim();
  }

  Future<void> _copyText(String value, String toast) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(toast)));
  }

  Future<void> _createToken() async {
    final wallet = _resolveWallet();
    if (wallet.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.availabilityNodeConnectWalletToast)));
      return;
    }

    final walletProvider = context.read<WalletProvider>();
    final signed = await walletProvider.ensureBackendSessionForActiveSigner(
      walletAddress: wallet,
    );
    if (!mounted) return;
    if (!signed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.availabilityNodeSigningRequiredToast)),
      );
      return;
    }

    try {
      final created = await context.read<AvailabilityOperatorProvider>().createToken(
            label: _labelController.text,
            walletAddress: wallet,
            expiresInDays: _expiresInDays,
          );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          final snippet = context
              .read<AvailabilityOperatorProvider>()
              .buildEnvSnippet(token: created.token, walletAddress: wallet);
          return AlertDialog(
            title: Text(l10n.availabilityNodeCreatedTitle),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.availabilityNodeCreatedBody),
                    const SizedBox(height: KubusSpacing.md),
                    _CodeBlock(text: created.token),
                    const SizedBox(height: KubusSpacing.md),
                    Text(
                      l10n.availabilityNodeEnvSnippetLabel,
                      style: Theme.of(dialogContext).textTheme.titleSmall,
                    ),
                    const SizedBox(height: KubusSpacing.md),
                    _CodeBlock(text: snippet),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton.icon(
                onPressed: () => unawaited(
                  _copyText(
                    created.token,
                    l10n.availabilityNodeTokenCopiedToast,
                  ),
                ),
                icon: const Icon(Icons.copy),
                label: Text(l10n.availabilityNodeCopyTokenButton),
              ),
              FilledButton.icon(
                onPressed: () {
                  unawaited(_copyText(
                    snippet,
                    l10n.availabilityNodeSnippetCopiedToast,
                  ));
                  Navigator.of(dialogContext).pop();
                },
                icon: const Icon(Icons.content_paste),
                label: Text(l10n.availabilityNodeCopySnippetButton),
              ),
            ],
          );
        },
      );
      if (!mounted) return;
      context.read<AvailabilityOperatorProvider>().clearCreatedToken();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.availabilityNodeCreateFailedToast}: $e')),
      );
    }
  }

  Future<void> _revokeToken(AvailabilityOperatorTokenRecord token) async {
    final wallet = _resolveWallet();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.availabilityNodeRevokeTitle),
        content: Text(l10n.availabilityNodeRevokeBody(token.label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<AvailabilityOperatorProvider>().revokeToken(
          tokenId: token.id,
          walletAddress: wallet,
        );
  }

  @override
  Widget build(BuildContext context) {
    final wallet = _resolveWallet(listen: true);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.availabilityNodeTitle)),
      body: Consumer<AvailabilityOperatorProvider>(
        builder: (context, provider, _) {
          return ListView(
            padding: const EdgeInsets.all(KubusSpacing.lg),
            children: [
              _InfoPanel(wallet: wallet),
              const SizedBox(height: KubusSpacing.lg),
              GlassSurface(
                child: Padding(
                  padding: const EdgeInsets.all(KubusSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.availabilityNodeCreateTitle,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: KubusSpacing.sm),
                      TextField(
                        controller: _labelController,
                        decoration: InputDecoration(labelText: l10n.availabilityNodeLabel),
                      ),
                      const SizedBox(height: KubusSpacing.sm),
                      DropdownButtonFormField<int>(
                        initialValue: _expiresInDays,
                        decoration: InputDecoration(labelText: l10n.availabilityNodeExpiry),
                        items: const [30, 90, 180, 365]
                            .map((days) => DropdownMenuItem<int>(
                                  value: days,
                                  child: Text(
                                    l10n.availabilityNodeExpiryDaysOption(days),
                                  ),
                                ))
                            .toList(growable: false),
                        onChanged: provider.isLoading
                            ? null
                            : (value) => setState(
                                  () => _expiresInDays = value ?? 90,
                                ),
                      ),
                      const SizedBox(height: KubusSpacing.md),
                      FilledButton.icon(
                        onPressed: provider.isLoading ? null : _createToken,
                        icon: provider.isLoading
                            ? const SizedBox.square(
                                dimension: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.vpn_key_outlined),
                        label: Text(l10n.commonCreate),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: KubusSpacing.lg),
              Text(l10n.availabilityNodeExistingTokensTitle,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: KubusSpacing.sm),
              if (provider.tokens.isEmpty)
                Text(
                  l10n.availabilityNodeEmptyState,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                )
              else
                ...provider.tokens.map(
                  (token) => Card(
                    child: ListTile(
                      leading: Icon(
                        token.status == 'active'
                            ? Icons.check_circle_outline
                            : Icons.block,
                        color: token.status == 'active'
                            ? AppColorUtils.greenAccent
                            : scheme.error,
                      ),
                      title: Text(token.label.isEmpty ? token.tokenPrefix : token.label),
                      subtitle: Text(
                        _buildTokenSubtitle(token),
                      ),
                      trailing: token.status == 'active'
                          ? IconButton(
                              tooltip: l10n.commonDelete,
                              onPressed: provider.isLoading
                                  ? null
                                  : () => unawaited(_revokeToken(token)),
                              icon: const Icon(Icons.delete_outline),
                            )
                          : null,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return date.toLocal().toIso8601String().split('.').first;
  }

  String _buildTokenSubtitle(AvailabilityOperatorTokenRecord token) {
    final parts = <String>[
      token.tokenPrefix,
      token.status,
      '${l10n.availabilityNodeExpiresLabel}: ${_formatDate(token.expiresAt)}',
    ];
    if (token.lastUsedAt != null) {
      parts.add(
        '${l10n.availabilityNodeLastUsedLabel}: ${_formatDate(token.lastUsedAt)}',
      );
    }
    return parts.join(' - ');
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.wallet});

  final String wallet;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GlassSurface(
      child: Padding(
        padding: const EdgeInsets.all(KubusSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.availabilityNodeWhatIsTitle,
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: KubusSpacing.sm),
            Text(l10n.availabilityNodeIntro),
            const SizedBox(height: KubusSpacing.md),
            Text('${l10n.availabilityNodeWalletLabel}: ${wallet.isEmpty ? '-' : wallet}'),
            const SizedBox(height: KubusSpacing.sm),
            Text(l10n.availabilityNodeSecurityNote),
            if (wallet.isEmpty) ...[
              const SizedBox(height: KubusSpacing.md),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pushNamed('/connect-wallet'),
                icon: const Icon(Icons.account_balance_wallet_outlined),
                label: Text(l10n.authConnectWalletButton),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(KubusSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(KubusRadius.md),
      ),
      child: SelectableText(
        text,
        style: const TextStyle(fontFamily: 'monospace'),
      ),
    );
  }
}
