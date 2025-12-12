import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/collectible.dart';

/// Local persistence for NFT series and collectibles.
///
/// This keeps marketplace/minting functional even when backend NFT endpoints
/// are disabled or unavailable. Backend sync can be layered on later.
class CollectiblesStorage {
  static final CollectiblesStorage _instance = CollectiblesStorage._internal();
  factory CollectiblesStorage() => _instance;
  CollectiblesStorage._internal();

  static const String _seriesKey = 'collectible_series_v1';
  static const String _collectiblesKey = 'collectibles_v1';

  Future<List<CollectibleSeries>> loadSeries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_seriesKey);
      if (raw == null || raw.trim().isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => CollectibleSeries.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.id.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('CollectiblesStorage.loadSeries failed: $e');
      return const [];
    }
  }

  Future<List<Collectible>> loadCollectibles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_collectiblesKey);
      if (raw == null || raw.trim().isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => Collectible.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.id.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('CollectiblesStorage.loadCollectibles failed: $e');
      return const [];
    }
  }

  Future<void> saveSeries(List<CollectibleSeries> series) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(series.map((e) => e.toJson()).toList());
    await prefs.setString(_seriesKey, payload);
  }

  Future<void> saveCollectibles(List<Collectible> collectibles) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(collectibles.map((e) => e.toJson()).toList());
    await prefs.setString(_collectiblesKey, payload);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_seriesKey);
    await prefs.remove(_collectiblesKey);
  }
}

