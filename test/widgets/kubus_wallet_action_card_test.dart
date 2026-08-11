import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/widgets/wallet/kubus_wallet_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _card({
  required String title,
  required String subtitle,
  required Color color,
}) {
  return SizedBox(
    width: 200,
    child: KubusWalletActionCard(
      title: title,
      subtitle: subtitle,
      icon: Icons.arrow_upward_rounded,
      color: color,
      onTap: () {},
      minHeight: KubusSizes.walletActionCardMinHeightCompact,
      density: KubusWalletDensity.compact,
    ),
  );
}

void main() {
  testWidgets('action cards in a rail share one height regardless of copy',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _card(
                title: 'Send',
                subtitle: 'Move tokens',
                color: Colors.red,
              ),
              _card(
                title: 'Secure wallet',
                subtitle:
                    'Back up your recovery phrase and turn on device protection '
                    'so you never lose access to this wallet',
                color: Colors.amber,
              ),
            ],
          ),
        ),
      ),
    );

    final cards = find.byType(KubusWalletActionCard);
    expect(cards, findsNWidgets(2));

    final first = tester.getSize(cards.first);
    final second = tester.getSize(cards.last);
    expect(first.height, second.height);
    expect(
      first.height,
      greaterThanOrEqualTo(KubusSizes.walletActionCardMinHeightCompact),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('titles never wrap', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _card(
            title: 'Connect an external wallet',
            subtitle: 'Choose a wallet app',
            color: Colors.blue,
          ),
        ),
      ),
    );

    final title = tester.widget<Text>(
      find.text('Connect an external wallet'),
    );
    expect(title.maxLines, 1);
    expect(title.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });
}
