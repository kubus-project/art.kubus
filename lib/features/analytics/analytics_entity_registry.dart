enum AnalyticsEntityType {
  user,
  artwork,
  collection,
  post,
  event,
  exhibition,
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
      case AnalyticsEntityType.platform:
        return 'platform';
    }
  }

  String get label {
    switch (this) {
      case AnalyticsEntityType.user:
        return 'Profile';
      case AnalyticsEntityType.artwork:
        return 'Artwork';
      case AnalyticsEntityType.collection:
        return 'Collection';
      case AnalyticsEntityType.post:
        return 'Community post';
      case AnalyticsEntityType.event:
        return 'Event';
      case AnalyticsEntityType.exhibition:
        return 'Exhibition';
      case AnalyticsEntityType.platform:
        return 'Platform';
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

  String get label {
    switch (this) {
      case AnalyticsScope.public:
        return 'Public';
      case AnalyticsScope.private:
        return 'Private';
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

  String get label {
    switch (this) {
      case AnalyticsGroupBy.source:
        return 'Source';
      case AnalyticsGroupBy.targetType:
        return 'Target type';
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
    return null;
  }
}
