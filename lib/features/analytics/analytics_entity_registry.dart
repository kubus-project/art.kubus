import '../../l10n/app_localizations.dart';

enum AnalyticsEntityType {
  user,
  artwork,
  collection,
  post,
  event,
  exhibition,
  dao,
  platform,
}

enum AnalyticsScope {
  public,
  private,
}

enum AnalyticsGroupBy {
  source,
  targetType,
}

extension AnalyticsEntityTypeX on AnalyticsEntityType {
  String get apiValue {
    switch (this) {
      case AnalyticsEntityType.user:
        return 'user';
      case AnalyticsEntityType.artwork:
        return 'artwork';
      case AnalyticsEntityType.collection:
        return 'collection';
      case AnalyticsEntityType.post:
        return 'post';
      case AnalyticsEntityType.event:
        return 'event';
      case AnalyticsEntityType.exhibition:
        return 'exhibition';
      case AnalyticsEntityType.dao:
        return 'dao';
      case AnalyticsEntityType.platform:
        return 'platform';
    }
  }
}

extension AnalyticsScopeX on AnalyticsScope {
  String get apiValue {
    switch (this) {
      case AnalyticsScope.public:
        return 'public';
      case AnalyticsScope.private:
        return 'private';
    }
  }

  String localizedLabel(AppLocalizations l10n) {
    switch (this) {
      case AnalyticsScope.public:
        return l10n.analyticsScopePublicLabel;
      case AnalyticsScope.private:
        return l10n.analyticsScopePrivateLabel;
    }
  }
}

extension AnalyticsGroupByX on AnalyticsGroupBy {
  String get apiValue {
    switch (this) {
      case AnalyticsGroupBy.source:
        return 'source';
      case AnalyticsGroupBy.targetType:
        return 'targetType';
    }
  }
}

class AnalyticsEntityRegistry {
  const AnalyticsEntityRegistry._();

  static const values = AnalyticsEntityType.values;

  static AnalyticsEntityType? tryParse(String raw) {
    final normalized = raw.trim().toLowerCase();
    for (final value in AnalyticsEntityType.values) {
      if (value.apiValue == normalized) return value;
    }
    if (normalized == 'profile') return AnalyticsEntityType.user;
    if (normalized == 'community_post' || normalized == 'communitypost') {
      return AnalyticsEntityType.post;
    }
    if (normalized == 'governance') return AnalyticsEntityType.dao;
    return null;
  }
}
