import 'package:flutter/material.dart';

import '../../utils/kubus_color_roles.dart';

class AnalyticsMetricColors {
  const AnalyticsMetricColors._();

  static Color resolve(BuildContext context, String metricId) {
    final scheme = Theme.of(context).colorScheme;
    final roles = KubusColorRoles.of(context);
    switch (metricId) {
      case 'likes':
      case 'likesGiven':
      case 'likesReceived':
        return roles.likeAction;
      case 'followers':
      case 'following':
      case 'visitorsReceived':
      case 'users':
      case 'activeUsers':
      case 'groups':
        return roles.statBlue;
      case 'views':
      case 'viewsGiven':
      case 'viewsReceived':
      case 'arSessions':
      case 'arEnabledArtworks':
        return roles.statTeal;
      case 'posts':
      case 'comments':
      case 'shares':
      case 'eventsHosted':
      case 'exhibitions':
        return roles.statCoral;
      case 'artworks':
      case 'publicStreetArtAdded':
      case 'collections':
      case 'exhibitionArtworks':
        return roles.statGreen;
      case 'achievementsUnlocked':
      case 'achievementTokensTotal':
      case 'nftsMinted':
      case 'engagement':
        return roles.statAmber;
      case 'saves':
      case 'bookmarks':
        return roles.warningAction;
      default:
        return scheme.primary;
    }
  }
}
