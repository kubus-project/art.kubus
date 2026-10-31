import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/screens/moderation/my_reports_screen.dart';
import 'package:art_kubus/services/content_report_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeService extends ContentReportService {
  _FakeService({
    this.reports = const [],
    this.decisions = const [],
    this.loadOutcome,
    this.appealOutcome = ModerationActionOutcome.done,
  });

  final List<ReporterReport> reports;
  final List<DecisionAboutMe> decisions;
  final ModerationActionOutcome? loadOutcome;
  final ModerationActionOutcome appealOutcome;
  final List<String> calls = [];

  @override
  Future<ModerationLoadResult> load() async {
    final failure = loadOutcome;
    if (failure != null) return ModerationLoadResult.failed(failure);
    return ModerationLoadResult.loaded(
        ModerationOverview(reports: reports, decisions: decisions));
  }

  @override
  Future<ModerationActionOutcome> requestReconsideration(String reportId,
      {String? note}) async {
    calls.add('reconsider:$reportId:${note ?? ''}');
    return ModerationActionOutcome.done;
  }

  @override
  Future<ModerationActionOutcome> appeal(String reportId,
      {required String note}) async {
    calls.add('appeal:$reportId:$note');
    return appealOutcome;
  }
}

ReporterReport _report({
  String id = 'r1',
  String status = 'resolved',
  String? outcome = 'content_removed',
  String? reason = 'Removed after review.',
  bool reconsidered = false,
}) =>
    ReporterReport(
      id: id,
      targetType: 'post',
      reasonCode: 'spam',
      status: status,
      outcome: outcome,
      outcomeReason: reason,
      decidedAt: null,
      reconsiderationRequested: reconsidered,
      createdAt: null,
    );

DecisionAboutMe _decision({
  String id = 'd1',
  bool appealed = false,
  String? result,
}) =>
    DecisionAboutMe(
      id: id,
      targetType: 'post',
      outcome: 'content_removed',
      statementOfReasons: 'Your post broke the posting rules.',
      decidedAt: null,
      appealRequested: appealed,
      appealResult: result,
      appealResultReason: result == null ? null : 'Reviewed again.',
    );

Future<void> _pump(
  WidgetTester tester,
  ContentReportService service, {
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: MyReportsScreen(service: service),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows decisions about the person and the reports they filed',
      (tester) async {
    await _pump(
        tester, _FakeService(reports: [_report()], decisions: [_decision()]));
    expect(find.text('Decisions about your content'), findsOneWidget);
    expect(find.textContaining('Your post broke the posting rules.'),
        findsOneWidget);
    expect(find.text('Reports you filed'), findsOneWidget);
    expect(find.textContaining('Removed after review.'), findsOneWidget);
    expect(find.text('Appeal this decision'), findsOneWidget);
    expect(find.text('Ask for a second look'), findsOneWidget);
  });

  testWidgets('empty lists say so', (tester) async {
    await _pump(tester, _FakeService());
    expect(find.text('No decision affects your content.'), findsOneWidget);
    expect(find.text('You have not filed any reports.'), findsOneWidget);
  });

  testWidgets('an appeal cannot be sent without an explanation',
      (tester) async {
    final service = _FakeService(decisions: [_decision()]);
    await _pump(tester, service);
    await tester.tap(find.byKey(const ValueKey<String>('appeal-d1')));
    await tester.pumpAndSettle();

    final send = find.byKey(const ValueKey<String>('moderation-note-send'));
    expect(tester.widget<FilledButton>(send).onPressed, isNull);

    await tester.enterText(
        find.byKey(const ValueKey<String>('moderation-note')),
        'This post was my own work.');
    await tester.pump();
    expect(tester.widget<FilledButton>(send).onPressed, isNotNull);
    await tester.tap(send);
    await tester.pumpAndSettle();

    expect(service.calls, ['appeal:d1:This post was my own work.']);
    expect(find.text('Sent.'), findsOneWidget);
  });

  testWidgets('a second look can be asked for without a note', (tester) async {
    final service = _FakeService(reports: [_report()]);
    await _pump(tester, service);
    await tester.tap(find.byKey(const ValueKey<String>('reconsider-r1')));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey<String>('moderation-note-send')));
    await tester.pumpAndSettle();
    expect(service.calls, ['reconsider:r1:']);
  });

  testWidgets('already-requested items offer no second action', (tester) async {
    await _pump(
        tester,
        _FakeService(
          reports: [_report(reconsidered: true)],
          decisions: [_decision(appealed: true)],
        ));
    expect(find.text('Appeal sent'), findsOneWidget);
    expect(find.text('Second look requested'), findsOneWidget);
    expect(find.text('Appeal this decision'), findsNothing);
    expect(find.text('Ask for a second look'), findsNothing);
  });

  testWidgets('a decided appeal shows its result and reasons', (tester) async {
    await _pump(
        tester,
        _FakeService(
            decisions: [_decision(appealed: true, result: 'reversed')]));
    expect(find.text('Appeal result: decision reversed'), findsOneWidget);
    expect(find.textContaining('Reviewed again.'), findsOneWidget);
  });

  testWidgets('a refused appeal explains why and does not claim success',
      (tester) async {
    final service = _FakeService(
      decisions: [_decision()],
      appealOutcome: ModerationActionOutcome.alreadyDone,
    );
    await _pump(tester, service);
    await tester.tap(find.byKey(const ValueKey<String>('appeal-d1')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey<String>('moderation-note')), 'Please look.');
    await tester.pump();
    await tester
        .tap(find.byKey(const ValueKey<String>('moderation-note-send')));
    await tester.pumpAndSettle();
    expect(find.text('This was already sent.'), findsOneWidget);
    expect(find.text('Sent.'), findsNothing);
  });

  testWidgets('a signed-out person is told to sign in', (tester) async {
    await _pump(tester,
        _FakeService(loadOutcome: ModerationActionOutcome.signInRequired));
    expect(find.text('Sign in to see your reports and decisions.'),
        findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('a failed load is explained and can be retried', (tester) async {
    await _pump(
        tester, _FakeService(loadOutcome: ModerationActionOutcome.failed));
    expect(
        find.text('Could not load your reports. Try again.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('Slovenian copy', (tester) async {
    await _pump(
        tester, _FakeService(reports: [_report()], decisions: [_decision()]),
        locale: const Locale('sl'));
    expect(find.text('Odločitve o vaši vsebini'), findsOneWidget);
    expect(find.text('Prijave, ki ste jih oddali'), findsOneWidget);
    expect(find.text('Pritoži se na odločitev'), findsOneWidget);
    expect(find.text('Zaprosi za ponovni pregled'), findsOneWidget);
    expect(find.textContaining('Vsebina odstranjena'), findsWidgets);
  });
}
