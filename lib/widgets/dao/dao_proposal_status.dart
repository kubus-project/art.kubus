import 'package:art_kubus/l10n/app_localizations.dart';

import '../../models/dao.dart';
import '../dashboard/kubus_dashboard_chrome.dart';

/// Localized label for a proposal's lifecycle state.
String daoProposalStatusLabel(AppLocalizations l10n, ProposalStatus status) {
  switch (status) {
    case ProposalStatus.draft:
      return l10n.daoProposalStatusDraft;
    case ProposalStatus.active:
      return l10n.daoProposalStatusActive;
    case ProposalStatus.voting:
      return l10n.daoProposalStatusVoting;
    case ProposalStatus.passed:
      return l10n.daoProposalStatusPassed;
    case ProposalStatus.failed:
      return l10n.daoProposalStatusFailed;
    case ProposalStatus.executed:
      return l10n.daoProposalStatusExecuted;
  }
}

/// Status tone: open votes warn, outcomes are positive/negative.
KubusStatusTone daoProposalStatusTone(ProposalStatus status) {
  switch (status) {
    case ProposalStatus.active:
    case ProposalStatus.voting:
      return KubusStatusTone.warning;
    case ProposalStatus.passed:
    case ProposalStatus.executed:
      return KubusStatusTone.positive;
    case ProposalStatus.failed:
      return KubusStatusTone.negative;
    case ProposalStatus.draft:
      return KubusStatusTone.neutral;
  }
}
