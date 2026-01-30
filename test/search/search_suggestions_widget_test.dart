import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/search_service.dart';
import 'package:art_kubus/utils/map_search_suggestion.dart';

class _SearchHarness extends StatelessWidget {
  const _SearchHarness({
    required this.service,
    required this.query,
  });

  final SearchService service;
  final String query;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 360,
            height: 240,
            child: FutureBuilder<List<MapSearchSuggestion>>(
              future: service.fetchSuggestions(
                context: context,
                query: query,
                scope: SearchScope.map,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SizedBox.shrink();
                }
                final suggestions = snapshot.data ?? const <MapSearchSuggestion>[];
                if (suggestions.isEmpty) {
                  return const Center(child: Text('No results found'));
                }
                return ListView.builder(
                  itemCount: suggestions.length,
                  itemBuilder: (context, index) {
                    final suggestion = suggestions[index];
                    return ListTile(
                      title: Text(suggestion.label),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  BackendApiService buildBackendWithSuggestions(List<Map<String, dynamic>> suggestions) {
    final backend = BackendApiService();
    backend.setHttpClient(
      MockClient((request) async {
        if (request.url.path.endsWith('/api/search/suggestions')) {
          return http.Response(
            jsonEncode({'suggestions': suggestions}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      }),
    );
    return backend;
  }

  testWidgets('search with empty query renders empty state', (tester) async {
    final service = SearchService(
      backendApi: buildBackendWithSuggestions(const []),
    );

    await tester.pumpWidget(
      _SearchHarness(
        service: service,
        query: '',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No results found'), findsOneWidget);
  });

  testWidgets('search with query renders results', (tester) async {
    final service = SearchService(
      backendApi: buildBackendWithSuggestions([
        {
          'label': 'Ocean Light',
          'type': 'artwork',
          'id': null,
        },
      ]),
    );

    await tester.pumpWidget(
      _SearchHarness(
        service: service,
        query: 'ocean',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ocean Light'), findsOneWidget);
  });
}
