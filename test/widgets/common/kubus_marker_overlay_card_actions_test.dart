import 'package:art_kubus/features/map/shared/map_overlay_sizing.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/art_marker.dart';
import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/widgets/common/kubus_marker_overlay_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

ArtMarker _marker() => ArtMarker(
      id: 'marker-1',
      name: 'Vodnik mural',
      description: 'A mural on a wall.',
      position: const LatLng(46.0569, 14.5058),
      type: ArtMarkerType.artwork,
      createdAt: DateTime(2024),
      createdBy: 'uploader-wallet',
    );

Artwork _artwork({String artist = 'Miron Milić'}) => Artwork(
      id: 'art-1',
      title: 'Vodnik mural',
      artist: artist,
      description: 'A mural on a wall.',
      position: const LatLng(46.0569, 14.5058),
      rewards: 0,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
      category: 'Mural',
    );

MarkerOverlayActionSpec _action(
  String id,
  String label,
  IconData icon,
  VoidCallback onTap,
) =>
    MarkerOverlayActionSpec(
      id: id,
      icon: icon,
      label: label,
      tooltip: label,
      semanticsLabel: label,
      isActive: false,
      activeColor: Colors.teal,
      onTap: onTap,
    );

List<MarkerOverlayActionSpec> _fiveActions(void Function(String id) onTap) => [
      _action('claim', 'Claim', Icons.gavel_outlined, () => onTap('claim')),
      _action('directions', 'Navigate', Icons.navigation_outlined,
          () => onTap('directions')),
      _action('save', 'Save', Icons.bookmark_border, () => onTap('save')),
      _action('share', 'Share', Icons.share_outlined, () => onTap('share')),
      _action('like', 'Likes 3', Icons.favorite_border, () => onTap('like')),
    ];

Widget _card({
  required double width,
  String? placeText,
  VoidCallback? onClose,
  List<MarkerOverlayActionSpec> actions = const <MarkerOverlayActionSpec>[],
  Artwork? artwork,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: KubusMarkerOverlayCard(
            marker: _marker(),
            artwork: artwork ?? _artwork(),
            baseColor: Colors.teal,
            displayTitle: 'Vodnik mural',
            canPresentExhibition: false,
            placeText: placeText,
            onClose: onClose ?? () {},
            onPrimaryAction: () {},
            primaryActionIcon: Icons.arrow_forward,
            primaryActionLabel: 'View details',
            actions: actions,
            maxWidth: width,
            maxHeight: 460,
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const placeKey = ValueKey<String>('marker_overlay_place');

  testWidgets('the place sits below the byline, after who made it',
      (tester) async {
    await tester
        .pumpWidget(_card(width: 320, placeText: 'Ljubljana, Slovenia'));
    await tester.pumpAndSettle();

    expect(find.byKey(placeKey), findsOneWidget);
    expect(find.text('Ljubljana, Slovenia'), findsOneWidget);

    final byline = tester.getTopLeft(
      find.textContaining('Miron', findRichText: true),
    );
    final place = tester.getTopLeft(find.byKey(placeKey));
    final title = tester.getTopLeft(find.text('Vodnik mural'));
    expect(title.dy, lessThan(byline.dy));
    expect(byline.dy, lessThan(place.dy));
  });

  testWidgets('no place row when there is nothing to say', (tester) async {
    await tester.pumpWidget(_card(width: 320));
    await tester.pumpAndSettle();
    expect(find.byKey(placeKey), findsNothing);
  });

  testWidgets('a very long place name stays on one line inside the card',
      (tester) async {
    final long = List.filled(12, 'Ljubljana-Moste-Polje').join(', ');
    await tester.pumpWidget(_card(width: 280, placeText: long));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final row = tester.getRect(find.byKey(placeKey));
    final card = tester.getRect(
      find.byKey(const ValueKey<String>('marker_overlay_card_surface')),
    );
    expect(row.right, lessThanOrEqualTo(card.right));
    expect(tester.getSize(find.byKey(placeKey)).height, lessThan(24));
  });

  testWidgets('the place row does not push the primary action out of the card',
      (tester) async {
    await tester.pumpWidget(
      _card(width: 320, placeText: 'Ljubljana, Slovenia'),
    );
    await tester.pumpAndSettle();
    final card = tester.getRect(
      find.byKey(const ValueKey<String>('marker_overlay_card_surface')),
    );
    final primary = tester.getRect(
      find.byKey(const ValueKey<String>('marker_overlay_primary_action')),
    );
    expect(primary.bottom, lessThanOrEqualTo(card.bottom));
  });

  testWidgets('the close control is reachable and operable by keyboard',
      (tester) async {
    var closed = 0;
    await tester.pumpWidget(_card(width: 320, onClose: () => closed += 1));
    await tester.pumpAndSettle();

    // First focus stop in the card must be the close control; Enter activates.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(closed, 1);
  });

  testWidgets('actions are reachable by keyboard in visual order',
      (tester) async {
    final fired = <String>[];
    await tester.pumpWidget(
      _card(
        width: 320,
        actions: [
          _action('marker_directions', 'Navigate', Icons.navigation_outlined,
              () => fired.add('directions')),
          _action('marker_save', 'Save', Icons.bookmark_border,
              () => fired.add('save')),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // close, directions, save, primary
    for (var i = 0; i < 2; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(fired, <String>['directions']);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(fired, <String>['directions', 'save']);
  });

  testWidgets('icon-only actions keep a spoken name and a hit area',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _card(
        width: 320,
        actions: [
          _action('marker_directions', 'Navigate', Icons.navigation_outlined,
              () {}),
          _action('marker_save', 'Save', Icons.bookmark_border, () {}),
          _action('marker_share', 'Share', Icons.share_outlined, () {}),
          _action('marker_like', 'Likes 3', Icons.favorite_border, () {}),
        ],
      ),
    );
    await tester.pumpAndSettle();

    for (final spoken in ['Navigate', 'Save', 'Share', 'Likes 3']) {
      expect(find.bySemanticsLabel(spoken), findsWidgets, reason: spoken);
    }
    final buttons = find.byKey(
      const ValueKey<String>('marker_overlay_secondary_action'),
    );
    expect(buttons, findsNWidgets(4));
    for (final element in buttons.evaluate()) {
      final size = tester.getSize(find.byWidget(element.widget));
      expect(size.height, greaterThanOrEqualTo(40));
    }
    handle.dispose();
  });

  testWidgets('a text-only artist stays plain text on the card',
      (tester) async {
    await tester.pumpWidget(_card(width: 320));
    await tester.pumpAndSettle();
    final byline = find.ancestor(
      of: find.textContaining('Miron', findRichText: true),
      matching: find.byType(InkWell),
    );
    expect(byline, findsNothing);
  });

  // The card's real width at each viewport, from the same sizing the map uses:
  // 336 at 390, 820 and 1440; 288 at 320.
  for (final viewport in <double>[320, 390, 820, 1440]) {
    testWidgets('five actions share one row at a $viewport viewport',
        (tester) async {
      final width = MapOverlaySizing.resolveCardWidth(
        BoxConstraints(maxWidth: viewport),
      );
      await tester.pumpWidget(
        _card(width: width, actions: _fiveActions((_) {})),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final buttons = find.byKey(
        const ValueKey<String>('marker_overlay_secondary_action'),
      );
      expect(buttons, findsNWidgets(5));
      final rows = <double>{
        for (final element in buttons.evaluate())
          tester.getTopLeft(find.byWidget(element.widget)).dy,
      };
      expect(rows, hasLength(1), reason: 'one row, no ragged wrap');

      final card = tester.getRect(
        find.byKey(const ValueKey<String>('marker_overlay_card_surface')),
      );
      for (final element in buttons.evaluate()) {
        final hit = tester.getRect(find.byWidget(element.widget));
        expect(card.contains(hit.center), isTrue);
      }
    });
  }

  testWidgets('five actions are reached by keyboard in visual order',
      (tester) async {
    final fired = <String>[];
    await tester.pumpWidget(
      _card(width: 336, actions: _fiveActions(fired.add)),
    );
    await tester.pumpAndSettle();

    // The first focus stop is the close control; it is passed over here, not
    // activated. The actions follow in visual order, the primary action last.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    const order = ['claim', 'directions', 'save', 'share', 'like'];
    for (final id in order) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(fired.last, id);
    }
    expect(fired, order);
  });

  testWidgets('an unknown artist stays unknown and never reads the uploader',
      (tester) async {
    await tester.pumpWidget(
      _card(
        width: 320,
        artwork:
            _artwork(artist: '').copyWith(walletAddress: 'uploader-wallet'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unknown artist'), findsOneWidget);
    expect(find.textContaining('uploader-wallet', findRichText: true),
        findsNothing);
    expect(find.textContaining('Miron', findRichText: true), findsNothing);
  });
}
