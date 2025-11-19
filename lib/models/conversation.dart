import 'dart:convert';

class ConversationMemberProfile {
  final String wallet;
  final String? displayName;
  final String? avatarUrl;

  const ConversationMemberProfile({
    required this.wallet,
    this.displayName,
    this.avatarUrl,
  });

  factory ConversationMemberProfile.fromJson(Map<String, dynamic> map) {
    final wallet = ((map['wallet'] ?? map['wallet_address'] ?? map['walletAddress']) ?? '').toString();
    final displayName = map['displayName'] as String? ?? map['display_name'] as String? ?? map['name'] as String? ?? (wallet.isNotEmpty ? wallet : null);
    final avatar = map['avatarUrl'] as String? ?? map['avatar_url'] as String?;
    return ConversationMemberProfile(wallet: wallet, displayName: displayName, avatarUrl: avatar);
  }
}

class Conversation {
  final String id;
  final String? title;
  final String? rawTitle;
  final bool isGroup;
  final String? createdBy;
  final DateTime? lastMessageAt;
  final String? lastMessage;
  final String? displayAvatar;
  final List<String> memberWallets;
  final List<ConversationMemberProfile> memberProfiles;
  final int memberCount;
  final ConversationMemberProfile? counterpartProfile;

  Conversation({
    required this.id,
    this.title,
    this.rawTitle,
    this.isGroup = false,
    this.createdBy,
    this.lastMessageAt,
    this.lastMessage,
    this.displayAvatar,
    this.memberWallets = const [],
    this.memberProfiles = const [],
    this.memberCount = 0,
    this.counterpartProfile,
  });

  factory Conversation.fromJson(Map<String, dynamic> j) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      try {
        return DateTime.parse(value.toString());
      } catch (_) {
        return null;
      }
    }

    List<String> parseWallets(dynamic value) {
      if (value == null) return <String>[];
      if (value is List) {
        return value.map((e) => (e ?? '').toString()).where((e) => e.isNotEmpty).toList();
      }
      if (value is String && value.isNotEmpty) {
        try {
          final parsed = jsonDecode(value);
          if (parsed is List) {
            return parsed.map((e) => (e ?? '').toString()).where((e) => e.isNotEmpty).toList();
          }
        } catch (_) {}
      }
      return <String>[];
    }

    Map<String, dynamic>? castToMap(dynamic value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) {
        return value.map((key, val) => MapEntry(key == null ? '' : key.toString(), val));
      }
      return null;
    }

    List<ConversationMemberProfile> parseProfiles(dynamic value) {
      if (value == null) return <ConversationMemberProfile>[];
      if (value is List) {
        return value
            .map(castToMap)
            .whereType<Map<String, dynamic>>()
            .map(ConversationMemberProfile.fromJson)
            .where((profile) => profile.wallet.isNotEmpty)
            .toList();
      }
      if (value is String && value.isNotEmpty) {
        try {
          final parsed = jsonDecode(value);
          if (parsed is List) {
            return parsed
                .map(castToMap)
                .whereType<Map<String, dynamic>>()
                .map(ConversationMemberProfile.fromJson)
                .where((profile) => profile.wallet.isNotEmpty)
                .toList();
          }
        } catch (_) {}
      }
      return <ConversationMemberProfile>[];
    }

    ConversationMemberProfile? parseCounterpart(dynamic value) {
      if (value == null) return null;
      final asMap = castToMap(value);
      if (asMap != null) {
        final profile = ConversationMemberProfile.fromJson(asMap);
        return profile.wallet.isNotEmpty ? profile : null;
      }
      if (value is String && value.isNotEmpty) {
        try {
          final parsed = jsonDecode(value);
          final parsedMap = castToMap(parsed);
          if (parsedMap != null) {
            final profile = ConversationMemberProfile.fromJson(parsedMap);
            return profile.wallet.isNotEmpty ? profile : null;
          }
        } catch (_) {}
      }
      return null;
    }

    int parseMemberCount(dynamic value, int fallback) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? fallback;
      return fallback;
    }

    final rawTitle = (j['raw_title'] ?? j['rawTitle']) as String?;
    final resolvedTitle = (j['resolved_title'] ?? j['resolvedTitle'] ?? j['title']) as String?;
    final memberWallets = parseWallets(j['memberWallets'] ?? j['member_wallets']);
    final memberProfiles = parseProfiles(j['memberProfiles'] ?? j['member_profiles']);
    final counterpart = parseCounterpart(j['counterpartProfile'] ?? j['counterpart_profile']);
    final memberCountRaw = parseMemberCount(j['memberCount'] ?? j['member_count'], memberProfiles.length);
    final memberCount = memberCountRaw == 0 && memberWallets.isNotEmpty ? memberWallets.length : memberCountRaw;
    final avatarCandidate = (j['display_avatar'] ?? j['displayAvatar'] ?? j['avatar'] ?? j['avatar_url']) as String?;
    final effectiveAvatar = avatarCandidate ?? counterpart?.avatarUrl;

    return Conversation(
      id: j['id'] as String,
      title: resolvedTitle ?? rawTitle,
      rawTitle: rawTitle,
      isGroup: (j['isGroup'] ?? j['is_group'] ?? false) == true,
      createdBy: (j['createdBy'] ?? j['created_by']) as String?,
      lastMessageAt: parseDate(j['lastMessageAt'] ?? j['last_message_at']),
      lastMessage: (j['lastMessage'] ?? j['last_message']) as String?,
      displayAvatar: effectiveAvatar,
      memberWallets: memberWallets,
      memberProfiles: memberProfiles,
      memberCount: memberCount,
      counterpartProfile: counterpart,
    );
  }
}
