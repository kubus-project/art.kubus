import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/common/kubus_action_tile.dart';
import 'package:art_kubus/widgets/detail/shared_settings_widgets.dart';
import 'package:art_kubus/widgets/wallet/kubus_wallet_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {double textScale = 1, double width = 320}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 700),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: SingleChildScrollView(child: child),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('a settings destination is one compact action tile',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(
      SharedSettingsDestinationTile(
        title: 'Security settings',
        subtitle: '2FA: Disabled, Auto-lock: 5 minutes',
        icon: Icons.security,
        onTap: () => taps++,
      ),
    ));

    final tile = tester.widget<KubusActionTile>(find.byType(KubusActionTile));
    expect(tile.layout, KubusActionTileLayout.compact);
    expect(tile.subtitle, '2FA: Disabled, Auto-lock: 5 minutes');
    // No foreground icon square: the glyph is the cropped ghost only.
    expect(
      find.descendant(
        of: find.byType(KubusActionTile),
        matching: find.byIcon(Icons.security),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.arrow_forward_ios), findsNothing);
    await tester.tap(find.byType(KubusActionTile));
    expect(taps, 1);
  });

  testWidgets('a destructive destination carries the destructive colour',
      (tester) async {
    await tester.pumpWidget(_app(
      Builder(
        builder: (context) => SharedSettingsDestinationTile(
          title: 'Delete account',
          subtitle: 'Remove your account',
          icon: Icons.delete_forever,
          isDestructive: true,
          onTap: () {},
        ),
      ),
    ));
    final tile = tester.widget<KubusActionTile>(find.byType(KubusActionTile));
    final context = tester.element(find.byType(KubusActionTile));
    expect(tile.accent, KubusColorRoles.of(context).destructive);
  });

  for (final scale in const [1.0, 1.3, 2.0]) {
    testWidgets('long copy wraps without overflow at 320 px, ${scale}x text',
        (tester) async {
      await tester.pumpWidget(_app(
        Column(
          children: [
            SharedSettingsDestinationTile(
              title: 'Upravljanje računa in nastavitve zasebnosti',
              subtitle:
                  'Vrsta računa: standardni, obvestila: vklopljena, samodejno '
                  'zaklepanje po petih minutah neaktivnosti',
              icon: Icons.manage_accounts,
              status: const Text('PREVERJENO'),
              onTap: () {},
            ),
          ],
        ),
        textScale: scale,
      ));
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(KubusActionTile)).width, 320);
    });
  }

  testWidgets('an unframed wallet section is a heading over its tiles',
      (tester) async {
    await tester.pumpWidget(_app(
      KubusWalletSectionCard(
        framed: false,
        title: 'Actions',
        subtitle: 'Send, receive or swap',
        child: KubusActionTile(
          title: 'Send',
          icon: Icons.arrow_upward,
          accent: Colors.red,
          layout: KubusActionTileLayout.compact,
          onTap: () {},
        ),
      ),
    ));
    expect(find.text('Actions'), findsOneWidget);
    // The only surface is the tile's own: no card around it.
    expect(
      find.ancestor(
        of: find.byType(KubusActionTile),
        matching: find.byType(DecoratedBox),
      ),
      findsNothing,
    );
  });
}
