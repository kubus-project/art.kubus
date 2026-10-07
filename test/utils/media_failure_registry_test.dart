import 'package:art_kubus/utils/media_failure_registry.dart';
import 'package:art_kubus/widgets/common/kubus_cached_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('KubusMediaFailureRegistry', () {
    test('remembers a failure until the retry window has passed', () {
      var now = DateTime(2026, 10, 7, 12);
      final registry = KubusMediaFailureRegistry(
        retryAfter: const Duration(minutes: 2),
        now: () => now,
      );
      const url = 'https://media.example/cover.jpg';
      expect(registry.hasRecentlyFailed(url), isFalse);
      registry.markFailed(url);
      expect(registry.hasRecentlyFailed(url), isTrue);
      now = now.add(const Duration(seconds: 119));
      expect(registry.hasRecentlyFailed(url), isTrue);
      now = now.add(const Duration(seconds: 1));
      expect(registry.hasRecentlyFailed(url), isFalse);
      expect(registry.length, 0, reason: 'an expired entry is dropped');
    });

    test('is keyed by the exact URL and bounded oldest-first', () {
      final registry = KubusMediaFailureRegistry(maxEntries: 2);
      registry.markFailed('a');
      registry.markFailed('b');
      registry.markFailed('c');
      expect(registry.length, 2);
      expect(registry.hasRecentlyFailed('a'), isFalse);
      expect(registry.hasRecentlyFailed('b'), isTrue);
      expect(registry.hasRecentlyFailed('c'), isTrue);
      expect(registry.hasRecentlyFailed('c?w=160'), isFalse);
      expect(registry.hasRecentlyFailed(null), isFalse);
      expect(registry.hasRecentlyFailed(''), isFalse);
    });
  });

  group('KubusCachedImage', () {
    const url = 'https://media.example/known-broken.jpg';

    tearDown(KubusMediaFailureRegistry.shared.clear);

    testWidgets('does not request media that just failed', (tester) async {
      KubusMediaFailureRegistry.shared.markFailed(url);
      Object? reportedError;
      await tester.pumpWidget(
        MaterialApp(
          home: KubusCachedImage(
            imageUrl: url,
            width: 120,
            height: 80,
            errorBuilder: (context, error, stack) {
              reportedError = error;
              return const Text('fallback');
            },
          ),
        ),
      );
      expect(find.byType(Image), findsNothing);
      expect(find.text('fallback'), findsOneWidget);
      expect(reportedError, isNotNull);
    });

    testWidgets('an unknown URL is still requested', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: KubusCachedImage(imageUrl: url, width: 120, height: 80),
        ),
      );
      expect(find.byType(Image), findsOneWidget);
    });
  });
}
