import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../../utils/kubus_entity_semantics.dart';
import 'kubus_atmosphere.dart';
import 'kubus_cached_image.dart';

/// What kind of thing the card previews.
///
/// Deliberately two variants, not a layout flag: an artwork and an artist are
/// not the same object, so they do not get the same composition. A third
/// variant would mean a third kind of thing exists, not a third style.
enum KubusEntityCardVariant {
  /// A cultural object: artwork, event, exhibition, collection, drop.
  ///
  /// Media led. The image is the subject and fills the card; the title and its
  /// context read off an information plate at the lower edge.
  media,

  /// A person or an organisation: artist, institution, any public profile.
  ///
  /// Identity led. The cover (or the role field when there is none) is the
  /// canvas; the avatar or logo and the name sit on a compact glass plate
  /// against it, exactly as the profile hero composes them.
  identity,
}

/// PRODUCT v5 entity preview — the **one** shared preview for a cultural
/// object or a public identity.
///
/// It is not a [KubusActionTile]: a tile is a shortcut to a destination and
/// says so with a title, a colour and a cropped glyph. This is a preview of a
/// thing that exists, so the thing itself — the photograph, the cover, the
/// face — is the dominant layer and the typography sits on top of it.
///
/// ## Composition contract
/// * Media occupies the whole card. There is no media rectangle stacked above
///   a separate text card, and no card inside a card.
/// * The title is primary and may take two lines; the creator/context line is
///   secondary; an optional [meta] line is tertiary. All three read off one
///   information plate at the lower edge, over a scrim that only darkens the
///   part of the image the text actually covers.
/// * The semantic category/role colour appears as a restrained 2 px edge along
///   the card's base and as the hover/focus edge. It never becomes a fill.
/// * Without usable media the card shows the authored role field — the
///   [KubusAtmosphere] field in the entity's own colour with its [fallbackGlyph]
///   cropped in the trailing corner — never an anonymous grey gradient with a
///   small centred icon.
///
/// ## Interaction contract
/// Shares the [KubusActionTile] interaction philosophy without being one:
/// * pointer hover (never touch): 2 px paint-only lift, the media scales to
///   [hoverMediaScale] inside the clip, the edge strengthens to the accent and
///   a soft contextual [KubusHoverResponse.accentShadow] fades in.
/// * nothing is painted at rest beyond the hairline and the base edge: no
///   resting drop shadow, so a rail of them does not read as floating clutter.
/// * reduced motion removes the lift and the media scale; the edge and shadow
///   still answer, so the card is never silent.
/// * keyboard focus is explicit and always available: a 2 px accent ring.
///
/// ## Management affordances
/// [status] (publication/visibility state) and [actions] (edit, overflow) are
/// for creator surfaces. [status] is always visible because state is
/// information. [actions] are revealed on pointer hover/focus so they do not
/// bury the artwork, and are permanently visible when [alwaysShowActions] is
/// set — which is what a touch surface must pass, since touch never hovers.
class KubusEntityCard extends StatefulWidget {
  const KubusEntityCard({
    super.key,
    required this.variant,
    required this.kind,
    required this.title,
    this.accent,
    this.fallbackGlyph,
    this.imageUrl,
    this.subtitle,
    this.subtitleWidget,
    this.meta,
    this.leading,
    this.badge,
    this.status,
    this.actions = const <Widget>[],
    this.alwaysShowActions = false,
    this.onTap,
    this.width,
    this.height,
    this.aspectRatio,
    this.semanticLabel,
    this.imageSemanticLabel,
    this.titleMaxLines = 2,
    this.enableHover = true,
    this.cacheVersion,
  }) : assert(
          height == null || aspectRatio == null,
          'Give the card a height or an aspect ratio, not both.',
        );

  final KubusEntityCardVariant variant;

  /// What kind of entity this is. It resolves both the accent and the no-media
  /// glyph through [KubusEntitySemantics], so a Home rail card, a profile
  /// portfolio card and a studio gallery card for the same kind of thing read
  /// as the same family without any surface restating the mapping.
  final KubusEntityKind kind;

  /// The object's or the identity's name. Always primary.
  final String title;

  /// Overrides the accent [kind] resolves. Only for a surface that genuinely
  /// carries a different signal — a profile's own artist/institution role
  /// colour rather than the discovery-rail profile blue.
  final Color? accent;

  /// Overrides the glyph [kind] resolves, for the same reason.
  final IconData? fallbackGlyph;

  final String? imageUrl;

  /// Creator, institution, authorship or category context. Secondary.
  final String? subtitle;

  /// Replaces [subtitle] where the context line is itself interactive — an
  /// artwork's creator opens that creator's profile. Style it with
  /// [onMediaSubtitleStyle] so the register stays the same as a plain one.
  final Widget? subtitleWidget;

  /// Place, date, count — the one extra fact worth the row. Tertiary.
  final String? meta;

  /// Identity variant only: the avatar or the institution logo.
  final Widget? leading;

  /// A marker over the media's leading top corner (promotion, featured).
  final Widget? badge;

  /// Publication/visibility state. Sits in the plate, above the title.
  final Widget? status;

  /// Creator management controls over the media's trailing top corner.
  final List<Widget> actions;

  /// Keep [actions] visible without hover. Touch surfaces must pass true.
  final bool alwaysShowActions;

  final VoidCallback? onTap;

  final double? width;
  final double? height;

  /// Height as a ratio of the resolved width. Lets a responsive grid keep one
  /// rhythm while the column width changes.
  final double? aspectRatio;

  final String? semanticLabel;

  /// Public entity media is content, so it may carry its own label. Left null
  /// the image is decorative and the card's own semantics describe it.
  final String? imageSemanticLabel;

  final int titleMaxLines;

  /// Pointer hover answer. Off for surfaces that are never pointer-driven.
  final bool enableHover;

  final String? cacheVersion;

  /// Media scale inside the clip on hover. Small enough to read as the image
  /// leaning forward rather than the card growing.
  static const double hoverMediaScale = 1.02;

  /// Card corner radius, shared by every entity preview.
  static const double radius = KubusRadius.md;

  /// The restrained category edge along the card's base.
  static const double baseEdge = 2;

  /// The paint-only media scale, present only where motion is allowed.
  static const Key mediaScaleKey =
      ValueKey<String>('kubus_entity_card_media_scale');

  /// The paint-only hover lift, present only where motion is allowed.
  static const Key liftKey = ValueKey<String>('kubus_entity_card_lift');

  /// The plate's secondary register, for a caller supplying a
  /// [subtitleWidget] so its own text matches a plain [subtitle].
  static TextStyle onMediaSubtitleStyle({double alpha = 0.88}) =>
      KubusTextStyles.metadataRegister.copyWith(
        color: Colors.white.withValues(alpha: alpha),
      );

  @override
  State<KubusEntityCard> createState() => _KubusEntityCardState();
}

class _KubusEntityCardState extends State<KubusEntityCard> {
  bool _hovered = false;
  bool _focused = false;

  bool get _interactive => widget.onTap != null;
  bool get _pointerHover => _hovered && widget.enableHover;
  bool get _answering => _pointerHover || _focused;

  void _set(void Function() apply) {
    if (!mounted) return;
    setState(apply);
  }

  Color _accent(KubusColorRoles roles) =>
      widget.accent ?? KubusEntitySemantics.accentFor(widget.kind, roles);

  IconData get _glyph =>
      widget.fallbackGlyph ?? KubusEntitySemantics.glyphFor(widget.kind);

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final accent = _accent(roles);
    final brightness = Theme.of(context).brightness;
    final motion = KubusHoverResponse.motionAllowed(context);
    final radius = BorderRadius.circular(KubusEntityCard.radius);

    // An interactive card is one button named by its label, so its own content
    // is hidden from the tree. The action buttons are not part of that content:
    // they stay separate, reachable nodes.
    Widget readOnly(Widget child) =>
        _interactive ? ExcludeSemantics(child: child) : child;
    final actionsShown = widget.alwaysShowActions || _answering;

    Widget card = AnimatedContainer(
      duration: KubusHoverResponse.duration,
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: _focused
              ? accent
              : _pointerHover
                  ? accent.withValues(alpha: 0.55)
                  : roles.rule,
          width: _focused ? 2 : KubusSizes.hairline,
        ),
        // Nothing at rest: a rail of cards must not read as floating chrome.
        boxShadow: KubusHoverResponse.accentShadow(
          accent,
          brightness,
          hovered: _answering,
        ),
      ),
      child: ClipRRect(
        // Clip inside the border so the media scale on hover never bleeds past
        // the edge and the rail does not need to reserve room for it.
        borderRadius: BorderRadius.circular(
          KubusEntityCard.radius - KubusSizes.hairline,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            readOnly(_buildMediaLayer(context, roles, motion)),
            readOnly(_buildScrim(context, accent)),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: readOnly(_buildPlate(context, roles)),
            ),
            // The category edge sits above the plate so a pale image can never
            // wash it out.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedContainer(
                duration: KubusHoverResponse.duration,
                curve: Curves.easeOutCubic,
                height: KubusEntityCard.baseEdge,
                color: accent.withValues(alpha: _answering ? 1 : 0.78),
              ),
            ),
            if (widget.badge != null)
              Positioned(
                top: KubusSpacing.sm,
                left: KubusSpacing.sm,
                child: readOnly(widget.badge!),
              ),
            if (widget.actions.isNotEmpty)
              Positioned(
                top: KubusSpacing.xs,
                right: KubusSpacing.xs,
                child: AnimatedOpacity(
                  duration: KubusHoverResponse.duration,
                  // Touch never hovers, so a touch surface pins them visible.
                  opacity: actionsShown ? 1 : 0,
                  child: IgnorePointer(
                    ignoring: !actionsShown,
                    // Invisible controls must not take keyboard focus either.
                    child: ExcludeFocus(
                      excluding: !actionsShown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: widget.actions,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (widget.aspectRatio != null) {
      card = AspectRatio(aspectRatio: widget.aspectRatio!, child: card);
    } else if (widget.height != null) {
      card = SizedBox(height: widget.height, child: card);
    }
    if (widget.width != null) {
      card = SizedBox(width: widget.width, child: card);
    }

    if (!_interactive) {
      return card;
    }

    final lifted = TweenAnimationBuilder<double>(
      tween: Tween<double>(
        end: _answering && motion ? -KubusHoverResponse.liftDistance : 0,
      ),
      duration: motion ? KubusHoverResponse.duration : Duration.zero,
      curve: Curves.easeOutCubic,
      child: card,
      builder: (context, dy, child) => Transform.translate(
        key: KubusEntityCard.liftKey,
        offset: Offset(0, dy),
        child: child,
      ),
    );

    final detector = FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap?.call();
            return null;
          },
        ),
      },
      onShowHoverHighlight: (hovered) {
        if (_hovered == hovered) return;
        _set(() => _hovered = hovered);
      },
      onShowFocusHighlight: (focused) {
        if (_focused == focused) return;
        _set(() => _focused = focused);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: lifted,
      ),
    );

    return Semantics(
      button: true,
      label: widget.semanticLabel ?? _defaultSemanticLabel(),
      onTap: widget.onTap,
      explicitChildNodes: true,
      child: detector,
    );
  }

  String _defaultSemanticLabel() => <String>[
        widget.title,
        if ((widget.subtitle ?? '').trim().isNotEmpty) widget.subtitle!.trim(),
        if ((widget.meta ?? '').trim().isNotEmpty) widget.meta!.trim(),
      ].join(', ');

  Widget _buildMediaLayer(
    BuildContext context,
    KubusColorRoles roles,
    bool motion,
  ) {
    final resolved = KubusCachedImage.resolveImageUrl(widget.imageUrl);
    final hasMedia = resolved != null && resolved.isNotEmpty;

    final media = hasMedia
        ? KubusCachedImage(
            imageUrl: widget.imageUrl,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            cacheVersion: widget.cacheVersion,
            semanticLabel: widget.imageSemanticLabel,
            excludeFromSemantics: widget.imageSemanticLabel == null,
            placeholderBuilder: (context) => _buildField(context, roles),
            errorBuilder: (context, _, __) => _buildField(context, roles),
          )
        : _buildField(context, roles);

    if (!motion) return media;

    // Paint-only: the scale happens inside the clip, so no layout changes and
    // nothing in the rail reflows.
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        end: _answering ? KubusEntityCard.hoverMediaScale : 1,
      ),
      duration: KubusHoverResponse.duration,
      curve: Curves.easeOutCubic,
      child: media,
      builder: (context, scale, child) => Transform.scale(
        key: KubusEntityCard.mediaScaleKey,
        scale: scale,
        child: child,
      ),
    );
  }

  /// The authored no-media field: the entity's own colour and its glyph, the
  /// same construction the profile cover fallback uses, so a card without an
  /// image still reads as a deliberate surface for that kind of entity.
  Widget _buildField(BuildContext context, KubusColorRoles roles) {
    final accent = _accent(roles);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return KubusAtmosphere(
      key: const ValueKey<String>('kubus_entity_card_field'),
      accent: accent,
      // One hue: the field states one role, not a two-colour composition.
      secondary: accent,
      // The ground itself carries the role's hue. On the raised surface alone
      // a card with no image is a near-white wash, which is not an identity.
      base: Color.alphaBlend(
        accent.withValues(alpha: dark ? 0.16 : 0.30),
        roles.surfaceRaised,
      ),
      glyph: _glyph,
      glyphAlignment: Alignment.bottomRight,
      framed: false,
      padding: EdgeInsets.zero,
      child: const SizedBox.expand(),
    );
  }

  /// A scrim only where the type sits. The image keeps its own light
  /// everywhere else, which is the whole point of a media-led card.
  ///
  /// With no image there is no photograph to protect, so the scrim is drawn
  /// from the entity's own deep tone rather than black: the card stays a
  /// field of that role instead of fading to neutral grey.
  Widget _buildScrim(BuildContext context, Color accent) {
    final resolved = KubusCachedImage.resolveImageUrl(widget.imageUrl);
    final hasMedia = resolved != null && resolved.isNotEmpty;
    final ink = hasMedia
        ? Colors.black
        : Color.lerp(Colors.black, accent, 0.32) ?? Colors.black;
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            // Stops, not a full-height wash: the top 45% is untouched.
            stops: const <double>[0, 0.45, 0.78, 1],
            colors: <Color>[
              Colors.transparent,
              ink.withValues(alpha: 0.06),
              ink.withValues(alpha: 0.52),
              ink.withValues(alpha: 0.80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlate(BuildContext context, KubusColorRoles roles) {
    final identity = widget.variant == KubusEntityCardVariant.identity;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.status != null) ...[
          widget.status!,
          const SizedBox(height: KubusSpacing.xs),
        ],
        Text(
          widget.title,
          maxLines: widget.titleMaxLines,
          overflow: TextOverflow.ellipsis,
          style: KubusTextStyles.sectionTitle.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            height: 1.15,
          ),
        ),
        if (widget.subtitleWidget != null) ...[
          const SizedBox(height: KubusSpacing.xxs),
          widget.subtitleWidget!,
        ] else if ((widget.subtitle ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: KubusSpacing.xxs),
          Text(
            widget.subtitle!.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: KubusEntityCard.onMediaSubtitleStyle(),
          ),
        ],
        if ((widget.meta ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: KubusSpacing.xxs),
          Text(
            widget.meta!.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: KubusTextStyles.detailCaption.copyWith(
              color: Colors.white.withValues(alpha: 0.70),
            ),
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KubusSpacing.sm + KubusSpacing.xxs,
        KubusSpacing.sm,
        KubusSpacing.sm + KubusSpacing.xxs,
        KubusSpacing.sm + KubusEntityCard.baseEdge,
      ),
      child: identity && widget.leading != null
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                widget.leading!,
                const SizedBox(width: KubusSpacing.sm),
                Expanded(child: text),
              ],
            )
          : text,
    );
  }
}
