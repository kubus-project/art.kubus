import 'dart:async';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/institution.dart';
import '../../../providers/institution_provider.dart';
import '../../../services/backend_api_service.dart';
import '../../../services/telemetry/telemetry_service.dart';
import '../../../utils/design_tokens.dart';
import '../../../utils/media_url_resolver.dart';
import '../../../utils/map_coordinate_rules.dart';
import '../../../utils/map_navigation.dart';
import '../../../widgets/common/kubus_cached_image.dart';
import '../../../widgets/empty_state_card.dart';
import '../../../widgets/glass_components.dart';
import '../../../widgets/inline_loading.dart';
import '../../events/event_detail_screen.dart';
import '../../../providers/activation_prompt_provider.dart';

/// Cover height. The profile avatar overlaps its lower edge by half its size.
const double _coverHeight = 220;
const double _avatarSize = 88;
const double _avatarOverlap = _avatarSize / 2;

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
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
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

  Future<void> _openEvent(Event event) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventDetailScreen(eventId: event.id),
      ),
    );
  }

  void _openExternal(Uri uri) {
    unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
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

  Widget _buildImageFallback(BuildContext context, {double iconSize = 48}) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primary.withValues(alpha: 0.22),
            scheme.secondary.withValues(alpha: 0.18),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.apartment_outlined,
          size: iconSize,
          color: scheme.onSurface.withValues(alpha: 0.72),
        ),
      ),
    );
  }

  Widget _buildCover(
    BuildContext context,
    Institution institution,
    String? coverUrl,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(KubusRadius.lg),
      ),
      child: SizedBox(
        key: const ValueKey('institution-cover-image'),
        height: _coverHeight,
        width: double.infinity,
        child: coverUrl == null
            ? _buildImageFallback(context)
            : KubusCachedImage(
                imageUrl: coverUrl,
                fit: BoxFit.cover,
                semanticLabel: l10n.institutionDetailCoverSemanticLabel(
                  institution.name.trim(),
                ),
                placeholderBuilder: (context) => _buildImageFallback(context),
                errorBuilder: (context, _, __) => _buildImageFallback(context),
              ),
      ),
    );
  }

  /// The profile image as a rounded square that overlaps the cover's lower
  /// edge. It is shown only when it is a different file from the cover.
  Widget _buildAvatar(
    BuildContext context,
    Institution institution,
    String? logoUrl,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('institution-profile-image'),
      width: _avatarSize,
      height: _avatarSize,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(KubusRadius.md + 3),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(KubusRadius.md),
        child: logoUrl == null
            ? _buildImageFallback(context, iconSize: 28)
            : KubusCachedImage(
                imageUrl: logoUrl,
                fit: BoxFit.cover,
                semanticLabel: l10n.institutionDetailLogoSemanticLabel(
                  institution.name.trim(),
                ),
                placeholderBuilder: (context) => _buildImageFallback(
                  context,
                  iconSize: 28,
                ),
                errorBuilder: (context, _, __) => _buildImageFallback(
                  context,
                  iconSize: 28,
                ),
              ),
      ),
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
    Institution institution, {
    required bool showName,
  }) {
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
    final hasStats = stats.activeEvents > 0 ||
        stats.artworkViews > 0 ||
        stats.totalVisitors > 0;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // One title per screen: the AppBar (standalone) or the desktop
        // sub-screen header (embedded) already carries the name.
        if (showName && name.isNotEmpty) ...[
          Text(
            name,
            style: KubusTextStyles.screenTitle.copyWith(
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: KubusSpacing.sm),
        ],
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

    return LiquidGlassCard(
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCover(context, institution, coverUrl),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  KubusSpacing.lg,
                  _avatarOverlap + KubusSpacing.md,
                  KubusSpacing.lg,
                  KubusSpacing.lg,
                ),
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
          Positioned(
            left: KubusSpacing.lg,
            top: _coverHeight - _avatarOverlap,
            child: _buildAvatar(context, institution, avatarUrl),
          ),
          // Photo-credit affordances: one per image that shows a credit. Each
          // 44 dp hit area sits in the image's bottom-right corner.
          if (credits.any((c) => c.cover))
            Positioned(
              key: const ValueKey('institution-cover-credit-button'),
              right: KubusSpacing.sm,
              top: _coverHeight - _creditButtonSize - KubusSpacing.sm,
              child: _buildCreditButton(context),
            ),
          if (avatarUrl != null && credits.any((c) => !c.cover))
            Positioned(
              key: const ValueKey('institution-avatar-credit-button'),
              left: KubusSpacing.lg + _avatarSize - _creditButtonSize,
              top: _coverHeight -
                  _avatarOverlap +
                  _avatarSize -
                  _creditButtonSize,
              child: _buildCreditButton(context),
            ),
        ],
      ),
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
                padding: const EdgeInsets.all(KubusSpacing.lg),
                children: [
                  _buildHeaderCard(
                    context,
                    institution,
                    showName: true,
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
      return body;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          name.isEmpty ? l10n.institutionDetailFallbackTitle : name,
          style: KubusTextStyles.mobileAppBarTitle,
        ),
      ),
      body: body,
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
