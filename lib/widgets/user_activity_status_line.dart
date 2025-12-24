import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:art_kubus/l10n/app_localizations.dart';

import '../config/config.dart';
import '../models/user_presence.dart';
import '../providers/presence_provider.dart';
import '../screens/art/art_detail_screen.dart';
import '../screens/art/collection_detail_screen.dart';
import '../screens/events/event_detail_screen.dart';
import '../screens/events/exhibition_detail_screen.dart';

class UserActivityStatusLine extends StatefulWidget {
  final String walletAddress;
  final TextAlign textAlign;
  final TextStyle? textStyle;

  const UserActivityStatusLine({
    super.key,
    required this.walletAddress,
    this.textAlign = TextAlign.start,
    this.textStyle,
  });

  @override
  State<UserActivityStatusLine> createState() => _UserActivityStatusLineState();
}

class _UserActivityStatusLineState extends State<UserActivityStatusLine> {
  Timer? _toggleTimer;
  bool _showLocation = false;
  String? _prefetchedWallet;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _prefetchPresenceIfNeeded();
  }

  @override
  void didUpdateWidget(covariant UserActivityStatusLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.walletAddress != widget.walletAddress) {
      _prefetchedWallet = null;
      _stopToggleTimer();
      _prefetchPresenceIfNeeded();
    }
  }

  void _prefetchPresenceIfNeeded() {
    if (!AppConfig.isFeatureEnabled('presence')) return;
    final wallet = widget.walletAddress.trim();
    if (wallet.isEmpty) return;

    PresenceProvider? provider;
    try {
      provider = Provider.of<PresenceProvider>(context, listen: false);
    } catch (_) {
      provider = null;
    }
    if (provider == null) return;

    if (_prefetchedWallet == wallet) return;
    _prefetchedWallet = wallet;
    provider.prefetch([wallet]);
  }

  void _startToggleTimer() {
    _toggleTimer?.cancel();
    _showLocation = false;
    _toggleTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      setState(() => _showLocation = !_showLocation);
    });
  }

  void _stopToggleTimer() {
    _toggleTimer?.cancel();
    _toggleTimer = null;
    _showLocation = false;
  }

  @override
  void dispose() {
    _stopToggleTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.isFeatureEnabled('presence')) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    final baseStyle = widget.textStyle ??
        Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.6),
            );

    PresenceProvider? presenceProvider;
    try {
      presenceProvider = Provider.of<PresenceProvider>(context);
    } catch (_) {
      presenceProvider = null;
    }
    final presence = presenceProvider?.presenceForWallet(widget.walletAddress);

    if (presence == null || presence.visible != true) {
      _stopToggleTimer();
      return const SizedBox.shrink();
    }

    final isOnline = presence.isOnline == true;
    if (isOnline) {
      _stopToggleTimer();
      return Text(
        l10n.presenceOnlineLabel,
        textAlign: widget.textAlign,
        style: baseStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final lastSeenAt = presence.lastSeenAt;
    if (lastSeenAt == null) {
      _stopToggleTimer();
      return const SizedBox.shrink();
    }

    final timeAgo = _timeAgo(l10n, lastSeenAt);
    final timeText = l10n.presenceLastSeenLabel(timeAgo);

    final canShowLocation = AppConfig.isFeatureEnabled('presenceLastVisitedLocation') &&
        presence.lastVisited != null &&
        (presence.lastVisitedTitle ?? '').trim().isNotEmpty &&
        presence.lastVisited!.isExpired == false;

    if (!canShowLocation) {
      _stopToggleTimer();
      return Text(
        timeText,
        textAlign: widget.textAlign,
        style: baseStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    if (_toggleTimer == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_toggleTimer == null) _startToggleTimer();
      });
    }

    final locationText = l10n.presenceLastSeenAtLabel((presence.lastVisitedTitle ?? '').trim());
    final activeChild = _showLocation
        ? InkWell(
            key: const ValueKey('presence_location'),
            onTap: () => _openLastVisited(context, presence.lastVisited!),
            child: Text(
              locationText,
              textAlign: widget.textAlign,
              style: baseStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          )
        : Text(
            timeText,
            key: const ValueKey('presence_time'),
            textAlign: widget.textAlign,
            style: baseStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );

    return AnimatedSwitcher(
      duration: AppConfig.shortAnimationDuration,
      switchInCurve: Curves.easeIn,
      switchOutCurve: Curves.easeOut,
      transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
      child: activeChild,
    );
  }

  String _timeAgo(AppLocalizations l10n, DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 7) {
      return l10n.commonTimeAgoWeeks((difference.inDays / 7).floor());
    }
    if (difference.inDays > 0) {
      return l10n.commonTimeAgoDays(difference.inDays);
    }
    if (difference.inHours > 0) {
      return l10n.commonTimeAgoHours(difference.inHours);
    }
    if (difference.inMinutes > 0) {
      return l10n.commonTimeAgoMinutes(difference.inMinutes);
    }
    return l10n.commonTimeAgoJustNow;
  }

  void _openLastVisited(BuildContext context, UserPresenceLastVisited lastVisited) {
    final id = lastVisited.id.trim();
    if (id.isEmpty) return;
    final type = lastVisited.type.trim().toLowerCase();

    switch (type) {
      case 'artwork':
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => ArtDetailScreen(artworkId: id)));
        return;
      case 'exhibition':
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => ExhibitionDetailScreen(exhibitionId: id)));
        return;
      case 'event':
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: id)));
        return;
      case 'collection':
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => CollectionDetailScreen(collectionId: id)));
        return;
    }
  }
}
