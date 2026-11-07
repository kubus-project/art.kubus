import 'dart:async';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/conversation_navigator.dart';
import '../../../models/institution.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/institution_provider.dart';
import '../../../services/backend_api_service.dart';
import '../../../services/contextual_auth_gate.dart';
import '../../../services/telemetry/telemetry_service.dart';
import '../../../services/user_service.dart';
import '../../../utils/design_tokens.dart';
import '../../../utils/media_url_resolver.dart';
import '../../../utils/map_coordinate_rules.dart';
import '../../../utils/map_navigation.dart';
import '../../../utils/user_profile_navigation.dart';
import '../../../widgets/avatar_widget.dart';
import '../../../widgets/dashboard/kubus_dashboard_chrome.dart';
import '../../../widgets/detail/profile_relationship_actions.dart';
import '../../../widgets/kubus_snackbar.dart';
import '../../../widgets/profile/profile_identity_hero.dart';
import '../../../widgets/empty_state_card.dart';
import '../../../widgets/glass_components.dart';
import '../../../widgets/inline_loading.dart';
import '../../events/event_detail_screen.dart';
import 'institution_claim_sheet.dart';
import '../../../providers/activation_prompt_provider.dart';

/// Minimum touch target of the photo-credit affordance.
const double _creditButtonSize = 44;

/// Reading width for the text column. The cover stays full width.
const double _readingWidth = 720;

class InstitutionDetailScreen extends StatefulWidget {
  const InstitutionDetailScreen({
    super.key,
    required this.institutionId,
    this.embedded = false,
  });

  final String institutionId;
  final bool embedded;

  @override
  State<InstitutionDetailScreen> createState() =>
      _InstitutionDetailScreenState();
}

class _InstitutionDetailScreenState extends State<InstitutionDetailScreen> {
  final BackendApiService _api = BackendApiService();

  Institution? _institution;
  List<Event> _events = const <Event>[];
  bool _loading = true;
  String? _error;

  /// Follow state of the explicitly verified account. Null until the status
  /// answers; it is only ever read for a verified link with an account UUID.
  bool? _accountIsFollowing;
  bool _accountFollowInFlight = false;

  /// True while the signed-in account has an undecided claim request on this
  /// profile; the claim action is then replaced by a status notice.
  bool _claimOpen = false;

  /// Whether the backend accepts claim requests right now; null until the
  /// probe answers. The claim action is only offered on a definite yes, so a
  /// switched-off feature never shows a button that leads to a dead end.
  bool? _claimsAvailable;

  /// Bumped when this screen learns the claim state itself (a request was
  /// just sent). A claim list that was requested earlier must not overwrite it.
  int _claimEpoch = 0;

  /// Anchors the image credits footer; the photo-credit buttons scroll to it.
  final GlobalKey _creditsFooterKey = GlobalKey();

  /// Small info button over an image: a translucent circle inside a 44 dp hit
  /// area that scrolls to the image credits.
  Widget _buildCreditButton(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final label = l10n.institutionDetailPhotoCreditsAction;
    return IconButton(
      tooltip: label,
      onPressed: _scrollToCredits,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(
        width: _creditButtonSize,
        height: _creditButtonSize,
      ),
      icon: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scheme.scrim.withValues(alpha: 0.5),
        ),
        child: const SizedBox.square(
          dimension: 28,
          child: Icon(Icons.info_outline, size: 18, color: Colors.white),
        ),
      ),
    );
  }

  void _scrollToCredits() {
    final targetContext = _creditsFooterKey.currentContext;
    if (targetContext == null) return;
    final reduceMotion = MediaQuery.disableAnimationsOf(targetContext);
    unawaited(Scrollable.ensureVisible(
      targetContext,
      alignment: 1.0,
      duration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInstitution();
      unawaited(
          TelemetryService().trackInstitutionViewed(widget.institutionId));
      if (!mounted) return;
      ActivationPromptProvider.recordEntityViewFor(context);
    });
  }

  Future<void> _loadInstitution() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final provider = context.read<InstitutionProvider>();
      Institution? institution =
          provider.getInstitutionById(widget.institutionId);
      var events = provider.getEventsByInstitution(widget.institutionId);

      if (institution == null || events.isEmpty) {
        await provider.refreshData();
        if (!mounted) return;
        institution ??= provider.getInstitutionById(widget.institutionId);
        if (events.isEmpty) {
          events = provider.getEventsByInstitution(widget.institutionId);
        }
      }

      if (institution == null) {
        final rawInstitution = await _api.getInstitution(widget.institutionId);
        if (!mounted) return;
        if (rawInstitution != null) {
          institution = _tryParseInstitution(rawInstitution);
        }
      }

      if (events.isEmpty) {
        final rawEvents = await _api.listEvents(
          institutionId: widget.institutionId,
          limit: 20,
          offset: 0,
        );
        if (!mounted) return;
        events = rawEvents.map(_tryParseEvent).whereType<Event>().toList();
      }

      events.sort((a, b) => a.startDate.compareTo(b.startDate));

      if (!mounted) return;
      setState(() {
        _institution = institution;
        _events = List<Event>.unmodifiable(events);
        _loading = false;
      });
      final linkedUserId = institution?.verifiedAccountProfile?.userId;
      if (linkedUserId != null) {
        unawaited(_refreshAccountFollowState(linkedUserId));
      }
      if (institution != null) {
        unawaited(_refreshClaimAvailability(institution));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  /// Learns whether claim requests are open, then (for a signed-in account)
  /// whether this account already has one. Only imported, unclaimed listings
  /// can be claimed, so nothing is asked for any other profile.
  Future<void> _refreshClaimAvailability(Institution institution) async {
    // Each load starts without claim state, so an earlier read (possibly for
    // another account) cannot keep the claim action hidden or shown.
    if (mounted) {
      setState(() {
        _claimsAvailable = null;
        _claimOpen = false;
      });
    }
    if (!institution.isImportedUnclaimed) return;
    final available = await _api.institutionClaimsAvailable();
    if (!mounted) return;
    setState(() => _claimsAvailable = available);
    if (available == true) await _refreshOwnClaimState(institution);
  }

  /// Whether the signed-in account already asked to claim [institution].
  /// Signed-out visitors and any failure leave the claim action available.
  Future<void> _refreshOwnClaimState(Institution institution) async {
    if (!institution.isImportedUnclaimed) return;
    if ((_api.getAuthToken() ?? '').trim().isEmpty) return;
    final epoch = _claimEpoch;
    // The read belongs to the account that was signed in when it started. A
    // sign-out or switch while it is in flight makes the answer another
    // account's, so it is dropped.
    final sessionEpoch = _api.authSessionEpoch;
    try {
      final claims = await _api.getMyInstitutionClaims();
      // A request sent while this read was in flight is newer than the read.
      if (!mounted ||
          epoch != _claimEpoch ||
          sessionEpoch != _api.authSessionEpoch) {
        return;
      }
      final id = institution.id.toLowerCase();
      final open =
          claims.any((claim) => claim.isOpen && claim.institutionId == id);
      if (open != _claimOpen) setState(() => _claimOpen = open);
    } catch (_) {
      // The claim action stays available; the backend refuses a duplicate.
    }
  }

  Future<void> _startClaim(Institution institution) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final authenticated = await const ContextualAuthGate().ensureAuthenticated(
      context,
      actionLabel: l10n.institutionClaimAuthAction,
      returnRoute: '/main',
      targetLabel: institution.name,
      sourceScreen: 'institution_detail',
    );
    if (!authenticated || !mounted) return;

    final result =
        await showInstitutionClaimSheet(context, institution: institution);
    if (!mounted || result == null) return;
    setState(() {
      _claimEpoch++;
      _claimOpen = true;
    });
    messenger.showKubusSnackBar(
      SnackBar(
        content: Text(result == InstitutionClaimSheetResult.submitted
            ? l10n.institutionClaimSubmittedToast
            : l10n.institutionClaimAlreadyOpenToast),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildClaimButton(AppLocalizations l10n, Institution institution) {
    void claim() => unawaited(_startClaim(institution));
    // The wrapper replaces the FAB's own semantics (a longer, clearer label),
    // so it must carry the tap action itself or assistive technology would
    // announce a button it cannot activate.
    return Semantics(
      button: true,
      enabled: true,
      focusable: true,
      label: l10n.institutionClaimButtonSemantics,
      onTap: claim,
      excludeSemantics: true,
      child: FloatingActionButton.extended(
        key: const ValueKey('institution-claim-button'),
        // Several FABs can exist in the desktop shell at once.
        heroTag: null,
        onPressed: claim,
        icon: const Icon(Icons.verified_user_outlined),
        label: Text(
          l10n.institutionClaimButton,
          style: KubusTypography.inter(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Institution? _tryParseInstitution(Map<String, dynamic> json) {
    try {
      return Institution.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Event? _tryParseEvent(Map<String, dynamic> json) {
    try {
      return Event.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  String _formatDateRange(BuildContext context, Event event) {
    final localizations = MaterialLocalizations.of(context);
    final start = localizations.formatShortDate(event.startDate);
    final end = localizations.formatShortDate(event.endDate);
    if (start == end) return start;
    return '$start - $end';
  }

  /// Website, booking, licence and source links only (not directions).
  void _openExternal(Uri uri) {
    unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
  }

  Future<void> _openEvent(Event event) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventDetailScreen(eventId: event.id),
      ),
    );
  }

  void _openInstitutionOnMap(Institution institution) {
    final position = LatLng(institution.latitude, institution.longitude);
    if (!isValidMapCoordinate(position)) return;
    MapNavigation.open(
      context,
      center: position,
      zoom: 16,
      initialSubjectId: institution.id,
      initialSubjectType: 'institution',
      initialTargetLabel: institution.name,
    );
  }

  Future<void> _refreshAccountFollowState(String accountUserId) async {
    final following =
        await UserService.fetchAuthoritativeFollowStateByUserId(accountUserId);
    if (!mounted || following == null) return;
    setState(() => _accountIsFollowing = following);
  }

  /// Follow / unfollow the verified account by its users.id, through the same
  /// account-id endpoints and reconciliation the user profile uses. A signed-out
  /// visitor gets the account gate and a follow intent keyed by the account id;
  /// the executor replays that intent through the account-id route.
  Future<void> _toggleAccountFollow({
    required String accountUserId,
    required String accountName,
  }) async {
    if (_accountFollowInFlight) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);
    final authenticated = await const ContextualAuthGate().ensureAuthenticated(
      context,
      actionLabel: l10n.commonFollow.toLowerCase(),
      returnRoute: '/main',
      actionType: PendingActionType.follow,
      targetType: PendingActionTargetType.user,
      targetId: accountUserId,
      targetLabel: accountName,
      sourceScreen: 'institution_detail',
    );
    if (!authenticated || !mounted) return;

    final requestedIsFollowing = !(_accountIsFollowing ?? false);
    setState(() => _accountFollowInFlight = true);
    bool? confirmed;
    try {
      final mutation = await UserService.setFollowStateByUserId(
        accountUserId,
        shouldFollow: requestedIsFollowing,
      );
      confirmed = mutation.pending
          ? await UserService.fetchAuthoritativeFollowStateByUserId(
              accountUserId)
          : mutation.isFollowing;
    } catch (error) {
      debugPrint('InstitutionDetailScreen: account follow failed: $error');
      confirmed = await UserService.fetchAuthoritativeFollowStateByUserId(
          accountUserId);
    }
    if (!mounted) return;
    setState(() {
      _accountFollowInFlight = false;
      if (confirmed != null) _accountIsFollowing = confirmed;
    });
    if (confirmed == requestedIsFollowing) {
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(requestedIsFollowing
              ? l10n.userProfileNowFollowingToast(accountName)
              : l10n.userProfileUnfollowedToast(accountName)),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(l10n.userProfileFollowUpdateFailedToast),
          duration: const Duration(seconds: 3),
          backgroundColor: theme.colorScheme.error,
        ),
      );
    }
  }

  /// Opens a conversation with the verified account's own wallet, through the
  /// same wallet-addressed flow and gate the user profile uses. The wallet is
  /// the only target: an account id or the venue id is never sent.
  Future<void> _messageAccount({
    required String wallet,
    required String accountName,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final authenticated = await const ContextualAuthGate().ensureAuthenticated(
      context,
      requirements: ProtectedActionRequirements.participant,
      actionLabel: l10n.userProfileMessageButtonLabel.toLowerCase(),
      returnRoute: '/main',
      targetLabel: accountName,
      sourceScreen: 'institution_detail',
    );
    if (!authenticated || !mounted) return;
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final chatAuth = chatProvider.isAuthenticated;
    try {
      final conv = await chatProvider.createConversation('', false, [wallet]);
      if (!mounted) return;
      if (conv == null) {
        messenger.showKubusSnackBar(
          SnackBar(
            content: Text(chatAuth
                ? l10n.userProfileConversationOpenFailedToast
                : l10n.userProfileMessageLoginRequiredToast),
          ),
        );
        return;
      }
      final preloaded = chatProvider.getPreloadedProfileMapsForConversation(
        conv.id,
      );
      final rawMembers =
          (preloaded['members'] as List<dynamic>?)?.cast<String>() ??
              <String>[];
      final members = rawMembers.isNotEmpty ? rawMembers : <String>[wallet];
      final avatars = Map<String, String?>.from(
        (preloaded['avatars'] as Map<String, String?>?) ?? <String, String?>{},
      );
      final names = Map<String, String?>.from(
        (preloaded['names'] as Map<String, String?>?) ?? <String, String?>{},
      );
      if ((names[members.first] ?? '').isEmpty) {
        names[members.first] = accountName;
      }
      await ConversationNavigator.openConversationWithPreload(
        context,
        conv,
        preloadedMembers: members,
        preloadedAvatars: avatars,
        preloadedDisplayNames: names,
      );
    } catch (error) {
      debugPrint('InstitutionDetailScreen: account message failed: $error');
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(l10n.userProfileConversationOpenGenericErrorToast),
        ),
      );
    }
  }

  /// Only plain public http(s) links are offered; credentials are refused.
  static Uri? _websiteUri(String raw) {
    final website = Uri.tryParse(raw.trim());
    if (website == null) return null;
    final isWeb = website.scheme == 'http' || website.scheme == 'https';
    if (!isWeb || website.host.isEmpty || website.userInfo.isNotEmpty) {
      return null;
    }
    return website;
  }

  static String _kindLabel(AppLocalizations l10n, InstitutionKind kind) {
    return switch (kind) {
      InstitutionKind.museum => l10n.institutionDetailKindMuseum,
      InstitutionKind.gallery => l10n.institutionDetailKindGallery,
      InstitutionKind.artsCentre => l10n.institutionDetailKindArtsCentre,
      InstitutionKind.exhibitionSpace =>
        l10n.institutionDetailKindExhibitionSpace,
      InstitutionKind.culturalCentre =>
        l10n.institutionDetailKindCulturalCentre,
      InstitutionKind.other => l10n.institutionDetailKindOther,
    };
  }

  /// Licence text for a credit: the CC name, the public domain mark, or a
  /// generic "Licence" link when the licence URL is not a known CC URL.
  static String? _licenceLabel(
    AppLocalizations l10n,
    InstitutionImageAttribution attribution,
  ) {
    final name = attribution.licenseName;
    if (name != null) return name;
    if (attribution.isPublicDomain) return l10n.institutionDetailPublicDomain;
    return attribution.licenseUrl == null
        ? null
        : l10n.institutionDetailLicenceFallback;
  }

  static String? _admissionLabel(
    AppLocalizations l10n,
    InstitutionVisitorAccess access,
  ) {
    final known = access.admission;
    if (known != null) {
      return switch (known) {
        InstitutionAdmission.free => l10n.institutionDetailAdmissionFree,
        InstitutionAdmission.paid => l10n.institutionDetailAdmissionPaid,
        InstitutionAdmission.mixed => l10n.institutionDetailAdmissionMixed,
      };
    }
    return access.admissionText;
  }

  /// `Cover photo: <author> · <licence> · Source` (or Profile photo), with the licence and source as
  /// tappable links. Missing parts are left out rather than shown empty.
  Widget _buildImageCredit(
    BuildContext context,
    InstitutionImageAttribution attribution, {
    required bool cover,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final textStyle = KubusTypography.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final credit = attribution.displayCredit;
    final licenceUrl = attribution.licenseUrl;
    final licenceLabel = _licenceLabel(l10n, attribution);
    final sourceUrl = attribution.sourceUrl;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          switch ((cover, credit)) {
            (true, null) => l10n.institutionDetailCoverPhotoLabel,
            (false, null) => l10n.institutionDetailProfilePhotoLabel,
            (true, final String author) =>
              l10n.institutionDetailCoverPhotoCredit(author),
            (false, final String author) =>
              l10n.institutionDetailProfilePhotoCredit(author),
          },
          style: textStyle,
        ),
        if (licenceUrl != null && licenceLabel != null) ...[
          Text(' · ', style: textStyle),
          _CreditLink(
            label: licenceLabel,
            semanticsLabel: l10n.institutionDetailLicenceLinkSemantics(
              licenceLabel,
            ),
            onPressed: () => _openExternal(Uri.parse(licenceUrl)),
          ),
        ],
        if (sourceUrl != null) ...[
          Text(' · ', style: textStyle),
          _CreditLink(
            // A Commons file page is named by its file title; other sources
            // keep the generic label.
            label: attribution.commonsFileTitle ??
                l10n.institutionDetailSourceLink,
            semanticsLabel: l10n.institutionDetailSourceLinkSemantics,
            onPressed: () => _openExternal(Uri.parse(sourceUrl)),
          ),
        ],
        // Creators of works shown in the photo (e.g. the architect).
        for (final work in attribution.depictedWorks) ...[
          Text(' · ', style: textStyle),
          Text(
            work.isArchitecture
                ? l10n.institutionDetailDepictedArchitecture(work.author)
                : l10n.institutionDetailDepictedArtwork(work.author),
            style: textStyle,
          ),
        ],
      ],
    );
  }

  Widget _buildCreditsFooter(
    BuildContext context,
    List<({bool cover, InstitutionImageAttribution attribution})> credits,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return KeyedSubtree(
      key: _creditsFooterKey,
      child: Container(
        key: const ValueKey('institution-image-credits'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
          KubusSpacing.lg,
          KubusSpacing.md,
          KubusSpacing.lg,
          KubusSpacing.lg,
        ),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: scheme.outline.withValues(alpha: 0.18)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.institutionDetailCreditsTitle,
              style: KubusTextStyles.navMetaLabel.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.64),
              ),
            ),
            const SizedBox(height: KubusSpacing.xs),
            for (final credit in credits)
              Padding(
                padding: const EdgeInsets.only(bottom: KubusSpacing.xxs),
                child: _buildImageCredit(context, credit.attribution,
                    cover: credit.cover),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(
    BuildContext context,
    Institution institution,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final coverUrl = MediaUrlResolver.resolveDisplayUrl(
      MediaUrlResolver.firstSafeRef(<String?>[institution.coverImageUrl]),
    );
    final logoUrl = MediaUrlResolver.resolveDisplayUrl(
      MediaUrlResolver.firstSafeRef(<String?>[institution.logoUrl]),
    );
    // A logo is never the hero: it appears once, as the avatar, and only when
    // it is not the same file as the cover.
    final avatarUrl = logoUrl != null && logoUrl != coverUrl ? logoUrl : null;

    // Credits are shown only for images that are actually on screen.
    // Each credit names the role of its image, so the reader knows which photo it covers.
    final credits = <({bool cover, InstitutionImageAttribution attribution})>[
      if (coverUrl != null && institution.coverAttribution != null)
        (cover: true, attribution: institution.coverAttribution!),
      if (avatarUrl != null && institution.logoAttribution != null)
        (cover: false, attribution: institution.logoAttribution!),
    ].where((entry) => !entry.attribution.isEmpty).toList(growable: false);

    final name = institution.name.trim();
    final kind = institution.institutionKind;
    final website = _websiteUri(institution.website);
    final address = institution.address.trim();
    final description = institution.description.trim();
    final hasMap = isValidMapCoordinate(
      LatLng(institution.latitude, institution.longitude),
    );
    final stats = institution.stats;
    final account = institution.verifiedAccountProfile;
    final accountUserId = account?.userId;
    final viewerIsAccount = account != null &&
        (UserProfileNavigation.isCurrentUser(context, account.profileId) ||
            UserProfileNavigation.isCurrentUser(context, accountUserId));
    // Follow needs the account's users.id; Message needs the account's own
    // wallet and an allowed preference. Each action is offered only when its
    // target exists, and neither is ever derived from a venue or member id.
    final followUserId = viewerIsAccount ? null : accountUserId;
    final messageWallet =
        viewerIsAccount || account == null || !account.canMessage
            ? null
            : account.walletAddress;
    final accountName = account?.displayName ?? name;
    final accountActions = followUserId != null || messageWallet != null
        ? ProfileRelationshipActions(
            isFollowing: _accountIsFollowing ?? false,
            isFollowLoading: _accountFollowInFlight,
            onFollow: followUserId == null
                ? () {}
                : () => unawaited(_toggleAccountFollow(
                      accountUserId: followUserId,
                      accountName: accountName,
                    )),
            onMessage: messageWallet == null
                ? () {}
                : () => unawaited(_messageAccount(
                      wallet: messageWallet,
                      accountName: accountName,
                    )),
            followLabel: l10n.userProfileFollowButton,
            followingLabel: l10n.userProfileFollowingButton,
            messageLabel: l10n.userProfileMessageButtonLabel,
            showFollow: followUserId != null,
            showMessage: messageWallet != null,
          )
        : null;
    final hasStats = stats.activeEvents > 0 ||
        stats.artworkViews > 0 ||
        stats.totalVisitors > 0;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: KubusSpacing.sm,
          runSpacing: KubusSpacing.sm,
          children: [
            if (kind != null) _DetailChip(label: _kindLabel(l10n, kind)),
            for (final discipline in institution.disciplines)
              _DetailChip(
                label: discipline.labelFor(
                  Localizations.localeOf(context).languageCode,
                ),
              ),
            if (institution.isVerified)
              _DetailChip(
                label: l10n.institutionDetailVerifiedChip,
                icon: Icons.verified_outlined,
              ),
          ],
        ),
        if (account != null) ...[
          const SizedBox(height: KubusSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const ValueKey('institution-linked-account-profile'),
              // The profile route resolves a public profile id directly.
              onPressed: () => unawaited(UserProfileNavigation.open(
                context,
                userId: account.profileId,
              )),
              icon: const Icon(Icons.account_circle_outlined),
              label: Text(l10n.institutionDetailAccountProfileAction),
            ),
          ),
        ],
        if (description.isNotEmpty) ...[
          const SizedBox(height: KubusSpacing.lg),
          Text(
            description,
            style: KubusTextStyles.sectionSubtitle.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.78),
            ),
          ),
        ],
        if (address.isNotEmpty) ...[
          const SizedBox(height: KubusSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.place_outlined, size: 18, color: scheme.primary),
              const SizedBox(width: KubusSpacing.xs),
              Expanded(
                child: Text(
                  address,
                  style: KubusTextStyles.detailBody.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (hasMap)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const ValueKey('institution-open-on-map'),
              onPressed: () => _openInstitutionOnMap(institution),
              icon: const Icon(Icons.map_outlined),
              label: Text(l10n.commonOpenOnMap),
            ),
          ),
        if (website != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const ValueKey('institution-website-link'),
              onPressed: () => _openExternal(website),
              icon: const Icon(Icons.open_in_new),
              label: Text(website.host),
            ),
          ),
        if (hasStats) ...[
          const SizedBox(height: KubusSpacing.lg),
          Wrap(
            spacing: KubusSpacing.md,
            runSpacing: KubusSpacing.md,
            children: [
              _StatTile(
                label: l10n.institutionDetailStatActiveEvents,
                value: stats.activeEvents.toString(),
              ),
              _StatTile(
                label: l10n.institutionDetailStatArtworkViews,
                value: stats.artworkViews.toString(),
              ),
              _StatTile(
                label: l10n.institutionDetailStatVisitors,
                value: stats.totalVisitors.toString(),
              ),
            ],
          ),
        ],
      ],
    );

    final hero = ProfileIdentityHero(
      displayName: name,
      // Only a verified link carries a handle. ProfileHandle drops blank,
      // wallet-shaped and placeholder usernames, so none is ever invented.
      handle: account?.username,
      actions: accountActions,
      isArtist: false,
      isInstitution: true,
      isVerified: institution.isVerified,
      coverImageUrl: coverUrl,
      coverSemanticLabel: l10n.institutionDetailCoverSemanticLabel(name),
      avatarRadius: 42,
      avatar: AvatarWidget(
        key: const ValueKey('institution-profile-image'),
        wallet: '',
        displayName: name,
        avatarUrl: avatarUrl,
        radius: 42,
        fetchMissingAvatar: false,
        enableProfileNavigation: false,
        showStatusIndicator: false,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          children: [
            hero,
            if (credits.any((c) => c.cover))
              // The accepted position is the cover's bottom-right corner. Only
              // when a Follow / Message row shares the hero's lower edge does
              // the button move to the top corner, so the two never overlap.
              Positioned(
                key: const ValueKey('institution-cover-credit-button'),
                right: KubusSpacing.sm,
                top: accountActions == null
                    ? ProfileIdentityHero.coverHeightWithImage -
                        _creditButtonSize -
                        KubusSpacing.sm
                    : KubusSpacing.sm,
                child: _buildCreditButton(context),
              ),
          ],
        ),
        const SizedBox(height: KubusSpacing.lg),
        LiquidGlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(KubusSpacing.lg),
                child: Align(
                  alignment: AlignmentDirectional.topStart,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _readingWidth),
                    child: content,
                  ),
                ),
              ),
              if (credits.isNotEmpty) _buildCreditsFooter(context, credits),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVisitSection(
    BuildContext context,
    InstitutionVisitorAccess access,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final hours = access.openingHoursText;
    final admission = _admissionLabel(l10n, access);
    final accessibility = access.accessibilityNote;
    final booking =
        access.bookingUrl == null ? null : Uri.tryParse(access.bookingUrl!);
    final source = Uri.tryParse(access.sourceUrl);

    return LiquidGlassCard(
      key: const ValueKey('institution-visit-section'),
      padding: const EdgeInsets.all(KubusSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.institutionDetailVisitTitle,
            style: KubusTextStyles.sectionTitle.copyWith(
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: KubusSpacing.md),
          if (hours != null)
            _InfoRow(label: l10n.institutionDetailOpeningHours, value: hours),
          if (admission != null)
            _InfoRow(label: l10n.institutionDetailAdmission, value: admission),
          if (accessibility != null)
            _InfoRow(
              label: l10n.institutionDetailAccessibility,
              value: accessibility,
            ),
          Wrap(
            spacing: KubusSpacing.sm,
            runSpacing: KubusSpacing.xs,
            children: [
              if (booking != null)
                TextButton.icon(
                  key: const ValueKey('institution-booking-link'),
                  onPressed: () => _openExternal(booking),
                  icon: const Icon(Icons.event_available_outlined),
                  label: Text(l10n.institutionDetailBookingLink),
                ),
              if (source != null)
                TextButton.icon(
                  key: const ValueKey('institution-visitor-source-link'),
                  onPressed: () => _openExternal(source),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(l10n.institutionDetailVisitorSourceLink),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEventsSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    if (_events.isEmpty) {
      return EmptyStateCard(
        icon: Icons.event_busy_outlined,
        title: l10n.institutionDetailNoEventsTitle,
        description: l10n.institutionDetailNoEventsDescription,
      );
    }

    final visibleEvents = _events.take(6).toList(growable: false);

    return LiquidGlassCard(
      padding: const EdgeInsets.all(KubusSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.institutionDetailEventsTitle,
            style: KubusTextStyles.sectionTitle.copyWith(
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: KubusSpacing.md),
          ...visibleEvents.map(
            (event) => Padding(
              padding: EdgeInsets.only(
                bottom:
                    identical(event, visibleEvents.last) ? 0 : KubusSpacing.sm,
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: KubusSpacing.sm,
                  vertical: KubusSpacing.xs,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(KubusRadius.md),
                ),
                tileColor:
                    scheme.surfaceContainerHighest.withValues(alpha: 0.24),
                leading: Icon(
                  Icons.event_outlined,
                  color: scheme.primary,
                ),
                title: Text(
                  event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${_formatDateRange(context, event)}\n${event.location}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openEvent(event),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final institution = _institution;
    final name = institution?.name.trim() ?? '';
    final imported = institution?.isImportedUnclaimed ?? false;
    final claimsAvailable = _claimsAvailable == true;
    final showClaim = imported && claimsAvailable && !_claimOpen;
    final claimButton =
        showClaim ? _buildClaimButton(l10n, institution!) : null;

    final body = _loading
        ? const Center(child: InlineLoading(expand: false))
        : institution == null
            ? EmptyStateCard(
                icon: Icons.apartment_outlined,
                title: _error == null
                    ? l10n.institutionDetailNotFoundTitle
                    : l10n.institutionDetailLoadErrorTitle,
                description: _error == null
                    ? l10n.institutionDetailNotFoundDescription
                    : l10n.institutionDetailLoadErrorDescription,
                showAction: true,
                actionLabel: l10n.commonRetry,
                onAction: _loadInstitution,
              )
            : ListView(
                // Room under the content so the floating claim button never
                // covers the last card.
                padding: EdgeInsets.fromLTRB(
                  KubusSpacing.lg,
                  KubusSpacing.lg,
                  KubusSpacing.lg,
                  KubusSpacing.lg + (showClaim ? 88 : 0),
                ),
                children: [
                  if (imported) ...[
                    KubusNoticeBanner(
                      margin: EdgeInsets.zero,
                      title: l10n.institutionImportedNoticeTitle,
                      message: l10n.institutionImportedNoticeMessage,
                    ),
                    if (_claimOpen) ...[
                      const SizedBox(height: KubusSpacing.sm),
                      KubusNoticeBanner(
                        margin: EdgeInsets.zero,
                        tone: KubusStatusTone.neutral,
                        icon: Icons.hourglass_top_outlined,
                        title: l10n.institutionClaimPendingTitle,
                        message: l10n.institutionClaimPendingMessage,
                      ),
                    ] else if (_claimsAvailable == false) ...[
                      const SizedBox(height: KubusSpacing.sm),
                      KubusNoticeBanner(
                        margin: EdgeInsets.zero,
                        tone: KubusStatusTone.neutral,
                        icon: Icons.schedule_outlined,
                        title: l10n.institutionClaimClosedTitle,
                        message: l10n.institutionClaimClosedMessage,
                      ),
                    ],
                    const SizedBox(height: KubusSpacing.lg),
                  ],
                  _buildHeaderCard(
                    context,
                    institution,
                  ),
                  const SizedBox(height: KubusSpacing.lg),
                  if (institution.visitorAccess != null) ...[
                    _buildVisitSection(context, institution.visitorAccess!),
                    const SizedBox(height: KubusSpacing.lg),
                  ],
                  _buildEventsSection(context),
                ],
              );

    if (widget.embedded) {
      if (claimButton == null) return body;
      return Stack(
        children: [
          Positioned.fill(child: body),
          Positioned(
            right: KubusSpacing.lg,
            bottom: KubusSpacing.lg,
            child: claimButton,
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          name.isEmpty ? l10n.institutionDetailFallbackTitle : name,
          style: KubusTextStyles.mobileAppBarTitle,
        ),
      ),
      body: body,
      floatingActionButton: claimButton,
    );
  }
}

/// A tappable credit link. The semantics label names the destination; the
/// visible text stays short so the credit line still fits a phone width.
class _CreditLink extends StatelessWidget {
  const _CreditLink({
    required this.label,
    required this.semanticsLabel,
    required this.onPressed,
  });

  final String label;
  final String semanticsLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      link: true,
      label: semanticsLabel,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: KubusSpacing.xxs),
          minimumSize: const Size(0, 44),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          label,
          style: KubusTypography.textTheme.bodySmall?.copyWith(
            color: scheme.primary,
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: KubusSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: KubusTextStyles.navMetaLabel.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.64),
            ),
          ),
          const SizedBox(height: KubusSpacing.xxs),
          Text(
            value,
            style: KubusTextStyles.detailBody.copyWith(
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({
    required this.label,
    this.icon,
  });

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KubusSpacing.md,
        vertical: KubusSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(KubusRadius.xl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: scheme.primary),
            const SizedBox(width: KubusSpacing.xs),
          ],
          Flexible(child: Text(label)),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 112),
      padding: const EdgeInsets.all(KubusSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(KubusRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: KubusTextStyles.sectionTitle.copyWith(
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: KubusSpacing.xxs),
          Text(
            label,
            style: KubusTextStyles.navMetaLabel.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.64),
            ),
          ),
        ],
      ),
    );
  }
}
