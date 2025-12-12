import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/map_screen.dart';
import '../screens/art/ar_screen.dart';
import '../screens/community/community_screen.dart';
import '../screens/community/profile_screen.dart';
import '../screens/web3/marketplace/marketplace.dart';
import '../screens/web3/wallet/wallet_home.dart';
import '../screens/settings_screen.dart';
import '../screens/activity/advanced_analytics_screen.dart';
import '../screens/activity/advanced_stats_screen.dart';
import '../screens/web3/achievements/achievements_page.dart';
import '../screens/web3/dao/governance_hub.dart';
import '../screens/web3/artist/artist_studio.dart';
import '../screens/web3/institution/institution_hub.dart';

@immutable
class ScreenDefinition {
  final String name;
  final IconData icon;

  const ScreenDefinition({
    required this.name,
    required this.icon,
  });
}

@immutable
class QuickActionScreen {
  final String key;
  final String name;
  final IconData icon;
  final int visitCount;

  const QuickActionScreen({
    required this.key,
    required this.name,
    required this.icon,
    required this.visitCount,
  });
}

class NavigationProvider with ChangeNotifier {
  static const String _visitCountKey = 'screen_visit_counts';
  static const String _lastVisitKey = 'screen_last_visit_times';
  static const Duration _visitDecayDuration = Duration(hours: 24);
  
  Map<String, int> _visitCounts = {};
  Map<String, DateTime> _lastVisitTimes = {};
  List<String> _frequentScreens = [];

  Map<String, int> get visitCounts => _visitCounts;
  List<String> get frequentScreens => _frequentScreens;

  // Screen definitions with their display names and navigation actions
  static const Map<String, ScreenDefinition> screenDefinitions = {
    'ar': ScreenDefinition(name: 'Create AR', icon: Icons.add_box),
    'map': ScreenDefinition(name: 'Explore Map', icon: Icons.explore),
    'community': ScreenDefinition(name: 'Community', icon: Icons.people),
    'profile': ScreenDefinition(name: 'Profile', icon: Icons.person),
    'marketplace': ScreenDefinition(name: 'Marketplace', icon: Icons.store),
    'wallet': ScreenDefinition(name: 'Wallet', icon: Icons.account_balance_wallet),
    'analytics': ScreenDefinition(name: 'Analytics', icon: Icons.analytics),
    'settings': ScreenDefinition(name: 'Settings', icon: Icons.settings),
    'stats': ScreenDefinition(name: 'My Stats', icon: Icons.bar_chart),
    'achievements': ScreenDefinition(name: 'Achievements', icon: Icons.emoji_events),
    'dao_hub': ScreenDefinition(name: 'DAO Hub', icon: Icons.how_to_vote),
    'studio': ScreenDefinition(name: 'Artist Studio', icon: Icons.palette),
    'institution_hub': ScreenDefinition(name: 'Institution Hub', icon: Icons.location_city),
  };

  Future<void> initialize() async {
    await _loadVisitCounts();
    _applyVisitDecay();
    _updateFrequentScreens();
  }

  /// Apply decay to visit counts - decrement counts for visits older than 24h
  void _applyVisitDecay() {
    final now = DateTime.now();
    final keysToDecay = <String>[];
    
    for (final entry in _lastVisitTimes.entries) {
      final timeSinceVisit = now.difference(entry.value);
      if (timeSinceVisit > _visitDecayDuration) {
        keysToDecay.add(entry.key);
      }
    }
    
    for (final key in keysToDecay) {
      final currentCount = _visitCounts[key] ?? 0;
      if (currentCount > 0) {
        // Decay by 1 for each 24h period elapsed
        final periodsElapsed = now.difference(_lastVisitTimes[key]!).inHours ~/ 24;
        final newCount = (currentCount - periodsElapsed).clamp(0, currentCount);
        if (newCount <= 0) {
          _visitCounts.remove(key);
          _lastVisitTimes.remove(key);
        } else {
          _visitCounts[key] = newCount;
        }
      }
    }
    
    _saveVisitCounts();
  }

  Future<void> _loadVisitCounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load visit counts
      final visitCountsJson = prefs.getString(_visitCountKey);
      if (visitCountsJson != null) {
        final Map<String, dynamic> decoded = {};
        visitCountsJson.split(',').forEach((entry) {
          final parts = entry.split(':');
          if (parts.length == 2) {
            decoded[parts[0]] = int.tryParse(parts[1]) ?? 0;
          }
        });
        _visitCounts = decoded.cast<String, int>();
      }
      
      // Load last visit times
      final lastVisitJson = prefs.getString(_lastVisitKey);
      if (lastVisitJson != null) {
        final Map<String, DateTime> decoded = {};
        lastVisitJson.split(',').forEach((entry) {
          final parts = entry.split(':');
          if (parts.length == 2) {
            final timestamp = int.tryParse(parts[1]);
            if (timestamp != null) {
              decoded[parts[0]] = DateTime.fromMillisecondsSinceEpoch(timestamp);
            }
          }
        });
        _lastVisitTimes = decoded;
      }
    } catch (e) {
      _visitCounts = {};
      _lastVisitTimes = {};
    }
  }

  Future<void> _saveVisitCounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save visit counts
      final visitCountsString = _visitCounts.entries
          .map((entry) => '${entry.key}:${entry.value}')
          .join(',');
      await prefs.setString(_visitCountKey, visitCountsString);
      
      // Save last visit times
      final lastVisitString = _lastVisitTimes.entries
          .map((entry) => '${entry.key}:${entry.value.millisecondsSinceEpoch}')
          .join(',');
      await prefs.setString(_lastVisitKey, lastVisitString);
    } catch (e) {
      // Handle error silently
    }
  }

  /// Clear all visit data - useful for resetting quick actions
  Future<void> clearVisitData() async {
    _visitCounts.clear();
    _lastVisitTimes.clear();
    _frequentScreens.clear();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_visitCountKey);
      await prefs.remove(_lastVisitKey);
    } catch (e) {
      // Handle error silently
    }
    
    notifyListeners();
  }

  void trackScreenVisit(String screenKey) {
    if (screenDefinitions.containsKey(screenKey)) {
      _visitCounts[screenKey] = (_visitCounts[screenKey] ?? 0) + 1;
      _lastVisitTimes[screenKey] = DateTime.now();
      _updateFrequentScreens();
      _saveVisitCounts();
      notifyListeners();
    }
  }

  void _updateFrequentScreens() {
    // Sort screens by MOST RECENT visit time (not by count)
    final sortedEntries = _lastVisitTimes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)); // Most recent first
    
    _frequentScreens = sortedEntries
        .take(4)
        .map((entry) => entry.key)
        .where((key) => screenDefinitions.containsKey(key))
        .toList();
    
    // If we don't have enough recent screens, fill with defaults
    final defaultScreens = ['ar', 'map', 'community', 'profile'];
    for (String defaultScreen in defaultScreens) {
      if (_frequentScreens.length < 4 && !_frequentScreens.contains(defaultScreen)) {
        _frequentScreens.add(defaultScreen);
      }
    }
    
    // Ensure we have exactly 4 screens
    _frequentScreens = _frequentScreens.take(4).toList();
  }

  List<QuickActionScreen> getFrequentScreensData() {
    return _frequentScreens
        .where((key) => screenDefinitions.containsKey(key))
        .map((screenKey) {
      final definition = screenDefinitions[screenKey]!;
      return QuickActionScreen(
        key: screenKey,
        name: definition.name,
        icon: definition.icon,
        visitCount: _visitCounts[screenKey] ?? 0,
      );
    }).toList();
  }

  /// Return only visited screens as quick actions, sorted by most recent.
  /// Cards only appear once you visit them, and disappear after 24h of inactivity.
  List<QuickActionScreen> getQuickActionScreens({int maxItems = 12}) {
    // Only include screens that have been visited (have visit count > 0)
    final visitedScreens = _visitCounts.entries
        .where((e) => e.value > 0 && screenDefinitions.containsKey(e.key))
        .map((e) => e.key)
        .toList();
    
    // Sort by most recent visit time
    visitedScreens.sort((a, b) {
      final aTime = _lastVisitTimes[a] ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = _lastVisitTimes[b] ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    return visitedScreens.take(maxItems).map((key) {
      final definition = screenDefinitions[key]!;
      return QuickActionScreen(
        key: key,
        name: definition.name,
        icon: definition.icon,
        visitCount: _visitCounts[key] ?? 0,
      );
    }).toList();
  }

  void navigateToScreen(BuildContext context, String screenKey) {
    trackScreenVisit(screenKey);

    Widget? destination;
    switch (screenKey) {
      case 'map':
        destination = const MapScreen();
        break;
      case 'ar':
        destination = const ARScreen();
        break;
      case 'community':
        destination = const CommunityScreen();
        break;
      case 'profile':
        destination = const ProfileScreen();
        break;
      case 'marketplace':
        destination = const Marketplace();
        break;
      case 'wallet':
        destination = const WalletHome();
        break;
      case 'settings':
        destination = const SettingsScreen();
        break;
      case 'analytics':
        destination = const AdvancedAnalyticsScreen(statType: 'Engagement');
        break;
      case 'stats':
        destination = const AdvancedStatsScreen(statType: 'Engagement');
        break;
      case 'achievements':
        destination = AchievementsPage();
        break;
      case 'dao_hub':
        destination = const GovernanceHub();
        break;
      case 'studio':
        destination = const ArtistStudio();
        break;
      case 'institution_hub':
        destination = const InstitutionHub();
        break;
    }

    if (destination != null) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => destination!));
      return;
    }

    final definition = screenDefinitions[screenKey];
    if (definition == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Unable to navigate to ${definition.name}')),
    );
  }

}
