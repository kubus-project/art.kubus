import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the analytics localization contract: every analytics-facing key
/// exists in both ARB files with a non-empty value, so EN and SL can never
/// drift for this namespace again.
void main() {
  Map<String, dynamic> loadArb(String path) {
    var raw = File(path).readAsStringSync();
    if (raw.startsWith('﻿')) {
      raw = raw.substring(1);
    }
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  bool isTranslatableKey(String key) =>
      !key.startsWith('@') && !key.startsWith('_');

  test('analytics l10n namespaces are key-for-key equal in EN and SL', () {
    final en = loadArb('lib/l10n/app_en.arb');
    final sl = loadArb('lib/l10n/app_sl.arb');

    const prefixes = <String>[
      'analytics',
      'desktopProfileAnalytics',
      'profileAccountHealth',
    ];

    final enKeys = en.keys
        .where(isTranslatableKey)
        .where((key) => prefixes.any(key.startsWith))
        .toSet();
    final slKeys = sl.keys
        .where(isTranslatableKey)
        .where((key) => prefixes.any(key.startsWith))
        .toSet();

    expect(enKeys.difference(slKeys), isEmpty,
        reason: 'keys missing from app_sl.arb');
    expect(slKeys.difference(enKeys), isEmpty,
        reason: 'keys missing from app_en.arb');
    expect(enKeys, isNotEmpty);

    for (final key in enKeys) {
      expect((en[key] as String).trim(), isNotEmpty,
          reason: 'empty EN value for $key');
      expect((sl[key] as String).trim(), isNotEmpty,
          reason: 'empty SL value for $key');
    }
  });
}
