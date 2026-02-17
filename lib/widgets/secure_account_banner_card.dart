import 'dart:convert';

import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/widgets/kubus_card.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  State<SecureAccountBannerCard> createState() => _SecureAccountBannerCardState();
}

class _SecureAccountBannerCardState extends State<SecureAccountBannerCard> {
  bool _loaded = false;
  bool _shouldShow = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String? _extractEmailClaim(String token) {
    final trimmed = token.trim();
    if (trimmed.isEmpty) return null;
    try {
      final parts = trimmed.split('.');
      if (parts.length < 2) return null;
      final payload = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(payload));
      final parsed = jsonDecode(decoded);
      if (parsed is Map<String, dynamic>) {
        final raw = parsed['email'];
        if (raw is String && raw.trim().isNotEmpty) return raw.trim();
      }
    } catch (_) {
      // Ignore parse failures.
    }
    return null;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissed =
          prefs.getBool(PreferenceKeys.secureAccountPromptDismissedV1) ?? false;
      final storedEmail =
          (prefs.getString(PreferenceKeys.secureAccountEmail) ?? '').trim();
      final tokenEmail =
          _extractEmailClaim((BackendApiService().getAuthToken() ?? '').trim());

      final hasEmail = storedEmail.isNotEmpty || (tokenEmail?.isNotEmpty ?? false);
      if (!mounted) return;
      setState(() {
        _loaded = true;
        _shouldShow = !dismissed && !hasEmail;
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

  void _openSecureAccount() {
    Navigator.of(context).pushNamed('/secure-account');
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || !_shouldShow) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;

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
                      'Secure your account',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Add email + password for recovery. Verification is last and non-blocking.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
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
                  style: GoogleFonts.inter(
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
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.primary,
                  side: BorderSide(color: scheme.primary.withValues(alpha: 0.45)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: KubusSpacing.md,
                    vertical: KubusSpacing.sm,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
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
