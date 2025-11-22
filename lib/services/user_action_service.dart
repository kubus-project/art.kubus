import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Records the user's own actions (likes, follows, saves, etc.) so they appear
/// in the unified recent activity timeline alongside backend notifications.
class UserActionService {
  static const _prefsKey = 'user_action_history';
  static const _maxEntries = 120;

  Future<void> recordAction(UserActionEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? <String>[];
    final payload = entry.toJson();
    raw.insert(0, jsonEncode(payload));
    if (raw.length > _maxEntries) {
      raw.removeRange(_maxEntries, raw.length);
    }
    await prefs.setStringList(_prefsKey, raw);
  }

  Future<List<Map<String, dynamic>>> getRecentActions({int limit = 50}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? <String>[];
    final entries = <Map<String, dynamic>>[];
    for (final item in raw) {
      try {
        final decoded = jsonDecode(item);
        if (decoded is Map<String, dynamic>) {
          entries.add(decoded);
        }
      } catch (_) {
        continue;
      }
      if (entries.length >= limit) break;
    }
    return entries;
  }
}

class UserActionEntry {
  final String id;
  final String type;
  final String title;
  final String? description;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;
  final bool isRead;

  const UserActionEntry({
    required this.id,
    required this.type,
    required this.title,
    this.description,
    required this.timestamp,
    this.metadata,
    this.isRead = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      if (description != null) 'description': description,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'actorName': 'You',
      if (metadata != null && metadata!.isNotEmpty) 'metadata': metadata,
    };
  }

  factory UserActionEntry.fromJson(Map<String, dynamic> json) {
    return UserActionEntry(
      id: json['id']?.toString() ?? 'user_action_${DateTime.now().microsecondsSinceEpoch}',
      type: json['type']?.toString() ?? 'system',
      title: json['title']?.toString() ?? 'You performed an action',
      description: json['description']?.toString(),
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      metadata: json['metadata'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['metadata'] as Map<String, dynamic>)
          : null,
      isRead: json['isRead'] == true,
    );
  }
}
