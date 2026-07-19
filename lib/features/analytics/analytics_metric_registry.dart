import 'package:flutter/material.dart';

import '../../utils/app_color_utils.dart';
import '../../l10n/app_localizations.dart';
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

  String localizedLabel(AppLocalizations l10n) {
    switch (id) {
      case 'followers':
        return l10n.analyticsMetricFollowersLabel;
      case 'following':
        return l10n.analyticsMetricFollowingLabel;
      case 'posts':
        return l10n.analyticsMetricPostsLabel;
      case 'comments':
        return l10n.analyticsMetricCommentsLabel;
      case 'artworks':
        return l10n.analyticsMetricArtworksLabel;
      case 'publicStreetArtAdded':
        return l10n.analyticsMetricPublicStreetArtAddedLabel;
      case 'arEnabledArtworks':
        return l10n.analyticsMetricArEnabledArtworksLabel;
      case 'collections':
        return l10n.analyticsMetricCollectionsLabel;
      case 'nftsMinted':
        return l10n.analyticsMetricArchiveObjectsCreatedLabel;
      case 'likesGiven':
        return l10n.analyticsMetricLikesGivenLabel;
      case 'achievementsUnlocked':
        return l10n.analyticsMetricAchievementsUnlockedLabel;
      case 'achievementTokensTotal':
        return l10n.analyticsMetricKub8RecognitionLabel;
      case 'likesReceived':
        return l10n.analyticsMetricLikesReceivedLabel;
      case 'viewsReceived':
        return l10n.analyticsMetricViewsReceivedLabel;
      case 'eventsHosted':
        return l10n.analyticsMetricEventsHostedLabel;
      case 'visitorsReceived':
        return l10n.analyticsMetricVisitorsReceivedLabel;
      case 'exhibitions':
        return l10n.analyticsMetricExhibitionsLabel;
      case 'exhibitionArtworks':
        return l10n.analyticsMetricExhibitionArtworksLabel;
      case 'artworksDiscovered':
        return l10n.analyticsMetricArtworksDiscoveredLabel;
      case 'arSessions':
        return l10n.analyticsMetricArSessionsLabel;
      case 'viewsGiven':
        return l10n.analyticsMetricViewsGivenLabel;
      case 'engagement':
        return l10n.analyticsMetricEngagementLabel;
      case 'views':
        return l10n.analyticsMetricViewsLabel;
      case 'likes':
        return l10n.analyticsMetricLikesLabel;
      case 'shares':
        return l10n.analyticsMetricSharesLabel;
      case 'saves':
        return l10n.analyticsMetricSavesLabel;
      case 'users':
        return l10n.analyticsMetricUsersLabel;
      case 'profiles':
        return l10n.analyticsMetricProfilesLabel;
      case 'groups':
        return l10n.analyticsMetricGroupsLabel;
      case 'follows':
        return l10n.analyticsMetricFollowsLabel;
      case 'daoTotalProposals':
        return l10n.analyticsMetricDaoTotalProposalsLabel;
      case 'daoActiveProposals':
        return l10n.analyticsMetricDaoActiveProposalsLabel;
      case 'daoVotesCast':
        return l10n.analyticsMetricDaoVotesCastLabel;
      case 'daoDelegates':
        return l10n.analyticsMetricDaoDelegatesLabel;
      case 'daoAverageVotingPower':
        return l10n.analyticsMetricDaoAverageVotingPowerLabel;
      case 'daoTreasuryAmount':
        return l10n.analyticsMetricDaoTreasuryAmountLabel;
      case 'daoTreasuryInflow':
        return l10n.analyticsMetricDaoTreasuryInflowLabel;
      case 'daoTreasuryOutflow':
        return l10n.analyticsMetricDaoTreasuryOutflowLabel;
      case 'daoRecentTransactions':
        return l10n.analyticsMetricDaoRecentTransactionsLabel;
    }
    return id;
  }

  String localizedDescription(AppLocalizations l10n) {
    switch (id) {
      case 'followers':
        return l10n.analyticsMetricFollowersDescription;
      case 'following':
        return l10n.analyticsMetricFollowingDescription;
      case 'posts':
        return l10n.analyticsMetricPostsDescription;
      case 'comments':
        return l10n.analyticsMetricCommentsDescription;
      case 'artworks':
        return l10n.analyticsMetricArtworksDescription;
      case 'publicStreetArtAdded':
        return l10n.analyticsMetricPublicStreetArtAddedDescription;
      case 'arEnabledArtworks':
        return l10n.analyticsMetricArEnabledArtworksDescription;
      case 'collections':
        return l10n.analyticsMetricCollectionsDescription;
      case 'nftsMinted':
        return l10n.analyticsMetricArchiveObjectsCreatedDescription;
      case 'likesGiven':
        return l10n.analyticsMetricLikesGivenDescription;
      case 'achievementsUnlocked':
        return l10n.analyticsMetricAchievementsUnlockedDescription;
      case 'achievementTokensTotal':
        return l10n.analyticsMetricKub8RecognitionDescription;
      case 'likesReceived':
        return l10n.analyticsMetricLikesReceivedDescription;
      case 'viewsReceived':
        return l10n.analyticsMetricViewsReceivedDescription;
      case 'eventsHosted':
        return l10n.analyticsMetricEventsHostedDescription;
      case 'visitorsReceived':
        return l10n.analyticsMetricVisitorsReceivedDescription;
      case 'exhibitions':
        return l10n.analyticsMetricExhibitionsDescription;
      case 'exhibitionArtworks':
        return l10n.analyticsMetricExhibitionArtworksDescription;
      case 'artworksDiscovered':
        return l10n.analyticsMetricArtworksDiscoveredDescription;
      case 'arSessions':
        return l10n.analyticsMetricArSessionsDescription;
      case 'viewsGiven':
        return l10n.analyticsMetricViewsGivenDescription;
      case 'engagement':
        return l10n.analyticsMetricEngagementDescription;
      case 'views':
        return l10n.analyticsMetricViewsDescription;
      case 'likes':
        return l10n.analyticsMetricLikesDescription;
      case 'shares':
        return l10n.analyticsMetricSharesDescription;
      case 'saves':
        return l10n.analyticsMetricSavesDescription;
      case 'users':
        return l10n.analyticsMetricUsersDescription;
      case 'profiles':
        return l10n.analyticsMetricProfilesDescription;
      case 'groups':
        return l10n.analyticsMetricGroupsDescription;
      case 'follows':
        return l10n.analyticsMetricFollowsDescription;
      case 'daoTotalProposals':
        return l10n.analyticsMetricDaoTotalProposalsDescription;
      case 'daoActiveProposals':
        return l10n.analyticsMetricDaoActiveProposalsDescription;
      case 'daoVotesCast':
        return l10n.analyticsMetricDaoVotesCastDescription;
      case 'daoDelegates':
        return l10n.analyticsMetricDaoDelegatesDescription;
      case 'daoAverageVotingPower':
        return l10n.analyticsMetricDaoAverageVotingPowerDescription;
      case 'daoTreasuryAmount':
        return l10n.analyticsMetricDaoTreasuryAmountDescription;
      case 'daoTreasuryInflow':
        return l10n.analyticsMetricDaoTreasuryInflowDescription;
      case 'daoTreasuryOutflow':
        return l10n.analyticsMetricDaoTreasuryOutflowDescription;
      case 'daoRecentTransactions':
        return l10n.analyticsMetricDaoRecentTransactionsDescription;
    }
    return id;
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
      icon: Icons.people_outline,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: userEntity,
      relevance: 90,
    ),
    AnalyticsMetricDefinition(
      id: 'following',
      icon: Icons.person_add_alt_1_outlined,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: userEntity,
      relevance: 50,
    ),
    AnalyticsMetricDefinition(
      id: 'posts',
      icon: Icons.forum_outlined,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: userEntity,
      relevance: 80,
    ),
    AnalyticsMetricDefinition(
      id: 'comments',
      icon: Icons.chat_bubble_outline,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: userEntity,
      seriesSupported: false,
      relevance: 35,
    ),
    AnalyticsMetricDefinition(
      id: 'artworks',
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
      icon: Icons.place_outlined,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: userEntity,
      seriesSupported: false,
      relevance: 40,
    ),
    AnalyticsMetricDefinition(
      id: 'arEnabledArtworks',
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
      icon: Icons.token_outlined,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: userEntity,
      seriesSupported: false,
      relevance: 55,
    ),
    AnalyticsMetricDefinition(
      id: 'likesGiven',
      icon: Icons.favorite_border,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: userEntity,
      relevance: 35,
    ),
    AnalyticsMetricDefinition(
      id: 'achievementsUnlocked',
      icon: Icons.emoji_events_outlined,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: userEntity,
      relevance: 40,
    ),
    AnalyticsMetricDefinition(
      id: 'achievementTokensTotal',
      icon: Icons.payments_outlined,
      format: AnalyticsMetricFormat.kub8,
      supportedEntities: userEntity,
      relevance: 70,
    ),
    AnalyticsMetricDefinition(
      id: 'likesReceived',
      icon: Icons.favorite_outline,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: userEntity,
      relevance: 85,
    ),
    AnalyticsMetricDefinition(
      id: 'viewsReceived',
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
      icon: Icons.event_available_outlined,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: userEntity,
      relevance: 92,
    ),
    AnalyticsMetricDefinition(
      id: 'visitorsReceived',
      icon: Icons.groups_outlined,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: userEntity,
      relevance: 96,
    ),
    AnalyticsMetricDefinition(
      id: 'exhibitions',
      icon: AppColorUtils.exhibitionIcon,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: userEntity,
      relevance: 75,
    ),
    AnalyticsMetricDefinition(
      id: 'exhibitionArtworks',
      icon: AppColorUtils.exhibitionIcon,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: userEntity,
      seriesSupported: false,
      relevance: 70,
    ),
    AnalyticsMetricDefinition(
      id: 'artworksDiscovered',
      icon: Icons.explore_outlined,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: userEntity,
      scopes: privateOnly,
      relevance: 60,
    ),
    AnalyticsMetricDefinition(
      id: 'arSessions',
      icon: Icons.view_in_ar_outlined,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: userEntity,
      scopes: privateOnly,
      relevance: 65,
    ),
    AnalyticsMetricDefinition(
      id: 'viewsGiven',
      icon: Icons.remove_red_eye_outlined,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: userEntity,
      scopes: privateOnly,
      seriesSupported: false,
      relevance: 30,
    ),
    AnalyticsMetricDefinition(
      id: 'engagement',
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
      icon: Icons.bookmark_border,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: contentEntities,
      relevance: 70,
    ),
    AnalyticsMetricDefinition(
      id: 'users',
      icon: Icons.people_alt_outlined,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: platformEntity,
      seriesSupported: false,
      relevance: 100,
    ),
    AnalyticsMetricDefinition(
      id: 'profiles',
      icon: Icons.badge_outlined,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: platformEntity,
      seriesSupported: false,
      relevance: 80,
    ),
    AnalyticsMetricDefinition(
      id: 'groups',
      icon: Icons.groups_2_outlined,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: platformEntity,
      seriesSupported: false,
      relevance: 65,
    ),
    AnalyticsMetricDefinition(
      id: 'follows',
      icon: Icons.person_add_alt_1_outlined,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: platformEntity,
      relevance: 60,
    ),
    AnalyticsMetricDefinition(
      id: 'daoTotalProposals',
      icon: Icons.how_to_vote_outlined,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: daoEntity,
      supportedGroupBys: {AnalyticsGroupBy.targetType},
      defaultGroupBy: AnalyticsGroupBy.targetType,
      relevance: 100,
    ),
    AnalyticsMetricDefinition(
      id: 'daoActiveProposals',
      icon: Icons.schedule_outlined,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: daoEntity,
      supportedGroupBys: {AnalyticsGroupBy.targetType},
      defaultGroupBy: AnalyticsGroupBy.targetType,
      relevance: 95,
    ),
    AnalyticsMetricDefinition(
      id: 'daoVotesCast',
      icon: Icons.ballot_outlined,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: daoEntity,
      supportedGroupBys: {AnalyticsGroupBy.targetType},
      defaultGroupBy: AnalyticsGroupBy.targetType,
      relevance: 90,
    ),
    AnalyticsMetricDefinition(
      id: 'daoDelegates',
      icon: Icons.groups_2_outlined,
      format: AnalyticsMetricFormat.compact,
      supportedEntities: daoEntity,
      relevance: 82,
    ),
    AnalyticsMetricDefinition(
      id: 'daoAverageVotingPower',
      icon: Icons.account_balance_wallet_outlined,
      format: AnalyticsMetricFormat.kub8,
      supportedEntities: daoEntity,
      seriesSupported: false,
      relevance: 74,
    ),
    AnalyticsMetricDefinition(
      id: 'daoTreasuryAmount',
      icon: Icons.account_balance_outlined,
      format: AnalyticsMetricFormat.kub8,
      supportedEntities: daoEntity,
      seriesSupported: false,
      relevance: 88,
    ),
    AnalyticsMetricDefinition(
      id: 'daoTreasuryInflow',
      icon: Icons.trending_up_outlined,
      format: AnalyticsMetricFormat.kub8,
      supportedEntities: daoEntity,
      supportedGroupBys: {AnalyticsGroupBy.targetType},
      defaultGroupBy: AnalyticsGroupBy.targetType,
      relevance: 68,
    ),
    AnalyticsMetricDefinition(
      id: 'daoTreasuryOutflow',
      icon: Icons.trending_down_outlined,
      format: AnalyticsMetricFormat.kub8,
      supportedEntities: daoEntity,
      supportedGroupBys: {AnalyticsGroupBy.targetType},
      defaultGroupBy: AnalyticsGroupBy.targetType,
      relevance: 66,
    ),
    AnalyticsMetricDefinition(
      id: 'daoRecentTransactions',
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
