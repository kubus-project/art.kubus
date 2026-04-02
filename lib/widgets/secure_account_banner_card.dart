import 'dart:convert';

import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/widgets/kubus_card.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureAccountBannerCard extends StatefulWidget {
  const SecureAccountBannerCard({
    super.key,
    this.padding = EdgeInsets.zero,
    this.bottomSpacing = 0,
  });

  final EdgeInsetsGeometry padding;
  final double bottomSpacing;

  @override
  State<SecureAccountBannerCard> createState() =>
      _SecureAccountBannerCardState();
}

class _SecureAccountBannerCardState extends State<SecureAccountBannerCard> {
  static const Duration _statusCacheTtl = Duration(hours: 6);

  bool _loaded = false;
  bool _shouldShow = false;
  bool _hasEmail = false;
  bool _hasPassword = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissed =
          prefs.getBool(PreferenceKeys.secureAccountPromptDismissedV1) ?? false;
      final storedEmail =
          (prefs.getString(PreferenceKeys.secureAccountEmail) ?? '').trim();
      var hasEmail = false;
      var hasPassword = false;
      var emailAuthEnabled = true;
      var loadedFromCache = false;

      final cachedRaw =
          (prefs.getString(PreferenceKeys.secureAccountStatusCacheV1) ?? '')
              .trim();
      final cachedTs =
          prefs.getInt(PreferenceKeys.secureAccountStatusCacheTsV1) ?? 0;
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      if (!forceRefresh && cachedRaw.isNotEmpty && cachedTs > 0) {
        final cacheAgeMs = nowMs - cachedTs;
        if (cacheAgeMs >= 0 && cacheAgeMs <= _statusCacheTtl.inMilliseconds) {
          try {
            final decoded = jsonDecode(cachedRaw);
            if (decoded is Map<String, dynamic>) {
              hasEmail = decoded['hasEmail'] == true;
              hasPassword = decoded['hasPassword'] == true;
              emailAuthEnabled = decoded['emailAuthEnabled'] != false;
              loadedFromCache = true;
            }
          } catch (_) {
            // Ignore malformed cache and continue with live fetch.
          }
        }
      }

      if (!loadedFromCache) {
        try {
          final status = await BackendApiService().getAccountSecurityStatus();
          hasEmail = status['hasEmail'] == true;
          hasPassword = status['hasPassword'] == true;
          emailAuthEnabled = status['emailAuthEnabled'] != false;

          await prefs.setString(
            PreferenceKeys.secureAccountStatusCacheV1,
            jsonEncode({
              'hasEmail': hasEmail,
              'hasPassword': hasPassword,
              'emailAuthEnabled': emailAuthEnabled,
            }),
          );
          await prefs.setInt(
            PreferenceKeys.secureAccountStatusCacheTsV1,
            nowMs,
          );
        } catch (_) {
          final tokenEmail =
              (BackendApiService().getCurrentAuthEmail() ?? '').trim();
          hasEmail = storedEmail.isNotEmpty || tokenEmail.isNotEmpty;
          // Legacy backend fallback: if we can only infer email, assume password is set too.
          hasPassword = hasEmail;
        }
      }

      if (!mounted) return;
      setState(() {
        _loaded = true;
        _hasEmail = hasEmail;
        _hasPassword = hasPassword;
        _shouldShow =
            emailAuthEnabled && !dismissed && !(hasEmail && hasPassword);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loaded = true;
        _shouldShow = false;
      });
    }
  }

  Future<void> _dismiss() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(PreferenceKeys.secureAccountPromptDismissedV1, true);
    } catch (_) {}
    if (!mounted) return;
    setState(() => _shouldShow = false);
  }

  Future<void> _openSecureAccount() async {
    await Navigator.of(context).pushNamed('/secure-account');
    if (!mounted) return;
    await _load(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || !_shouldShow) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final title = _hasEmail && !_hasPassword
        ? l10n.authSecureAccountAddPasswordTitle
        : l10n.authSecureAccountTitle;
    final subtitle = _hasEmail && !_hasPassword
        ? l10n.authSecureAccountBannerAddPasswordSubtitle
        : l10n.authSecureAccountFormDefaultSubtitle;

    Widget card = KubusCard(
      padding: const EdgeInsets.all(KubusSpacing.md),
      color: scheme.surfaceContainerHigh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline,
                  color: scheme.onSurface.withValues(alpha: 0.85), size: 20),
              const SizedBox(width: KubusSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: KubusTextStyles.sectionTitle.copyWith(
                        fontSize: KubusChromeMetrics.navLabel,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: KubusSpacing.xs),
                    Text(
                      subtitle,
                      style: KubusTextStyles.navMetaLabel.copyWith(
                        height: 1.3,
                        color: scheme.onSurface.withValues(alpha: 0.75),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _dismiss,
                icon: Icon(
                  Icons.close_rounded,
                  color: scheme.onSurface.withValues(alpha: 0.55),
                  size: 18,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                tooltip: 'Dismiss',
              ),
            ],
          ),
          const SizedBox(height: KubusSpacing.sm),
          Row(
            children: [
              TextButton(
                onPressed: _dismiss,
                child: Text(
                  'Not now',
                  style: KubusTextStyles.navLabel.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _openSecureAccount,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: Text(
                  'Secure',
                  style: KubusTextStyles.navLabel.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.primary,
                  side:
                      BorderSide(color: scheme.primary.withValues(alpha: 0.45)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: KubusSpacing.md,
                    vertical: KubusSpacing.sm,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(KubusRadius.md),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (widget.padding != EdgeInsets.zero) {
      card = Padding(padding: widget.padding, child: card);
    }

    final bottom = widget.bottomSpacing;
    if (bottom <= 0) return card;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        card,
        SizedBox(height: bottom),
      ],
    );
  }
}
