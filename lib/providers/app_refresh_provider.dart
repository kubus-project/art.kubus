import 'package:flutter/material.dart';

/// App wide refresh provider to notify components to refresh their data.
class AppRefreshProvider extends ChangeNotifier {
  int _globalVersion = 0;
  int _notificationsVersion = 0;
  int _profileVersion = 0;
  int _chatVersion = 0;
  int _communityVersion = 0;

  int get globalVersion => _globalVersion;
  int get notificationsVersion => _notificationsVersion;
  int get profileVersion => _profileVersion;
  int get chatVersion => _chatVersion;
  int get communityVersion => _communityVersion;

  void triggerAll() {
    _globalVersion++;
    notifyListeners();
  }

  void triggerNotifications() {
    _notificationsVersion++;
    notifyListeners();
  }

  void triggerProfile() {
    _profileVersion++;
    notifyListeners();
  }

  void triggerChat() {
    _chatVersion++;
    notifyListeners();
  }

  void triggerCommunity() {
    _communityVersion++;
    notifyListeners();
  }
}
