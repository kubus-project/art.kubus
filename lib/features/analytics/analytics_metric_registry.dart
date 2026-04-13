import 'package:flutter/material.dart';

import 'analytics_entity_registry.dart';

enum AnalyticsMetricFormat {
  count,
  compact,
  percent,
  kub8,
}

enum AnalyticsChartKind {
  line,
  bar,
}

class AnalyticsMetricDefinition {
  const AnalyticsMetricDefinition({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.format,
    required this.supportedEntities,
    this.scopes = const <AnalyticsScope>{
      AnalyticsScope.public,
      AnalyticsScope.private,
    },
    this.supportedGroupBys = const <AnalyticsGroupBy>{},
    this.defaultGroupBy,
    this.chartKind = AnalyticsChartKind.line,
    this.seriesSupported = true,
    this.relevance = 0,
  });

  final String id;
  final String label;
  final String description;
  final IconData icon;
  final AnalyticsMetricFormat format;
  final Set<AnalyticsEntityType> supportedEntities;
  final Set<AnalyticsScope> scopes;
  final Set<AnalyticsGroupBy> supportedGroupBys;
  final AnalyticsGroupBy? defaultGroupBy;
  final AnalyticsChartKind chartKind;
  final bool seriesSupported;
  final int relevance;

  bool supportsEntity(AnalyticsEntityType entityType) {
    return supportedEntities.contains(entityType);
  }

  bool supportsScope(AnalyticsScope scope) {
    return scopes.contains(scope);
  }

  bool get privateOnly =>
      scopes.length == 1 && scopes.contains(AnalyticsScope.private);

  String formatValue(num value) {
    switch (format) {
      case AnalyticsMetricFormat.count:
        return value.round().toString();
      case AnalyticsMetricFormat.compact:
        return AnalyticsMetricRegistry.formatCompact(value);
      case AnalyticsMetricFormat.percent:
        return '${value.toStringAsFixed(value >= 10 ? 0 : 1)}%';
      case AnalyticsMetricFormat.kub8:
        return '${AnalyticsMetricRegistry.formatCompact(value)} KUB8';
    }
  }
}

class AnalyticsMetricRegistry {
  const AnalyticsMetricRegistry._();

  static const userEntity = <AnalyticsEntityType>{AnalyticsEntityType.user};
  static const contentEntities = <AnalyticsEntityType>{
    AnalyticsEntityType.artwork,
    AnalyticsEntityType.post,
  };
  static const eventEntities = <AnalyticsEntityType>{
    AnalyticsEntityType.event,
    AnalyticsEntityType.exhibition,
  };
  static const platformEntity = <AnalyticsEntityType>{
    AnalyticsEntityType.platform,
  };
  static const daoEntity = <AnalyticsEntityType>{
    AnalyticsEntityType.dao,
  };

  static const publicAndPrivate = <AnalyticsScope>{
    AnalyticsScope.public,
    AnalyticsScope.private,
  };
  static const privateOnly = <AnalyticsScope>{AnalyticsScope.private};

  static const List<AnalyticsMetricDefinition> metrics =
      <AnalyticsMetricDefinition>[
    AnalyticsMetricDefinition(
      id: 'followers',
      label: 'Followers',
      description: 'People following this profile.',
      icon: Icons.people_outline,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: userEntity,
      relevance: 90,
    ),
    AnalyticsMetricDefinition(
      id: 'following',
      label: 'Following',
      description: 'Profiles followed by this wallet.',
      icon: Icons.person_add_alt_1_outlined,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: userEntity,
      relevance: 50,
    ),
    AnalyticsMetricDefinition(
      id: 'posts',
      label: 'Posts',
      description: 'Community posts published by this profile.',
      icon: Icons.forum_outlined,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: userEntity,
      relevance: 80,
    ),
    AnalyticsMetricDefinition(
      id: 'comments',
      label: 'Comments',
      description: 'Comments written by this profile.',
      icon: Icons.chat_bubble_outline,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: userEntity,
      seriesSupported: false,
      relevance: 35,
    ),
    AnalyticsMetricDefinition(
      id: 'artworks',
      label: 'Artworks',
      description: 'Active artworks attributed to this profile.',
      icon: Icons.palette_outlined,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: {
        AnalyticsEntityType.user,
        AnalyticsEntityType.exhibition,
        AnalyticsEntityType.collection,
        AnalyticsEntityType.platform,
      },
      relevance: 95,
    ),
    AnalyticsMetricDefinition(
      id: 'publicStreetArtAdded',
      label: 'Street art',
      description: 'Public street art markers added by this profile.',
      icon: Icons.place_outlined,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: userEntity,
      seriesSupported: false,
      relevance: 40,
    ),
    AnalyticsMetricDefinition(
      id: 'arEnabledArtworks',
      label: 'AR artworks',
      description: 'Published artworks with AR enabled.',
      icon: Icons.view_in_ar_outlined,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: {
        AnalyticsEntityType.user,
        AnalyticsEntityType.platform,
      },
      seriesSupported: false,
      relevance: 80,
    ),
    AnalyticsMetricDefinition(
      id: 'collections',
      label: 'Collections',
      description: 'Collections created by this profile.',
      icon: Icons.collections_bookmark_outlined,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: {
        AnalyticsEntityType.user,
        AnalyticsEntityType.platform,
      },
      seriesSupported: false,
      relevance: 45,
    ),
    AnalyticsMetricDefinition(
      id: 'nftsMinted',
      label: 'NFTs minted',
      description: 'Minted NFT artworks.',
      icon: Icons.token_outlined,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: userEntity,
      seriesSupported: false,
      relevance: 55,
    ),
    AnalyticsMetricDefinition(
      id: 'likesGiven',
      label: 'Likes given',
      description: 'Likes this profile has sent.',
      icon: Icons.favorite_border,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: userEntity,
      relevance: 35,
    ),
    AnalyticsMetricDefinition(
      id: 'achievementsUnlocked',
      label: 'Achievements',
      description: 'Unlocked achievements.',
      icon: Icons.emoji_events_outlined,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: userEntity,
      relevance: 40,
    ),
    AnalyticsMetricDefinition(
      id: 'achievementTokensTotal',
      label: 'KUB8 earned',
      description: 'KUB8 earned through achievement rewards.',
      icon: Icons.payments_outlined,
      format: AnalyticsMetricFormat.kub8,
      supportedEntities: userEntity,
      relevance: 70,
    ),
    AnalyticsMetricDefinition(
      id: 'likesReceived',
      label: 'Likes received',
      description: 'Likes received across public work and posts.',
      icon: Icons.favorite_outline,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: userEntity,
      relevance: 85,
    ),
    AnalyticsMetricDefinition(
      id: 'viewsReceived',
      label: 'Views received',
      description: 'Views across public work, posts, events, and exhibitions.',
      icon: Icons.visibility_outlined,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: userEntity,
      supportedGroupBys: {
        AnalyticsGroupBy.source,
        AnalyticsGroupBy.targetType,
      },
      relevance: 100,
    ),
    AnalyticsMetricDefinition(
      id: 'eventsHosted',
      label: 'Events hosted',
      description: 'Events owned or hosted by this profile.',
      icon: Icons.event_available_outlined,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: userEntity,
      relevance: 92,
    ),
    AnalyticsMetricDefinition(
      id: 'visitorsReceived',
      label: 'Visitors',
      description: 'Views on hosted events and exhibitions.',
      icon: Icons.groups_outlined,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: userEntity,
      relevance: 96,
    ),
    AnalyticsMetricDefinition(
      id: 'exhibitions',
      label: 'Exhibitions',
      description: 'Exhibitions this profile participates in.',
      icon: Icons.museum_outlined,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: userEntity,
      relevance: 75,
    ),
    AnalyticsMetricDefinition(
      id: 'exhibitionArtworks',
      label: 'Exhibition artworks',
      description: 'Artworks included in owned exhibitions.',
      icon: Icons.collections_outlined,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: userEntity,
      seriesSupported: false,
      relevance: 70,
    ),
    AnalyticsMetricDefinition(
      id: 'artworksDiscovered',
      label: 'Discoveries',
      description: 'Artworks discovered by this profile.',
      icon: Icons.explore_outlined,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: userEntity,
      scopes: privateOnly,
      relevance: 60,
    ),
    AnalyticsMetricDefinition(
      id: 'arSessions',
      label: 'AR sessions',
      description: 'AR sessions started by this profile.',
      icon: Icons.view_in_ar_outlined,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: userEntity,
      scopes: privateOnly,
      relevance: 65,
    ),
    AnalyticsMetricDefinition(
      id: 'viewsGiven',
      label: 'Views given',
      description: 'Content views by this profile.',
      icon: Icons.remove_red_eye_outlined,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: userEntity,
      scopes: privateOnly,
      seriesSupported: false,
      relevance: 30,
    ),
    AnalyticsMetricDefinition(
      id: 'engagement',
      label: 'Engagement',
      description: 'Weighted likes, comments, shares, and saves.',
      icon: Icons.bolt_outlined,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: {
        AnalyticsEntityType.user,
        AnalyticsEntityType.artwork,
        AnalyticsEntityType.post,
        AnalyticsEntityType.event,
        AnalyticsEntityType.exhibition,
      },
      scopes: privateOnly,
      relevance: 98,
    ),
    AnalyticsMetricDefinition(
      id: 'views',
      label: 'Views',
      description: 'View events for the selected entity.',
      icon: Icons.visibility_outlined,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: {
        AnalyticsEntityType.artwork,
        AnalyticsEntityType.post,
        AnalyticsEntityType.event,
        AnalyticsEntityType.exhibition,
        AnalyticsEntityType.platform,
      },
      supportedGroupBys: {
        AnalyticsGroupBy.source,
        AnalyticsGroupBy.targetType,
      },
      relevance: 100,
    ),
    AnalyticsMetricDefinition(
      id: 'likes',
      label: 'Likes',
      description: 'Likes on the selected entity.',
      icon: Icons.favorite_outline,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: {
        AnalyticsEntityType.artwork,
        AnalyticsEntityType.post,
        AnalyticsEntityType.platform,
      },
      relevance: 82,
    ),
    AnalyticsMetricDefinition(
      id: 'shares',
      label: 'Shares',
      description: 'Share events for the selected entity.',
      icon: Icons.ios_share_outlined,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: {
        AnalyticsEntityType.artwork,
        AnalyticsEntityType.post,
        AnalyticsEntityType.event,
        AnalyticsEntityType.exhibition,
      },
      supportedGroupBys: {AnalyticsGroupBy.source},
      relevance: 70,
    ),
    AnalyticsMetricDefinition(
      id: 'saves',
      label: 'Saves',
      description: 'Saved bookmarks for the selected entity.',
      icon: Icons.bookmark_border,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: contentEntities,
      relevance: 70,
    ),
    AnalyticsMetricDefinition(
      id: 'users',
      label: 'Users',
      description: 'Registered user count.',
      icon: Icons.people_alt_outlined,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: platformEntity,
      seriesSupported: false,
      relevance: 100,
    ),
    AnalyticsMetricDefinition(
      id: 'profiles',
      label: 'Profiles',
      description: 'Public profile count.',
      icon: Icons.badge_outlined,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: platformEntity,
      seriesSupported: false,
      relevance: 80,
    ),
    AnalyticsMetricDefinition(
      id: 'groups',
      label: 'Groups',
      description: 'Public community groups.',
      icon: Icons.groups_2_outlined,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: platformEntity,
      seriesSupported: false,
      relevance: 65,
    ),
    AnalyticsMetricDefinition(
      id: 'follows',
      label: 'Follows',
      description: 'Follow relationships across the platform.',
      icon: Icons.person_add_alt_1_outlined,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: platformEntity,
      relevance: 60,
    ),
    AnalyticsMetricDefinition(
      id: 'daoTotalProposals',
      label: 'Total proposals',
      description: 'Governance proposals created in the DAO.',
      icon: Icons.how_to_vote_outlined,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: daoEntity,
      supportedGroupBys: {AnalyticsGroupBy.targetType},
      defaultGroupBy: AnalyticsGroupBy.targetType,
      relevance: 100,
    ),
    AnalyticsMetricDefinition(
      id: 'daoActiveProposals',
      label: 'Active proposals',
      description: 'Proposals currently open for governance action.',
      icon: Icons.schedule_outlined,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: daoEntity,
      supportedGroupBys: {AnalyticsGroupBy.targetType},
      defaultGroupBy: AnalyticsGroupBy.targetType,
      relevance: 95,
    ),
    AnalyticsMetricDefinition(
      id: 'daoVotesCast',
      label: 'Votes cast',
      description: 'Votes submitted across DAO proposals.',
      icon: Icons.ballot_outlined,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: daoEntity,
      supportedGroupBys: {AnalyticsGroupBy.targetType},
      defaultGroupBy: AnalyticsGroupBy.targetType,
      relevance: 90,
    ),
    AnalyticsMetricDefinition(
      id: 'daoDelegates',
      label: 'Delegates',
      description: 'Delegates available for voting power delegation.',
      icon: Icons.groups_2_outlined,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: daoEntity,
      relevance: 82,
    ),
    AnalyticsMetricDefinition(
      id: 'daoAverageVotingPower',
      label: 'Avg voting power',
      description: 'Average voting power across delegates.',
      icon: Icons.account_balance_wallet_outlined,
      format: AnalyticsMetricFormat.kub8,
      supportedEntities: daoEntity,
      seriesSupported: false,
      relevance: 74,
    ),
    AnalyticsMetricDefinition(
      id: 'daoTreasuryAmount',
      label: 'Treasury',
      description: 'Current DAO treasury value.',
      icon: Icons.account_balance_outlined,
      format: AnalyticsMetricFormat.kub8,
      supportedEntities: daoEntity,
      seriesSupported: false,
      relevance: 88,
    ),
    AnalyticsMetricDefinition(
      id: 'daoTreasuryInflow',
      label: 'Treasury inflow',
      description: 'Positive treasury transactions.',
      icon: Icons.trending_up_outlined,
      format: AnalyticsMetricFormat.kub8,
      supportedEntities: daoEntity,
      supportedGroupBys: {AnalyticsGroupBy.targetType},
      defaultGroupBy: AnalyticsGroupBy.targetType,
      relevance: 68,
    ),
    AnalyticsMetricDefinition(
      id: 'daoTreasuryOutflow',
      label: 'Treasury outflow',
      description: 'Outgoing treasury transactions.',
      icon: Icons.trending_down_outlined,
      format: AnalyticsMetricFormat.kub8,
      supportedEntities: daoEntity,
      supportedGroupBys: {AnalyticsGroupBy.targetType},
      defaultGroupBy: AnalyticsGroupBy.targetType,
      relevance: 66,
    ),
    AnalyticsMetricDefinition(
      id: 'daoRecentTransactions',
      label: 'Recent transactions',
      description: 'Recent DAO treasury and execution activity.',
      icon: Icons.receipt_long_outlined,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: daoEntity,
      supportedGroupBys: {AnalyticsGroupBy.targetType},
      defaultGroupBy: AnalyticsGroupBy.targetType,
      relevance: 60,
    ),
  ];

  static final Map<String, AnalyticsMetricDefinition> _byId =
      Map<String, AnalyticsMetricDefinition>.unmodifiable(
    <String, AnalyticsMetricDefinition>{
      for (final metric in metrics) metric.id: metric,
    },
  );

  static AnalyticsMetricDefinition? byId(String id) {
    return _byId[id.trim()];
  }

  static AnalyticsMetricDefinition requireById(String id) {
    final metric = byId(id);
    if (metric == null) {
      throw ArgumentError.value(id, 'id', 'Unknown analytics metric');
    }
    return metric;
  }

  static List<AnalyticsMetricDefinition> forEntity(
    AnalyticsEntityType entityType, {
    bool includePrivate = true,
  }) {
    final out = metrics
        .where((metric) => metric.supportsEntity(entityType))
        .where((metric) => includePrivate || !metric.privateOnly)
        .toList(growable: false)
      ..sort((a, b) => b.relevance.compareTo(a.relevance));
    return out;
  }

  static bool supportsSeriesFor({
    required AnalyticsMetricDefinition metric,
    required AnalyticsEntityType entityType,
    required AnalyticsScope scope,
  }) {
    if (!metric.seriesSupported || !metric.supportsEntity(entityType)) {
      return false;
    }
    if (!metric.supportsScope(scope)) return false;

    switch (entityType) {
      case AnalyticsEntityType.user:
        if (scope == AnalyticsScope.public) {
          return const <String>{
            'followers',
            'following',
            'posts',
            'artworks',
            'achievementsUnlocked',
            'achievementTokensTotal',
            'likesReceived',
            'viewsReceived',
            'eventsHosted',
            'visitorsReceived',
            'exhibitions',
          }.contains(metric.id);
        }
        return const <String>{
          'followers',
          'following',
          'posts',
          'artworks',
          'likesGiven',
          'achievementsUnlocked',
          'achievementTokensTotal',
          'likesReceived',
          'viewsReceived',
          'eventsHosted',
          'visitorsReceived',
          'exhibitions',
          'artworksDiscovered',
          'arSessions',
          'engagement',
        }.contains(metric.id);
      case AnalyticsEntityType.artwork:
      case AnalyticsEntityType.post:
        return const <String>{
          'views',
          'likes',
          'comments',
          'shares',
          'saves',
          'engagement',
        }.contains(metric.id);
      case AnalyticsEntityType.event:
      case AnalyticsEntityType.exhibition:
        return const <String>{
          'views',
          'shares',
          'engagement',
        }.contains(metric.id);
      case AnalyticsEntityType.dao:
        return const <String>{
          'daoTotalProposals',
          'daoActiveProposals',
          'daoVotesCast',
          'daoDelegates',
          'daoTreasuryInflow',
          'daoTreasuryOutflow',
          'daoRecentTransactions',
        }.contains(metric.id);
      case AnalyticsEntityType.platform:
        return scope == AnalyticsScope.private &&
            const <String>{'views', 'likes', 'follows'}.contains(metric.id);
      case AnalyticsEntityType.collection:
        return false;
    }
  }

  static String formatCompact(num value) {
    final abs = value.abs();
    final sign = value < 0 ? '-' : '';
    if (abs >= 1000000000) {
      return '$sign${(abs / 1000000000).toStringAsFixed(1)}b';
    }
    if (abs >= 1000000) {
      return '$sign${(abs / 1000000).toStringAsFixed(1)}m';
    }
    if (abs >= 1000) {
      return '$sign${(abs / 1000).toStringAsFixed(1)}k';
    }
    return value.round().toString();
  }
}
