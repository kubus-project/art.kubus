part of 'kubus_marker_overlay_card.dart';

/// Keyboard focus for a quick card.
///
/// A pointer open never moves focus. A keyboard open (Enter or Space on a
/// nearby row or search result, see [KeyboardActivationTracker]) starts a
/// focus session: focus moves to the card's title, the entry point. The title
/// is not a Tab stop of its own, so Tab from it goes to the close control and
/// then the actions in visual order (close, actions, pager, primary action).
/// Shift+Tab from the first control walks back out of the card.
///
/// The card is non-modal, so nothing is trapped. The card scope hands focus to
/// the surrounding page at either edge ([TraversalEdgeBehavior.parentScope]).
///
/// When the card closes while focus is still in it, or the dismissal left no
/// focus at all (Escape clears focus before closing), focus returns to the
/// control that opened the card if that control still exists, and otherwise to
/// the screen's fallback focus node (the map search field).
class _MarkerOverlayFocusSession {
  _MarkerOverlayFocusSession({required this.invoker, this.fallback});

  final FocusNode? invoker;
  FocusNode? fallback;
  final Set<FocusScopeNode> scopes = <FocusScopeNode>{};
  int mountedHosts = 0;
  bool entryFocusPending = true;
  bool focusWithinOrLost = false;
}

/// Wraps one quick card in its focus scope and traversal group.
///
/// Hosts are short-lived: the overlay recreates the card when its placement
/// changes (centered until the anchor resolves) or when the selection changes.
/// A session therefore spans every host mounted for one keyboard open, so a
/// recreated card joins the session instead of starting a new one or
/// restoring focus early.
class _MarkerOverlayFocusHost extends StatefulWidget {
  const _MarkerOverlayFocusHost({
    required this.fallbackFocusNode,
    required this.builder,
  });

  final FocusNode? fallbackFocusNode;
  final Widget Function(BuildContext context, FocusNode entryFocusNode) builder;

  @override
  State<_MarkerOverlayFocusHost> createState() =>
      _MarkerOverlayFocusHostState();
}

_MarkerOverlayFocusSession? _activeMarkerOverlayFocusSession;

/// Drops any focus session left open by a previous test. Test-only.
void resetMarkerOverlayFocusSessionForTests() {
  _activeMarkerOverlayFocusSession = null;
  FocusManager.instance
      .removeListener(_MarkerOverlayFocusHostState._onPrimaryFocusChanged);
}

class _MarkerOverlayFocusHostState extends State<_MarkerOverlayFocusHost> {
  // Programmatic entry point only: skipTraversal keeps it out of the Tab order
  // so a Tab into the card still starts at its close control.
  final FocusNode _entry = FocusNode(
    debugLabel: 'marker_overlay_entry',
    skipTraversal: true,
  );
  final FocusScopeNode _scope = FocusScopeNode(
    debugLabel: 'marker_overlay_scope',
    traversalEdgeBehavior: TraversalEdgeBehavior.parentScope,
  );
  _MarkerOverlayFocusSession? _session;

  @override
  void initState() {
    super.initState();
    if (KeyboardActivationTracker.consumeRecentActivation()) {
      _startSession();
    }
    final session = _activeMarkerOverlayFocusSession;
    if (session == null) return;
    _session = session;
    session.mountedHosts++;
    session.scopes.add(_scope);
    session.fallback ??= widget.fallbackFocusNode;
    _onPrimaryFocusChanged();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || session.mountedHosts == 0) return;
      // Focus that was inside a card the overlay just replaced has nowhere to
      // go; the card's entry point takes it back.
      final lostInside = session.focusWithinOrLost &&
          FocusManager.instance.primaryFocus == null;
      if (session.entryFocusPending || lostInside) _entry.requestFocus();
    });
  }

  @override
  void didUpdateWidget(covariant _MarkerOverlayFocusHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    final session = _session;
    if (session != null && widget.fallbackFocusNode != null) {
      session.fallback = widget.fallbackFocusNode;
    }
  }

  @override
  void dispose() {
    final session = _session;
    _session = null;
    if (session != null) {
      session.mountedHosts--;
      session.scopes.remove(_scope);
      if (session.mountedHosts == 0) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _endSessionIfUnused(session),
        );
      }
    }
    _entry.dispose();
    _scope.dispose();
    super.dispose();
  }

  void _startSession() {
    // A new keyboard open replaces any session still around. The replaced
    // session's restore is dropped: the new card is now where focus belongs.
    _activeMarkerOverlayFocusSession = _MarkerOverlayFocusSession(
      // The row that was activated names itself; focus at this point is not
      // reliably that row.
      invoker: KeyboardActivationTracker.takeInvoker() ??
          FocusManager.instance.primaryFocus,
      fallback: widget.fallbackFocusNode,
    );
    FocusManager.instance.removeListener(_onPrimaryFocusChanged);
    FocusManager.instance.addListener(_onPrimaryFocusChanged);
  }

  static void _onPrimaryFocusChanged() {
    final session = _activeMarkerOverlayFocusSession;
    if (session == null) return;
    final primary = FocusManager.instance.primaryFocus;
    final inside = primary != null && _isWithinAny(primary, session.scopes);
    session.focusWithinOrLost = primary == null || inside;
    if (inside) session.entryFocusPending = false;
  }

  static bool _isWithinAny(FocusNode node, Set<FocusScopeNode> scopes) {
    for (FocusNode? current = node; current != null; current = current.parent) {
      if (scopes.contains(current)) return true;
    }
    return false;
  }

  static void _endSessionIfUnused(_MarkerOverlayFocusSession session) {
    if (!identical(_activeMarkerOverlayFocusSession, session)) return;
    if (session.mountedHosts > 0) return;
    _activeMarkerOverlayFocusSession = null;
    FocusManager.instance.removeListener(_onPrimaryFocusChanged);
    if (!session.focusWithinOrLost) return;
    // Something else took focus after the card closed (for example a details
    // panel that requested its own focus): leave that focus alone.
    if (FocusManager.instance.primaryFocus != null) return;
    for (final candidate in <FocusNode?>[session.invoker, session.fallback]) {
      if (candidate == null) continue;
      // FocusNode.context is not cleared when its element goes away, so the
      // element itself must still be mounted.
      final context = candidate.context;
      if (context == null || !context.mounted) continue;
      if (!candidate.canRequestFocus) continue;
      candidate.requestFocus();
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      node: _scope,
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: widget.builder(context, _entry),
      ),
    );
  }
}

/// The card's title as its focus entry point: a heading for assistive
/// technology, activated like a tap (opens details) with Enter or Space, and
/// outlined while keyboard focus is on it.
class _OverlayKeyboardTitle extends StatefulWidget {
  const _OverlayKeyboardTitle({
    required this.focusNode,
    required this.onActivate,
    required this.accent,
    required this.child,
  });

  final FocusNode focusNode;
  final VoidCallback? onActivate;
  final Color accent;
  final Widget child;

  @override
  State<_OverlayKeyboardTitle> createState() => _OverlayKeyboardTitleState();
}

class _OverlayKeyboardTitleState extends State<_OverlayKeyboardTitle> {
  bool _showFocus = false;

  @override
  Widget build(BuildContext context) {
    final onActivate = widget.onActivate;
    return FocusableActionDetector(
      focusNode: widget.focusNode,
      enabled: onActivate != null,
      mouseCursor: SystemMouseCursors.click,
      onShowFocusHighlight: (value) {
        if (_showFocus != value) setState(() => _showFocus = value);
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            onActivate?.call();
            return null;
          },
        ),
      },
      child: Semantics(
        header: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onActivate,
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: _showFocus
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(KubusRadius.xs),
                    border: Border.all(
                      color: widget.accent,
                      width: KubusBorders.emphasisWidth,
                    ),
                  )
                : const BoxDecoration(),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
