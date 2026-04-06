import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Shared time formatting for activity/notification tiles.
String formatActivityTime(BuildContext context, DateTime timestamp) {
  final l10n = AppLocalizations.of(context)!;
  final now = DateTime.now();
  final diff = now.difference(timestamp);
  if (diff.inMinutes < 1) return l10n.commonJustNow;
  if (diff.inMinutes < 60) return l10n.commonTimeAgoMinutes(diff.inMinutes);
  if (diff.inHours < 24) return l10n.commonTimeAgoHours(diff.inHours);
  if (diff.inDays < 7) return l10n.commonTimeAgoDays(diff.inDays);
  return MaterialLocalizations.of(context).formatShortDate(timestamp);
}
