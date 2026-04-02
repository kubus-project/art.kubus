import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/search_service.dart';
import 'kubus_search_config.dart';
import 'kubus_search_result.dart';

@immutable
class KubusSearchState {
  const KubusSearchState({
    required this.query,
    required this.isFetching,
    required this.isOverlayVisible,
    required this.results,
  });

  final String query;
  final bool isFetching;
  final bool isOverlayVisible;
  final List<KubusSearchResult> results;

  KubusSearchState copyWith({
    String? query,
    bool? isFetching,
    bool? isOverlayVisible,
    List<KubusSearchResult>? results,
  }) {
    return KubusSearchState(
      query: query ?? this.query,
      isFetching: isFetching ?? this.isFetching,
      isOverlayVisible: isOverlayVisible ?? this.isOverlayVisible,
      results: results ?? this.results,
    );
  }
}

class KubusSearchController extends ChangeNotifier {
  KubusSearchController({
    required this.config,
    SearchService? searchService,
    TextEditingController? textController,
  })  : _searchService = searchService ?? SearchService(),
        textController = textController ?? TextEditingController() {
    _ownsTextController = textController == null;
  }

  final KubusSearchConfig config;
  final SearchService _searchService;
  final TextEditingController textController;

  late final bool _ownsTextController;
  final Set<LayerLink> _focusedFieldLinks = <LayerLink>{};

  Timer? _debounce;
  int _requestToken = 0;
  bool _disposed = false;
  LayerLink? _activeFieldLink;

  KubusSearchState _state = const KubusSearchState(
    query: '',
    isFetching: false,
    isOverlayVisible: false,
    results: <KubusSearchResult>[],
  );

  KubusSearchState get state => _state;
  LayerLink? get activeFieldLink => _activeFieldLink;
  bool get hasFocusedField => _focusedFieldLinks.isNotEmpty;

  void _setState(KubusSearchState next) {
    if (_disposed) return;
    if (identical(next, _state)) return;
    _state = next;
    notifyListeners();
  }

  bool _shouldShowOverlayFor(String query) {
    final trimmed = query.trim();
    if (hasFocusedField) {
      return config.showOverlayOnFocus || trimmed.isNotEmpty;
    }
    return _state.isOverlayVisible && trimmed.isNotEmpty;
  }

  void updateFieldFocus(LayerLink link, bool hasFocus) {
    if (_disposed) return;
    final previousActiveFieldLink = _activeFieldLink;
    if (hasFocus) {
      _focusedFieldLinks.add(link);
      _activeFieldLink = link;
    } else {
      _focusedFieldLinks.remove(link);
      if (_activeFieldLink == link) {
        _activeFieldLink =
            _focusedFieldLinks.isEmpty ? null : _focusedFieldLinks.last;
      }
    }
    final shouldShow = _shouldShowOverlayFor(_state.query);
    if (shouldShow != _state.isOverlayVisible) {
      _setState(_state.copyWith(isOverlayVisible: shouldShow));
      return;
    }

    if (previousActiveFieldLink != _activeFieldLink) {
      notifyListeners();
    }
  }

  void onQueryChanged(BuildContext context, String value) {
    final nextQuery = value;
    final trimmed = nextQuery.trim();
    final snapshot = SearchContextSnapshot.capture(
      context,
      config: config,
    );

    _debounce?.cancel();
    _debounce = null;

    _setState(
      _state.copyWith(
        query: nextQuery,
        isOverlayVisible: _shouldShowOverlayFor(nextQuery),
        isFetching: trimmed.length >= config.minChars ? _state.isFetching : false,
        results: trimmed.length >= config.minChars ? _state.results : const [],
      ),
    );

    if (trimmed.length < config.minChars) {
      _requestToken += 1;
      return;
    }

    final myToken = ++_requestToken;
    _debounce = Timer(config.debounceDuration, () {
      unawaited(_fetchResults(snapshot, trimmed, token: myToken));
    });
  }

  void onSubmitted() {
    dismissOverlay();
  }

  void dismissOverlay({bool clearResults = false}) {
    _debounce?.cancel();
    _debounce = null;
    _requestToken += 1;
    _setState(
      _state.copyWith(
        isOverlayVisible: false,
        isFetching: false,
        results: clearResults ? const <KubusSearchResult>[] : _state.results,
      ),
    );
  }

  void clearQueryWithContext(BuildContext context) {
    textController.clear();
    _requestToken += 1;
    onQueryChanged(context, '');
    dismissOverlay(clearResults: true);
  }

  void setQuery(BuildContext context, String value) {
    textController.text = value;
    textController.selection = TextSelection.collapsed(offset: value.length);
    onQueryChanged(context, value);
  }

  Future<void> _fetchResults(
    SearchContextSnapshot snapshot,
    String trimmedQuery, {
    required int token,
  }) async {
    if (_disposed || token != _requestToken) return;

    _setState(_state.copyWith(isFetching: true));

    try {
      final results = await _searchService.fetchResults(
        snapshot: snapshot,
        query: trimmedQuery,
        config: config,
      );
      if (_disposed || token != _requestToken) return;
      _setState(
        _state.copyWith(
          isFetching: false,
          results: results,
          isOverlayVisible: _shouldShowOverlayFor(trimmedQuery),
        ),
      );
    } catch (_) {
      if (_disposed || token != _requestToken) return;
      _setState(
        _state.copyWith(
          isFetching: false,
          results: const <KubusSearchResult>[],
          isOverlayVisible: _shouldShowOverlayFor(trimmedQuery),
        ),
      );
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _requestToken += 1;
    _focusedFieldLinks.clear();
    _activeFieldLink = null;
    if (_ownsTextController) {
      textController.dispose();
    }
    super.dispose();
  }
}
