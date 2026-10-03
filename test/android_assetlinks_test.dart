import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // SHA-256 of the protected direct-distribution release certificate, as
  // verified from the signed v0.7.4 APK with `apksigner verify --print-certs`.
  const directReleaseFingerprint =
      '42:68:42:AD:10:CB:AF:2F:45:31:5B:EA:69:36:25:3E:C3:2D:42:B4:4D:25:F6:93:'
      '5A:1D:2B:9C:E3:B1:C8:A3';

  late List<dynamic> statements;

  setUpAll(() {
    final file = File('web/.well-known/assetlinks.json');
    expect(file.existsSync(), isTrue,
        reason: 'The web artifact must ship Digital Asset Links.');
    statements = jsonDecode(file.readAsStringSync()) as List<dynamic>;
  });

  test('assetlinks.json associates com.art.kubus for handle_all_urls', () {
    expect(statements, hasLength(1));
    final statement = statements.single as Map<String, dynamic>;
    expect(statement['relation'],
        <String>['delegate_permission/common.handle_all_urls']);
    final target = statement['target'] as Map<String, dynamic>;
    expect(target['namespace'], 'android_app');
    expect(target['package_name'], 'com.art.kubus');
  });

  test('assetlinks.json lists well-formed SHA-256 certificate fingerprints',
      () {
    final target = (statements.single as Map<String, dynamic>)['target']
        as Map<String, dynamic>;
    final fingerprints =
        (target['sha256_cert_fingerprints'] as List<dynamic>).cast<String>();
    expect(fingerprints, contains(directReleaseFingerprint));
    final shape = RegExp(r'^([0-9A-F]{2}:){31}[0-9A-F]{2}$');
    for (final fingerprint in fingerprints) {
      expect(shape.hasMatch(fingerprint), isTrue, reason: fingerprint);
    }
    expect(fingerprints.toSet(), hasLength(fingerprints.length));
  });

  test('assetlinks package matches the Android application id', () {
    final gradle = File('android/app/build.gradle.kts').existsSync()
        ? File('android/app/build.gradle.kts').readAsStringSync()
        : File('android/app/build.gradle').readAsStringSync();
    expect(gradle, contains('applicationId = "com.art.kubus"'));
  });
}
