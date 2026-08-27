import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/wallet.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/widgets/wallet/kubus_token_identity.dart';
import 'package:art_kubus/widgets/wallet_transaction_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

WalletTransaction _buildTransaction({
  required String signature,
  required TransactionType type,
  required TransactionStatus status,
  required WalletTransactionDirection direction,
  WalletTransactionFinality finality = WalletTransactionFinality.unknown,
  int? confirmationCount,
  String token = 'SOL',
  double amount = 1.0,
  String? swapToToken,
  double? swapToAmount,
  List<WalletTransactionAssetChange> assetChanges =
      const <WalletTransactionAssetChange>[],
  List<WalletRelatedTransaction> relatedTransactions =
      const <WalletRelatedTransaction>[],
}) {
  return WalletTransaction(
    id: signature,
    signature: signature,
    type: type,
    status: status,
    direction: direction,
    finality: finality,
    token: token,
    amount: amount,
    timestamp: DateTime(2026, 4, 22, 12, 0, 0),
    fromAddress: 'from-address-123',
    toAddress: 'to-address-456',
    confirmationCount: confirmationCount,
    swapToToken: swapToToken,
    swapToAmount: swapToAmount,
    assetChanges: assetChanges,
    relatedTransactions: relatedTransactions,
  );
}

void main() {
  testWidgets('does not show unknown finality chip when finality is unknown', (
    tester,
  ) async {
    final tx = _buildTransaction(
      signature: 'sig-unknown-finality',
      type: TransactionType.send,
      status: TransactionStatus.submitted,
      direction: WalletTransactionDirection.outgoing,
      finality: WalletTransactionFinality.unknown,
      confirmationCount: null,
      assetChanges: const <WalletTransactionAssetChange>[
        WalletTransactionAssetChange(
          symbol: 'SOL',
          mint: 'native',
          amount: -1.0,
          isPrimary: true,
          direction: WalletTransactionDirection.outgoing,
          assetKind: WalletTransactionAssetKind.native,
        ),
      ],
    );

    await tester.pumpWidget(_wrap(WalletTransactionCard(transaction: tx)));

    expect(find.text('Submitted'), findsOneWidget);
    expect(find.text('Unknown'), findsNothing);
  });

  testWidgets(
    'swap card uses swapTo fallback when incoming asset change is missing',
    (tester) async {
      final tx = _buildTransaction(
        signature: 'sig-swap-fallback',
        type: TransactionType.swap,
        status: TransactionStatus.pending,
        direction: WalletTransactionDirection.swap,
        token: 'SOL',
        amount: 1.25,
        swapToToken: 'USDC',
        swapToAmount: 12.5,
        assetChanges: const <WalletTransactionAssetChange>[
          WalletTransactionAssetChange(
            symbol: 'SOL',
            mint: 'native',
            amount: -1.25,
            isPrimary: true,
            direction: WalletTransactionDirection.outgoing,
            assetKind: WalletTransactionAssetKind.native,
          ),
        ],
      );

      await tester.pumpWidget(_wrap(WalletTransactionCard(transaction: tx)));

      expect(find.text('-1.2500 SOL'), findsOneWidget);
      expect(find.text('+12.5000 USDC'), findsOneWidget);
    },
  );

  testWidgets('related transaction row shows related status chip', (
    tester,
  ) async {
    final tx = _buildTransaction(
      signature: 'sig-related-status',
      type: TransactionType.send,
      status: TransactionStatus.pending,
      direction: WalletTransactionDirection.outgoing,
      relatedTransactions: const <WalletRelatedTransaction>[
        WalletRelatedTransaction(
          signature: 'related-fee-sig',
          label: 'Team fee',
          token: 'KUB8',
          amount: 0.1,
          status: TransactionStatus.failed,
        ),
      ],
      assetChanges: const <WalletTransactionAssetChange>[
        WalletTransactionAssetChange(
          symbol: 'KUB8',
          mint: 'mint-kub8',
          amount: -1.0,
          isPrimary: true,
          direction: WalletTransactionDirection.outgoing,
          assetKind: WalletTransactionAssetKind.spl,
        ),
      ],
    );

    await tester.pumpWidget(
      _wrap(WalletTransactionCard(transaction: tx, initiallyExpanded: true)),
    );

    expect(find.text('Team fee'), findsOneWidget);
    expect(find.text('Failed'), findsOneWidget);
  });

  testWidgets('compact card lays out on a narrow phone without overflowing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final tx = _buildTransaction(
      signature: 'sig-narrow-layout',
      type: TransactionType.receive,
      status: TransactionStatus.finalized,
      direction: WalletTransactionDirection.incoming,
      finality: WalletTransactionFinality.finalized,
      confirmationCount: 32,
      token: 'KUB8',
      amount: 1234.5678,
    );

    await tester.pumpWidget(
      _wrap(WalletTransactionCard(transaction: tx, compact: true)),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    // "Received" must render as one unbroken line — the old layout squeezed
    // the title into the same Wrap as the status chips and split the word.
    final title = tester.widget<Text>(find.text('Received'));
    expect(title.maxLines, 1);
    expect(title.softWrap, isFalse);

    // The confirmation chip keeps its own line and its own intrinsic width.
    final chip = tester.widget<Text>(find.text('32 confirmations'));
    expect(chip.maxLines, 1);
    expect(chip.softWrap, isFalse);
    expect(
      tester.getSize(find.text('32 confirmations')).height,
      lessThan(KubusSizes.chipMinHeight),
    );

    // Amount stays on one line next to the title.
    expect(find.text('+1234.5678 KUB8'), findsOneWidget);
  });

  testWidgets('transaction badge carries the asset mark', (tester) async {
    final tx = _buildTransaction(
      signature: 'sig-token-mark',
      type: TransactionType.send,
      status: TransactionStatus.confirmed,
      direction: WalletTransactionDirection.outgoing,
      token: 'SOL',
    );

    await tester.pumpWidget(_wrap(WalletTransactionCard(transaction: tx)));

    expect(find.byType(KubusTokenAvatar), findsOneWidget);
    expect(
      tester.widget<KubusTokenAvatar>(find.byType(KubusTokenAvatar)).symbol,
      'SOL',
    );
  });

  testWidgets('stake transaction uses the teal wallet role', (tester) async {
    final tx = _buildTransaction(
      signature: 'sig-stake-role',
      type: TransactionType.stake,
      status: TransactionStatus.confirmed,
      direction: WalletTransactionDirection.self,
    );

    await tester.pumpWidget(_wrap(WalletTransactionCard(transaction: tx)));

    final stakeIcon = tester.widget<Icon>(
      find.byIcon(Icons.lock_outline_rounded),
    );
    expect(stakeIcon.color, KubusColors.accentTealDark);
  });

  testWidgets('expanded signature row shows a truncated monospace value', (
    tester,
  ) async {
    const longSignature =
        '5x7Qk2mNqL9vTbYcWd3RfHgJ4pZaSeD6uVnB8oXiC1tMgKrEyPwQ2';
    final tx = _buildTransaction(
      signature: longSignature,
      type: TransactionType.send,
      status: TransactionStatus.confirmed,
      direction: WalletTransactionDirection.outgoing,
    );

    await tester.pumpWidget(
      _wrap(WalletTransactionCard(transaction: tx, initiallyExpanded: true)),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Head and tail survive; the middle collapses so a hash cannot wrap into
    // a ragged three-line block.
    expect(find.text(longSignature), findsNothing);
    expect(
      find.text(
        '${longSignature.substring(0, 8)}…'
        '${longSignature.substring(longSignature.length - 8)}',
      ),
      findsOneWidget,
    );
  });
}
