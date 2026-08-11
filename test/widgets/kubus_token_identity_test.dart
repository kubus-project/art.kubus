import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/utils/kubus_brand_colors.dart';
import 'package:art_kubus/widgets/wallet/kubus_token_identity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

KubusTokenVisual _resolve(WidgetTester tester, String symbol) {
  final context = tester.element(find.byType(Placeholder));
  return KubusTokenIdentity.resolve(context, symbol);
}

Future<void> _pumpProbe(WidgetTester tester) async {
  await tester.pumpWidget(_wrap(const Placeholder()));
}

void main() {
  group('KubusTokenIdentity', () {
    testWidgets('KUB8 and SOL carry distinct fixed brand identities',
        (tester) async {
      await _pumpProbe(tester);

      final kub8 = _resolve(tester, 'kub8');
      final sol = _resolve(tester, ' sol ');

      expect(kub8.symbol, 'KUB8');
      expect(kub8.glyph, KubusTokenGlyph.kubusCube);
      expect(kub8.accent, KubusColors.primaryVariantDark);

      expect(sol.symbol, 'SOL');
      expect(sol.glyph, KubusTokenGlyph.solana);
      expect(sol.accent, KubusBrandColors.solanaPurple);

      expect(kub8.accent, isNot(sol.accent));
    });

    testWidgets('unknown symbols get a stable accent and initials glyph',
        (tester) async {
      await _pumpProbe(tester);

      final first = _resolve(tester, 'USDC');
      final second = _resolve(tester, 'USDC');

      expect(first.glyph, KubusTokenGlyph.initials);
      expect(first.initials, 'US');
      expect(first.accent, second.accent);
    });
  });

  group('KubusTokenAvatar', () {
    testWidgets('sizes come from the token scale', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              KubusTokenAvatar(
                symbol: 'KUB8',
                size: KubusTokenAvatarSize.sm,
              ),
              KubusTokenAvatar(
                symbol: 'SOL',
                size: KubusTokenAvatarSize.lg,
              ),
            ],
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(KubusTokenAvatar).first).width,
        KubusSizes.tokenAvatarSm,
      );
      expect(
        tester.getSize(find.byType(KubusTokenAvatar).last).width,
        KubusSizes.tokenAvatarLg,
      );
    });

    testWidgets('exposes the ticker to screen readers', (tester) async {
      await tester.pumpWidget(_wrap(const KubusTokenAvatar(symbol: 'kub8')));

      expect(find.bySemanticsLabel('KUB8'), findsOneWidget);
    });
  });
}
