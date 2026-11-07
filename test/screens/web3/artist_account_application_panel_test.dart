import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/artist_application.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/screens/web3/artist/artist_account_application_panel.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

ArtistApplicationSummary _application(String status) =>
    ArtistApplicationSummary.tryParse(<String, dynamic>{
      'id': 'app-1',
      'portfolioUrl': 'https://example.com/work',
      'medium': 'Painting',
      'statement': 'A statement of at least twenty characters.',
      'status': status,
    })!;

Future<AppLocalizations> _pumpPanel(
  WidgetTester tester, {
  required Future<ArtistApplicationSummary?> Function() fetch,
  Future<ArtistApplicationSummary> Function({
    required String portfolioUrl,
    required String medium,
    required String statement,
  })? submit,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await tester.binding.setSurfaceSize(const Size(900, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeProvider().lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: ArtistAccountApplicationPanel(fetch: fetch, submit: submit),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return AppLocalizations.delegate.load(const Locale('en'));
}

void main() {
  group('normalizeArtistPortfolioUrl', () {
    test('adds https to a bare host and rejects non-web links', () {
      expect(normalizeArtistPortfolioUrl('example.com/work'),
          'https://example.com/work');
      expect(normalizeArtistPortfolioUrl('https://example.com'),
          'https://example.com');
      expect(normalizeArtistPortfolioUrl(''), isNull);
      expect(normalizeArtistPortfolioUrl('ftp://example.com'), isNull);
    });
  });

  testWidgets(
      'walletless account sees the account apply action, not a wallet prompt',
      (tester) async {
    final l10n = await _pumpPanel(
      tester,
      fetch: () async => null,
    );

    expect(find.text(l10n.artistStudioAccountCtaApply), findsOneWidget);
    expect(find.text(l10n.artistStudioDaoStatusNotApplied), findsOneWidget);
    expect(find.text(l10n.artistStudioCtaConnectWalletToApply), findsNothing);
    expect(find.text(l10n.artistStudioConnectWalletToSubmitForDaoReview),
        findsNothing);
  });

  testWidgets('a pending application shows its status and no second apply',
      (tester) async {
    final l10n = await _pumpPanel(
      tester,
      fetch: () async => _application('pending'),
    );

    expect(find.text(l10n.artistStudioDaoStatusPending), findsOneWidget);
    expect(find.text(l10n.artistStudioAccountCtaApply), findsNothing);
    expect(find.text(l10n.artistStudioAccountDetailPending), findsOneWidget);
  });

  testWidgets(
      'an approved application shows approved, a rejected one can be resent',
      (tester) async {
    var l10n = await _pumpPanel(
      tester,
      fetch: () async => _application('approved'),
    );
    expect(find.text(l10n.artistStudioDaoStatusApproved), findsOneWidget);
    expect(find.text(l10n.artistStudioAccountCtaApply), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    l10n = await _pumpPanel(
      tester,
      fetch: () async => _application('rejected'),
    );
    expect(find.text(l10n.artistStudioDaoStatusRejected), findsOneWidget);
    expect(find.text(l10n.artistStudioCtaResubmitForReview), findsOneWidget);
  });

  testWidgets(
      'a 404 from a backend without the route shows unavailable and does not '
      'crash', (tester) async {
    final l10n = await _pumpPanel(
      tester,
      fetch: () async => throw BackendApiRequestException(
        statusCode: 404,
        path: '/api/dao/artist-applications/mine',
        body: 'Cannot GET',
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text(l10n.artistStudioAccountApplicationUnavailable),
        findsOneWidget);
    expect(find.text(l10n.artistStudioAccountCtaRetry), findsOneWidget);
    expect(find.text(l10n.artistStudioAccountCtaApply), findsNothing);
  });

  testWidgets(
      'submitting the form sends the account fields and shows the new status',
      (tester) async {
    final submitted = <String, String>{};
    final l10n = await _pumpPanel(
      tester,
      fetch: () async => null,
      submit: ({
        required String portfolioUrl,
        required String medium,
        required String statement,
      }) async {
        submitted['portfolioUrl'] = portfolioUrl;
        submitted['medium'] = medium;
        submitted['statement'] = statement;
        return _application('pending');
      },
    );

    await tester.tap(find.text(l10n.artistStudioAccountCtaApply));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byType(TextFormField).at(0), 'example.com/work');
    await tester.enterText(find.byType(TextFormField).at(1), 'Painting');
    await tester.enterText(
      find.byType(TextFormField).at(2),
      'A statement of at least twenty characters.',
    );
    final submitButton = find.text(l10n.artistStudioApplicationSubmitButton);
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    // The submit spinner animates for as long as the request is in flight, so
    // pumpAndSettle would never settle. Pump a bounded number of frames instead.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(submitted['portfolioUrl'], 'https://example.com/work');
    expect(submitted['medium'], 'Painting');
    expect(
        submitted['statement'], 'A statement of at least twenty characters.');
    expect(find.text(l10n.artistStudioDaoStatusPending), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
