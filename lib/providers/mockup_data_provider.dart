import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockupDataProvider with ChangeNotifier {
  static const String _mockDataEnabledKey = 'mockup_data_enabled';
  bool _isMockDataEnabled = true;
  bool _isInitialized = false;

  bool get isMockDataEnabled => _isMockDataEnabled;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      _isMockDataEnabled = prefs.getBool(_mockDataEnabledKey) ?? true;
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      _isMockDataEnabled = true;
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> toggleMockData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isMockDataEnabled = !_isMockDataEnabled;
      await prefs.setBool(_mockDataEnabledKey, _isMockDataEnabled);
      notifyListeners();
    } catch (e) {
      // Handle error silently for now
    }
  }

  Future<void> enableMockData() async {
    if (_isMockDataEnabled) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      _isMockDataEnabled = true;
      await prefs.setBool(_mockDataEnabledKey, true);
      notifyListeners();
    } catch (e) {
      // Handle error silently for now
    }
  }

  Future<void> disableMockData() async {
    if (!_isMockDataEnabled) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      _isMockDataEnabled = false;
      await prefs.setBool(_mockDataEnabledKey, false);
      notifyListeners();
    } catch (e) {
      // Handle error silently for now
    }
  }

  /// For production IPFS integration
  /// When mockup data is disabled, this would connect to IPFS
  bool get isProductionMode => !_isMockDataEnabled;
  
  /// Debug information for developers
  String get debugInfo => 'MockData: $_isMockDataEnabled, Initialized: $_isInitialized';
}
