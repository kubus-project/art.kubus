import 'package:art_kubus/providers/main_tab_provider.dart';
import 'package:art_kubus/providers/map_deep_link_provider.dart';
import 'package:art_kubus/services/share/share_deep_link_parser.dart';
import 'package:art_kubus/services/share/share_types.dart';
import 'package:art_kubus/utils/share_deep_link_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('marker deep link selects map tab and enqueues marker intent', (tester) async {
    final tabs = MainTabProvider();
    final mapIntents = MapDeepLinkProvider();
    const target = ShareDeepLinkTarget(type: ShareEntityType.marker, id: 'm1');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: tabs),
          ChangeNotifierProvider.value(value: mapIntents),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return Center(
                child: TextButton(
                  onPressed: () {
                    // ignore: discarded_futures
                    ShareDeepLinkNavigation.open(context, target);
                  },
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();

    expect(tabs.index, 0);
    expect(mapIntents.pending?.markerId, 'm1');
  });
}

