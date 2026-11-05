import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

/// Play treats broad storage access as a restricted capability. The app picks
/// files through system pickers and shares from its cache, so it must not ask
/// for it. These checks keep the source manifest honest; the merged release
/// manifest is checked by the Android release compile job.
void main() {
  late XmlDocument manifest;

  setUpAll(() {
    manifest = XmlDocument.parse(
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync());
  });

  Iterable<XmlElement> permissions() =>
      manifest.findAllElements('uses-permission');

  String? name(XmlElement e) => e.getAttribute('name',
      namespace: 'http://schemas.android.com/apk/res/android');

  test('no all-files access and no legacy write access', () {
    final names = permissions().map(name).toSet();
    expect(
        names, isNot(contains('android.permission.MANAGE_EXTERNAL_STORAGE')));
    expect(names, isNot(contains('android.permission.WRITE_EXTERNAL_STORAGE')));
  });

  test('legacy external storage mode is not requested', () {
    final application = manifest.findAllElements('application').single;
    expect(
      application.getAttribute('requestLegacyExternalStorage',
          namespace: 'http://schemas.android.com/apk/res/android'),
      isNull,
    );
  });

  test('read access to external storage is limited to API 32 and older', () {
    final read = permissions()
        .where((e) => name(e) == 'android.permission.READ_EXTERNAL_STORAGE');
    for (final e in read) {
      expect(
        e.getAttribute('maxSdkVersion',
            namespace: 'http://schemas.android.com/apk/res/android'),
        '32',
      );
    }
  });

  test('identity and platform requirements are unchanged', () {
    final gradle = File('android/app/build.gradle').readAsStringSync();
    expect(gradle, contains('applicationId = "com.art.kubus"'));
    expect(gradle, contains('targetSdk = 36'));
  });
}
