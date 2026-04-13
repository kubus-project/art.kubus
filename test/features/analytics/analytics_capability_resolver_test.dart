import 'package:art_kubus/features/analytics/analytics_capability_resolver.dart';
import 'package:art_kubus/features/analytics/analytics_entity_registry.dart';
import 'package:art_kubus/features/analytics/analytics_presets.dart';
import 'package:art_kubus/models/dao.dart';
import 'package:art_kubus/models/user_persona.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AnalyticsViewerContext viewer({
    String viewerWallet = 'wallet_owner',
    String subjectId = 'wallet_owner',
    UserPersona? persona,
    DAOReview? daoReview,
    bool profileIsArtist = false,
    bool profileIsInstitution = false,
    bool isAdmin = false,
    bool analyticsEnabled = true,
  }) {
    return AnalyticsViewerContext(
      viewerWallet: viewerWallet,
      subjectId: subjectId,
      persona: persona,
      daoReview: daoReview,
      profileIsArtist: profileIsArtist,
      profileIsInstitution: profileIsInstitution,
      isAdmin: isAdmin,
      analyticsEnabled: analyticsEnabled,
    );
  }

  DAOReview review({
    String status = 'approved',
    String role = 'artist',
  }) {
    return DAOReview(
      id: 'review_1',
      walletAddress: 'wallet_owner',
      portfolioUrl: 'https://example.test',
      medium: 'mixed',
      statement: 'review',
      status: status,
      createdAt: DateTime.utc(2025, 1, 1),
      metadata: <String, dynamic>{'role': role},
    );
  }

  test(
      'profile analytics allow public access for non-owners only to public metrics',
      () {
    final capabilities = AnalyticsCapabilityResolver.resolve(
      preset: AnalyticsPresets.profile,
      viewer: viewer(
        viewerWallet: 'wallet_viewer',
        subjectId: 'wallet_owner',
      ),
    );

    expect(capabilities.canView, isTrue);
    expect(capabilities.canViewPrivate, isFalse);
    expect(capabilities.scope, AnalyticsScope.public);
    expect(capabilities.allowedMetrics.map((metric) => metric.id),
        contains('viewsReceived'));
    expect(
      capabilities.allowedMetrics.map((metric) => metric.id),
      isNot(contains('engagement')),
    );
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
        daoReview: review(status: 'pending', role: 'artist'),
      ),
    );

    expect(pending.canView, isFalse);
    expect(pending.blockedTitle, 'Artist review pending');

    final approved = AnalyticsCapabilityResolver.resolve(
      preset: AnalyticsPresets.artist,
      viewer: viewer(
        persona: UserPersona.creator,
        daoReview: review(role: 'artist'),
      ),
    );

    expect(approved.canView, isTrue);
    expect(approved.canViewPrivate, isTrue);
  });

  test('institution analytics reject incompatible artist persona', () {
    final capabilities = AnalyticsCapabilityResolver.resolve(
      preset: AnalyticsPresets.institution,
      viewer: viewer(
        persona: UserPersona.creator,
        profileIsArtist: true,
      ),
    );

    expect(capabilities.canView, isFalse);
    expect(capabilities.blockedTitle, 'Institution analytics unavailable');
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
