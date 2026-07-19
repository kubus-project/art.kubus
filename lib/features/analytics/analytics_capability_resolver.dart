import '../../models/dao.dart';
import '../../models/user_persona.dart';
import '../../utils/dao_role_verification.dart';
import '../../utils/wallet_utils.dart';
import 'analytics_entity_registry.dart';
import 'analytics_metric_registry.dart';
import 'analytics_presets.dart';

class AnalyticsViewerContext {
  const AnalyticsViewerContext({
    required this.viewerWallet,
    required this.subjectId,
    required this.persona,
    required this.daoReview,
    required this.profileIsArtist,
    required this.profileIsInstitution,
    required this.isAdmin,
    required this.analyticsEnabled,
  });

  final String viewerWallet;
  final String subjectId;
  final UserPersona? persona;
  final DAOReview? daoReview;
  final bool profileIsArtist;
  final bool profileIsInstitution;
  final bool isAdmin;
  final bool analyticsEnabled;

  bool get isSignedIn => viewerWallet.trim().isNotEmpty;

  bool get isOwner {
    final viewer = viewerWallet.trim();
    final subject = subjectId.trim();
    if (viewer.isEmpty || subject.isEmpty) return false;
    return WalletUtils.equals(viewer, subject);
  }

  DaoRoleVerification get roleVerification {
    return DaoRoleVerification(
      walletAddress: subjectId,
      review: daoReview,
    );
  }
}

/// Typed reason a viewer cannot open an analytics surface. Display copy for
/// every reason lives in `AnalyticsBlockedCopy` so it stays localized.
enum AnalyticsBlockedReason {
  walletRequired,
  analyticsDisabled,
  adminRequired,
  ownerRequired,
  privateOnly,
  artistReviewPending,
  artistReviewRejected,
  artistRoleMismatch,
  artistApprovalRequired,
  institutionReviewPending,
  institutionReviewRejected,
  institutionRoleMismatch,
  institutionApprovalRequired,
}

class AnalyticsCapabilities {
  const AnalyticsCapabilities({
    required this.canView,
    required this.canViewPrivate,
    required this.canExport,
    required this.scope,
    required this.allowedMetrics,
    required this.allowedOverviewMetrics,
    this.blockedReason,
  });

  final bool canView;
  final bool canViewPrivate;
  final bool canExport;
  final AnalyticsScope scope;
  final List<AnalyticsMetricDefinition> allowedMetrics;
  final List<AnalyticsMetricDefinition> allowedOverviewMetrics;
  final AnalyticsBlockedReason? blockedReason;

  bool get hasSeriesAccess =>
      canView &&
      allowedMetrics.any((m) {
        return m.seriesSupported && m.supportsScope(scope);
      });

  bool allowsMetric(AnalyticsMetricDefinition metric) {
    return allowedMetrics.any((entry) => entry.id == metric.id);
  }
}

class AnalyticsCapabilityResolver {
  const AnalyticsCapabilityResolver._();

  static AnalyticsCapabilities resolve({
    required AnalyticsPreset preset,
    required AnalyticsViewerContext viewer,
  }) {
    final subjectMissing = preset.entityType != AnalyticsEntityType.platform &&
        viewer.subjectId.trim().isEmpty;
    if (subjectMissing) {
      return _blocked(AnalyticsBlockedReason.walletRequired);
    }

    if (!viewer.analyticsEnabled) {
      return _blocked(AnalyticsBlockedReason.analyticsDisabled);
    }

    if (preset.roleRequirement == AnalyticsRoleRequirement.admin) {
      if (!viewer.isAdmin) {
        return _blocked(AnalyticsBlockedReason.adminRequired);
      }
      return _allowed(preset: preset, canViewPrivate: true);
    }

    if (preset.requiresOwner && !viewer.isOwner) {
      return _blocked(AnalyticsBlockedReason.ownerRequired);
    }

    final roleBlock = _roleBlockReason(preset, viewer);
    if (roleBlock != null) {
      return _blocked(roleBlock);
    }

    final canViewPrivate = viewer.isOwner;
    if (!canViewPrivate && !preset.allowsPublicView) {
      return _blocked(AnalyticsBlockedReason.privateOnly);
    }

    return _allowed(preset: preset, canViewPrivate: canViewPrivate);
  }

  static AnalyticsBlockedReason? _roleBlockReason(
    AnalyticsPreset preset,
    AnalyticsViewerContext viewer,
  ) {
    switch (preset.roleRequirement) {
      case AnalyticsRoleRequirement.none:
        return null;
      case AnalyticsRoleRequirement.admin:
        return viewer.isAdmin ? null : AnalyticsBlockedReason.adminRequired;
      case AnalyticsRoleRequirement.artist:
        if (_approvedForArtist(viewer)) return null;
        final verification = viewer.roleVerification;
        if (verification.isPendingFor(DaoRoleType.artist)) {
          return AnalyticsBlockedReason.artistReviewPending;
        }
        if (verification.isRejectedFor(DaoRoleType.artist)) {
          return AnalyticsBlockedReason.artistReviewRejected;
        }
        if (viewer.persona == UserPersona.institution ||
            viewer.profileIsInstitution) {
          return AnalyticsBlockedReason.artistRoleMismatch;
        }
        return AnalyticsBlockedReason.artistApprovalRequired;
      case AnalyticsRoleRequirement.institution:
        if (_approvedForInstitution(viewer)) return null;
        final verification = viewer.roleVerification;
        if (verification.isPendingFor(DaoRoleType.institution)) {
          return AnalyticsBlockedReason.institutionReviewPending;
        }
        if (verification.isRejectedFor(DaoRoleType.institution)) {
          return AnalyticsBlockedReason.institutionReviewRejected;
        }
        if (viewer.persona == UserPersona.creator || viewer.profileIsArtist) {
          return AnalyticsBlockedReason.institutionRoleMismatch;
        }
        return AnalyticsBlockedReason.institutionApprovalRequired;
    }
  }

  static bool _approvedForArtist(AnalyticsViewerContext viewer) {
    return viewer.profileIsArtist ||
        viewer.roleVerification.isApprovedFor(DaoRoleType.artist);
  }

  static bool _approvedForInstitution(AnalyticsViewerContext viewer) {
    return viewer.profileIsInstitution ||
        viewer.roleVerification.isApprovedFor(DaoRoleType.institution);
  }

  static AnalyticsCapabilities _allowed({
    required AnalyticsPreset preset,
    required bool canViewPrivate,
  }) {
    final scope =
        canViewPrivate ? AnalyticsScope.private : AnalyticsScope.public;
    final metrics = _filterMetrics(preset.metrics, scope);
    final overview = _filterMetrics(preset.overviewMetrics, scope);
    return AnalyticsCapabilities(
      canView: true,
      canViewPrivate: canViewPrivate,
      canExport: canViewPrivate && preset.supportsExport,
      scope: scope,
      allowedMetrics: metrics,
      allowedOverviewMetrics:
          overview.isNotEmpty ? overview : metrics.take(4).toList(),
    );
  }

  static List<AnalyticsMetricDefinition> _filterMetrics(
    List<AnalyticsMetricDefinition> metrics,
    AnalyticsScope scope,
  ) {
    return metrics
        .where((metric) => metric.supportsScope(scope))
        .toList(growable: false);
  }

  static AnalyticsCapabilities _blocked(AnalyticsBlockedReason reason) {
    return AnalyticsCapabilities(
      canView: false,
      canViewPrivate: false,
      canExport: false,
      scope: AnalyticsScope.public,
      allowedMetrics: const <AnalyticsMetricDefinition>[],
      allowedOverviewMetrics: const <AnalyticsMetricDefinition>[],
      blockedReason: reason,
    );
  }
}
