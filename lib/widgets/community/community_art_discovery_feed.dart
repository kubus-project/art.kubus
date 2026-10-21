import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../community/art_discovery.dart';
import '../../community/community_interactions.dart';
import '../../l10n/app_localizations.dart';
import '../../models/artwork.dart';
import '../../models/exhibition.dart';
import '../../providers/community_art_discovery_provider.dart';
import '../../utils/artwork_navigation.dart';
import '../../utils/creator_shell_navigation.dart';
import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../../utils/media_url_resolver.dart';
import '../common/kubus_cached_image.dart';
import '../empty_state_card.dart';
import '../inline_loading.dart';
import '../kubus_button.dart';
import '../kubus_card.dart';

/// The Community Art tab: one scrollable discovery feed that mixes
/// personalised, nearby and new-and-noteworthy entries, each with one small
/// grounded context label and its canonical destination.
///
/// Posts are drawn by the host screen ([postBuilder]) so they keep the card,
/// actions and navigation of that surface; artworks and exhibitions use the
/// compact cards below.
class CommunityArtDiscoveryFeed extends StatelessWidget {
  const CommunityArtDiscoveryFeed({
    super.key,
    required this.postBuilder,
    required this.onRefresh,
    required this.onUseMyLocation,
    this.matches,
    this.padding = const EdgeInsets.all(KubusSpacing.lg),
    this.maxContentWidth,
  });

  /// Builds the card for a post entry.
  final Widget Function(BuildContext context, CommunityPost post) postBuilder;

  /// Re-runs discovery (pull to refresh and the retry action).
  final Future<void> Function() onRefresh;

  /// Re-runs discovery after asking for the device position.
  final Future<void> Function() onUseMyLocation;

  /// Optional text filter (the tab's search field).
  final bool Function(ArtDiscoveryItem item)? matches;

  final EdgeInsets padding;

  /// Reading column cap for wide layouts.
  final double? maxContentWidth;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityArtDiscoveryProvider>();
    final l10n = AppLocalizations.of(context)!;
    // The filter runs over the whole ranked feed before the page is cut, so a
    // lower-ranked match stays reachable through Load more.
    final shown = provider.visibleItems(matches);
    final filtering = matches != null;

    if (provider.loading && provider.allItems.isEmpty) {
      return const Center(child: _FeedLoading());
    }

    final children = <Widget>[
      _DiscoveryHeader(provider: provider, onUseMyLocation: onUseMyLocation),
      const SizedBox(height: KubusSpacing.md),
      if (provider.error != null && provider.allItems.isEmpty)
        EmptyStateCard(
          icon: Icons.cloud_off_outlined,
          title: l10n.communityArtDiscoveryErrorTitle,
          description: l10n.communityArtDiscoveryErrorBody,
          showAction: true,
          actionLabel: l10n.commonRetry,
          onAction: onRefresh,
        )
      else if (shown.isEmpty && filtering)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: KubusSpacing.xl),
          child: Center(
            child: Text(
              l10n.commonNoResultsFound,
              style: KubusTypography.textTheme.bodyMedium?.copyWith(
                color: KubusColorRoles.of(context).foregroundMuted,
              ),
            ),
          ),
        )
      else if (shown.isEmpty)
        EmptyStateCard(
          icon: Icons.brush_outlined,
          title: l10n.communityArtDiscoveryEmptyTitle,
          description: l10n.communityArtDiscoveryEmptyBody,
          showAction: true,
          actionLabel: l10n.commonRefresh,
          onAction: onRefresh,
        )
      else
        for (final item in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: KubusSpacing.lg),
            child: _DiscoveryEntry(item: item, postBuilder: postBuilder),
          ),
      if (provider.hasMoreMatching(matches))
        Padding(
          padding: const EdgeInsets.only(bottom: KubusSpacing.lg),
          child: Center(
            child: KubusButton(
              onPressed: provider.loadMore,
              label: l10n.communityArtDiscoveryLoadMore,
              variant: KubusButtonVariant.secondary,
            ),
          ),
        ),
      if (provider.loading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: KubusSpacing.lg),
          child: Center(child: _FeedLoading()),
        ),
    ];

    Widget list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      children: children,
    );
    final cap = maxContentWidth;
    if (cap != null) {
      list = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: cap),
          child: list,
        ),
      );
    }
    return RefreshIndicator(onRefresh: onRefresh, child: list);
  }
}

class _FeedLoading extends StatelessWidget {
  const _FeedLoading();

  @override
  Widget build(BuildContext context) =>
      const InlineLoading(expand: false, tileSize: 4);
}

class _DiscoveryHeader extends StatelessWidget {
  const _DiscoveryHeader({
    required this.provider,
    required this.onUseMyLocation,
  });

  final CommunityArtDiscoveryProvider provider;
  final Future<void> Function() onUseMyLocation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    final location = provider.location;
    final subtitle = switch (location?.source) {
      ArtDiscoveryLocationSource.mapCenter ||
      ArtDiscoveryLocationSource.selected =>
        l10n.communityArtDiscoverySubtitleMap,
      ArtDiscoveryLocationSource.device =>
        l10n.communityArtDiscoverySubtitleDevice,
      ArtDiscoveryLocationSource.saved =>
        l10n.communityArtDiscoverySubtitleSaved,
      null => l10n.communityArtDiscoverySubtitlePublic,
    };
    final usingDevice = location?.source == ArtDiscoveryLocationSource.device;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.communityArtDiscoveryTitle,
          style: KubusTextStyles.screenTitle.copyWith(color: roles.foreground),
        ),
        const SizedBox(height: KubusSpacing.xs),
        Text(
          location == null
              ? subtitle
              : '$subtitle · ${l10n.communityArtDiscoveryWithin(l10n.commonDistanceKm(provider.radiusKm.round().toString()))}',
          style: KubusTypography.textTheme.bodySmall?.copyWith(
            color: roles.foregroundMuted,
          ),
        ),
        if (!usingDevice) ...[
          const SizedBox(height: KubusSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: KubusButton(
              onPressed: provider.loading ? null : onUseMyLocation,
              label: l10n.communityArtDiscoveryUseMyLocation,
              icon: Icons.near_me_outlined,
              variant: KubusButtonVariant.secondary,
            ),
          ),
        ],
      ],
    );
  }
}

String _reasonLabel(
  AppLocalizations l10n,
  ArtDiscoveryReason reason,
) =>
    switch (reason) {
      ArtDiscoveryReason.fromFollowed =>
        l10n.communityArtDiscoveryReasonFollowed,
      ArtDiscoveryReason.nearby => l10n.communityArtDiscoveryReasonNearby,
      ArtDiscoveryReason.exhibition =>
        l10n.communityArtDiscoveryReasonExhibition,
      ArtDiscoveryReason.recentReview => l10n.communityArtDiscoveryReasonReview,
      ArtDiscoveryReason.newArtwork =>
        l10n.communityArtDiscoveryReasonNewArtwork,
      ArtDiscoveryReason.communityDiscussion =>
        l10n.communityArtDiscoveryReasonDiscussion,
      ArtDiscoveryReason.forYou => l10n.communityArtDiscoveryReasonForYou,
    };

IconData _reasonIcon(ArtDiscoveryReason reason) => switch (reason) {
      ArtDiscoveryReason.fromFollowed => Icons.person_outline,
      ArtDiscoveryReason.nearby => Icons.place_outlined,
      ArtDiscoveryReason.exhibition => Icons.museum_outlined,
      ArtDiscoveryReason.recentReview => Icons.rate_review_outlined,
      ArtDiscoveryReason.newArtwork => Icons.auto_awesome_outlined,
      ArtDiscoveryReason.communityDiscussion => Icons.forum_outlined,
      ArtDiscoveryReason.forYou => Icons.bookmark_border,
    };

class _ReasonLabel extends StatelessWidget {
  const _ReasonLabel({required this.item});

  final ArtDiscoveryItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    final distance = item.distanceKm;
    final text = distance != null && item.reason == ArtDiscoveryReason.nearby
        ? '${_reasonLabel(l10n, item.reason)} · ${l10n.commonDistanceKmAway(distance < 10 ? distance.toStringAsFixed(1) : distance.round().toString())}'
        : _reasonLabel(l10n, item.reason);
    return Padding(
      padding: const EdgeInsets.only(bottom: KubusSpacing.xs),
      child: Row(
        children: [
          Icon(
            _reasonIcon(item.reason),
            size: 14,
            color: roles.foregroundMuted,
          ),
          const SizedBox(width: KubusSpacing.xs),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: KubusTypography.structural(
                fontSize: 12,
                color: roles.foregroundMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoveryEntry extends StatelessWidget {
  const _DiscoveryEntry({required this.item, required this.postBuilder});

  final ArtDiscoveryItem item;
  final Widget Function(BuildContext context, CommunityPost post) postBuilder;

  @override
  Widget build(BuildContext context) {
    final Widget body;
    switch (item.kind) {
      case ArtDiscoveryKind.post:
        body = postBuilder(context, item.post!);
      case ArtDiscoveryKind.artwork:
        body = _ArtworkCard(artwork: item.artwork!);
      case ArtDiscoveryKind.exhibition:
        body = _ExhibitionCard(exhibition: item.exhibition!);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReasonLabel(item: item),
        body,
      ],
    );
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.url, required this.label});

  final String? url;
  final String label;

  @override
  Widget build(BuildContext context) {
    final resolved = MediaUrlResolver.resolveDisplayUrl(
      url,
      maxWidth: MediaUrlResolver.cardMaxWidth,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(KubusRadius.surface),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: KubusCachedImage(
          imageUrl: resolved,
          fit: BoxFit.cover,
          decodeToDisplaySize: true,
          semanticLabel: label,
        ),
      ),
    );
  }
}

class _ArtworkCard extends StatelessWidget {
  const _ArtworkCard({required this.artwork});

  final Artwork artwork;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    return Semantics(
      button: true,
      label: '${artwork.title}, ${artwork.artist}',
      child: KubusCard(
        onTap: () => openArtwork(context, artwork.id, source: 'art_discovery'),
        padding: const EdgeInsets.all(KubusSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CoverImage(url: artwork.imageUrl, label: artwork.title),
            const SizedBox(height: KubusSpacing.sm),
            Text(
              artwork.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: KubusTextStyles.screenTitle.copyWith(
                color: roles.foreground,
              ),
            ),
            if (artwork.artist.trim().isNotEmpty) ...[
              const SizedBox(height: KubusSpacing.xxs),
              Text(
                artwork.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: KubusTypography.textTheme.bodySmall?.copyWith(
                  color: roles.foregroundMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExhibitionCard extends StatelessWidget {
  const _ExhibitionCard({required this.exhibition});

  final Exhibition exhibition;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    String? when;
    final start = exhibition.startsAt;
    final end = exhibition.endsAt;
    if (start != null || end != null) {
      String fmt(DateTime d) =>
          MaterialLocalizations.of(context).formatMediumDate(d.toLocal());
      when = [
        if (start != null) fmt(start),
        if (end != null) fmt(end),
      ].join(' – ');
    }
    final place = (exhibition.locationName ?? '').trim();
    final meta = [
      if (when != null) when,
      if (place.isNotEmpty) place,
    ].join(' · ');
    assert(locale.isNotEmpty);
    return Semantics(
      button: true,
      label: exhibition.title,
      child: KubusCard(
        // Shell-aware: the desktop shell keeps its sidebar and header, mobile
        // keeps a normal route.
        onTap: () => CreatorShellNavigation.openExhibitionDetailWorkspace(
          context,
          exhibitionId: exhibition.id,
          initialExhibition: exhibition,
        ),
        padding: const EdgeInsets.all(KubusSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((exhibition.coverUrl ?? '').trim().isNotEmpty) ...[
              _CoverImage(url: exhibition.coverUrl, label: exhibition.title),
              const SizedBox(height: KubusSpacing.sm),
            ],
            Text(
              exhibition.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: KubusTextStyles.screenTitle.copyWith(
                color: roles.foreground,
              ),
            ),
            if (meta.isNotEmpty) ...[
              const SizedBox(height: KubusSpacing.xxs),
              Text(
                meta,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: KubusTypography.textTheme.bodySmall?.copyWith(
                  color: roles.foregroundMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
