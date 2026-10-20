import 'package:flutter/widgets.dart';

import '../../models/message.dart';
import '../../utils/design_tokens.dart';

/// Consecutive messages from one sender stay in a visual group while they are
/// no more than this far apart.
const Duration kMessageGroupWindow = Duration(minutes: 5);

/// Largest bubble width on wide layouts; narrower viewports use a fraction.
const double kMessageBubbleMaxWidth = 560;

/// Column width for the thread and conversation list on wide layouts.
const double kMessagingColumnMaxWidth = 760;

String _senderIdentityKey(ChatMessage message) {
  final wallet = message.senderWallet.trim();
  if (wallet.isNotEmpty) return wallet.toLowerCase();
  return (message.senderUserId ?? '').trim();
}

/// True when [a] and [b] belong to the same visual group: the same sender
/// with an identity, and created within [kMessageGroupWindow] of each other.
/// Symmetric in its arguments.
bool messagesShareGroup(ChatMessage a, ChatMessage b) {
  final key = _senderIdentityKey(a);
  if (key.isEmpty || key != _senderIdentityKey(b)) return false;
  return b.createdAt.difference(a.createdAt).abs() <= kMessageGroupWindow;
}

/// Bubble corners: the outer corners stay at the full sheet radius, and the
/// corners on the sender's edge tighten toward neighbours in the same group.
BorderRadius messageBubbleRadius({
  required bool isMine,
  required bool groupStart,
  required bool groupEnd,
}) {
  const outer = Radius.circular(KubusRadius.sheet);
  const inner = Radius.circular(KubusRadius.sm);
  final senderTop = groupStart ? outer : inner;
  final senderBottom = groupEnd ? outer : inner;
  if (isMine) {
    return BorderRadius.only(
      topLeft: outer,
      bottomLeft: outer,
      topRight: senderTop,
      bottomRight: senderBottom,
    );
  }
  return BorderRadius.only(
    topRight: outer,
    bottomRight: outer,
    topLeft: senderTop,
    bottomLeft: senderBottom,
  );
}

/// Motion is skipped entirely when the platform asks for reduced motion.
bool messagingReduceMotion(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;
