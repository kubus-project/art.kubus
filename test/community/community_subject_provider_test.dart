import 'dart:convert';

import 'package:art_kubus/models/community_subject.dart';
import 'package:art_kubus/providers/community_subject_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('CommunitySubjectProvider batches resolve calls and caches results',
      () async {
    final api = BackendApiService();
    var resolveCalls = 0;
    api.setAuthTokenForTesting('token');
    api.setHttpClient(
      MockClient((request) async {
        if (request.url.path.endsWith('/api/community/subjects/resolve')) {
          resolveCalls++;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final subjects = (body['subjects'] as List)
              .cast<Map<String, dynamic>>();
          final data = subjects
              .map((subject) => <String, dynamic>{
                    'type': subject['type'],
                    'id': subject['id'],
                    'title': 'Title ${subject['id']}',
                  })
              .toList();
          return http.Response(
            jsonEncode(<String, dynamic>{'data': data}),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      }),
    );

    final provider = CommunitySubjectProvider(api: api);
    provider.queueResolve(const [
      CommunitySubjectRef(type: 'artwork', id: 'a1'),
      CommunitySubjectRef(type: 'collection', id: 'c1'),
    ]);

    await pumpEventQueue();
    await pumpEventQueue();

    expect(resolveCalls, 1);
    expect(
      provider.previewFor(const CommunitySubjectRef(type: 'artwork', id: 'a1')),
      isNotNull,
    );
    expect(
      provider.previewFor(const CommunitySubjectRef(type: 'collection', id: 'c1')),
      isNotNull,
    );

    provider.queueResolve(const [
      CommunitySubjectRef(type: 'artwork', id: 'a1'),
      CommunitySubjectRef(type: 'collection', id: 'c1'),
    ]);

    await pumpEventQueue();
    expect(resolveCalls, 1);
  });
}
