import 'package:art_kubus/features/analytics/analytics_capability_resolver.dart';
import 'package:art_kubus/features/analytics/analytics_entity_registry.dart';
import 'package:art_kubus/features/analytics/analytics_presets.dart';
import 'package:art_kubus/models/account_verification.dart';
import 'package:art_kubus/models/user_persona.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AnalyticsViewerContext viewer({
    String viewerWallet = 'wallet_owner',
    String subjectId = 'wallet_owner',
    UserPersona? persona,
    ArtistVerificationStatus artistStatus = ArtistVerificationStatus.notApplied,
    InstitutionAccessStatus institutionAccess = InstitutionAccessStatus.none,
    bool profileIsArtist = false,
    bool profileIsInstitution = false,
    bool isAdmin = false,
    bool analyticsBuildAvailable = true,
    bool analyticsPreferenceEnabled = true,
  }) {
    return AnalyticsViewerContext(
      viewerWallet: viewerWallet,
      subjectId: subjectId,
      persona: persona,
      artistStatus: artistStatus,
      institutionAccess: institutionAccess,
      profileIsArtist: profileIsArtist,
      profileIsInstitution: profileIsInstitution,
      isAdmin: isAdmin,
      analyticsBuildAvailable: analyticsBuildAvailable,
      analyticsPreferenceEnabled: analyticsPreferenceEnabled,
    );
  }

  test('profile analytics are owner-bound', () {
    final capabilities = AnalyticsCapabilityResolver.resolve(
      preset: AnalyticsPresets.profile,
      viewer: viewer(
        viewerWallet: 'wallet_viewer',
        subjectId: 'wallet_owner',
      ),
    );

    expect(capabilities.canView, isFalse);
    expect(capabilities.canViewPrivate, isFalse);
    expect(capabilities.blockedReason, AnalyticsBlockedReason.ownerRequired);
  });

  test('distinguishes a user opt-out from an unavailable build', () {
    final preferenceDisabled = AnalyticsCapabilityResolver.resolve(
      preset: AnalyticsPresets.profile,
      viewer: viewer(analyticsPreferenceEnabled: false),
    );
    final buildUnavailable = AnalyticsCapabilityResolver.resolve(
      preset: AnalyticsPresets.profile,
      viewer: viewer(analyticsBuildAvailable: false),
    );

    expect(
      preferenceDisabled.blockedReason,
      AnalyticsBlockedReason.analyticsDisabledByPreference,
    );
    expect(
      buildUnavailable.blockedReason,
      AnalyticsBlockedReason.analyticsUnavailable,
    );
  });

  test('dao analytics are public and use governance metrics', () {
    final capabilities = AnalyticsCapabilityResolver.resolve(
      preset: AnalyticsPresets.dao,
      viewer: viewer(
        viewerWallet: 'wallet_viewer',
        subjectId: 'governance',
      ),
    );

    expect(capabilities.canView, isTrue);
    expect(capabilities.canViewPrivate, isFalse);
    expect(capabilities.canExport, isFalse);
    expect(capabilities.scope, AnalyticsScope.public);
    final metricIds = capabilities.allowedMetrics.map((metric) => metric.id);
    expect(
        metricIds,
        containsAll(<String>[
          'daoTotalProposals',
          'daoVotesCast',
          'daoTreasuryAmount',
        ]));
    expect(metricIds, isNot(contains('users')));
    expect(metricIds, isNot(contains('profiles')));
  });

  test('profile owner receives private analytics and export capability', () {
    final capabilities = AnalyticsCapabilityResolver.resolve(
      preset: AnalyticsPresets.profile,
      viewer: viewer(),
    );

    expect(capabilities.canView, isTrue);
    expect(capabilities.canViewPrivate, isTrue);
    expect(capabilities.canExport, isTrue);
    expect(capabilities.scope, AnalyticsScope.private);
    expect(capabilities.allowedMetrics.map((metric) => metric.id),
        contains('engagement'));
  });

  test('artist analytics require an approved artist role', () {
    final pending = AnalyticsCapabilityResolver.resolve(
      preset: AnalyticsPresets.artist,
      viewer: viewer(
        persona: UserPersona.creator,
        artistStatus: ArtistVerificationStatus.pending,
      ),
    );

    expect(pending.canView, isFalse);
    expect(
      pending.blockedReason,
      AnalyticsBlockedReason.artistReviewPending,
    );

    final approved = AnalyticsCapabilityResolver.resolve(
      preset: AnalyticsPresets.artist,
      viewer: viewer(
        persona: UserPersona.creator,
        artistStatus: ArtistVerificationStatus.approved,
      ),
    );

    expect(approved.canView, isTrue);
    expect(approved.canViewPrivate, isTrue);
  });

  test('institution analytics follow membership, not an artist persona', () {
    // Roles are additive: an artist can also be a member of an institution.
    final member = AnalyticsCapabilityResolver.resolve(
      preset: AnalyticsPresets.institution,
      viewer: viewer(
        persona: UserPersona.creator,
        profileIsArtist: true,
        artistStatus: ArtistVerificationStatus.approved,
        institutionAccess: InstitutionAccessStatus.member,
      ),
    );
    expect(member.canView, isTrue);

    final pending = AnalyticsCapabilityResolver.resolve(
      preset: AnalyticsPresets.institution,
      viewer: viewer(
        institutionAccess: InstitutionAccessStatus.requestPending,
      ),
    );
    expect(pending.canView, isFalse);
    expect(
        pending.blockedReason, AnalyticsBlockedReason.institutionReviewPending);

    // An artist persona or profile flag alone grants nothing.
    final none = AnalyticsCapabilityResolver.resolve(
      preset: AnalyticsPresets.institution,
      viewer: viewer(persona: UserPersona.institution),
    );
    expect(none.canView, isFalse);
    expect(
        none.blockedReason, AnalyticsBlockedReason.institutionApprovalRequired);
  });

  test('platform analytics require admin context', () {
    final blocked = AnalyticsCapabilityResolver.resolve(
      preset: AnalyticsPresets.platform,
      viewer: viewer(subjectId: 'global'),
    );
    expect(blocked.canView, isFalse);

    final allowed = AnalyticsCapabilityResolver.resolve(
      preset: AnalyticsPresets.platform,
      viewer: viewer(subjectId: 'global', isAdmin: true),
    );
    expect(allowed.canView, isTrue);
    expect(allowed.scope, AnalyticsScope.private);
    expect(
        allowed.allowedMetrics.map((metric) => metric.id), contains('views'));
  });
}
