import 'event.dart';

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  final str = value.toString();
  if (str.isEmpty) return null;
  return DateTime.tryParse(str);
}

class CollabMember {
  final String userId;
  final String role;
  final DateTime? createdAt;
  final UserSummaryDto? user;

  const CollabMember({
    required this.userId,
    required this.role,
    this.createdAt,
    this.user,
  });

  factory CollabMember.fromJson(Map<String, dynamic> json) {
    final userRaw = json['user'];
    return CollabMember(
      userId: (json['userId'] ?? json['memberUserId'] ?? json['member_user_id'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      createdAt: _parseDateTime(json['createdAt'] ?? json['created_at']),
      user: userRaw is Map<String, dynamic> ? UserSummaryDto.fromJson(userRaw) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'role': role,
      'createdAt': createdAt?.toIso8601String(),
      'user': user?.toJson(),
    };
  }
}
