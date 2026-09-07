import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/kubus_node_provider.dart';
import '../../widgets/kubus_kit.dart';
import '../../widgets/node/node_ui.dart';

/// Authorizes a freshly installed kubus Node against the signed-in account.
///
/// The Node's own setup page shows a short code; entering it here is what turns
/// "some machine claims to be a Node" into "this account authorized this
/// Node". Nothing is granted until the explicit confirmation on this screen, so
/// the person always sees the Node's fingerprint and what the credential covers
/// before deciding.
class AddNodeScreen extends StatefulWidget {
  const AddNodeScreen({super.key});

  static Future<bool?> show(BuildContext context) =>
      Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const AddNodeScreen()),
      );

  @override
  State<AddNodeScreen> createState() => _AddNodeScreenState();
}

class _AddNodeScreenState extends State<AddNodeScreen> {
  final TextEditingController _code = TextEditingController();
  Map<String, dynamic>? _installation;
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _lookup(AppLocalizations l10n) => _run(() async {
        final provider = context.read<KubusNodeProvider>();
        try {
          final found = await provider.lookupInstallation(_code.text);
          if (!mounted) return;
          setState(() => _installation = found);
        } catch (_) {
          if (!mounted) return;
          setState(() {
            _installation = null;
            _message = l10n.kubusAddNodeNotFound;
          });
        }
      });

  Future<void> _decide(AppLocalizations l10n, {required bool authorize}) =>
      _run(() async {
        final provider = context.read<KubusNodeProvider>();
        final id = (_installation?['installationId'] ?? '').toString();
        if (id.isEmpty) return;
        try {
          if (authorize) {
            await provider.authorizeInstallation(id);
          } else {
            await provider.declineInstallation(id);
          }
          if (!mounted) return;
          setState(() {
            _installation = null;
            _message = authorize
                ? l10n.kubusAddNodeAuthorized
                : l10n.kubusAddNodeDeclined;
          });
          if (authorize) unawaitedRefresh(provider);
        } catch (_) {
          if (!mounted) return;
          setState(() => _message = l10n.kubusAddNodeFailed);
        }
      });

  /// A newly authorized Node registers itself moments later; refreshing here
  /// means My Nodes is already correct when the person navigates back.
  void unawaitedRefresh(KubusNodeProvider provider) {
    provider.loadOwnedNodes();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final installation = _installation;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(l10n.kubusAddNodeTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(KubusSpacing.lg),
            children: [
              NodePanel(child: Text(l10n.kubusAddNodeIntro)),
              const SizedBox(height: KubusSpacing.md),
              TextField(
                controller: _code,
                enabled: !_busy && installation == null,
                textCapitalization: TextCapitalization.characters,
                maxLength: 8,
                inputFormatters: [
                  UpperCaseTextFormatter(),
                  FilteringTextInputFormatter.allow(RegExp('[0-9A-HJ-NP-TV-Z]')),
                ],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l10n.kubusAddNodeCodeLabel,
                ),
              ),
              const SizedBox(height: KubusSpacing.md),
              if (installation == null)
                KubusButton(
                  label: l10n.kubusAddNodeLookup,
                  onPressed: _busy || _code.text.trim().length != 8
                      ? null
                      : () => _lookup(l10n),
                )
              else
                NodePanel(
                  title: l10n.kubusAddNodeReview,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text((installation['label'] ?? '').toString().isEmpty
                          ? l10n.kubusNodeEntryTitle
                          : installation['label'].toString()),
                      const SizedBox(height: KubusSpacing.sm),
                      Text(
                        '${l10n.kubusAddNodeFingerprint}: '
                        '${(installation['fingerprint'] ?? '').toString().substring(0, 16)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: KubusSpacing.md),
                      Text(l10n.kubusAddNodeGrants),
                      const SizedBox(height: KubusSpacing.md),
                      KubusButton(
                        label: l10n.kubusAddNodeAuthorize,
                        onPressed:
                            _busy ? null : () => _decide(l10n, authorize: true),
                      ),
                      const SizedBox(height: KubusSpacing.sm),
                      KubusOutlineButton(
                        label: l10n.kubusAddNodeDecline,
                        onPressed: _busy
                            ? null
                            : () => _decide(l10n, authorize: false),
                      ),
                    ],
                  ),
                ),
              if (_busy) ...[
                const SizedBox(height: KubusSpacing.md),
                const Center(child: InlineLoading(width: 40, height: 40)),
              ],
              if (_message != null) ...[
                const SizedBox(height: KubusSpacing.md),
                NodePanel(child: Text(_message!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Setup codes are displayed uppercase; accepting lowercase silently would make
/// a correctly-read code look wrong.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
