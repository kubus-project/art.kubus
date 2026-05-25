import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../attestation_badge_panel.dart';

class ProfileBadgesVerificationSection extends StatelessWidget {
  const ProfileBadgesVerificationSection({
    super.key,
    this.compact = false,
    this.padding,
    this.title,
    this.subtitle,
  });

  final bool compact;
  final EdgeInsetsGeometry? padding;
  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final child = AttestationBadgePanel(
      title: title ?? l10n.profileBadgesVerificationTitle,
      subtitle: subtitle ?? l10n.profileBadgesVerificationSubtitle,
      compact: compact,
    );

    final resolvedPadding = padding;
    if (resolvedPadding == null) return child;
    return Padding(
      padding: resolvedPadding,
      child: child,
    );
  }
}
