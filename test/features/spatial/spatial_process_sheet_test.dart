import 'package:art_kubus/features/spatial/spatial_process_sheet.dart';
import 'package:art_kubus/providers/spatial_library_provider.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: child,
    );

Future<SpatialProcessorChoice?> _openAndTapOwnNode(
  WidgetTester tester, {
  required SpatialOwnNodeReachability ownNode,
  bool providersAvailableNow = true,
}) async {
  SpatialProcessorChoice? result;
  await tester.pumpWidget(
    _app(
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await SpatialProcessSheet.show(
              context,
              ownNode: ownNode,
              providersAvailableNow: providersAvailableNow,
            );
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('This kubus Node'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  group('the process sheet never hides a processor behind pairing', () {
    testWidgets('an unpaired own Node tile is not visually disabled',
        (tester) async {
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => SpatialProcessSheet.show(
                context,
                ownNode: SpatialOwnNodeReachability.unpaired,
                providersAvailableNow: true,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final tile = find.text('This kubus Node');
      expect(tile, findsOneWidget);
      final opacity = tester.widget<Opacity>(
        find.ancestor(of: tile, matching: find.byType(Opacity)).first,
      );
      // The unpaired tile carries no reduced-opacity disabled affordance —
      // it is a live invitation to pair, not a greyed-out dead end.
      expect(opacity.opacity, 1.0);
      expect(find.text('Not connected — tap to pair'), findsOneWidget);
    });

    testWidgets('tapping an unpaired own Node returns connectOwnNode',
        (tester) async {
      final choice = await _openAndTapOwnNode(
        tester,
        ownNode: SpatialOwnNodeReachability.unpaired,
      );
      expect(choice, SpatialProcessorChoice.connectOwnNode);
    });

    testWidgets('tapping an already-paired local Node returns ownNode',
        (tester) async {
      final choice = await _openAndTapOwnNode(
        tester,
        ownNode: SpatialOwnNodeReachability.localNetwork,
      );
      expect(choice, SpatialProcessorChoice.ownNode);
    });

    testWidgets('tapping an already-paired remote Node returns ownNode',
        (tester) async {
      final choice = await _openAndTapOwnNode(
        tester,
        ownNode: SpatialOwnNodeReachability.remote,
      );
      expect(choice, SpatialProcessorChoice.ownNode);
    });

    testWidgets(
        'the KUBUS Network option stays tappable with zero providers online',
        (tester) async {
      SpatialProcessorChoice? result;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await SpatialProcessSheet.show(
                  context,
                  ownNode: SpatialOwnNodeReachability.unpaired,
                  providersAvailableNow: false,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'No provider is available right now. The request stays open '
          'until one is.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Kubus network'));
      await tester.pumpAndSettle();
      expect(result, SpatialProcessorChoice.kubusNetwork);
    });
  });
}
