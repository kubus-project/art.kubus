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

class AnalyticsCapabilities {
  const AnalyticsCapabilities({
    required this.canView,
    required this.canViewPrivate,
    required this.canExport,
    required this.scope,
    required this.allowedMetrics,
    required this.allowedOverviewMetrics,
    this.blockedTitle,
    this.blockedDescription,
  });

  final bool canView;
  final bool canViewPrivate;
  final bool canExport;
  final AnalyticsScope scope;
  final List<AnalyticsMetricDefinition> allowedMetrics;
  final List<AnalyticsMetricDefinition> allowedOverviewMetrics;
  final String? blockedTitle;
  final String? blockedDescription;

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
      return _blocked(
        preset: preset,
        title: 'Connect your wallet',
        description: 'Analytics are available after a wallet is connected.',
      );
    }

    if (!viewer.analyticsEnabled) {
      return _blocked(
        preset: preset,
        title: 'Analytics disabled',
        description:
            'Enable analytics in Settings to view charts and insights.',
      );
    }

    if (preset.roleRequirement == AnalyticsRoleRequirement.admin) {
      if (!viewer.isAdmin) {
        return _blocked(
          preset: preset,
          title: 'Admin analytics',
          description: 'Platform analytics require an admin session.',
        );
      }
      return _allowed(preset: preset, canViewPrivate: true);
    }

    if (preset.requiresOwner && !viewer.isOwner) {
      return _blocked(
        preset: preset,
        title: 'Private analytics',
        description: 'Use the wallet that owns this workspace.',
      );
    }

    final roleBlock = _roleBlockReason(preset, viewer);
    if (roleBlock != null) {
      return _blocked(
        preset: preset,
        title: roleBlock.$1,
        description: roleBlock.$2,
      );
    }

    final canViewPrivate = viewer.isOwner;
    if (!canViewPrivate && !preset.allowsPublicView) {
      return _blocked(
        preset: preset,
        title: 'Private analytics',
        description: 'This analytics workspace is available to its owner only.',
      );
    }

    return _allowed(preset: preset, canViewPrivate: canViewPrivate);
  }

  static (String, String)? _roleBlockReason(
    AnalyticsPreset preset,
    AnalyticsViewerContext viewer,
  ) {
    switch (preset.roleRequirement) {
      case AnalyticsRoleRequirement.none:
        return null;
      case AnalyticsRoleRequirement.admin:
        return viewer.isAdmin
            ? null
            : ('Admin analytics', 'Platform analytics require admin access.');
      case AnalyticsRoleRequirement.artist:
        if (_approvedForArtist(viewer)) return null;
        final verification = viewer.roleVerification;
        if (verification.isPendingFor(DaoRoleType.artist)) {
          return (
            'Artist review pending',
            'Artist analytics unlock after DAO approval.'
          );
        }
        if (verification.isRejectedFor(DaoRoleType.artist)) {
          return (
            'Artist review rejected',
            'Submit an approved artist review before using artist analytics.'
          );
        }
        if (viewer.persona == UserPersona.institution ||
            viewer.profileIsInstitution) {
          return (
            'Artist analytics unavailable',
            'Use an approved artist wallet for artist analytics.'
          );
        }
        return (
          'Artist approval required',
          'Apply for DAO artist review to unlock artist analytics.'
        );
      case AnalyticsRoleRequirement.institution:
        if (_approvedForInstitution(viewer)) return null;
        final verification = viewer.roleVerification;
        if (verification.isPendingFor(DaoRoleType.institution)) {
          return (
            'Institution review pending',
            'Institution analytics unlock after DAO approval.'
          );
        }
        if (verification.isRejectedFor(DaoRoleType.institution)) {
          return (
            'Institution review rejected',
            'Submit an approved institution review before using analytics.'
          );
        }
        if (viewer.persona == UserPersona.creator || viewer.profileIsArtist) {
          return (
            'Institution analytics unavailable',
            'Use an approved institution wallet for institution analytics.'
          );
        }
        return (
          'Institution approval required',
          'Apply for DAO institution review to unlock institution analytics.'
        );
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

  static AnalyticsCapabilities _blocked({
    required AnalyticsPreset preset,
    required String title,
    required String description,
  }) {
    return AnalyticsCapabilities(
      canView: false,
      canViewPrivate: false,
      canExport: false,
      scope: AnalyticsScope.public,
      allowedMetrics: const <AnalyticsMetricDefinition>[],
      allowedOverviewMetrics: const <AnalyticsMetricDefinition>[],
      blockedTitle: title,
      blockedDescription: description,
    );
  }
}
