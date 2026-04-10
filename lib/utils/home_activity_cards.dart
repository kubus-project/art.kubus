import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/stats/stats_models.dart';
import '../models/user_persona.dart';
import 'kubus_color_roles.dart';

enum HomeActivityRole {
  artist,
  institution,
  lover,
}

enum HomeActivityMetric {
  artworks,
  views,
  likes,
  followers,
  visitors,
  eventsHosted,
  exhibitions,
  programViews,
  discovered,
  arSessions,
  following,
  likesGiven,
}

enum HomeActivityCardActionType {
  analytics,
  institutionAnalytics,
}

class HomeActivityCardAction {
  const HomeActivityCardAction._({
    required this.type,
    this.statType,
  });

  const HomeActivityCardAction.analytics(String statType)
      : this._(
          type: HomeActivityCardActionType.analytics,
          statType: statType,
        );

  const HomeActivityCardAction.institutionAnalytics()
      : this._(type: HomeActivityCardActionType.institutionAnalytics);

  final HomeActivityCardActionType type;
  final String? statType;
}

class HomeActivityCardData {
  const HomeActivityCardData({
    required this.metric,
    required this.label,
    required this.value,
    required this.isLoading,
    required this.icon,
    required this.color,
    required this.action,
  });

  final HomeActivityMetric metric;
  final String label;
  final int value;
  final bool isLoading;
  final IconData icon;
  final Color color;
  final HomeActivityCardAction? action;
}

class HomeActivitySourceData {
  const HomeActivitySourceData({
    required this.publicCounters,
    required this.publicLoading,
    required this.discoveredCount,
    required this.discoveredLoading,
    required this.arSessions,
    required this.arSessionsLoading,
    required this.exhibitionsCount,
    required this.exhibitionsLoading,
    required this.programViews,
    required this.programViewsLoading,
  });

  final Map<String, int> publicCounters;
  final bool publicLoading;
  final int discoveredCount;
  final bool discoveredLoading;
  final int arSessions;
  final bool arSessionsLoading;
  final int exhibitionsCount;
  final bool exhibitionsLoading;
  final int programViews;
  final bool programViewsLoading;
}

const List<String> homeActivityPublicSnapshotMetrics = <String>[
  'artworks',
  'viewsReceived',
  'likesReceived',
  'followers',
  'following',
  'likesGiven',
  'visitorsReceived',
  'eventsHosted',
];

const List<String> homeActivityPrivateSnapshotMetrics = <String>[
  'artworksDiscovered',
  'arSessions',
];

HomeActivityRole resolveHomeActivityRole({
  required UserPersona? persona,
  required bool isArtist,
  required bool isInstitution,
}) {
  switch (persona) {
    case UserPersona.creator:
      return HomeActivityRole.artist;
    case UserPersona.institution:
      return HomeActivityRole.institution;
    case UserPersona.lover:
      return HomeActivityRole.lover;
    case null:
      if (isInstitution) return HomeActivityRole.institution;
      if (isArtist) return HomeActivityRole.artist;
      return HomeActivityRole.lover;
  }
}

DateTime homeActivityProgramViewsFromUtc() => DateTime.utc(2020, 1, 1);

DateTime homeActivityProgramViewsToUtc(DateTime nowUtc) =>
    DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day)
        .add(const Duration(days: 1));

int sumHomeProgramViews(StatsSeries? series) {
  if (series == null) return 0;
  return series.series
      .where((point) => point.g == 'event' || point.g == 'exhibition')
      .fold<int>(0, (sum, point) => sum + point.v);
}

List<HomeActivityCardData> buildHomeActivityCards({
  required AppLocalizations l10n,
  required KubusColorRoles roles,
  required UserPersona? persona,
  required bool isArtist,
  required bool isInstitution,
  required HomeActivitySourceData source,
}) {
  final role = resolveHomeActivityRole(
    persona: persona,
    isArtist: isArtist,
    isInstitution: isInstitution,
  );
  final metrics = switch (role) {
    HomeActivityRole.artist => const <HomeActivityMetric>[
        HomeActivityMetric.artworks,
        HomeActivityMetric.views,
        HomeActivityMetric.likes,
        HomeActivityMetric.followers,
      ],
    HomeActivityRole.institution => const <HomeActivityMetric>[
        HomeActivityMetric.visitors,
        HomeActivityMetric.eventsHosted,
        HomeActivityMetric.exhibitions,
        HomeActivityMetric.programViews,
      ],
    HomeActivityRole.lover => const <HomeActivityMetric>[
        HomeActivityMetric.discovered,
        HomeActivityMetric.arSessions,
        HomeActivityMetric.following,
        HomeActivityMetric.likesGiven,
      ],
  };

  return metrics
      .map((metric) => HomeActivityCardData(
            metric: metric,
            label: _labelForMetric(metric, l10n),
            value: _valueForMetric(metric, source),
            isLoading: _loadingForMetric(metric, source),
            icon: _iconForMetric(metric),
            color: _colorForMetric(metric, roles),
            action: _actionForMetric(metric),
          ))
      .toList(growable: false);
}

String labelForHomeActivityStatType(
  String statType,
  AppLocalizations l10n,
) {
  switch (statType.trim().toLowerCase()) {
    case 'artworks':
      return l10n.homeStatArtworks;
    case 'followers':
      return l10n.homeStatFollowers;
    case 'views':
      return l10n.homeStatViews;
    case 'likes':
      return l10n.homeStatLikes;
    case 'visitors':
      return l10n.homeStatVisitors;
    case 'eventshosted':
      return l10n.homeStatEventsHosted;
    case 'exhibitions':
      return l10n.homeStatExhibitions;
    case 'programviews':
      return l10n.homeStatProgramViews;
    case 'discovered':
      return l10n.homeStatDiscovered;
    case 'arsessions':
      return l10n.homeStatArSessions;
    case 'following':
      return l10n.homeStatFollowing;
    case 'likesgiven':
      return l10n.homeStatLikesGiven;
    default:
      return statType;
  }
}

String _labelForMetric(
  HomeActivityMetric metric,
  AppLocalizations l10n,
) {
  switch (metric) {
    case HomeActivityMetric.artworks:
      return l10n.homeStatArtworks;
    case HomeActivityMetric.views:
      return l10n.homeStatViews;
    case HomeActivityMetric.likes:
      return l10n.homeStatLikes;
    case HomeActivityMetric.followers:
      return l10n.homeStatFollowers;
    case HomeActivityMetric.visitors:
      return l10n.homeStatVisitors;
    case HomeActivityMetric.eventsHosted:
      return l10n.homeStatEventsHosted;
    case HomeActivityMetric.exhibitions:
      return l10n.homeStatExhibitions;
    case HomeActivityMetric.programViews:
      return l10n.homeStatProgramViews;
    case HomeActivityMetric.discovered:
      return l10n.homeStatDiscovered;
    case HomeActivityMetric.arSessions:
      return l10n.homeStatArSessions;
    case HomeActivityMetric.following:
      return l10n.homeStatFollowing;
    case HomeActivityMetric.likesGiven:
      return l10n.homeStatLikesGiven;
  }
}

int _valueForMetric(
  HomeActivityMetric metric,
  HomeActivitySourceData source,
) {
  switch (metric) {
    case HomeActivityMetric.artworks:
      return source.publicCounters['artworks'] ?? 0;
    case HomeActivityMetric.views:
      return source.publicCounters['viewsReceived'] ?? 0;
    case HomeActivityMetric.likes:
      return source.publicCounters['likesReceived'] ?? 0;
    case HomeActivityMetric.followers:
      return source.publicCounters['followers'] ?? 0;
    case HomeActivityMetric.visitors:
      return source.publicCounters['visitorsReceived'] ?? 0;
    case HomeActivityMetric.eventsHosted:
      return source.publicCounters['eventsHosted'] ?? 0;
    case HomeActivityMetric.exhibitions:
      return source.exhibitionsCount;
    case HomeActivityMetric.programViews:
      return source.programViews;
    case HomeActivityMetric.discovered:
      return source.discoveredCount;
    case HomeActivityMetric.arSessions:
      return source.arSessions;
    case HomeActivityMetric.following:
      return source.publicCounters['following'] ?? 0;
    case HomeActivityMetric.likesGiven:
      return source.publicCounters['likesGiven'] ?? 0;
  }
}

bool _loadingForMetric(
  HomeActivityMetric metric,
  HomeActivitySourceData source,
) {
  switch (metric) {
    case HomeActivityMetric.exhibitions:
      return source.exhibitionsLoading;
    case HomeActivityMetric.programViews:
      return source.programViewsLoading;
    case HomeActivityMetric.discovered:
      return source.discoveredLoading;
    case HomeActivityMetric.arSessions:
      return source.arSessionsLoading;
    case HomeActivityMetric.artworks:
    case HomeActivityMetric.views:
    case HomeActivityMetric.likes:
    case HomeActivityMetric.followers:
    case HomeActivityMetric.visitors:
    case HomeActivityMetric.eventsHosted:
    case HomeActivityMetric.following:
    case HomeActivityMetric.likesGiven:
      return source.publicLoading;
  }
}

IconData _iconForMetric(HomeActivityMetric metric) {
  switch (metric) {
    case HomeActivityMetric.artworks:
      return Icons.image_outlined;
    case HomeActivityMetric.views:
      return Icons.visibility_outlined;
    case HomeActivityMetric.likes:
      return Icons.favorite_outline;
    case HomeActivityMetric.followers:
      return Icons.people_outline;
    case HomeActivityMetric.visitors:
      return Icons.groups_outlined;
    case HomeActivityMetric.eventsHosted:
      return Icons.event_available_outlined;
    case HomeActivityMetric.exhibitions:
      return Icons.museum_outlined;
    case HomeActivityMetric.programViews:
      return Icons.insights_outlined;
    case HomeActivityMetric.discovered:
      return Icons.explore_outlined;
    case HomeActivityMetric.arSessions:
      return Icons.view_in_ar_outlined;
    case HomeActivityMetric.following:
      return Icons.person_add_alt_1_outlined;
    case HomeActivityMetric.likesGiven:
      return Icons.thumb_up_alt_outlined;
  }
}

Color _colorForMetric(
  HomeActivityMetric metric,
  KubusColorRoles roles,
) {
  switch (metric) {
    case HomeActivityMetric.artworks:
      return roles.web3ArtistStudioAccent;
    case HomeActivityMetric.views:
      return roles.statTeal;
    case HomeActivityMetric.likes:
      return roles.statCoral;
    case HomeActivityMetric.followers:
      return roles.statBlue;
    case HomeActivityMetric.visitors:
      return roles.statBlue;
    case HomeActivityMetric.eventsHosted:
      return roles.statAmber;
    case HomeActivityMetric.exhibitions:
      return roles.web3InstitutionAccent;
    case HomeActivityMetric.programViews:
      return roles.statTeal;
    case HomeActivityMetric.discovered:
      return roles.statTeal;
    case HomeActivityMetric.arSessions:
      return roles.statBlue;
    case HomeActivityMetric.following:
      return roles.statAmber;
    case HomeActivityMetric.likesGiven:
      return roles.statCoral;
  }
}

HomeActivityCardAction? _actionForMetric(HomeActivityMetric metric) {
  switch (metric) {
    case HomeActivityMetric.artworks:
      return const HomeActivityCardAction.analytics('artworks');
    case HomeActivityMetric.views:
      return const HomeActivityCardAction.analytics('views');
    case HomeActivityMetric.likes:
      return const HomeActivityCardAction.analytics('likes');
    case HomeActivityMetric.followers:
      return const HomeActivityCardAction.analytics('followers');
    case HomeActivityMetric.visitors:
      return const HomeActivityCardAction.analytics('visitors');
    case HomeActivityMetric.eventsHosted:
      return const HomeActivityCardAction.analytics('eventsHosted');
    case HomeActivityMetric.exhibitions:
      return const HomeActivityCardAction.analytics('exhibitions');
    case HomeActivityMetric.programViews:
      return const HomeActivityCardAction.institutionAnalytics();
    case HomeActivityMetric.discovered:
      return const HomeActivityCardAction.analytics('discovered');
    case HomeActivityMetric.arSessions:
      return const HomeActivityCardAction.analytics('arSessions');
    case HomeActivityMetric.following:
      return const HomeActivityCardAction.analytics('following');
    case HomeActivityMetric.likesGiven:
      return const HomeActivityCardAction.analytics('likesGiven');
  }
}
