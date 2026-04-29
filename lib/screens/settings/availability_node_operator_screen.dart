import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/availability_operator_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/wallet_provider.dart';
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
  final TextEditingController _labelController =
      TextEditingController(text: 'Home server node');
  int _expiresInDays = 90;
  String? _loadedWallet;

  _AvailabilityNodeCopy get copy =>
      _AvailabilityNodeCopy.forLocale(Localizations.localeOf(context));

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
    final strings = copy;
    if (wallet.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(strings.connectWallet)));
      return;
    }

    final walletProvider = context.read<WalletProvider>();
    final signed = await walletProvider.ensureBackendSessionForActiveSigner(
      walletAddress: wallet,
    );
    if (!mounted) return;
    if (!signed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.signingRequired)),
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
            title: Text(strings.createdTitle),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(strings.createdBody),
                    const SizedBox(height: KubusSpacing.md),
                    _CodeBlock(text: created.token),
                    const SizedBox(height: KubusSpacing.md),
                    Text(strings.envSnippet),
                    const SizedBox(height: KubusSpacing.sm),
                    _CodeBlock(text: snippet),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton.icon(
                onPressed: () => unawaited(
                  _copyText(created.token, strings.tokenCopied),
                ),
                icon: const Icon(Icons.copy),
                label: Text(strings.copyToken),
              ),
              FilledButton.icon(
                onPressed: () {
                  unawaited(_copyText(snippet, strings.snippetCopied));
                  Navigator.of(dialogContext).pop();
                },
                icon: const Icon(Icons.content_paste),
                label: Text(strings.copySnippet),
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
        SnackBar(content: Text('${strings.createFailed}: $e')),
      );
    }
  }

  Future<void> _revokeToken(AvailabilityOperatorTokenRecord token) async {
    final wallet = _resolveWallet();
    final strings = copy;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.revokeTitle),
        content: Text(strings.revokeBody(token.label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.revoke),
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
    final strings = copy;
    final wallet = _resolveWallet(listen: true);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(strings.title)),
      body: Consumer<AvailabilityOperatorProvider>(
        builder: (context, provider, _) {
          return ListView(
            padding: const EdgeInsets.all(KubusSpacing.lg),
            children: [
              _InfoPanel(wallet: wallet, copy: strings),
              const SizedBox(height: KubusSpacing.lg),
              GlassSurface(
                child: Padding(
                  padding: const EdgeInsets.all(KubusSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(strings.createTitle,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: KubusSpacing.sm),
                      TextField(
                        controller: _labelController,
                        decoration: InputDecoration(labelText: strings.label),
                      ),
                      const SizedBox(height: KubusSpacing.sm),
                      DropdownButtonFormField<int>(
                        initialValue: _expiresInDays,
                        decoration: InputDecoration(labelText: strings.expiry),
                        items: const [30, 90, 180, 365]
                            .map((days) => DropdownMenuItem<int>(
                                  value: days,
                                  child: Text('$days days'),
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
                        label: Text(strings.createButton),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: KubusSpacing.lg),
              Text(strings.existingTokens,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: KubusSpacing.sm),
              if (provider.tokens.isEmpty)
                Text(
                  strings.empty,
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
                        '${token.tokenPrefix} - ${token.status} - ${strings.expires}: ${_formatDate(token.expiresAt)}',
                      ),
                      trailing: token.status == 'active'
                          ? IconButton(
                              tooltip: strings.revoke,
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
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.wallet, required this.copy});

  final String wallet;
  final _AvailabilityNodeCopy copy;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      child: Padding(
        padding: const EdgeInsets.all(KubusSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(copy.whatIsNode,
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: KubusSpacing.sm),
            Text(copy.description),
            const SizedBox(height: KubusSpacing.md),
            Text('${copy.operatorWallet}: ${wallet.isEmpty ? '-' : wallet}'),
            const SizedBox(height: KubusSpacing.sm),
            Text(copy.securityNote),
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

class _AvailabilityNodeCopy {
  const _AvailabilityNodeCopy({
    required this.title,
    required this.whatIsNode,
    required this.description,
    required this.operatorWallet,
    required this.securityNote,
    required this.createTitle,
    required this.label,
    required this.expiry,
    required this.createButton,
    required this.createdTitle,
    required this.createdBody,
    required this.envSnippet,
    required this.copyToken,
    required this.copySnippet,
    required this.tokenCopied,
    required this.snippetCopied,
    required this.existingTokens,
    required this.empty,
    required this.expires,
    required this.revoke,
    required this.revokeTitle,
    required this.cancel,
    required this.connectWallet,
    required this.signingRequired,
    required this.createFailed,
  });

  final String title;
  final String whatIsNode;
  final String description;
  final String operatorWallet;
  final String securityNote;
  final String createTitle;
  final String label;
  final String expiry;
  final String createButton;
  final String createdTitle;
  final String createdBody;
  final String envSnippet;
  final String copyToken;
  final String copySnippet;
  final String tokenCopied;
  final String snippetCopied;
  final String existingTokens;
  final String empty;
  final String expires;
  final String revoke;
  final String revokeTitle;
  final String cancel;
  final String connectWallet;
  final String signingRequired;
  final String createFailed;

  String revokeBody(String label) =>
      'Revoke ${label.isEmpty ? 'this token' : label}? The node using it will stop authenticating.';

  static _AvailabilityNodeCopy forLocale(Locale locale) {
    if (locale.languageCode == 'sl') {
      return const _AvailabilityNodeCopy(
        title: 'Availability Node',
        whatIsNode: 'Kubus Availability Node',
        description:
            'Vozlisce hrani kanonicne javne CID-e, posilja heartbeat in oddaja commitment zapise. Ne upravlja tvoje denarnice in ne more porabiti sredstev.',
        operatorWallet: 'Operatorska denarnica',
        securityNote:
            'Token shrani kot geslo. Prikazan je samo enkrat in ga lahko kadarkoli preklices.',
        createTitle: 'Ustvari operatorski token',
        label: 'Oznaka',
        expiry: 'Veljavnost',
        createButton: 'Ustvari token',
        createdTitle: 'Token je ustvarjen',
        createdBody:
            'Kopiraj ga zdaj. Po zaprtju tega okna celoten token ne bo vec prikazan.',
        envSnippet: '.env izsek za kubus-node',
        copyToken: 'Kopiraj token',
        copySnippet: 'Kopiraj .env',
        tokenCopied: 'Token je kopiran',
        snippetCopied: '.env izsek je kopiran',
        existingTokens: 'Obstojeci tokeni',
        empty: 'Za to denarnico ni operatorskih tokenov.',
        expires: 'potece',
        revoke: 'Preklici',
        revokeTitle: 'Preklici token',
        cancel: 'Preklic',
        connectWallet: 'Najprej povezi denarnico.',
        signingRequired:
            'Za ustvarjanje operatorskega tokena je potreben podpis denarnice.',
        createFailed: 'Tokena ni bilo mogoce ustvariti',
      );
    }
    return const _AvailabilityNodeCopy(
      title: 'Availability Node',
      whatIsNode: 'Kubus Availability Node',
      description:
          'A node stores canonical public CIDs, sends heartbeats, and submits commitments. It does not control your wallet or spend funds.',
      operatorWallet: 'Operator wallet',
      securityNote:
          'Store this token like a password. It is shown once and can be revoked at any time.',
      createTitle: 'Create operator token',
      label: 'Label',
      expiry: 'Expiry',
      createButton: 'Create token',
      createdTitle: 'Token created',
      createdBody:
          'Copy it now. The full token will not be shown again after this dialog closes.',
      envSnippet: '.env snippet for kubus-node',
      copyToken: 'Copy token',
      copySnippet: 'Copy .env',
      tokenCopied: 'Token copied',
      snippetCopied: '.env snippet copied',
      existingTokens: 'Existing tokens',
      empty: 'No operator tokens for this wallet yet.',
      expires: 'expires',
      revoke: 'Revoke',
      revokeTitle: 'Revoke token',
      cancel: 'Cancel',
      connectWallet: 'Connect a wallet first.',
      signingRequired:
          'Wallet-signed authority is required to create an operator token.',
      createFailed: 'Failed to create token',
    );
  }
}
