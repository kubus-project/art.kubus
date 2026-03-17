import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setAuthTokenForTesting(null);
  });

  test('syncSecureAccountStatusFromResponse persists email and verification',
      () async {
    final api = BackendApiService();

    await api.syncSecureAccountStatusFromResponse(<String, dynamic>{
      'success': true,
      'data': <String, dynamic>{
        'securityStatus': <String, dynamic>{
          'hasEmail': true,
          'hasPassword': true,
          'email': 'wallet@example.com',
          'emailVerified': true,
          'emailAuthEnabled': true,
        },
      },
    });

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString(PreferenceKeys.secureAccountEmail),
      'wallet@example.com',
    );
    expect(
      prefs.getBool(PreferenceKeys.secureAccountEmailVerifiedV1),
      isTrue,
    );
  });

  test(
      'syncSecureAccountStatusFromResponse clears stale email when account has none',
      () async {
    final api = BackendApiService();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        PreferenceKeys.secureAccountEmail, 'stale@example.com');
    await prefs.setBool(PreferenceKeys.secureAccountEmailVerifiedV1, true);

    await api.syncSecureAccountStatusFromResponse(<String, dynamic>{
      'success': true,
      'data': <String, dynamic>{
        'securityStatus': <String, dynamic>{
          'hasEmail': false,
          'hasPassword': false,
          'email': null,
          'emailVerified': false,
          'emailAuthEnabled': true,
        },
      },
    });

    expect(prefs.getString(PreferenceKeys.secureAccountEmail), isNull);
    expect(
      prefs.getBool(PreferenceKeys.secureAccountEmailVerifiedV1),
      isFalse,
    );
  });

  test(
      'resendEmailVerification stays anonymous even when an auth token is cached',
      () async {
    final api = BackendApiService();
    api.setAuthTokenForTesting('cached-token');
    api.setHttpClient(
      MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/auth/resend-verification');
        expect(request.headers.containsKey('Authorization'), isFalse);
        return http.Response(
          '{"success":true,"message":"If an account exists for this email, a verification email will be sent shortly."}',
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    final response =
        await api.resendEmailVerification(email: 'user@example.com');

    expect(response['success'], isTrue);
    expect(response['message'], contains('If an account exists'));
  });

  test(
      'resendEmailVerificationForCurrentAccount attaches Authorization header',
      () async {
    final api = BackendApiService();
    api.setAuthTokenForTesting('cached-token');
    api.setHttpClient(
      MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/auth/resend-verification');
        expect(request.headers['Authorization'], 'Bearer cached-token');
        return http.Response(
          '{"success":true,"data":{"emailVerificationSent":true,"securityStatus":{"hasEmail":true,"hasPassword":true,"email":"wallet@example.com","emailVerified":false,"emailAuthEnabled":true}}}',
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    final response = await api.resendEmailVerificationForCurrentAccount(
      email: 'wallet@example.com',
    );

    expect(response['success'], isTrue);
  });

  test('resendEmailVerificationForCurrentAccount fails without auth token',
      () async {
    final api = BackendApiService();
    api.setAuthTokenForTesting(null);

    expect(
      () => api.resendEmailVerificationForCurrentAccount(
        email: 'wallet@example.com',
      ),
      throwsA(isA<Exception>()),
    );
  });
}
