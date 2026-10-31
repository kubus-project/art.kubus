import 'backend_api_service.dart';

/// Categories a report can be filed under. [wire] is the value the backend
/// accepts as `reasonCode`.
enum ReportCategory {
  illegalContent('illegal_content'),
  copyright('copyright'),
  privacy('privacy'),
  harassment('harassment'),
  spam('spam'),
  impersonation('impersonation'),
  safety('safety'),
  other('other');

  const ReportCategory(this.wire);

  final String wire;

  /// Reports that assert a legal wrong carry an explicit good-faith statement and
  /// an explanation. Whether they are formal notices under any law is the
  /// operator's decision, not the app's.
  bool get needsGoodFaithStatement =>
      this == ReportCategory.illegalContent || this == ReportCategory.copyright;
}

class ContentReportDraft {
  const ContentReportDraft({
    required this.category,
    this.details,
    this.goodFaithStatement = false,
    this.contactEmail,
  });

  final ReportCategory category;
  final String? details;
  final bool goodFaithStatement;
  final String? contactEmail;

  static final RegExp _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static bool isValidEmail(String value) => _email.hasMatch(value.trim());

  /// The draft is complete when the backend would accept it: notice-type reports
  /// need the statement and an explanation, and a contact address must parse.
  bool get isComplete {
    if (category.needsGoodFaithStatement) {
      if (!goodFaithStatement) return false;
      if ((details ?? '').trim().isEmpty) return false;
    }
    final email = (contactEmail ?? '').trim();
    return email.isEmpty || isValidEmail(email);
  }
}

class ReporterReport {
  const ReporterReport({
    required this.id,
    required this.targetType,
    required this.reasonCode,
    required this.status,
    required this.outcome,
    required this.outcomeReason,
    required this.decidedAt,
    required this.reconsiderationRequested,
    required this.createdAt,
  });

  factory ReporterReport.fromJson(Map<String, dynamic> json) => ReporterReport(
        id: (json['id'] ?? '').toString(),
        targetType: (json['targetType'] ?? '').toString(),
        reasonCode: json['reasonCode']?.toString(),
        status: (json['status'] ?? '').toString(),
        outcome: json['outcome']?.toString(),
        outcomeReason: json['outcomeReason']?.toString(),
        decidedAt: DateTime.tryParse((json['decidedAt'] ?? '').toString()),
        reconsiderationRequested: json['reconsiderationRequestedAt'] != null,
        createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
      );

  final String id;
  final String targetType;
  final String? reasonCode;
  final String status;
  final String? outcome;
  final String? outcomeReason;
  final DateTime? decidedAt;
  final bool reconsiderationRequested;
  final DateTime? createdAt;

  bool get canRequestReconsideration =>
      outcome != null && !reconsiderationRequested;
}

class DecisionAboutMe {
  const DecisionAboutMe({
    required this.id,
    required this.targetType,
    required this.outcome,
    required this.statementOfReasons,
    required this.decidedAt,
    required this.appealRequested,
    required this.appealResult,
    required this.appealResultReason,
  });

  factory DecisionAboutMe.fromJson(Map<String, dynamic> json) =>
      DecisionAboutMe(
        id: (json['id'] ?? '').toString(),
        targetType: (json['targetType'] ?? '').toString(),
        outcome: (json['outcome'] ?? '').toString(),
        statementOfReasons: json['statementOfReasons']?.toString(),
        decidedAt: DateTime.tryParse((json['decidedAt'] ?? '').toString()),
        appealRequested: json['appealRequestedAt'] != null,
        appealResult: json['appealResult']?.toString(),
        appealResultReason: json['appealResultReason']?.toString(),
      );

  final String id;
  final String targetType;
  final String outcome;
  final String? statementOfReasons;
  final DateTime? decidedAt;
  final bool appealRequested;
  final String? appealResult;
  final String? appealResultReason;

  bool get canAppeal => !appealRequested;
}

enum ModerationActionOutcome {
  done,
  signInRequired,
  notAvailable,
  alreadyDone,
  tooManyRequests,
  failed,
}

class ModerationOverview {
  const ModerationOverview({
    this.reports = const <ReporterReport>[],
    this.decisions = const <DecisionAboutMe>[],
  });

  final List<ReporterReport> reports;
  final List<DecisionAboutMe> decisions;
}

class ModerationLoadResult {
  const ModerationLoadResult.loaded(ModerationOverview this.overview)
      : outcome = ModerationActionOutcome.done;
  const ModerationLoadResult.failed(this.outcome) : overview = null;

  final ModerationActionOutcome outcome;
  final ModerationOverview? overview;
}

typedef ModerationListFetch = Future<List<Map<String, dynamic>>> Function();
typedef ModerationNoteSend = Future<void> Function(String id, String? note);

/// The person's own side of moderation: the reports they filed and what was
/// decided about them, and the decisions that affect their own content, each with
/// the one follow-up the backend allows (reconsideration or appeal).
class ContentReportService {
  ContentReportService({
    ModerationListFetch? fetchReports,
    ModerationListFetch? fetchDecisions,
    ModerationNoteSend? sendReconsideration,
    ModerationNoteSend? sendAppeal,
  })  : _fetchReports = fetchReports ?? BackendApiService().getMyReports,
        _fetchDecisions =
            fetchDecisions ?? BackendApiService().getDecisionsAboutMe,
        _sendReconsideration = sendReconsideration ??
            ((id, note) => BackendApiService()
                .requestReportReconsideration(id, note: note)),
        _sendAppeal = sendAppeal ??
            ((id, note) => BackendApiService()
                .appealModerationDecision(id, note: note ?? ''));

  final ModerationListFetch _fetchReports;
  final ModerationListFetch _fetchDecisions;
  final ModerationNoteSend _sendReconsideration;
  final ModerationNoteSend _sendAppeal;

  static ModerationActionOutcome _outcomeFor(Object error) {
    if (error is BackendApiRequestException) {
      switch (error.statusCode) {
        case 401:
        case 403:
          return ModerationActionOutcome.signInRequired;
        case 404:
          return ModerationActionOutcome.notAvailable;
        case 409:
          return ModerationActionOutcome.alreadyDone;
        case 429:
          return ModerationActionOutcome.tooManyRequests;
      }
    }
    return ModerationActionOutcome.failed;
  }

  Future<ModerationLoadResult> load() async {
    try {
      final reports = await _fetchReports();
      final decisions = await _fetchDecisions();
      return ModerationLoadResult.loaded(ModerationOverview(
        reports: reports.map(ReporterReport.fromJson).toList(growable: false),
        decisions:
            decisions.map(DecisionAboutMe.fromJson).toList(growable: false),
      ));
    } catch (error) {
      return ModerationLoadResult.failed(_outcomeFor(error));
    }
  }

  Future<ModerationActionOutcome> requestReconsideration(String reportId,
      {String? note}) async {
    try {
      await _sendReconsideration(reportId, note);
      return ModerationActionOutcome.done;
    } catch (error) {
      return _outcomeFor(error);
    }
  }

  /// An appeal needs its explanation; the backend refuses an empty one.
  Future<ModerationActionOutcome> appeal(String reportId,
      {required String note}) async {
    if (note.trim().isEmpty) return ModerationActionOutcome.failed;
    try {
      await _sendAppeal(reportId, note);
      return ModerationActionOutcome.done;
    } catch (error) {
      return _outcomeFor(error);
    }
  }
}
