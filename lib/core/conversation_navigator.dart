import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../screens/community/conversation_screen.dart';
import '../models/conversation.dart';

class ConversationNavigator {
  /// Opens the conversation screen while passing preloaded maps obtained from ChatProvider or supplied overrides.
  static Future<T?> openConversationWithPreload<T>(
    BuildContext context,
    Conversation conversation, {
    List<String>? preloadedMembers,
    Map<String, String?>? preloadedAvatars,
    Map<String, String?>? preloadedDisplayNames,
    bool pushReplacement = false,
  }) async {
    final chat = Provider.of<ChatProvider>(context, listen: false);
    try {
      final metadataMembers = <String>[];
      final metadataAvatars = <String, String?>{};
      final metadataNames = <String, String?>{};
      final seenWallets = <String>{};

      void addMember(String wallet, {String? displayName, String? avatar}) {
        final trimmed = wallet.trim();
        if (trimmed.isEmpty) return;
        final lower = trimmed.toLowerCase();
        if (!seenWallets.contains(lower)) {
          metadataMembers.add(trimmed);
          seenWallets.add(lower);
        }
        if (displayName != null && displayName.trim().isNotEmpty) {
          final current = metadataNames[trimmed];
          if (current == null || current.isEmpty || current == trimmed) {
            metadataNames[trimmed] = displayName.trim();
          }
        }
        if (avatar != null && avatar.trim().isNotEmpty) {
          final current = metadataAvatars[trimmed];
          if (current == null || current.isEmpty) {
            metadataAvatars[trimmed] = avatar.trim();
          }
        }
      }

      for (final profile in conversation.memberProfiles) {
        addMember(profile.wallet, displayName: profile.displayName, avatar: profile.avatarUrl);
      }
      if (conversation.counterpartProfile != null) {
        addMember(conversation.counterpartProfile!.wallet, displayName: conversation.counterpartProfile!.displayName, avatar: conversation.counterpartProfile!.avatarUrl);
      }
      for (final wallet in conversation.memberWallets) {
        addMember(wallet);
      }

      // Attempt to normalize preloaded maps so ConversationScreen receives
      // useful non-empty values or null (so it can fall back to provider logic).
      Map<String, dynamic> map = {};
      try {
        map = chat.getPreloadedProfileMapsForConversation(conversation.id);
      } catch (_) {}

      // Resolve members: prefer explicit non-empty preloadedMembers, then provider map
      List<String>? members;
      if (preloadedMembers != null && preloadedMembers.isNotEmpty) {
        members = List<String>.from(preloadedMembers);
      } else if (metadataMembers.isNotEmpty) {
        members = List<String>.from(metadataMembers);
      } else {
        try {
          final inferred = (map['members'] as List<dynamic>?)?.cast<String>() ?? <String>[];
          if (inferred.isNotEmpty) members = inferred;
        } catch (_) {}
      }

      // Resolve avatars/names: prefer explicit maps, otherwise provider map
      final Map<String, String?> avatars = {};
      final Map<String, String?> names = {};

      void mergeInto(Map<String, String?> target, Map<String, String?> source, {bool override = false}) {
        source.forEach((key, value) {
          if (key.isEmpty) return;
          if (!override && target.containsKey(key) && (target[key]?.isNotEmpty ?? false)) return;
          if (value == null || value.isEmpty) return;
          target[key] = value;
        });
      }

      mergeInto(avatars, metadataAvatars);
      mergeInto(names, metadataNames);

      try {
        if (preloadedAvatars != null) {
          mergeInto(avatars, preloadedAvatars.cast<String, String?>(), override: true);
        } else {
          final rawAv = (map['avatars'] as Map<String, String?>? ?? {});
          mergeInto(avatars, rawAv.cast<String, String?>());
        }
      } catch (_) {}

      try {
        if (preloadedDisplayNames != null) {
          mergeInto(names, preloadedDisplayNames.cast<String, String?>(), override: true);
        } else {
          final rawNm = (map['names'] as Map<String, String?>? ?? {});
          mergeInto(names, rawNm.cast<String, String?>());
        }
      } catch (_) {}

      // If we have a primary member, try to ensure there's at least an entry for them
      if (members != null && members.isNotEmpty) {
        final primary = members.first;
        if (avatars[primary] == null || (avatars[primary]?.isEmpty ?? true)) {
          try {
            final cached = chat.getCachedUser(primary);
            if (cached != null && cached.profileImageUrl != null && cached.profileImageUrl!.isNotEmpty) avatars[primary] = cached.profileImageUrl;
          } catch (_) {}
        }
        if (names[primary] == null || (names[primary]?.isEmpty ?? true)) {
          try {
            final cached = chat.getCachedUser(primary);
            if (cached != null && cached.name.isNotEmpty) names[primary] = cached.name;
          } catch (_) {}
        }
      }

      // If avatars or names are empty maps, pass null so ConversationScreen will consult provider fallback
      final passAvatars = avatars.isNotEmpty ? avatars : null;
      final passNames = names.isNotEmpty ? names : null;

      final route = MaterialPageRoute<T>(builder: (_) => ConversationScreen(
            conversation: conversation,
            preloadedMembers: members,
            preloadedAvatars: passAvatars,
            preloadedDisplayNames: passNames,
          ));
      final navigator = Navigator.of(context);
      if (pushReplacement) return navigator.pushReplacement<T, T>(route);
      return navigator.push<T>(route);
    } catch (e) {
      // Fallback: just navigate to conversation without preloads
      final route = MaterialPageRoute<T>(builder: (_) => ConversationScreen(conversation: conversation));
      return Navigator.of(context).push<T>(route);
    }
  }
}
