import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/screens/web3/promotions/promotion_checkout_return_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpReturnScreen(
  WidgetTester tester, {
  required Locale locale,
  String? status,
  String? sessionId,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: PromotionCheckoutReturnScreen(
        status: status,
        sessionId: sessionId,
      ),
    ),
  );
  await tester.pump();
}

/// English literals that were hard-coded before the localization pass.
const List<String> _legacyEnglishLiterals = <String>[
  'Promotion Checkout',
  'Promotion payment received',
  'Promotion checkout cancelled',
  'Promotion checkout',
  'Your payment was received. The promotion request is now waiting for admin review.',
  'No payment was captured. You can return to the app and submit the promotion again when ready.',
  'Return to the app to review the current status of your promotion request.',
  'Stripe session',
];

void _expectNoLegacyEnglish(WidgetTester tester) {
  for (final literal in _legacyEnglishLiterals) {
    expect(find.text(literal), findsNothing, reason: literal);
    expect(find.textContaining(literal), findsNothing, reason: literal);
  }
}

void main() {
  testWidgets('successful return renders fully in Slovenian', (tester) async {
    await _pumpReturnScreen(
      tester,
      locale: const Locale('sl'),
      status: 'success',
      sessionId: 'cs_test_123',
    );

    expect(find.text('Plačilo promocije'), findsOneWidget);
    expect(find.text('Plačilo za promocijo je prejeto'), findsOneWidget);
    expect(
      find.text(
        'Plačilo je prejeto. Zahteva za promocijo zdaj čaka na pregled administratorja.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Seja Stripe: cs_test_123'), findsOneWidget);
    expect(find.text('Odpri aplikacijo'), findsOneWidget);
    expect(find.text('Prijava'), findsOneWidget);
    _expectNoLegacyEnglish(tester);
  });

  testWidgets('cancelled return renders fully in Slovenian', (tester) async {
    await _pumpReturnScreen(
      tester,
      locale: const Locale('sl'),
      status: 'cancelled',
      sessionId: 'cs_test_456',
    );

    expect(find.text('Plačilo za promocijo je preklicano'), findsOneWidget);
    expect(
      find.text(
        'Plačilo ni bilo izvedeno. Ko boste pripravljeni, se vrnite v aplikacijo in promocijo znova oddajte.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Seja Stripe: cs_test_456'), findsOneWidget);
    _expectNoLegacyEnglish(tester);
  });

  testWidgets('unknown status falls back to the Slovenian default copy',
      (tester) async {
    await _pumpReturnScreen(
      tester,
      locale: const Locale('sl'),
      status: 'pending',
    );

    expect(find.text('Plačilo promocije'), findsNWidgets(2));
    expect(
      find.text(
        'Vrnite se v aplikacijo in preverite trenutno stanje zahteve za promocijo.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Seja Stripe'), findsNothing);
    _expectNoLegacyEnglish(tester);
  });

  testWidgets('English smoke case keeps the English copy', (tester) async {
    await _pumpReturnScreen(
      tester,
      locale: const Locale('en'),
      status: 'success',
      sessionId: 'cs_test_789',
    );

    expect(find.text('Promotion Checkout'), findsOneWidget);
    expect(find.text('Promotion payment received'), findsOneWidget);
    expect(find.textContaining('Stripe session: cs_test_789'), findsOneWidget);
    expect(find.text('Open app'), findsOneWidget);
  });
}
