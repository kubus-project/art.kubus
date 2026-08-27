import 'package:art_kubus/config/api_keys.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/utils/kubus_brand_colors.dart';
import 'package:art_kubus/widgets/wallet/kubus_token_identity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

KubusTokenVisual _resolve(WidgetTester tester, String symbol, {String? mint}) {
  final context = tester.element(find.byType(Placeholder));
  return KubusTokenIdentity.resolve(context, symbol, mint: mint);
}

Future<void> _pumpProbe(WidgetTester tester) async {
  await tester.pumpWidget(_wrap(const Placeholder()));
}

void main() {
  group('KubusTokenIdentity', () {
    testWidgets('KUB8 and SOL carry distinct fixed brand identities', (
      tester,
    ) async {
      await _pumpProbe(tester);

      final kub8 = _resolve(
        tester,
        'kub8',
        mint: ApiKeys.kub8MintAddress,
      );
      final sol = _resolve(
        tester,
        ' sol ',
        mint: KubusTokenIdentity.nativeSolMint,
      );

      expect(kub8.symbol, 'KUB8');
      expect(kub8.glyph, KubusTokenGlyph.kubusCube);
      expect(kub8.accent, KubusColors.primaryVariantDark);

      expect(sol.symbol, 'SOL');
      expect(sol.glyph, KubusTokenGlyph.solana);
      expect(sol.accent, KubusBrandColors.solanaPurple);

      expect(kub8.accent, isNot(sol.accent));
    });

    testWidgets('a token that only calls itself KUB8 gets no canonical mark', (
      tester,
    ) async {
      // The attack. A symbol is metadata any SPL token can set, so an
      // airdropped token can name itself KUB8 or SOL. Deciding branding from
      // the symbol made such a token render with the house cube throughout
      // wallet lists and transaction cards, which is what makes an airdrop look
      // official. Only the mint can settle it.
      await _pumpProbe(tester);

      // The glyph is the mark a person actually recognises, so that is what
      // must not be lent out. (The generic accent is drawn from the role
      // palette and can legitimately land near a brand colour; it carries no
      // claim of authenticity on its own.)
      final impostor = _resolve(
        tester,
        'KUB8',
        mint: 'ImPoSToRMint1111111111111111111111111111111',
      );
      expect(impostor.glyph, KubusTokenGlyph.initials);
      expect(impostor.glyph, isNot(KubusTokenGlyph.kubusCube));

      final fakeSol = _resolve(
        tester,
        'SOL',
        mint: 'ImPoSToRMint1111111111111111111111111111111',
      );
      expect(fakeSol.glyph, KubusTokenGlyph.initials);
      expect(fakeSol.glyph, isNot(KubusTokenGlyph.solana));
    });

    testWidgets('an asset with no known mint is not branded either', (
      tester,
    ) async {
      // "I cannot prove what this is" must read as unknown, never as canonical.
      await _pumpProbe(tester);

      expect(_resolve(tester, 'KUB8').glyph, KubusTokenGlyph.initials);
      expect(_resolve(tester, 'SOL', mint: '').glyph, KubusTokenGlyph.initials);
    });

    testWidgets('wrapped SOL is Solana itself and keeps the mark', (
      tester,
    ) async {
      await _pumpProbe(tester);

      final wrapped = _resolve(
        tester,
        'SOL',
        mint: KubusTokenIdentity.wrappedSolMint,
      );
      expect(wrapped.glyph, KubusTokenGlyph.solana);
    });

    testWidgets('unknown symbols get a stable accent and initials glyph', (
      tester,
    ) async {
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
              KubusTokenAvatar(symbol: 'KUB8', size: KubusTokenAvatarSize.sm),
              KubusTokenAvatar(symbol: 'SOL', size: KubusTokenAvatarSize.lg),
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
      await tester.pumpWidget(
        _wrap(
          const KubusTokenAvatar(
            symbol: 'kub8',
            mint: ApiKeys.kub8MintAddress,
          ),
        ),
      );

      expect(find.bySemanticsLabel('KUB8'), findsOneWidget);
    });
  });
}
