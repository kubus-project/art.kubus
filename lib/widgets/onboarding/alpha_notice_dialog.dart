import 'dart:async';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/utils/support_links.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:art_kubus/widgets/kubus_button.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AlphaNoticeDialog extends StatefulWidget {
  const AlphaNoticeDialog({
    super.key,
    required this.onContinue,
  });

  static const String websiteUrl = 'https://art.kubus.site';

  final Future<void> Function() onContinue;

  @override
  State<AlphaNoticeDialog> createState() => _AlphaNoticeDialogState();
}

class _AlphaNoticeDialogState extends State<AlphaNoticeDialog> {
  bool _continuing = false;
  bool _openingWebsite = false;

  Future<void> _continue() async {
    if (_continuing || _openingWebsite) return;
    setState(() => _continuing = true);
    try {
      await widget.onContinue();
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() => _continuing = false);
      }
    }
  }

  Future<void> _openWebsite() async {
    if (_continuing || _openingWebsite) return;
    setState(() => _openingWebsite = true);
    try {
      final uri = Uri.parse(AlphaNoticeDialog.websiteUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: SupportLinks.preferredLaunchMode);
      }
    } finally {
      if (mounted) {
        setState(() => _openingWebsite = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      child: KubusAlertDialog(
        semanticLabel: l10n.alphaNoticeTitle,
        icon: CircleAvatar(
          radius: 22,
          backgroundColor: scheme.primary.withValues(alpha: 0.14),
          child: Icon(
            Icons.travel_explore_rounded,
            color: scheme.primary,
          ),
        ),
        title: Text(l10n.alphaNoticeTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.alphaNoticeBody,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.86),
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: KubusSpacing.lg),
            KubusButton(
              onPressed: _continuing ? null : () => unawaited(_continue()),
              label: l10n.alphaNoticeContinue,
              icon: Icons.arrow_forward_rounded,
              isLoading: _continuing,
              isFullWidth: true,
            ),
            const SizedBox(height: KubusSpacing.sm),
            KubusOutlineButton(
              onPressed:
                  _openingWebsite ? null : () => unawaited(_openWebsite()),
              label: l10n.alphaNoticeBackToWebsite,
              icon: Icons.open_in_new_rounded,
              isLoading: _openingWebsite,
              isFullWidth: true,
            ),
          ],
        ),
      ),
    );
  }
}
