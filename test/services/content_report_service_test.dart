import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/content_report_service.dart';
import 'package:flutter_test/flutter_test.dart';

BackendApiRequestException _http(int status) =>
    BackendApiRequestException(statusCode: status, path: '/api/reports');

void main() {
  group('ContentReportDraft', () {
    test('an ordinary category needs nothing more', () {
      expect(
        const ContentReportDraft(category: ReportCategory.spam).isComplete,
        isTrue,
      );
    });

    test('illegal content and copyright need a statement and an explanation',
        () {
      for (final category in [
        ReportCategory.illegalContent,
        ReportCategory.copyright
      ]) {
        expect(ContentReportDraft(category: category).isComplete, isFalse);
        expect(
          ContentReportDraft(category: category, details: 'It is mine.')
              .isComplete,
          isFalse,
          reason: 'explanation without the statement',
        );
        expect(
          ContentReportDraft(category: category, goodFaithStatement: true)
              .isComplete,
          isFalse,
          reason: 'statement without an explanation',
        );
        expect(
          ContentReportDraft(
            category: category,
            details: 'It is mine.',
            goodFaithStatement: true,
          ).isComplete,
          isTrue,
        );
      }
    });

    test('a contact address, when given, must parse', () {
      expect(
        const ContentReportDraft(
                category: ReportCategory.spam, contactEmail: 'nope')
            .isComplete,
        isFalse,
      );
      expect(
        const ContentReportDraft(
                category: ReportCategory.spam, contactEmail: 'a@example.test')
            .isComplete,
        isTrue,
      );
    });

    test('wire values match what the backend accepts', () {
      expect(ReportCategory.values.map((c) => c.wire), [
        'illegal_content',
        'copyright',
        'privacy',
        'harassment',
        'spam',
        'impersonation',
        'safety',
        'other',
      ]);
    });
  });

  group('ContentReportService', () {
    ContentReportService service({
      List<Map<String, dynamic>>? reports,
      List<Map<String, dynamic>>? decisions,
      Object? loadError,
      Object? sendError,
      List<String>? sent,
    }) =>
        ContentReportService(
          fetchReports: () async {
            if (loadError != null) throw loadError;
            return reports ?? [];
          },
          fetchDecisions: () async => decisions ?? [],
          sendReconsideration: (id, note) async {
            sent?.add('reconsider:$id:${note ?? ''}');
            if (sendError != null) throw sendError;
          },
          sendAppeal: (id, note) async {
            sent?.add('appeal:$id:${note ?? ''}');
            if (sendError != null) throw sendError;
          },
        );

    test('parses the reporter view and the affected view', () async {
      final result = await service(
        reports: [
          {
            'id': 'r1',
            'targetType': 'post',
            'reasonCode': 'spam',
            'status': 'resolved',
            'outcome': 'content_removed',
            'outcomeReason': 'Removed.',
            'decidedAt': '2026-10-31T11:00:00.000Z',
            'reconsiderationRequestedAt': null,
            'createdAt': '2026-10-31T10:00:00.000Z',
          }
        ],
        decisions: [
          {
            'id': 'r2',
            'targetType': 'post',
            'outcome': 'content_removed',
            'statementOfReasons': 'It broke the rules.',
            'decidedAt': '2026-10-31T11:00:00.000Z',
            'appealRequestedAt': null,
            'appealResult': null,
          }
        ],
      ).load();

      final overview = result.overview!;
      expect(overview.reports.single.canRequestReconsideration, isTrue);
      expect(overview.reports.single.outcomeReason, 'Removed.');
      expect(overview.decisions.single.canAppeal, isTrue);
      expect(
          overview.decisions.single.statementOfReasons, 'It broke the rules.');
    });

    test(
        'a report without a decision cannot be reconsidered; one already asked cannot repeat',
        () async {
      final overview = (await service(reports: [
        {'id': 'a', 'status': 'open'},
        {
          'id': 'b',
          'status': 'resolved',
          'outcome': 'no_action',
          'reconsiderationRequestedAt': '2026-10-31T12:00:00.000Z'
        },
      ]).load())
          .overview!;
      expect(overview.reports[0].canRequestReconsideration, isFalse);
      expect(overview.reports[1].canRequestReconsideration, isFalse);
    });

    test('loading maps HTTP failures to outcomes', () async {
      expect((await service(loadError: _http(401)).load()).outcome,
          ModerationActionOutcome.signInRequired);
      expect((await service(loadError: _http(429)).load()).outcome,
          ModerationActionOutcome.tooManyRequests);
      expect((await service(loadError: StateError('x')).load()).outcome,
          ModerationActionOutcome.failed);
    });

    test('an appeal needs its explanation and sends nothing without one',
        () async {
      final sent = <String>[];
      final svc = service(sent: sent);
      expect(
          await svc.appeal('r2', note: '   '), ModerationActionOutcome.failed);
      expect(sent, isEmpty);
      expect(await svc.appeal('r2', note: 'This was my own work.'),
          ModerationActionOutcome.done);
      expect(sent, ['appeal:r2:This was my own work.']);
    });

    test('send failures map to outcomes the screen can explain', () async {
      expect(await service(sendError: _http(409)).requestReconsideration('r1'),
          ModerationActionOutcome.alreadyDone);
      expect(await service(sendError: _http(404)).requestReconsideration('r1'),
          ModerationActionOutcome.notAvailable);
      expect(await service(sendError: _http(500)).appeal('r1', note: 'x'),
          ModerationActionOutcome.failed);
    });
  });
}
