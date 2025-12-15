import 'event.dart';

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  final str = value.toString();
  if (str.isEmpty) return null;
  return DateTime.tryParse(str);
}

class CollabInvite {
  final String id;
  final String entityType;
  final String entityId;
  final String invitedUserId;
  final String invitedByUserId;
  final UserSummaryDto? invitedBy;
  final String role;
  final String status; // pending|accepted|declined|expired
  final DateTime? createdAt;
  final DateTime? expiresAt;

  const CollabInvite({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.invitedUserId,
    required this.invitedByUserId,
    this.invitedBy,
    required this.role,
    required this.status,
    this.createdAt,
    this.expiresAt,
  });

  bool get isPending => status.toLowerCase() == 'pending';

  factory CollabInvite.fromJson(Map<String, dynamic> json) {
    final invitedByRaw = json['invitedBy'] ?? json['invited_by'];
    return CollabInvite(
      id: (json['id'] ?? '').toString(),
      entityType: (json['entityType'] ?? json['entity_type'] ?? '').toString(),
      entityId: (json['entityId'] ?? json['entity_id'] ?? '').toString(),
      invitedUserId: (json['invitedUserId'] ?? json['invited_user_id'] ?? '').toString(),
      invitedByUserId: (json['invitedByUserId'] ?? json['invited_by_user_id'] ?? '').toString(),
      invitedBy: invitedByRaw is Map<String, dynamic> ? UserSummaryDto.fromJson(invitedByRaw) : null,
      role: (json['role'] ?? 'viewer').toString(),
      status: (json['status'] ?? 'pending').toString(),
      createdAt: _parseDateTime(json['createdAt'] ?? json['created_at']),
      expiresAt: _parseDateTime(json['expiresAt'] ?? json['expires_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entityType': entityType,
      'entityId': entityId,
      'invitedUserId': invitedUserId,
      'invitedByUserId': invitedByUserId,
      'invitedBy': invitedBy?.toJson(),
      'role': role,
      'status': status,
      'createdAt': createdAt?.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
    };
  }
}
