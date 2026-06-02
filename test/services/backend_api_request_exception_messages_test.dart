import 'package:flutter_test/flutter_test.dart';
import 'package:art_kubus/services/backend_api_service.dart';

void main() {
  test('gateway timeout message is human readable', () {
    const error = BackendApiRequestException(
      statusCode: 504,
      path: '/api/profiles',
      body: '<html>Gateway Timeout</html>',
    );

    expect(
      error.toString(),
      'Server timed out. Your connection is okay, but art.kubus API did not respond in time.',
    );
  });

  test('upload timeout message suggests retrying smaller media', () {
    const error = BackendApiRequestException(
      statusCode: 504,
      path: '/api/profiles/avatars',
    );

    expect(error.toString(), 'Upload timed out. Try a smaller image or retry.');
  });

  test('temporary outage message is human readable', () {
    const error = BackendApiRequestException(
      statusCode: 503,
      path: '/api/community/posts',
    );

    expect(error.toString(), 'Server is temporarily unavailable.');
  });
}
