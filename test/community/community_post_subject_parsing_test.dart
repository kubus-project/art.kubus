import 'dart:convert';

import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('Community post artworkId maps to subject fields', () async {
    final api = BackendApiService();
    api.setAuthTokenForTesting('token');
    api.setHttpClient(
      MockClient((request) async {
        if (request.url.path.endsWith('/api/community/posts/post_1')) {
          final payload = <String, dynamic>{
            'id': 'post_1',
            'authorId': 'user_1',
            'authorName': 'Artist',
            'content': 'Hello world',
            'createdAt': '2024-01-01T00:00:00.000Z',
            'artworkId': 'art_1',
            'artworkTitle': 'Test Artwork',
            'artworkImage': '/uploads/test.jpg',
          };
          return http.Response(
            jsonEncode(<String, dynamic>{'data': payload}),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      }),
    );

    final post = await api.getCommunityPostById('post_1');
    expect(post.subjectType, 'artwork');
    expect(post.subjectId, 'art_1');
    expect(post.artwork?.id, 'art_1');
  });
}
