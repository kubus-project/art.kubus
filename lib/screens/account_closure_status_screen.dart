import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/account_closure.dart';
import '../services/backend_api_service.dart';
import '../utils/design_tokens.dart';
import '../widgets/inline_loading.dart';

/// Public navigation, authenticated by the narrow receipt rather than a login.
class AccountClosureStatusScreen extends StatefulWidget {
  const AccountClosureStatusScreen({super.key});

  @override
  State<AccountClosureStatusScreen> createState() =>
      _AccountClosureStatusScreenState();
}

class _AccountClosureStatusScreenState
    extends State<AccountClosureStatusScreen> {
  final _input = TextEditingController();
  final _api = BackendApiService();
  AccountClosureReceipt? _receipt;
  AccountClosureStatus? _status;
  bool _busy = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final receipt = await _api.loadAccountClosureReceipt();
      if (!mounted) return;
      _receipt = receipt;
      if (receipt != null) {
        _status = await _api.getAccountClosureStatus(receipt);
      }
      if (!mounted) return;
      setState(() {
        _busy = false;
        _failed = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _failed = true;
          _status = null;
        });
      }
    }
  }

  Future<void> _import() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final receipt = AccountClosureReceipt.fromJson(
          Map<String, dynamic>.from(jsonDecode(_input.text.trim()) as Map));
      final status = await _api.getAccountClosureStatus(receipt);
      await _api.saveAccountClosureReceipt(receipt);
      if (!mounted) return;
      _input.clear();
      setState(() {
        _receipt = receipt;
        _status = status;
        _busy = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _failed = true;
          _status = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final stateText = switch (_status?.state) {
      AccountClosureState.received => l10n.accountClosureReceived,
      AccountClosureState.processing => l10n.accountClosureProcessing,
      AccountClosureState.reviewRequired => l10n.accountClosureReviewRequired,
      AccountClosureState.completedManaged =>
        l10n.accountClosureCompletedManaged,
      null => null,
    };
    return Scaffold(
      appBar: AppBar(title: Text(l10n.accountClosureStatusTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(KubusSpacing.lg),
            children: [
              if (_busy)
                const Center(child: InlineLoading(width: 48, height: 24)),
              if (stateText != null) ...[
                Text(stateText,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: KubusSpacing.md),
              ],
              Text(l10n.accountClosureLimitations),
              if (_status?.lawfulRetention == true) ...[
                const SizedBox(height: KubusSpacing.md),
                Text(l10n.accountClosureLawfulRetention),
              ],
              const SizedBox(height: KubusSpacing.lg),
              if (_failed)
                Text(l10n.accountClosureStatusUnavailable,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              if (_receipt != null) ...[
                FilledButton.tonal(
                    onPressed: _busy
                        ? null
                        : () async {
                            await Clipboard.setData(
                                ClipboardData(text: _receipt!.encode()));
                          },
                    child: Text(l10n.accountClosureCopyReceipt)),
                Text(l10n.accountClosureReceiptPrivacy),
                TextButton(
                    onPressed: _busy
                        ? null
                        : () {
                            setState(() {
                              _busy = true;
                              _failed = false;
                            });
                            _load();
                          },
                    child: Text(l10n.accountClosureRefresh)),
              ],
              if (_receipt == null) Text(l10n.accountClosureReceiptPrivacy),
              ...[
                const SizedBox(height: KubusSpacing.md),
                TextField(
                    controller: _input,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                        labelText: l10n.accountClosurePasteReceipt)),
                FilledButton(
                    onPressed: _busy ? null : _import,
                    child: Text(l10n.accountClosureRefresh)),
              ],
              const SizedBox(height: KubusSpacing.lg),
              TextButton(
                  onPressed: () => Navigator.of(context)
                      .pushNamedAndRemoveUntil('/onboarding', (_) => false),
                  child: Text(l10n.accountClosureContinue)),
            ],
          ),
        ),
      ),
    );
  }
}
