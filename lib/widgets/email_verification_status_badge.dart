import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmailVerificationStatusBadge extends StatefulWidget {
  const EmailVerificationStatusBadge({
    super.key,
    this.dense = false,
    this.alignment = Alignment.center,
    this.topSpacing = 0,
  });

  final bool dense;
  final Alignment alignment;
  final double topSpacing;

  @override
  State<EmailVerificationStatusBadge> createState() =>
      _EmailVerificationStatusBadgeState();
}

class _EmailVerificationStatusBadgeState
    extends State<EmailVerificationStatusBadge> {
  bool _loaded = false;
  bool _shouldShow = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email =
          (prefs.getString(PreferenceKeys.secureAccountEmail) ?? '').trim();
      final verified =
          prefs.getBool(PreferenceKeys.secureAccountEmailVerifiedV1) ?? false;
      if (!mounted) return;
      setState(() {
        _loaded = true;
        _shouldShow = email.isNotEmpty && !verified;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loaded = true;
        _shouldShow = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || !_shouldShow) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final dense = widget.dense;

    Widget badge = Align(
      alignment: widget.alignment,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: dense ? KubusSpacing.sm : KubusSpacing.md,
          vertical:
              dense ? KubusSpacing.xs : KubusSpacing.xs + KubusSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: scheme.error.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(KubusRadius.xl),
          border: Border.all(color: scheme.error.withValues(alpha: 0.35)),
        ),
        child: Text(
          AppLocalizations.of(context)!.authEmailNotVerifiedBadge,
          style: KubusTextStyles.compactBadge.copyWith(
            fontSize: dense
                ? KubusChromeMetrics.navBadgeLabel + 2
                : KubusChromeMetrics.navMetaLabel,
            fontWeight: FontWeight.w700,
            color: scheme.error,
          ),
        ),
      ),
    );

    final top = widget.topSpacing;
    if (top <= 0) return badge;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: top),
        badge,
      ],
    );
  }
}
