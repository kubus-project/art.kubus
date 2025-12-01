import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NavigationProvider with ChangeNotifier {
  static const String _visitCountKey = 'screen_visit_counts';
  static const String _lastVisitKey = 'screen_last_visit_times';
  
  Map<String, int> _visitCounts = {};
  Map<String, DateTime> _lastVisitTimes = {};
  List<String> _frequentScreens = [];

  Map<String, int> get visitCounts => _visitCounts;
  List<String> get frequentScreens => _frequentScreens;

  // Screen definitions with their display names and navigation actions
  static const Map<String, Map<String, dynamic>> screenDefinitions = {
    'ar': {
      'name': 'Create AR',
      'icon': Icons.add_box,
      'color': Color(0xFF6C63FF),
      'route': '/ar',
    },
    'map': {
      'name': 'Explore Map',
      'icon': Icons.explore,
      'color': Color(0xFF00D4AA),
      'tabIndex': 0,
    },
    'community': {
      'name': 'Community',
      'icon': Icons.people,
      'color': Color(0xFFFFD93D),
      'tabIndex': 3,
    },
    'profile': {
      'name': 'Profile',
      'icon': Icons.person,
      'color': Color(0xFF9C27B0),
      'tabIndex': 4,
    },
    'marketplace': {
      'name': 'Marketplace',
      'icon': Icons.store,
      'color': Color(0xFFFF6B6B),
      'route': '/marketplace',
    },
    'wallet': {
      'name': 'Wallet',
      'icon': Icons.account_balance_wallet,
      'color': Color(0xFF4ECDC4),
      'route': '/wallet',
    },
    'analytics': {
      'name': 'Analytics',
      'icon': Icons.analytics,
      'color': Color(0xFF2196F3),
      'action': 'analytics',
    },
    'settings': {
      'name': 'Settings',
      'icon': Icons.settings,
      'color': Color(0xFF757575),
      'tabIndex': 5,
    },
    'stats': {
      'name': 'My Stats',
      'icon': Icons.bar_chart,
      'color': Color(0xFF4CAF50),
      'action': 'stats',
    },
    'achievements': {
      'name': 'Achievements',
      'icon': Icons.emoji_events,
      'color': Color(0xFFFFC107),
      'action': 'achievements',
    },
    'dao_hub': {
      'name': 'DAO Hub',
      'icon': Icons.how_to_vote,
      'color': Color(0xFF10B981),
      'action': 'dao',
    },
    'studio': {
      'name': 'Artist Studio',
      'icon': Icons.palette,
      'color': Color(0xFFF59E0B),
      'action': 'artist_studio',
    },
    'institution_hub': {
      'name': 'Institution Hub',
      'icon': Icons.location_city,
      'color': Color(0xFF667EEA),
      'action': 'institution_hub',
    },
  };

  Future<void> initialize() async {
    await _loadVisitCounts();
    _updateFrequentScreens();
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

  List<Map<String, dynamic>> getFrequentScreensData() {
    return _frequentScreens.map((screenKey) {
      final definition = screenDefinitions[screenKey]!;
      return {
        'key': screenKey,
        'name': definition['name'],
        'icon': definition['icon'],
        'color': definition['color'],
        'visitCount': _visitCounts[screenKey] ?? 0,
      };
    }).toList();
  }

  void navigateToScreen(BuildContext context, String screenKey) {
    trackScreenVisit(screenKey);
    
    final definition = screenDefinitions[screenKey];
    if (definition == null) return;

    if (definition.containsKey('route')) {
      Navigator.pushNamed(context, definition['route']);
    } else if (definition.containsKey('tabIndex')) {
      // Switch to specific tab using DefaultTabController
      try {
        final tabController = DefaultTabController.of(context);
        tabController.animateTo(definition['tabIndex'] as int);
      } catch (e) {
        // If DefaultTabController is not available, show a message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to navigate to ${definition['name']}')),
        );
      }
    } else if (definition.containsKey('action')) {
      // Handle custom actions
      _handleCustomAction(context, definition['action']);
    }
  }

  void _handleCustomAction(BuildContext context, String action) {
    switch (action) {
      case 'analytics':
        Navigator.pushNamed(context, '/advanced_analytics');
        break;
      case 'stats':
        Navigator.pushNamed(context, '/advanced_stats');
        break;
      case 'achievements':
        Navigator.pushNamed(context, '/achievements');
        break;
      case 'dao':
        Navigator.pushNamed(context, '/dao');
        break;
      case 'artist_studio':
        Navigator.pushNamed(context, '/artist_studio');
        break;
      case 'institution_hub':
        Navigator.pushNamed(context, '/institution_hub');
        break;
      default:
        // Fallback to showing a snackbar or dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$action feature coming soon!')),
        );
    }
  }
}
