import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guest entry points into Community must meet the contextual account gate at
/// the point of entry, and every gated like or comment must carry its intent
/// so it can be continued after sign-in. The screens are too provider-heavy
/// for a cheap widget test, so the wiring is guarded at source level here;
/// the gate, continuation and executor behaviour are covered by widget and
/// unit tests next to this one.
void main() {
  String read(String path) =>
      File(path).readAsStringSync().replaceAll('\r\n', '\n');

  /// Body of the first member declared with [signature], up to the first line
  /// that closes it at [indent] (two spaces for members of a class or part
  /// extension, four for a closure declared inside a method).
  String memberBody(String source, String signature, {int indent = 2}) {
    final start = source.indexOf(signature);
    expect(start, isNonNegative, reason: signature);
    final closing = '\n${' ' * indent}}\n';
    final end = source.indexOf(closing, start);
    expect(end, isNonNegative, reason: 'no closing brace for $signature');
    return source.substring(start, end);
  }

  const mobileFeed =
      'lib/screens/community/community_screen_parts/community_screen_p2.dart';
  const mobileFeedLike =
      'lib/screens/community/community_screen_parts/community_screen_p4.dart';
  const postDetail = 'lib/screens/community/post_detail_screen.dart';
  const groupFeed = 'lib/screens/community/group_feed_screen.dart';
  const desktopFeedParts =
      'lib/screens/desktop/community/desktop_community_screen_parts/';
  const desktopFeedP2 = '${desktopFeedParts}desktop_community_screen_p2.dart';
  const desktopFeedP3 = '${desktopFeedParts}desktop_community_screen_p3.dart';
  const desktopFeedP4 = '${desktopFeedParts}desktop_community_screen_p4.dart';
  const desktopFeedP5 = '${desktopFeedParts}desktop_community_screen_p5.dart';
  const messages = 'lib/screens/community/messages_screen.dart';

  group('post likes carry their intent', () {
    for (final entry in <(String, String, String)>[
      (mobileFeedLike, 'void _toggleLike(int index)', 'mobile feed'),
      (postDetail, 'Future<void> _toggleLike()', 'post detail'),
      (groupFeed, 'Future<void> _toggleLike(', 'group feed'),
      (desktopFeedP3, 'Future<void> _togglePostLike(', 'desktop feed'),
    ]) {
      test('${entry.$3} like is gated as a post like', () {
        final body = memberBody(read(entry.$1), entry.$2);
        expect(body, contains('ContextualAuthGate()'), reason: entry.$3);
        expect(body, contains('PendingActionType.like'), reason: entry.$3);
        expect(body, contains('PendingActionTargetType.post'),
            reason: entry.$3);
        expect(body, contains('targetId:'), reason: entry.$3);
      });
    }
  });

  group('inline comments meet the gate before they are sent', () {
    test('mobile feed inline comment submit is gated', () {
      final body = memberBody(
        read(mobileFeed),
        'Future<void> submitInlineComment() async {',
        indent: 4,
      );
      expect(body, contains('ContextualAuthGate()'));
      expect(body, contains('PendingActionType.comment'));
      expect(body.indexOf('ensureAuthenticated('),
          lessThan(body.indexOf('addComment(')));
    });

    test('desktop feed inline comment submit is gated', () {
      final body = memberBody(
        read(desktopFeedP3),
        'Future<void> submitInlineComment() async {',
        indent: 4,
      );
      expect(body, contains('ContextualAuthGate()'));
      expect(body, contains('PendingActionType.comment'));
      expect(body.indexOf('ensureAuthenticated('),
          lessThan(body.indexOf('addComment(')));
    });
  });

  group('desktop composer opens only through the compose gate', () {
    test('the composer dialog is opened from one gated helper only', () {
      final p2 = read(desktopFeedP2);
      // One declaration of the flag setter, inside the helper that opens it.
      expect(RegExp(r'_showComposeDialog = true').allMatches(p2).length, 1);
      final opener = memberBody(p2, 'void _openComposeDialog()');
      expect(opener, contains('_showComposeDialog = true'));
      expect(
        memberBody(p2, 'Future<void> _requestComposer('),
        contains('open();'),
      );
    });

    test('every desktop compose option goes through the gate', () {
      final p2 = read(desktopFeedP2);
      final fabBody =
          memberBody(p2, 'List<CommunityFabOption> _getFabOptions(');
      expect(
        RegExp(r'_requestComposer\(').allMatches(fabBody).length,
        greaterThanOrEqualTo(4),
        reason: 'post, group post, art drop and review each gate',
      );
      expect(fabBody, isNot(contains('_showComposeDialog = true')));
    });

    test('the inline composer expands only through the gate', () {
      final p4 = read(desktopFeedP4);
      final prompt = memberBody(p4, 'Widget _buildCreatePostPrompt(');
      expect(prompt, contains('_toggleComposerExpansion()'));
      expect(
        prompt,
        isNot(contains('_isComposerExpanded = !_isComposerExpanded')),
      );
      expect(
        memberBody(p4, 'Future<void> _toggleComposerExpansion()'),
        contains('_requestComposerExpansion('),
      );
      expect(
        memberBody(p4, 'Future<void> _requestComposerExpansion('),
        contains('ensureCommunityComposeAccess('),
      );
    });

    test('the sidebar and share-launched composer open through the gate', () {
      final p3 = read(desktopFeedP3);
      final p5 = read(desktopFeedP5);
      expect(p3, contains('_requestComposerExpansion('));
      expect(p5, contains('_requestComposerExpansion('));
      expect(p3, isNot(contains('_isComposerExpanded = true')));
      expect(p5, isNot(contains('_isComposerExpanded = true')));
    });

    test('resuming a composer request reopens the same surface', () {
      final p2 = read(desktopFeedP2);
      final resume = memberBody(p2, 'void _resumeComposeIntent(');
      expect(resume, contains('_openComposeDialog'));
      expect(resume, contains('_requestComposerExpansion'));
    });
  });

  group('chat and conversation creation are gated at entry', () {
    test('mobile new conversation asks for an account before the dialog', () {
      final body = memberBody(
        read(messages),
        'Future<void> _startConversation() async {',
      );
      expect(body, contains('ContextualAuthGate()'));
      expect(body.indexOf('ensureAuthenticated('),
          lessThan(body.indexOf('showKubusDialog')));
    });

    test('desktop new conversation asks for an account before the dialog', () {
      final body = memberBody(
        read(desktopFeedP4),
        'Future<void> _startNewConversation() async {',
      );
      expect(body, contains('ContextualAuthGate()'));
      expect(body.indexOf('ensureAuthenticated('),
          lessThan(body.indexOf('showKubusDialog')));
    });
  });
}
