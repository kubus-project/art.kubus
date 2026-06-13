import '../utils/creator_display_format.dart';

enum ParticipantIdentitySource {
  fallback,
  conversationSnapshot,
  messageSnapshot,
  profileHydration,
  localUser,
}

class ResolvedConversationParticipant {
  const ResolvedConversationParticipant({
    required this.identityKey,
    this.walletAddress,
    this.userId,
    this.displayName,
    this.username,
    this.avatarUrl,
    this.source = ParticipantIdentitySource.fallback,
    this.updatedAt,
  });

  final String identityKey;
  final String? walletAddress;
  final String? userId;
  final String? displayName;
  final String? username;
  final String? avatarUrl;
  final ParticipantIdentitySource source;
  final DateTime? updatedAt;

  String get stableDisplayLabel {
    return CreatorDisplayFormat.format(
      fallbackLabel: 'Unknown user',
      displayName: displayName,
      username: username,
      wallet: _nonEmpty(walletAddress) ?? _nonEmpty(userId),
    ).primary;
  }

  ResolvedConversationParticipant mergeFrom(
    ResolvedConversationParticipant next,
  ) {
    final nextSourceWins = next.source.index >= source.index;
    final mergedSource = nextSourceWins ? next.source : source;
    final nextUpdatedAt = next.updatedAt;
    final mergedUpdatedAt = nextUpdatedAt != null &&
            (updatedAt == null || nextUpdatedAt.isAfter(updatedAt!))
        ? nextUpdatedAt
        : updatedAt;

    return ResolvedConversationParticipant(
      identityKey: identityKey,
      walletAddress: _preferStableIdentifier(walletAddress, next.walletAddress),
      userId: _preferStableIdentifier(userId, next.userId),
      displayName:
          _preferMetadata(displayName, next.displayName, nextSourceWins),
      username: _preferMetadata(username, next.username, nextSourceWins),
      avatarUrl: _preferMetadata(avatarUrl, next.avatarUrl, nextSourceWins),
      source: mergedSource,
      updatedAt: mergedUpdatedAt,
    );
  }

  bool hasSameVisibleIdentity(ResolvedConversationParticipant other) {
    if (stableDisplayLabel != other.stableDisplayLabel) return false;
    if ((_nonEmpty(avatarUrl) ?? '') != (_nonEmpty(other.avatarUrl) ?? '')) {
      return false;
    }

    final usesWalletFallback = _nonEmpty(displayName) == null &&
        _nonEmpty(username) == null &&
        _nonEmpty(walletAddress) != null;
    final otherUsesWalletFallback = _nonEmpty(other.displayName) == null &&
        _nonEmpty(other.username) == null &&
        _nonEmpty(other.walletAddress) != null;
    if (usesWalletFallback || otherUsesWalletFallback) {
      return _normalizeKey(walletAddress) == _normalizeKey(other.walletAddress);
    }

    final usesUserIdFallback = _nonEmpty(displayName) == null &&
        _nonEmpty(username) == null &&
        _nonEmpty(walletAddress) == null &&
        _nonEmpty(userId) != null;
    final otherUsesUserIdFallback = _nonEmpty(other.displayName) == null &&
        _nonEmpty(other.username) == null &&
        _nonEmpty(other.walletAddress) == null &&
        _nonEmpty(other.userId) != null;
    if (usesUserIdFallback || otherUsesUserIdFallback) {
      return _normalizeKey(userId) == _normalizeKey(other.userId);
    }

    return true;
  }
}

String normalizeParticipantIdentityKey({
  String? walletAddress,
  String? userId,
  String? senderId,
}) {
  final wallet = _normalizeKey(walletAddress);
  if (wallet.isNotEmpty) return wallet;

  final user = _normalizeKey(userId);
  if (user.isNotEmpty) return user;

  final sender = _normalizeKey(senderId);
  if (sender.isNotEmpty) return sender;

  return 'unknown';
}

String? _nonEmpty(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

String _normalizeKey(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return '';
  return trimmed.toLowerCase();
}

String? _preferStableIdentifier(String? current, String? next) {
  final existing = _nonEmpty(current);
  if (existing != null) return existing;
  return _nonEmpty(next);
}

String? _preferMetadata(String? current, String? next, bool nextSourceWins) {
  final existing = _nonEmpty(current);
  final incoming = _nonEmpty(next);
  if (incoming == null) return existing;
  if (existing == null) return incoming;
  return nextSourceWins ? incoming : existing;
}
