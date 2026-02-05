import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/search_service.dart';
import '../../../utils/map_search_suggestion.dart';

@immutable
class MapSearchState {
  const MapSearchState({
    required this.query,
    required this.isFetching,
    required this.isOverlayVisible,
    required this.suggestions,
  });

  final String query;
  final bool isFetching;
  final bool isOverlayVisible;
  final List<MapSearchSuggestion> suggestions;

  bool get hasQuery => query.trim().isNotEmpty;

  MapSearchState copyWith({
    String? query,
    bool? isFetching,
    bool? isOverlayVisible,
    List<MapSearchSuggestion>? suggestions,
  }) {
    return MapSearchState(
      query: query ?? this.query,
      isFetching: isFetching ?? this.isFetching,
      isOverlayVisible: isOverlayVisible ?? this.isOverlayVisible,
      suggestions: suggestions ?? this.suggestions,
    );
  }
}

/// Controller that owns map-search UI state (query, focus, debounced suggestion
/// fetching, overlay visibility).
///
/// This is intentionally *not* a Provider: it is a screen-owned controller
/// (see Map refactor docs) and must remain idempotent and disposable.
class MapSearchController extends ChangeNotifier {
  MapSearchController({
    SearchService? searchService,
    this.scope = SearchScope.map,
    this.minChars = 2,
    this.limit = 8,
    this.debounceDuration = const Duration(milliseconds: 275),
    this.showOverlayOnFocus = false,
    TextEditingController? textController,
    FocusNode? focusNode,
    LayerLink? fieldLink,
  })  : _searchService = searchService ?? SearchService(),
        textController = textController ?? TextEditingController(),
        focusNode = focusNode ?? FocusNode(),
        fieldLink = fieldLink ?? LayerLink() {
    _ownsTextController = textController == null;
    _ownsFocusNode = focusNode == null;

    this.focusNode.addListener(_handleFocusChanged);
  }

  final SearchService _searchService;

  /// Scope used by [SearchService] to filter and fallback.
  final SearchScope scope;

  final int minChars;
  final int limit;
  final Duration debounceDuration;

  /// When true, focusing the field will show the overlay even for an empty
  /// query (useful to display a min-chars hint on mobile).
  final bool showOverlayOnFocus;

  /// Anchor link for CompositedTransformTarget/Follower.
  final LayerLink fieldLink;

  final TextEditingController textController;
  final FocusNode focusNode;

  late final bool _ownsTextController;
  late final bool _ownsFocusNode;

  Timer? _debounce;
  int _requestToken = 0;

  MapSearchState _state = const MapSearchState(
    query: '',
    isFetching: false,
    isOverlayVisible: false,
    suggestions: <MapSearchSuggestion>[],
  );

  MapSearchState get state => _state;

  void _setState(MapSearchState next) {
    if (identical(next, _state)) return;
    _state = next;
    notifyListeners();
  }

  bool _shouldShowOverlayFor(String query) {
    if (!focusNode.hasFocus) return false;
    if (showOverlayOnFocus) return true;
    return query.trim().isNotEmpty;
  }

  void _handleFocusChanged() {
    final shouldShow = _shouldShowOverlayFor(_state.query);
    if (shouldShow == _state.isOverlayVisible) return;
    _setState(_state.copyWith(isOverlayVisible: shouldShow));
  }

  /// Called by the UI on every keystroke.
  ///
  /// We accept a [BuildContext] here so the controller can delegate provider
  /// reads to [SearchService] while staying context-safe (we capture providers
  /// before async gaps inside the service).
  void onQueryChanged(BuildContext context, String value) {
    final nextQuery = value;
    final trimmed = nextQuery.trim();

    _debounce?.cancel();
    _debounce = null;

    // Update immediate UI state.
    _setState(
      _state.copyWith(
        query: nextQuery,
        isOverlayVisible: _shouldShowOverlayFor(nextQuery),
        // Clear results instantly if the query is too short.
        isFetching: trimmed.length >= minChars ? _state.isFetching : false,
        suggestions: trimmed.length >= minChars ? _state.suggestions : const [],
      ),
    );

    if (trimmed.length < minChars) {
      // Invalidate any in-flight requests.
      _requestToken += 1;
      return;
    }

    final myToken = ++_requestToken;
    _debounce = Timer(debounceDuration, () {
      unawaited(_fetchSuggestions(context, trimmed, token: myToken));
    });
  }

  /// Optional: called when the user presses enter/search.
  void onSubmitted() {
    // Submitting typically means: keep text, hide suggestions.
    dismissOverlay(unfocus: true);
  }

  void dismissOverlay({bool unfocus = true}) {
    _debounce?.cancel();
    _debounce = null;

    // Invalidate in-flight requests so late arrivals don't pop the overlay.
    _requestToken += 1;

    if (unfocus && focusNode.hasFocus) {
      focusNode.unfocus();
    }

    if (!_state.isOverlayVisible && !_state.isFetching && _state.suggestions.isEmpty) {
      return;
    }

    _setState(
      _state.copyWith(
        isOverlayVisible: false,
        isFetching: false,
        suggestions: const <MapSearchSuggestion>[],
      ),
    );
  }

  void clearQueryWithContext(BuildContext context) {
    textController.clear();
    onQueryChanged(context, '');
    dismissOverlay(unfocus: true);
  }

  Future<void> _fetchSuggestions(
    BuildContext context,
    String trimmedQuery, {
    required int token,
  }) async {
    // Drop if query changed since scheduling.
    if (token != _requestToken) return;

    _setState(_state.copyWith(isFetching: true));

    try {
      final suggestions = await _searchService.fetchSuggestions(
        context: context,
        query: trimmedQuery,
        scope: scope,
        limit: limit,
      );

      if (token != _requestToken) return;

      _setState(
        _state.copyWith(
          isFetching: false,
          suggestions: suggestions,
          isOverlayVisible: _shouldShowOverlayFor(trimmedQuery),
        ),
      );
    } catch (_) {
      if (token != _requestToken) return;
      _setState(
        _state.copyWith(
          isFetching: false,
          suggestions: const <MapSearchSuggestion>[],
          isOverlayVisible: _shouldShowOverlayFor(trimmedQuery),
        ),
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    focusNode.removeListener(_handleFocusChanged);

    if (_ownsTextController) {
      textController.dispose();
    }
    if (_ownsFocusNode) {
      focusNode.dispose();
    }

    super.dispose();
  }
}
