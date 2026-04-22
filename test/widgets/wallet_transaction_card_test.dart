import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/wallet.dart';
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
  testWidgets('does not show unknown finality chip when finality is unknown',
      (tester) async {
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
  });

  testWidgets('related transaction row shows related status chip',
      (tester) async {
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
      _wrap(
        WalletTransactionCard(
          transaction: tx,
          initiallyExpanded: true,
        ),
      ),
    );

    expect(find.text('Team fee'), findsOneWidget);
    expect(find.text('Failed'), findsOneWidget);
  });
}
