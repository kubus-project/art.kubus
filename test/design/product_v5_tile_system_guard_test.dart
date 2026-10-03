import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source guard for the PRODUCT v5 tile system (0.8.0 visual hardening).
///
/// A destination or shortcut (a thing that goes somewhere) is a
/// `KubusActionTile`; a metric is a `KubusStatCard`; an empty or error state
/// is an `EmptyStateCard`. This test keeps three legacy shapes from creeping
/// back:
///
/// 1. one-off navigation card classes (`_ActionCard`, `_CreateOptionCard`…),
/// 2. the raw Material `Card(child: ListTile(…))` destination row,
/// 3. the "icon square + title + chevron" row written by hand.
///
/// Utility controls are out of scope: back/close/search buttons, switches,
/// form pickers, search-result and entity rows, media and AR controls.
/// A file that legitimately keeps the hand-written row lists the reason in
/// [_iconSquareRowAllowlist]; add to it only with a semantic reason.
void main() {
  final lib = Directory('lib');
  final files = lib
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList(growable: false);

  String read(File f) => f.readAsStringSync();
  String rel(File f) => f.path.replaceAll(r'\', '/');

  test('the legacy destination primitives stay deleted', () {
    expect(File('lib/widgets/gradient_icon_card.dart').existsSync(), isFalse);
    expect(File('lib/widgets/drawer/menu_item.dart').existsSync(), isFalse);
    for (final f in files) {
      expect(read(f), isNot(contains('GradientIconCard')),
          reason: '${rel(f)} uses the deleted gradient icon square');
    }
  });

  test('no one-off navigation card classes', () {
    final pattern = RegExp(
      r'class\s+_?\w*(ActionCard|ActionTile|OptionCard|ShortcutCard|MenuTile|NavCard|FeatureCard|SettingsTile)\b',
    );
    final offenders = <String>[];
    for (final f in files) {
      for (final m in pattern.allMatches(read(f))) {
        final name = m.group(0)!.replaceFirst(RegExp(r'class\s+'), '');
        // The shared primitives themselves.
        if (const {
          'KubusActionTile',
          'KubusActionSidebarTile',
          'KubusWalletActionCard',
          'SharedSettingsDestinationTile',
        }.contains(name)) {
          continue;
        }
        offenders.add('${rel(f)}: $name');
      }
    }
    expect(offenders, isEmpty,
        reason: 'A destination is a KubusActionTile (or '
            'KubusActionSidebarTile); extend the shared primitive instead of '
            'writing a local card.');
  });

  test('no raw Material Card(child: ListTile) destination rows', () {
    final pattern =
        RegExp(r'\bCard\(\s*(?:margin:[^;]*?,\s*)?child:\s*ListTile\(');
    final offenders = <String>[];
    for (final f in files) {
      if (pattern.hasMatch(read(f)) &&
          !_cardListTileAllowlist.containsKey(rel(f))) {
        offenders.add(rel(f));
      }
    }
    expect(offenders, isEmpty,
        reason: 'Use KubusActionTile for a destination, KubusCard for '
            'grouped content, or a ruled list row for an entity.');
  });

  test('hand-written icon-square rows with a chevron are allowlisted only', () {
    final iconSquare = RegExp(
      r'Container\(\s*width:[^,]+,\s*height:[^,]+,\s*decoration:\s*BoxDecoration\((?:(?!Container\().){0,260}?borderRadius(?:(?!Container\().){0,200}?child:\s*(?:const\s+)?Icon\(',
      dotAll: true,
    );
    final chevron = RegExp(
      r'Icons\.(chevron_right|arrow_forward_ios|navigate_next)',
    );
    final offenders = <String>[];
    for (final f in files) {
      final path = rel(f);
      final text = read(f);
      if (!iconSquare.hasMatch(text) || !chevron.hasMatch(text)) continue;
      if (_iconSquareRowAllowlist.containsKey(path)) continue;
      offenders.add(path);
    }
    expect(offenders, isEmpty,
        reason: 'This file draws an icon square next to a chevron. If it is '
            'a destination, use KubusActionTile; if it is an entity, result '
            'or picker row, add it to _iconSquareRowAllowlist with the '
            'reason.');
  });

  test('every allowlisted file still exists (no stale exemptions)', () {
    for (final path in [
      ..._iconSquareRowAllowlist.keys,
      ..._cardListTileAllowlist.keys,
    ]) {
      expect(File(path).existsSync(), isTrue, reason: '$path was removed');
    }
  });
}

/// Files that keep an icon square beside a chevron for a semantic reason that
/// is not "this is a destination".
const Map<String, String> _iconSquareRowAllowlist = <String, String>{
  'lib/screens/art/ar_screen.dart':
      'AR session lists and sheets: spatial/media utility rows and entity '
          'rows, not destinations',
  'lib/screens/settings/availability_node_operator_screen.dart':
      'operator token list: administrative entity rows',
  'lib/screens/community/community_screen_parts/community_screen_p4.dart':
      'composer search results: result rows, not destinations',
  'lib/screens/events/exhibition_list_screen.dart':
      'exhibition list: entity rows with their own options menu',
  'lib/widgets/user_persona_picker_content.dart':
      'persona choice: a form picker, selection not navigation',
};

/// Files that keep `Card(child: ListTile(…))` for entity rows.
const Map<String, String> _cardListTileAllowlist = <String, String>{
  'lib/screens/art/ar_screen.dart':
      'AR object and artwork lists: entity rows inside an AR session sheet',
  'lib/screens/settings/availability_node_operator_screen.dart':
      'operator token list: administrative entity rows',
};
