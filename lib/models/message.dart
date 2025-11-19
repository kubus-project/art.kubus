import 'dart:convert';

class MessageReply {
  final String messageId;
  final String senderWallet;
  final String? senderDisplayName;
  final String? message;

  const MessageReply({
    required this.messageId,
    required this.senderWallet,
    this.senderDisplayName,
    this.message,
  });

  factory MessageReply.fromJson(Map<String, dynamic> j) {
    return MessageReply(
      messageId: (j['messageId'] ?? j['message_id'] ?? j['id'] ?? '').toString(),
      senderWallet: (j['senderWallet'] ?? j['sender_wallet'] ?? j['wallet'] ?? '').toString(),
      senderDisplayName: j['senderDisplayName'] as String? ?? j['sender_display_name'] as String?,
      message: j['message'] as String?,
    );
  }
}

class MessageReaction {
  final String emoji;
  final int count;
  final List<String> reactors;

  const MessageReaction({
    required this.emoji,
    required this.count,
    required this.reactors,
  });

  factory MessageReaction.fromJson(Map<String, dynamic> j) {
    final emoji = (j['emoji'] ?? '').toString();
    final countValue = j['count'];
    final int count = countValue is int ? countValue : int.tryParse(countValue?.toString() ?? '0') ?? 0;
    List<String> reactors = const [];
    final rawReactors = j['reactors'];
    if (rawReactors is List) {
      reactors = rawReactors.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
    }
    return MessageReaction(emoji: emoji, count: count, reactors: reactors);
  }
}

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderWallet;
  final String? senderUsername;
  final String? senderDisplayName;
  final String? senderAvatar;
  final String message;
  final Map<String, dynamic>? data;
  final MessageReply? replyTo;
  final List<MessageReaction> reactions;
  final int readersCount;
  final bool readByCurrent;
  final List<Map<String, dynamic>> readers;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderWallet,
    this.senderUsername,
    this.senderDisplayName,
    this.senderAvatar,
    required this.message,
    this.data,
    this.replyTo,
    this.reactions = const [],
    this.readersCount = 0,
    this.readByCurrent = false,
    this.readers = const [],
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j) {
    // Normalize `data` field which may come as a JSON string or a Map
    Map<String, dynamic>? data;
    try {
      final rawData = j['data'];
      if (rawData == null) {
        data = null;
      } else if (rawData is String) {
        try {
          final parsed = rawData.isNotEmpty ? (jsonDecode(rawData) as Map<String, dynamic>?) : null;
          data = parsed;
        } catch (_) {
          data = null;
        }
      } else if (rawData is Map) {
        data = Map<String, dynamic>.from(rawData);
      } else {
        data = null;
      }

    } catch (_) {
      data = null;
    }

    // Normalize readers list into List<Map<String,dynamic>>
    List<Map<String, dynamic>> readersList = [];
    try {
      final rawReaders = j['readers'] ?? j['readers_list'];
      if (rawReaders == null) {
        readersList = [];
      } else if (rawReaders is String) {
        try {
          final parsed = jsonDecode(rawReaders) as List<dynamic>;
          readersList = parsed.map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}).toList();
        } catch (_) {
          readersList = [];
        }
      } else if (rawReaders is List) {
        readersList = rawReaders.map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}).toList();
      } else {
        readersList = [];
      }
    } catch (_) {
      readersList = [];
    }

    // Parse createdAt robustly
    DateTime createdAt;
    try {
      final rawCreated = j['created_at'] ?? j['createdAt'];
      if (rawCreated == null) {
        createdAt = DateTime.now();
      } else if (rawCreated is DateTime) {
        createdAt = rawCreated;
      } else {
        createdAt = DateTime.parse(rawCreated.toString());
      }
    } catch (_) {
      createdAt = DateTime.now();
    }

    // Parse reply preview if present
    MessageReply? replyTo;
    try {
      final rawReply = j['replyTo'] ?? j['reply_to'] ?? j['replyPreview'] ?? j['reply_preview'];
      if (rawReply is Map) {
        replyTo = MessageReply.fromJson(Map<String, dynamic>.from(rawReply));
      } else if (rawReply is String && rawReply.isNotEmpty) {
        final parsed = jsonDecode(rawReply);
        if (parsed is Map<String, dynamic>) replyTo = MessageReply.fromJson(parsed);
      }
    } catch (_) {
      replyTo = null;
    }

    // Normalize reactions into strongly typed list
    List<MessageReaction> reactionList = const [];
    try {
      final rawReactions = j['reactions'];
      if (rawReactions is List) {
        reactionList = rawReactions
          .whereType<Map>()
          .map((e) => MessageReaction.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      } else if (rawReactions is String && rawReactions.isNotEmpty) {
        final parsed = jsonDecode(rawReactions);
        if (parsed is List) {
          reactionList = parsed
              .whereType<Map>()
              .map((e) => MessageReaction.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
      }
    } catch (_) {
      reactionList = const [];
    }

    // Ensure id is present and fallback to a synthetic id if not
    final rawId = j['id'] ?? j['message_id'] ?? j['messageId'] ?? j['uuid'] ?? j['tempId'];
    final idStr = (rawId != null) ? rawId.toString() : DateTime.now().millisecondsSinceEpoch.toString();
    return ChatMessage(
      id: idStr,
      conversationId: (j['conversation_id'] as String?) ?? (j['conversationId'] as String? ?? ''),
      senderWallet: (j['sender_wallet'] ?? j['senderWallet'] ?? j['wallet'] ?? j['from']) as String? ?? '',
      senderUsername: (j['username'] ?? j['sender_username'] ?? j['senderUsername']) as String?,
      senderDisplayName: (j['display_name'] ?? j['sender_display_name'] ?? j['senderDisplayName']) as String?,
      senderAvatar: (j['avatar_url'] ?? j['avatar'] ?? j['senderAvatar']) as String?,
      message: (j['message'] as String?) ?? '',
      data: data,
      replyTo: replyTo,
      reactions: reactionList,
      readersCount: (j['readers_count'] ?? j['readersCount']) is int ? (j['readers_count'] ?? j['readersCount']) as int : int.tryParse((j['readers_count'] ?? j['readersCount'])?.toString() ?? '0') ?? 0,
      readByCurrent: (j['read_by_current'] ?? j['readByCurrent']) == true,
      readers: readersList,
      createdAt: createdAt,
    );
  }

  ChatMessage copyWith({
    String? message,
    Map<String, dynamic>? data,
    MessageReply? replyTo,
    List<MessageReaction>? reactions,
    int? readersCount,
    bool? readByCurrent,
    List<Map<String, dynamic>>? readers,
  }) {
    return ChatMessage(
      id: id,
      conversationId: conversationId,
      senderWallet: senderWallet,
      senderUsername: senderUsername,
      senderDisplayName: senderDisplayName,
      senderAvatar: senderAvatar,
      message: message ?? this.message,
      data: data ?? this.data,
      replyTo: replyTo ?? this.replyTo,
      reactions: reactions ?? this.reactions,
      readersCount: readersCount ?? this.readersCount,
      readByCurrent: readByCurrent ?? this.readByCurrent,
      readers: readers ?? this.readers,
      createdAt: createdAt,
    );
  }
}
