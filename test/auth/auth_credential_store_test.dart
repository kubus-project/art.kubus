import 'dart:async';

import 'package:art_kubus/services/auth_credential_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, String> secure;
  late List<String> deleted;
  late Set<String> failingDeletes;
  late bool failWrite;
  Completer<void>? readBarrier;
  Completer<void>? writeBarrier;
  Completer<void>? entered;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    secure = {};
    deleted = [];
    failingDeletes = {};
    failWrite = false;
    readBarrier = null;
    writeBarrier = null;
    entered = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      final args = call.arguments as Map;
      final key = args['key'] as String;
      switch (call.method) {
        case 'read':
          final value = secure[key];
          if (entered != null && !entered!.isCompleted) entered!.complete();
          await readBarrier?.future;
          return value;
        case 'write':
          if (entered != null && !entered!.isCompleted) entered!.complete();
          await writeBarrier?.future;
          if (failWrite) throw PlatformException(code: 'synthetic-write-error');
          secure[key] = args['value'] as String;
          return null;
        case 'delete':
          deleted.add(key);
          if (failingDeletes.contains(key)) {
            throw PlatformException(code: 'synthetic-delete-error');
          }
          secure.remove(key);
          return null;
      }
      throw StateError('Unexpected platform operation');
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('native writes secrets only to secure store and supports restart',
      () async {
    final store = AuthCredentialStore(web: false);
    expect(await store.save('jwt_token', 'synthetic-A'), isTrue);
    expect(await store.save('refresh_token', 'synthetic-R'), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('jwt_token'), isNull);
    expect(prefs.getString('refresh_token'), isNull);
    expect(secure['jwt_token'], 'synthetic-A');
    expect(secure['refresh_token'], 'synthetic-R');
    expect(await AuthCredentialStore(web: false).readAccess(), 'synthetic-A');
  });

  test('native legacy migration stores before removing preference aliases',
      () async {
    SharedPreferences.setMockInitialValues({
      'auth_token': 'synthetic-legacy',
      'refreshToken': 'synthetic-refresh',
    });
    expect(
        await AuthCredentialStore(web: false).readAccess(), 'synthetic-legacy');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('auth_token'), isNull);
    expect(prefs.getString('refreshToken'), isNull);
    expect(secure['jwt_token'], 'synthetic-legacy');
    expect(secure['refresh_token'], 'synthetic-refresh');
  });

  test('secure write failure fails closed without preference duplication',
      () async {
    failWrite = true;
    final store = AuthCredentialStore(web: false);
    await expectLater(store.save('jwt_token', 'synthetic-A'),
        throwsA(isA<PlatformException>()));
    expect(
        (await SharedPreferences.getInstance()).getString('jwt_token'), isNull);
    expect(await AuthCredentialStore(web: false).readAccess(), isNull);
  });

  test(
      'failed JWT deletion does not skip refresh/aliases; marker blocks restart',
      () async {
    secure.addAll({'jwt_token': 'synthetic-A', 'refresh_token': 'synthetic-R'});
    SharedPreferences.setMockInitialValues({'authToken': 'synthetic-old'});
    failingDeletes.add('jwt_token');
    final result = await AuthCredentialStore(web: false).clear();
    expect(result.complete, isFalse);
    expect(result.restartBlocked, isTrue);
    expect(deleted, containsAll(['jwt_token', 'refresh_token', 'authToken']));
    expect(secure['refresh_token'], isNull);
    expect(
        (await SharedPreferences.getInstance()).getString('authToken'), isNull);
    expect(await AuthCredentialStore(web: false).readAccess(), isNull);
  });

  test('late secure read cannot restore a signed-out session', () async {
    secure['jwt_token'] = 'synthetic-A';
    readBarrier = Completer<void>();
    entered = Completer<void>();
    final store = AuthCredentialStore(web: false);
    final read = store.readAccess();
    await entered!.future;
    final clear = store.clear();
    readBarrier!.complete();
    expect(await read, isNull);
    expect((await clear).complete, isTrue);
    expect(secure, isEmpty);
  });

  test('logout marker persists before a hung secure read completes', () async {
    secure['jwt_token'] = 'synthetic-A';
    readBarrier = Completer<void>();
    entered = Completer<void>();
    final store = AuthCredentialStore(web: false);
    final pendingRead = store.readAccess();
    await entered!.future;
    final cleanup = store.clear();
    // SharedPreferences is independent of the blocked secure operation.
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(
        (await SharedPreferences.getInstance())
            .getBool(AuthCredentialStore.revokedKey),
        isTrue);
    readBarrier!.complete();
    expect(await pendingRead, isNull);
    await cleanup;
  });

  test('late write is serialized before logout and account B persistence',
      () async {
    writeBarrier = Completer<void>();
    entered = Completer<void>();
    final store = AuthCredentialStore(web: false);
    final saveA = store.save('jwt_token', 'synthetic-A');
    await entered!.future;
    final clear = store.clear();
    final saveB = store.save('jwt_token', 'synthetic-B');
    writeBarrier!.complete();
    expect(await saveA, isFalse);
    expect((await clear).complete, isTrue);
    expect(await saveB, isTrue);
    expect(secure['jwt_token'], 'synthetic-B');
    expect(await store.readAccess(), 'synthetic-B');
  });

  test(
      'web removes legacy persistence, keeps current memory only, reload signs out',
      () async {
    SharedPreferences.setMockInitialValues({'jwt_token': 'synthetic-legacy'});
    secure['jwt_token'] = 'synthetic-old-web-plugin';
    final web = AuthCredentialStore(web: true);
    expect(await web.readAccess(), isNull);
    expect(secure, isEmpty);
    expect(await web.save('jwt_token', 'synthetic-web'), isTrue);
    expect(await web.readAccess(), 'synthetic-web');
    expect(secure, isEmpty);
    expect(
        (await SharedPreferences.getInstance()).getString('jwt_token'), isNull);
    expect(await AuthCredentialStore(web: true).readAccess(), isNull);
    await web.clear();
    expect(await web.readAccess(), isNull);
  });

  test(
      'preference read exception and corrupt marker cannot restore credentials',
      () async {
    secure['jwt_token'] = 'synthetic-A';
    final broken = AuthCredentialStore(
        web: false,
        preferences: () async => throw StateError('synthetic read failure'));
    await expectLater(broken.readAccess(), throwsStateError);
    SharedPreferences.setMockInitialValues(
        {AuthCredentialStore.revokedKey: 'corrupt-type'});
    await expectLater(AuthCredentialStore(web: false).readAccess(),
        throwsA(isA<TypeError>()));
  });
}
