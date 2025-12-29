import 'package:flutter/foundation.dart';

class AnalyticsFiltersProvider extends ChangeNotifier {
  static const List<String> allowedTimeframes = <String>['7d', '30d', '90d', '1y'];

  String _artistTimeframe = '30d';
  String _institutionTimeframe = '30d';

  String get artistTimeframe => _artistTimeframe;
  String get institutionTimeframe => _institutionTimeframe;

  void setArtistTimeframe(String timeframe) {
    final normalized = timeframe.trim().toLowerCase();
    if (!allowedTimeframes.contains(normalized)) return;
    if (_artistTimeframe == normalized) return;
    _artistTimeframe = normalized;
    notifyListeners();
  }

  void setInstitutionTimeframe(String timeframe) {
    final normalized = timeframe.trim().toLowerCase();
    if (!allowedTimeframes.contains(normalized)) return;
    if (_institutionTimeframe == normalized) return;
    _institutionTimeframe = normalized;
    notifyListeners();
  }
}

