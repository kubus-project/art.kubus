import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/institution.dart';

/// Local persistence for institutions and events.
///
/// This keeps the institution hub and AR subject picker functional when
/// backend institution/event endpoints are disabled or unavailable.
class InstitutionStorage {
  static final InstitutionStorage _instance = InstitutionStorage._internal();
  factory InstitutionStorage() => _instance;
  InstitutionStorage._internal();

  static const String _institutionsKey = 'institutions_v1';
  static const String _eventsKey = 'institution_events_v1';
  static const String _registrationsPrefix = 'event_registrations_v1_';

  Future<List<Institution>> loadInstitutions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_institutionsKey);
      if (raw == null || raw.trim().isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => Institution.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.id.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('InstitutionStorage.loadInstitutions failed: $e');
      return const [];
    }
  }

  Future<List<Event>> loadEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_eventsKey);
      if (raw == null || raw.trim().isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => Event.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.id.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('InstitutionStorage.loadEvents failed: $e');
      return const [];
    }
  }

  Future<void> saveInstitutions(List<Institution> institutions) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(institutions.map((e) => e.toJson()).toList());
    await prefs.setString(_institutionsKey, payload);
  }

  Future<void> saveEvents(List<Event> events) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(events.map((e) => e.toJson()).toList());
    await prefs.setString(_eventsKey, payload);
  }

  Future<Set<String>> loadRegistrationsForUser(String userId) async {
    try {
      final normalized = userId.trim();
      if (normalized.isEmpty) return <String>{};
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_registrationsPrefix$normalized');
      if (raw == null || raw.trim().isEmpty) return <String>{};
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <String>{};
      return decoded.whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    } catch (e) {
      debugPrint('InstitutionStorage.loadRegistrationsForUser failed: $e');
      return <String>{};
    }
  }

  Future<void> saveRegistrationsForUser(String userId, Set<String> eventIds) async {
    final normalized = userId.trim();
    if (normalized.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(eventIds.toList());
    await prefs.setString('$_registrationsPrefix$normalized', payload);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_institutionsKey);
    await prefs.remove(_eventsKey);
  }
}

