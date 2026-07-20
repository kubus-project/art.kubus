import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/analytics_filters_provider.dart';
import 'analytics_entity_registry.dart';
import 'analytics_metric_registry.dart';

enum AnalyticsPresetKind {
  profile,
  artist,
  institution,
  community,
  dao,
  platform,
}

enum AnalyticsRoleRequirement {
  none,
  artist,
  institution,
  admin,
}

class AnalyticsPreset {
  const AnalyticsPreset({
    required this.kind,
    required this.contextKey,
    required this.entityType,
    required this.icon,
    required this.metricIds,
    required this.overviewMetricIds,
    required this.defaultMetricId,
    this.primaryMetricId,
    this.defaultGroupBy,
    this.roleRequirement = AnalyticsRoleRequirement.none,
    this.requiresOwner = false,
    this.allowsPublicView = true,
    this.supportsExport = true,
  });

  final AnalyticsPresetKind kind;
  final String contextKey;
  final AnalyticsEntityType entityType;
  final IconData icon;
  final List<String> metricIds;
  final List<String> overviewMetricIds;
  final String defaultMetricId;
  final String? primaryMetricId;
  final AnalyticsGroupBy? defaultGroupBy;
  final AnalyticsRoleRequirement roleRequirement;
  final bool requiresOwner;
  final bool allowsPublicView;
  final bool supportsExport;

  List<AnalyticsMetricDefinition> get metrics {
    return metricIds
        .map(AnalyticsMetricRegistry.byId)
        .whereType<AnalyticsMetricDefinition>()
        .where((metric) => metric.supportsEntity(entityType))
        .toList(growable: false);
  }

  List<AnalyticsMetricDefinition> get overviewMetrics {
    return overviewMetricIds
        .map(AnalyticsMetricRegistry.byId)
        .whereType<AnalyticsMetricDefinition>()
        .where((metric) => metric.supportsEntity(entityType))
        .toList(growable: false);
  }

  AnalyticsMetricDefinition get defaultMetric {
    final resolved = AnalyticsMetricRegistry.byId(defaultMetricId);
    if (resolved != null && resolved.supportsEntity(entityType)) {
      return resolved;
    }
    return metrics.first;
  }

  String localizedTitle(AppLocalizations l10n) {
    switch (kind) {
      case AnalyticsPresetKind.profile:
        return l10n.analyticsPresetProfileTitle;
      case AnalyticsPresetKind.artist:
        return l10n.analyticsPresetArtistTitle;
      case AnalyticsPresetKind.institution:
        return l10n.analyticsPresetInstitutionTitle;
      case AnalyticsPresetKind.community:
        return l10n.analyticsPresetCommunityTitle;
      case AnalyticsPresetKind.dao:
        return l10n.analyticsPresetDaoTitle;
      case AnalyticsPresetKind.platform:
        return l10n.analyticsPresetPlatformTitle;
    }
  }

  String localizedScopeLabel(AppLocalizations l10n) {
    switch (kind) {
      case AnalyticsPresetKind.profile:
        return l10n.analyticsPresetProfileScopeLabel;
      case AnalyticsPresetKind.artist:
        return l10n.analyticsPresetArtistScopeLabel;
      case AnalyticsPresetKind.institution:
        return l10n.analyticsPresetInstitutionScopeLabel;
      case AnalyticsPresetKind.community:
        return l10n.analyticsPresetCommunityScopeLabel;
      case AnalyticsPresetKind.dao:
        return l10n.analyticsPresetDaoScopeLabel;
      case AnalyticsPresetKind.platform:
        return l10n.analyticsPresetPlatformScopeLabel;
    }
  }

  String localizedSubtitle(AppLocalizations l10n) {
    switch (kind) {
      case AnalyticsPresetKind.profile:
        return l10n.analyticsPresetProfileSubtitle;
      case AnalyticsPresetKind.artist:
        return l10n.analyticsPresetArtistSubtitle;
      case AnalyticsPresetKind.institution:
        return l10n.analyticsPresetInstitutionSubtitle;
      case AnalyticsPresetKind.community:
        return l10n.analyticsPresetCommunitySubtitle;
      case AnalyticsPresetKind.dao:
        return l10n.analyticsPresetDaoSubtitle;
      case AnalyticsPresetKind.platform:
        return l10n.analyticsPresetPlatformSubtitle;
    }
  }
}

class AnalyticsPresets {
  const AnalyticsPresets._();

  static const profile = AnalyticsPreset(
    kind: AnalyticsPresetKind.profile,
    contextKey: AnalyticsFiltersProvider.profileContextKey,
    entityType: AnalyticsEntityType.user,
    icon: Icons.person_outline,
    defaultMetricId: 'viewsReceived',
    overviewMetricIds: <String>[
      'viewsReceived',
      'likesReceived',
      'followers',
      'posts',
    ],
    metricIds: <String>[
      'viewsReceived',
      'likesReceived',
      'followers',
      'following',
      'posts',
      'artworks',
      'engagement',
      'artworksDiscovered',
      'arSessions',
    ],
    requiresOwner: true,
    allowsPublicView: false,
  );

  static const community = AnalyticsPreset(
    kind: AnalyticsPresetKind.community,
    contextKey: AnalyticsFiltersProvider.communityContextKey,
    entityType: AnalyticsEntityType.user,
    icon: Icons.forum_outlined,
    defaultMetricId: 'posts',
    overviewMetricIds: <String>[
      'posts',
      'comments',
      'likesReceived',
      'engagement',
    ],
    metricIds: <String>[
      'posts',
      'comments',
      'likesReceived',
      'viewsReceived',
      'followers',
      'engagement',
    ],
    requiresOwner: true,
    allowsPublicView: false,
  );

  static const artist = AnalyticsPreset(
    kind: AnalyticsPresetKind.artist,
    contextKey: AnalyticsFiltersProvider.artistContextKey,
    entityType: AnalyticsEntityType.user,
    icon: Icons.palette_outlined,
    defaultMetricId: 'viewsReceived',
    overviewMetricIds: <String>[
      'viewsReceived',
      'likesReceived',
      'artworks',
      'achievementTokensTotal',
    ],
    metricIds: <String>[
      'viewsReceived',
      'likesReceived',
      'artworks',
      'arEnabledArtworks',
      'nftsMinted',
      'achievementTokensTotal',
      'arSessions',
      'engagement',
    ],
    roleRequirement: AnalyticsRoleRequirement.artist,
    requiresOwner: true,
    allowsPublicView: false,
  );

  static const institution = AnalyticsPreset(
    kind: AnalyticsPresetKind.institution,
    contextKey: AnalyticsFiltersProvider.institutionContextKey,
    entityType: AnalyticsEntityType.user,
    icon: Icons.account_balance_outlined,
    defaultMetricId: 'viewsReceived',
    defaultGroupBy: AnalyticsGroupBy.targetType,
    overviewMetricIds: <String>[
      'visitorsReceived',
      'eventsHosted',
      'exhibitions',
      'achievementTokensTotal',
    ],
    metricIds: <String>[
      'viewsReceived',
      'visitorsReceived',
      'eventsHosted',
      'exhibitions',
      'exhibitionArtworks',
      'achievementTokensTotal',
      'engagement',
    ],
    roleRequirement: AnalyticsRoleRequirement.institution,
    requiresOwner: true,
    allowsPublicView: false,
  );

  static const platform = AnalyticsPreset(
    kind: AnalyticsPresetKind.platform,
    contextKey: 'platform',
    entityType: AnalyticsEntityType.platform,
    icon: Icons.admin_panel_settings_outlined,
    defaultMetricId: 'views',
    overviewMetricIds: <String>[
      'users',
      'profiles',
      'artworks',
      'views',
    ],
    metricIds: <String>[
      'views',
      'likes',
      'follows',
    ],
    roleRequirement: AnalyticsRoleRequirement.admin,
    requiresOwner: false,
    allowsPublicView: false,
  );

  static const dao = AnalyticsPreset(
    kind: AnalyticsPresetKind.dao,
    contextKey: AnalyticsFiltersProvider.daoContextKey,
    entityType: AnalyticsEntityType.dao,
    icon: Icons.how_to_vote_outlined,
    defaultMetricId: 'daoTotalProposals',
    overviewMetricIds: <String>[
      'daoTotalProposals',
      'daoActiveProposals',
      'daoVotesCast',
      'daoTreasuryAmount',
    ],
    metricIds: <String>[
      'daoTotalProposals',
      'daoActiveProposals',
      'daoVotesCast',
      'daoDelegates',
      'daoAverageVotingPower',
      'daoTreasuryAmount',
      'daoTreasuryInflow',
      'daoTreasuryOutflow',
      'daoRecentTransactions',
    ],
    supportsExport: false,
  );

  static const values = <AnalyticsPreset>[
    profile,
    artist,
    institution,
    community,
    dao,
    platform,
  ];

  static AnalyticsPreset byKind(AnalyticsPresetKind kind) {
    for (final preset in values) {
      if (preset.kind == kind) return preset;
    }
    return profile;
  }

  static AnalyticsPresetKind? tryParseKind(String raw) {
    final normalized = raw.trim().toLowerCase();
    for (final value in AnalyticsPresetKind.values) {
      if (value.name == normalized) return value;
    }
    if (normalized == 'home') return AnalyticsPresetKind.profile;
    if (normalized == 'governance') return AnalyticsPresetKind.dao;
    return null;
  }
}
