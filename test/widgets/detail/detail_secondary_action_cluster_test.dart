import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/widgets/detail/detail_shell_primitives.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

DetailSecondaryAction _action(
  String label, {
  IconData icon = Icons.circle_outlined,
  bool pinned = false,
  VoidCallback? onTap,
}) =>
    DetailSecondaryAction(
      icon: icon,
      label: label,
      tooltip: label,
      pinned: pinned,
      onTap: onTap ?? () {},
    );

/// The desktop artwork panel's six secondary actions, with Directions pinned.
List<DetailSecondaryAction> _panelActions(List<String> taps) => [
      DetailSecondaryAction(
        icon: Icons.view_in_ar,
        label: 'View in AR',
        tooltip: 'View in AR',
        onTap: () => taps.add('ar'),
      ),
      DetailSecondaryAction(
        icon: Icons.bookmark_border,
        label: 'Save',
        tooltip: 'Save',
        onTap: () => taps.add('save'),
      ),
      DetailSecondaryAction(
        icon: Icons.favorite_border,
        label: '12',
        tooltip: 'Likes',
        semanticsLabel: 'Likes 12',
        onTap: () => taps.add('like'),
      ),
      DetailSecondaryAction(
        icon: Icons.comment_outlined,
        label: '3',
        tooltip: 'Comments',
        onTap: () => taps.add('comments'),
      ),
      DetailSecondaryAction(
        icon: Icons.share,
        label: 'Share',
        tooltip: 'Share',
        onTap: () => taps.add('share'),
      ),
      DetailSecondaryAction(
        icon: Icons.directions,
        label: 'Get directions',
        tooltip: 'Get directions',
        pinned: true,
        onTap: () => taps.add('directions'),
      ),
    ];

Widget _host({
  required double width,
  required double textScale,
  required Widget child,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: Center(
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    ),
  );
}

List<String> _labels(List<DetailSecondaryAction> actions) =>
    actions.map((action) => action.label).toList(growable: false);

void main() {
  group('partitionDetailSecondaryActions', () {
    test('when everything fits, nothing overflows and order is kept', () {
      final actions = [_action('A'), _action('B'), _action('C')];
      final parts = partitionDetailSecondaryActions(actions, maxVisible: 3);
      expect(_labels(parts.shown), ['A', 'B', 'C']);
      expect(parts.overflow, isEmpty);
    });

    test('a pinned action leads and is never moved behind More', () {
      final taps = <String>[];
      final actions = _panelActions(taps);
      final parts = partitionDetailSecondaryActions(actions, maxVisible: 4);
      expect(parts.shown.first.label, 'Get directions');
      expect(parts.shown.map((a) => a.label), contains('Get directions'));
      expect(parts.shown.length + parts.overflow.length, actions.length);
      expect(parts.overflow.map((a) => a.label),
          isNot(contains('Get directions')));
    });

    test('past the cap, the overflow keeps its order and nothing is lost', () {
      final actions = [
        _action('AR'),
        _action('Save'),
        _action('Like'),
        _action('Comments'),
        _action('Share'),
        _action('Directions', pinned: true),
      ];
      final parts = partitionDetailSecondaryActions(actions, maxVisible: 4);
      expect(_labels(parts.shown), ['Directions', 'AR', 'Save']);
      expect(_labels(parts.overflow), ['Like', 'Comments', 'Share']);
    });

    test('pinned actions are shown even when they exceed the cap', () {
      final actions = [
        _action('One', pinned: true),
        _action('Two', pinned: true),
        _action('Three', pinned: true),
        _action('Four'),
        _action('Five'),
      ];
      final parts = partitionDetailSecondaryActions(actions, maxVisible: 2);
      expect(_labels(parts.shown), ['One', 'Two', 'Three']);
      expect(_labels(parts.overflow), ['Four', 'Five']);
    });

    test('an action without a label is dropped and never counted', () {
      final actions = [_action('  '), _action('Save'), _action('Share')];
      final parts = partitionDetailSecondaryActions(actions, maxVisible: 2);
      expect(_labels(parts.shown), ['Save', 'Share']);
      expect(parts.overflow, isEmpty);
    });

    test('a cap of one with nothing pinned leaves only the More control', () {
      final actions = [_action('A'), _action('B'), _action('C')];
      final parts = partitionDetailSecondaryActions(actions, maxVisible: 1);
      expect(parts.shown, isEmpty);
      expect(_labels(parts.overflow), ['A', 'B', 'C']);
    });
  });

  group('DetailSecondaryActionCluster', () {
    for (final width in const [300.0, 312.0, 360.0]) {
      for (final textScale in const [1.0, 1.3]) {
        testWidgets(
            'grid keeps Directions first and lays out at $width px, '
            'text scale $textScale', (tester) async {
          final taps = <String>[];
          await tester.pumpWidget(_host(
            width: width,
            textScale: textScale,
            child: DetailSecondaryActionCluster(
              actions: _panelActions(taps),
              maxVisible: 6,
              layout: DetailSecondaryActionLayout.grid,
            ),
          ));
          await tester.pump();

          // No overflow was reported (the framework fails the test if it was).
          for (final label in [
            'View in AR',
            'Save',
            'Likes',
            'Comments',
            'Share',
            'Get directions',
          ]) {
            expect(find.byTooltip(label), findsOneWidget, reason: label);
          }
          expect(find.byTooltip('More'), findsNothing);

          final directions =
              tester.getTopLeft(find.byTooltip('Get directions'));
          final save = tester.getTopLeft(find.byTooltip('Save'));
          expect(directions.dy, lessThanOrEqualTo(save.dy));
        });
      }
    }

    testWidgets(
        'a count-only grid tile is spoken by its tooltip, not its count',
        (tester) async {
      await tester.pumpWidget(_host(
        width: 360,
        textScale: 1,
        child: DetailSecondaryActionCluster(
          actions: [
            DetailSecondaryAction(
              icon: Icons.favorite_border,
              label: '7',
              tooltip: 'Likes',
              onTap: () {},
            ),
          ],
          layout: DetailSecondaryActionLayout.grid,
        ),
      ));
      await tester.pump();

      expect(find.bySemanticsLabel('Likes'), findsOneWidget);
      expect(find.bySemanticsLabel('7'), findsNothing);
    });

    testWidgets('grid overflow goes to an explicit More control, never a cut',
        (tester) async {
      final taps = <String>[];
      await tester.pumpWidget(_host(
        width: 360,
        textScale: 1,
        child: DetailSecondaryActionCluster(
          actions: _panelActions(taps),
          maxVisible: 4,
          layout: DetailSecondaryActionLayout.grid,
        ),
      ));
      await tester.pump();

      expect(find.byTooltip('Get directions'), findsOneWidget);
      expect(find.byTooltip('Likes'), findsNothing);
      expect(find.byTooltip('More'), findsOneWidget);

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share').last);
      await tester.pumpAndSettle();
      expect(taps, ['share']);
    });

    testWidgets('wrap overflow opens More and runs the chosen action',
        (tester) async {
      final taps = <String>[];
      await tester.pumpWidget(_host(
        width: 360,
        textScale: 1,
        child: DetailSecondaryActionCluster(
          actions: _panelActions(taps),
          maxVisible: 3,
        ),
      ));
      await tester.pump();

      expect(find.byTooltip('Get directions'), findsOneWidget);
      expect(find.byTooltip('More'), findsOneWidget);

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      // The overflow item for the comments action is labelled with its count.
      await tester.tap(find.text('3').last);
      await tester.pumpAndSettle();
      expect(taps, ['comments']);
    });

    testWidgets('an empty cluster renders nothing', (tester) async {
      await tester.pumpWidget(_host(
        width: 360,
        textScale: 1,
        child: const DetailSecondaryActionCluster(
          actions: <DetailSecondaryAction>[],
          layout: DetailSecondaryActionLayout.grid,
        ),
      ));
      await tester.pump();
      expect(find.byTooltip('More'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
