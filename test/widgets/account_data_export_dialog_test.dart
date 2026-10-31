import 'dart:async';
import 'dart:typed_data';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/services/account_data_export_service.dart';
import 'package:art_kubus/widgets/account_data_export_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeExport extends AccountDataExportService {
  _FakeExport(this.outcome, {this.gate}) : super(fetch: () async => [1]);

  final AccountDataExportOutcome outcome;
  final Completer<void>? gate;
  int runs = 0;

  @override
  Future<AccountDataExportOutcome> run() async {
    runs += 1;
    await gate?.future;
    return outcome;
  }
}

Future<void> _open(
  WidgetTester tester,
  AccountDataExportService service, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => showAccountDataExportDialog(
              context,
              service: service,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  late AppLocalizations en;
  late AppLocalizations sl;

  setUp(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
    sl = await AppLocalizations.delegate.load(const Locale('sl'));
  });

  testWidgets('the dialog says what the file contains and what it leaves out',
      (tester) async {
    await _open(tester, _FakeExport(AccountDataExportOutcome.saved));

    expect(find.text(en.settingsExportDataDialogTitle), findsOneWidget);
    expect(find.text(en.settingsExportDataDialogBody), findsOneWidget);
    expect(en.settingsExportDataDialogBody, contains('Passwords'));
    expect(find.text(en.settingsExportDownloadButton), findsOneWidget);
    expect(find.text(en.commonCancel), findsOneWidget);
  });

  testWidgets('Download runs the export once and then reports the file ready',
      (tester) async {
    final service = _FakeExport(AccountDataExportOutcome.saved);
    await _open(tester, service);

    await tester.tap(find.text(en.settingsExportDownloadButton));
    await tester.pumpAndSettle();

    expect(service.runs, 1);
    expect(find.text(en.settingsExportReady), findsOneWidget);
    expect(find.text(en.commonClose), findsOneWidget);
  });

  testWidgets('while the export runs the buttons are off and progress shows',
      (tester) async {
    final gate = Completer<void>();
    final service = _FakeExport(AccountDataExportOutcome.saved, gate: gate);
    await _open(tester, service);

    await tester.tap(find.text(en.settingsExportDownloadButton));
    await tester.pump();

    expect(find.text(en.settingsExportPreparing), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text(en.settingsExportDownloadButton),
        warnIfMissed: false);
    await tester.pump();
    expect(service.runs, 1, reason: 'a second tap must not start another');

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text(en.settingsExportReady), findsOneWidget);
  });

  testWidgets('each failure shows its own message and keeps the dialog open',
      (tester) async {
    final cases = <AccountDataExportOutcome, String Function(AppLocalizations)>{
      AccountDataExportOutcome.signInRequired: (l) =>
          l.settingsExportSignInRequired,
      AccountDataExportOutcome.tooManyRequests: (l) =>
          l.settingsExportTooManyRequests,
      AccountDataExportOutcome.failed: (l) => l.settingsExportFailed,
    };
    for (final entry in cases.entries) {
      await _open(tester, _FakeExport(entry.key));
      await tester.tap(find.text(en.settingsExportDownloadButton));
      await tester.pumpAndSettle();

      expect(find.text(entry.value(en)), findsOneWidget,
          reason: '${entry.key}');
      expect(find.text(en.settingsExportReady), findsNothing);
      // The user can try again.
      expect(find.text(en.settingsExportDownloadButton), findsOneWidget);

      await tester.tap(find.text(en.commonCancel));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('the Slovenian dialog uses the Slovenian strings',
      (tester) async {
    await _open(tester, _FakeExport(AccountDataExportOutcome.saved),
        locale: const Locale('sl'));

    expect(find.text(sl.settingsExportDataDialogTitle), findsOneWidget);
    expect(find.text(sl.settingsExportDownloadButton), findsOneWidget);
    expect(sl.settingsExportDataDialogTitle,
        isNot(en.settingsExportDataDialogTitle));
    expect(sl.settingsExportFailed, contains('support@kubus.site'));
  });

  testWidgets('opening the dialog fetches nothing', (tester) async {
    final service = _FakeExport(AccountDataExportOutcome.saved);
    await _open(tester, service);
    expect(service.runs, 0);
  });

  test('the delivered bytes are not altered on the way to the platform',
      () async {
    Uint8List? seen;
    final service = AccountDataExportService(
      fetch: () async => [123, 125],
      deliver: (bytes, _) async => seen = bytes,
      clock: () => DateTime.utc(2026, 1, 2),
    );
    expect(await service.run(), AccountDataExportOutcome.saved);
    expect(seen, orderedEquals([123, 125]));
  });
}
