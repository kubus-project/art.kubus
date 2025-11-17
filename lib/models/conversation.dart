class Conversation {
  final String id;
  final String? title;
  final bool isGroup;
  final String? createdBy;
  final DateTime? lastMessageAt;
  final String? lastMessage;
  final String? displayAvatar;

  Conversation({
    required this.id,
    this.title,
    this.isGroup = false,
    this.createdBy,
    this.lastMessageAt,
    this.lastMessage,
    this.displayAvatar,
  });

  factory Conversation.fromJson(Map<String, dynamic> j) {
    return Conversation(
      id: j['id'] as String,
      title: j['title'] as String?,
      isGroup: (j['isGroup'] ?? false) as bool,
      createdBy: j['createdBy'] as String?,
      lastMessageAt: j['lastMessageAt'] != null ? DateTime.parse(j['lastMessageAt']) : null,
      lastMessage: j['lastMessage'] as String?,
      displayAvatar: (j['display_avatar'] ?? j['displayAvatar'] ?? j['avatar'] ?? j['avatar_url']) as String?,
    );
  }
}
