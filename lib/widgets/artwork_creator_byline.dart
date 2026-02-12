import 'dart:async';

import 'package:flutter/material.dart';

import 'package:art_kubus/l10n/app_localizations.dart';

import '../models/artwork.dart';
import '../models/user.dart';
import '../services/event_bus.dart';
import '../services/user_service.dart';
import '../utils/user_identity_display.dart';
import '../utils/wallet_utils.dart';
import '../utils/user_profile_navigation.dart';

class ArtworkCreatorByline extends StatefulWidget {
  final Artwork artwork;
  final TextStyle? style;
  final int maxLines;
  final bool includeByPrefix;
  final bool showUsername;
  final bool linkToProfile;

  const ArtworkCreatorByline({
    super.key,
    required this.artwork,
    this.style,
    this.maxLines = 1,
    this.includeByPrefix = true,
    this.showUsername = false,
    this.linkToProfile = true,
  });

  @override
  State<ArtworkCreatorByline> createState() => _ArtworkCreatorBylineState();
}

class _ArtworkCreatorBylineState extends State<ArtworkCreatorByline> {
  List<_CreatorRef> _creators = const <_CreatorRef>[];
  final Map<String, UserIdentityDisplay> _resolvedIdentityByUserId =
      <String, UserIdentityDisplay>{};
  StreamSubscription<Map<String, dynamic>>? _profileUpdatedSub;

  @override
  void initState() {
    super.initState();
    _refreshCreators();

    // If the local user updates their profile (displayName/avatar), refresh labels.
    _profileUpdatedSub = EventBus().on('profile_updated').listen((event) {
      if (!mounted) return;
      final payload = event['payload'];
      String? wallet;
      try {
        if (payload is Map) {
          wallet = (payload['walletAddress'] ?? payload['wallet_address'])?.toString();
        } else {
          // UserProfile model is not imported here; best-effort extraction.
          wallet = (payload?.walletAddress ?? payload?.wallet_address)?.toString();
        }
      } catch (_) {
        wallet = null;
      }

      final normalized = (wallet ?? '').trim();
      if (normalized.isEmpty) return;
      if (_creators.any((c) => (c.userId ?? '').toLowerCase() == normalized.toLowerCase())) {
        _resolveCreatorNames(forceRefresh: true);
      }
    });
  }

  @override
  void didUpdateWidget(covariant ArtworkCreatorByline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artwork.id != widget.artwork.id ||
        oldWidget.artwork.artist != widget.artwork.artist ||
        oldWidget.artwork.metadata != widget.artwork.metadata) {
      _refreshCreators();
    }
  }

  @override
  void dispose() {
    _profileUpdatedSub?.cancel();
    super.dispose();
  }

  void _refreshCreators() {
    final next = _extractCreators(widget.artwork);
    _creators = next;
    _resolveCreatorNames(forceRefresh: false);
  }

  Future<void> _resolveCreatorNames({required bool forceRefresh}) async {
    final ids = _creators
        .map((c) => (c.userId ?? '').trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (ids.isEmpty) return;

    final futures = ids.map((id) async {
      try {
        final User? user = await UserService.getUserById(id, forceRefresh: forceRefresh);
        final name = (user?.name ?? '').trim();
        final username = (user?.username ?? '').trim();
        if (name.isNotEmpty || username.isNotEmpty) {
          _resolvedIdentityByUserId[id] = UserIdentityDisplay(
            name: name.isNotEmpty ? name : username,
            username: username.isNotEmpty ? username : null,
          );
        }
      } catch (_) {}
    });

    await Future.wait(futures);
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final baseStyle = widget.style ?? DefaultTextStyle.of(context).style;
    final colorScheme = Theme.of(context).colorScheme;

    final creators = _creators;
    if (creators.isEmpty) {
      final artist = widget.artwork.artist.trim();
      final walletFallback = _extractFallbackWallet(widget.artwork.metadata);
      final compactWallet = _compactWallet(
        WalletUtils.looksLikeWallet(artist) ? artist : walletFallback,
      );
      final safeArtist = artist.isNotEmpty && !WalletUtils.looksLikeWallet(artist)
          ? artist
          : (compactWallet ?? (l10n?.commonUnknown ?? 'Unknown artist'));
      return Text(
        safeArtist,
        style: baseStyle,
        maxLines: widget.maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    String prefix = '';
    String suffix = '';
    if (widget.includeByPrefix) {
      // Keep localization order by splitting on a sentinel placeholder.
      // Example: EN "by {artist}" -> ["by ", ""]
      // Some locales might place the placeholder elsewhere.
      final marker = '\u{FFFF}';
      final template = (l10n != null) ? l10n.commonByArtist(marker) : 'by $marker';
      final parts = template.split(marker);
      prefix = parts.isNotEmpty ? parts.first : '';
      suffix = parts.length > 1 ? parts.sublist(1).join(marker) : '';
    }

    final linkStyle = baseStyle.copyWith(
      color: colorScheme.primary,
      decoration: widget.linkToProfile ? TextDecoration.underline : TextDecoration.none,
      decorationColor: colorScheme.primary,
    );

    final spans = <InlineSpan>[];
    if (prefix.isNotEmpty) {
      spans.add(TextSpan(text: prefix, style: baseStyle));
    }

    for (var i = 0; i < creators.length; i++) {
      final creator = creators[i];
      if (i > 0) {
        spans.add(TextSpan(text: ', ', style: baseStyle));
      }

      final userId = creator.userId;
      final resolved = (userId != null && userId.isNotEmpty)
          ? _resolvedIdentityByUserId[userId]
          : null;
      final primaryLabel = (resolved?.name ?? creator.label).trim();
      final rawUsername = (resolved?.username ?? creator.username);
      final username = (widget.showUsername && rawUsername != null && rawUsername.trim().isNotEmpty)
          ? rawUsername.trim()
          : null;
      final combinedLabel = username == null ? primaryLabel : '$primaryLabel @${username.startsWith('@') ? username.substring(1) : username}';

      if (userId != null && userId.isNotEmpty && widget.linkToProfile) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: InkWell(
              onTap: () => UserProfileNavigation.open(
                context,
                userId: userId,
                username: creator.username,
              ),
              child: Text(combinedLabel, style: linkStyle),
            ),
          ),
        );
      } else {
        spans.add(TextSpan(text: combinedLabel, style: baseStyle));
      }
    }

    if (suffix.isNotEmpty) {
      spans.add(TextSpan(text: suffix, style: baseStyle));
    }

    return RichText(
      maxLines: widget.maxLines,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(style: baseStyle, children: spans),
    );
  }
}

class _CreatorRef {
  final String label;
  final String? userId;
  final String? username;

  const _CreatorRef({
    required this.label,
    this.userId,
    this.username,
  });
}

List<_CreatorRef> _extractCreators(Artwork artwork) {
  final creators = <_CreatorRef>[];
  final bylineLabels = _extractCreatorBylineLabels(artwork.metadata);

  void add({String? userId, String? label, String? username}) {
    final safeLabel = (label ?? '').trim();
    final safeUserId = (userId ?? '').trim();
    if (safeLabel.isEmpty && safeUserId.isEmpty) return;

    final display = (safeLabel.isNotEmpty && !WalletUtils.looksLikeWallet(safeLabel))
        ? safeLabel
        : (_compactWallet(
                WalletUtils.looksLikeWallet(safeUserId) ? safeUserId : safeLabel) ??
            'Unknown artist');

    creators.add(
      _CreatorRef(
        label: display,
        userId: safeUserId.isEmpty ? null : safeUserId,
        username: (username ?? '').trim().isEmpty ? null : username?.trim(),
      ),
    );
  }

  final meta = artwork.metadata;

  // Try rich creator lists first.
  dynamic raw = meta?['creators'] ??
      meta?['artists'] ??
      meta?['collaborators'] ??
      meta?['contributors'];

  if (raw is List) {
    for (final entry in raw) {
      if (entry is String) {
        final s = entry.trim();
        add(
          userId: s,
          label: WalletUtils.looksLikeWallet(s) ? null : s,
        );
      } else if (entry is Map) {
        final map = entry.cast<dynamic, dynamic>();
        final userId = map['walletAddress'] ??
            map['wallet_address'] ??
            map['wallet'] ??
            map['userId'] ??
            map['user_id'] ??
            map['id'];
        final label = map['displayName'] ??
            map['display_name'] ??
            map['username'] ??
            map['artistName'] ??
            map['artist_name'] ??
            map['name'];
        final username = map['username'];
        add(userId: userId?.toString(), label: label?.toString(), username: username?.toString());
      }
    }
  }

  // Try a list of wallet addresses.
  final rawWallets = meta?['creatorWallets'] ??
      meta?['creatorWalletAddresses'] ??
      meta?['walletAddresses'] ??
      meta?['wallets'];
  if (creators.isEmpty && rawWallets is List) {
    for (final entry in rawWallets) {
      add(userId: entry?.toString(), label: null);
    }
  }

  // Fallback: single creator wallet + artwork.artist label.
  if (creators.isEmpty) {
    final wallet = (meta?['walletAddress'] ??
            meta?['wallet_address'] ??
            meta?['artistWallet'] ??
            meta?['artistWalletAddress'] ??
            meta?['creatorWallet'] ??
            meta?['creatorWalletAddress'])
        ?.toString();

    final rawArtistName = meta?['artistName'] ?? meta?['artist_name'];
    final artistName = rawArtistName?.toString().trim();
    final labelCandidate = artwork.artist.trim().isNotEmpty
        ? artwork.artist.trim()
        : (artistName != null && artistName.isNotEmpty ? artistName : '');
    final label = labelCandidate.isNotEmpty && !WalletUtils.looksLikeWallet(labelCandidate)
        ? labelCandidate
        : (_compactWallet(wallet ?? labelCandidate) ?? 'Unknown artist');

    add(userId: wallet, label: label);
  }

  if (bylineLabels.isNotEmpty) {
    final relabeledCreators = <_CreatorRef>[];
    for (var i = 0; i < creators.length; i++) {
      final creator = creators[i];
      if (i >= bylineLabels.length) {
        relabeledCreators.add(creator);
        continue;
      }

      final bylineLabel = _normalizeBylineLabel(bylineLabels[i]);
      relabeledCreators.add(
        _CreatorRef(
          label: bylineLabel ?? creator.label,
          userId: creator.userId,
          username: creator.username,
        ),
      );
    }

    for (var i = creators.length; i < bylineLabels.length; i++) {
      _addBylineLabel(relabeledCreators, bylineLabels[i]);
    }
    return relabeledCreators;
  }

  return creators;
}

void _addBylineLabel(List<_CreatorRef> creators, String label) {
  final safeLabel = _normalizeBylineLabel(label);
  if (safeLabel == null) return;
  creators.add(_CreatorRef(label: safeLabel));
}

String? _normalizeBylineLabel(String label) {
  final clean = label.trim();
  if (clean.isEmpty) return null;
  if (!WalletUtils.looksLikeWallet(clean)) return clean;
  return _compactWallet(clean) ?? 'Unknown artist';
}

String? _extractFallbackWallet(Map<String, dynamic>? meta) {
  if (meta == null || meta.isEmpty) return null;
  for (final key in const <String>[
    'walletAddress',
    'wallet_address',
    'artistWallet',
    'artist_wallet',
    'creatorWallet',
    'creator_wallet',
    'creatorWalletAddress',
    'creator_wallet_address',
  ]) {
    final raw = meta[key]?.toString().trim();
    if (raw != null && raw.isNotEmpty && WalletUtils.looksLikeWallet(raw)) {
      return raw;
    }
  }
  return null;
}

List<String> _extractCreatorBylineLabels(Map<String, dynamic>? meta) {
  if (meta == null || meta.isEmpty) return const <String>[];
  final raw = meta['creator_name_byline'] ??
      meta['creatorNameByline'] ??
      meta['creator_byline'] ??
      meta['creatorByline'] ??
      meta['artist_name_byline'] ??
      meta['artistNameByline'] ??
      meta['artist_byline'] ??
      meta['artistByline'];
  if (raw == null) return const <String>[];

  if (raw is List) {
    return raw
        .map((entry) => entry.toString().trim())
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
  }

  final byline = raw.toString().trim();
  if (byline.isEmpty) return const <String>[];
  if (!byline.contains(',') &&
      !byline.contains(';') &&
      !byline.contains('/') &&
      !byline.contains('|')) {
    return <String>[byline];
  }

  return byline
      .split(RegExp(r'\s*[,;/|]\s*'))
      .map((entry) => entry.trim())
      .where((entry) => entry.isNotEmpty)
      .toList(growable: false);
}

String? _compactWallet(String? wallet) {
  final normalized = (wallet ?? '').trim();
  if (normalized.isEmpty) return null;
  if (!WalletUtils.looksLikeWallet(normalized)) return null;
  if (normalized.length <= 10) return '${normalized.substring(0, 4)}...';
  return '${normalized.substring(0, 6)}...${normalized.substring(normalized.length - 4)}';
}
