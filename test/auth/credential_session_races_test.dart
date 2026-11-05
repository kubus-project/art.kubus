import 'dart:async';
import 'dart:convert';

import 'package:art_kubus/services/auth_credential_store.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
String jwt(String id) => 'e30.${base64Url.encode(utf8.encode(jsonEncode({
          'id': id,
          'exp': 2100000000
        }))).replaceAll('=', '')}.synthetic';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BackendApiService api;
  late Map<String, String> secure;
  late Set<String> failedDeletes;
  Completer<void>? writeBarrier;
  Completer<void>? writeEntered;
  var failAWrite = false;

  setUp(() {
    api = BackendApiService();
    SharedPreferences.setMockInitialValues({});
    secure = {};
    failedDeletes = {};
    writeBarrier = null;
    writeEntered = null;
    failAWrite = false;
    api.resetCredentialStoreForTesting();
    api.setAuthTokenForTesting(null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      final args = call.arguments as Map;
      final key = args['key'] as String;
      if (call.method == 'read') return secure[key];
      if (call.method == 'delete') {
        if (failedDeletes.contains(key)) {
          throw PlatformException(code: 'synthetic-delete-failure');
        }
        secure.remove(key);
        return null;
      }
      if (call.method == 'write') {
        final value = args['value'] as String;
        if (value == jwt('A')) {
          if (writeEntered != null && !writeEntered!.isCompleted) {
            writeEntered!.complete();
          }
          await writeBarrier?.future;
          if (failAWrite) {
            throw PlatformException(code: 'synthetic-write-failure');
          }
        }
        secure[key] = value;
        return null;
      }
      throw StateError('Unexpected credential operation');
    });
  });
  tearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null));

  for (final newerAccount in [false, true]) {
    test(
        'delayed login cannot restore after ${newerAccount ? 'account B login' : 'logout'}',
        () async {
      final entered = Completer<void>();
      final response = Completer<void>();
      api.setHttpClient(MockClient((_) async {
        entered.complete();
        await response.future;
        return http.Response(
            jsonEncode(
                {'token': jwt('A'), 'refreshToken': 'synthetic-refresh-A'}),
            200);
      }));
      final login = api.loginWithEmail(
          email: 'synthetic@example.invalid', password: 'synthetic-not-real');
      final rejected = expectLater(login, throwsStateError);
      await entered.future;
      await api.clearAuth();
      if (newerAccount) await api.setAuthToken(jwt('B'));
      response.complete();
      await rejected;
      expect(api.getAuthToken(), newerAccount ? jwt('B') : isNull);
      expect(secure['jwt_token'], newerAccount ? jwt('B') : isNull);
      expect(secure['refresh_token'], isNull);
    });
  }

  for (final failWrite in [false, true]) {
    test(
        'interleaved ${failWrite ? 'failed' : 'late'} A commit cannot revoke/mix B credential pair',
        () async {
      writeBarrier = Completer<void>();
      writeEntered = Completer<void>();
      failAWrite = failWrite;
      final a = api.persistAuthTokensFromResponse(
          {'token': jwt('A'), 'refreshToken': 'synthetic-refresh-A'});
      final rejected = expectLater(a, throwsA(anything));
      await writeEntered!.future;
      final b = api.persistAuthTokensFromResponse(
          {'token': jwt('B'), 'refreshToken': 'synthetic-refresh-B'});
      writeBarrier!.complete();
      await rejected;
      expect(await b, isTrue);
      expect(api.getAuthToken(), jwt('B'));
      expect(secure['jwt_token'], jwt('B'));
      expect(secure['refresh_token'], 'synthetic-refresh-B');
    });
  }

  test(
      'logout attempts refresh deletion despite JWT failure and restart cannot load retained JWT',
      () async {
    await api.persistAuthTokensFromResponse(
        {'token': jwt('A'), 'refreshToken': 'synthetic-refresh-A'});
    failedDeletes.add('jwt_token');
    await api.clearAuth();
    expect(api.getAuthToken(), isNull);
    expect(secure['refresh_token'], isNull);
    expect(
        (await SharedPreferences.getInstance())
            .getBool(AuthCredentialStore.revokedKey),
        isTrue);
    api.resetCredentialStoreForTesting();
    await api.loadAuthToken();
    expect(api.getAuthToken(), isNull);
  });
}
