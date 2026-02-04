import 'package:art_kubus/utils/creator_display_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CreatorDisplayFormat.format', () {
    test('prefers displayName and explicit username', () {
      final r = CreatorDisplayFormat.format(
        fallbackLabel: 'Creator',
        displayName: 'Maya Chen',
        username: 'maya_chen',
        wallet: '7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU',
      );
      expect(r.primary, 'Maya Chen');
      expect(r.secondary, '@maya_chen');
    });

    test('does not invent a handle from displayName', () {
      final r = CreatorDisplayFormat.format(
        fallbackLabel: 'Creator',
        displayName: 'Franc Purg',
        username: null,
        wallet: '7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU',
      );
      expect(r.primary, 'Franc Purg');
      expect(r.secondary, isNull);
    });

    test('uses username as primary when name missing', () {
      final r = CreatorDisplayFormat.format(
        fallbackLabel: 'Creator',
        displayName: null,
        username: '@john_doe',
        wallet: null,
      );
      expect(r.primary, '@john_doe');
      expect(r.secondary, isNull);
    });

    test('never shows wallet as a name', () {
      final r = CreatorDisplayFormat.format(
        fallbackLabel: 'Creator',
        displayName: '0x742d35Cc6634C0532925a3b844Bc9e7595f88941',
        username: null,
        wallet: '0x742d35Cc6634C0532925a3b844Bc9e7595f88941',
      );
      expect(r.primary, 'Creator');
      expect(r.secondary, isNull);
    });

    test('treats "Unknown creator" as empty', () {
      final r = CreatorDisplayFormat.format(
        fallbackLabel: 'Creator',
        displayName: 'Unknown creator',
        username: null,
        wallet: null,
      );
      expect(r.primary, 'Creator');
      expect(r.secondary, isNull);
    });
  });
}
