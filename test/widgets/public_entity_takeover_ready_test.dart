import 'package:art_kubus/providers/public_entity_takeover_provider.dart';
import 'package:art_kubus/services/share/share_deep_link_parser.dart';
import 'package:art_kubus/services/share/share_types.dart';
import 'package:art_kubus/widgets/public_entity_takeover_ready.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  const cases = <(ShareEntityType, String)>[
    (ShareEntityType.profile, 'profiles'),
    (ShareEntityType.event, 'events'),
    (ShareEntityType.exhibition, 'exhibitions'),
    (ShareEntityType.collection, 'collections'),
    (ShareEntityType.post, 'posts'),
  ];

  for (final (type, segment) in cases) {
    testWidgets('$type signals after its meaningful child paints',
        (tester) async {
      final provider = PublicEntityTakeoverProvider();
      provider.seed(
        initialUri: Uri.parse('/en/$segment/entity-1'),
        target: ShareDeepLinkTarget(
          type: type,
          id: 'entity-1',
          localeCode: 'en',
        ),
      );
      expect(provider.isReady, isFalse);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            home: PublicEntityTakeoverReady(
              type: type,
              entityId: 'entity-1',
              child: const Text('meaningful entity'),
            ),
          ),
        ),
      );
      expect(provider.isReady, isTrue);
    });
  }

  testWidgets('a rendered record with the wrong identity cannot signal',
      (tester) async {
    final provider = PublicEntityTakeoverProvider();
    provider.seed(
      initialUri: Uri.parse('/en/events/event-1'),
      target: const ShareDeepLinkTarget(
        type: ShareEntityType.event,
        id: 'event-1',
        localeCode: 'en',
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(
          home: PublicEntityTakeoverReady(
            type: ShareEntityType.event,
            entityId: 'event-2',
            child: Text('wrong event'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(provider.isReady, isFalse);
  });
}
