import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

void main() {
  test('Android notifications use a separate transparent monochrome glyph', () {
    final manifest = XmlDocument.parse(
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
    );
    final app = manifest.findAllElements('application').single;
    expect(app.getAttribute('android:icon'), '@mipmap/ic_launcher');

    final icon = XmlDocument.parse(
      File('android/app/src/main/res/drawable/ic_notification.xml')
          .readAsStringSync(),
    );
    final vector = icon.rootElement;
    expect(vector.name.local, 'vector');
    expect(vector.getAttribute('android:background'), isNull);
    expect(vector.getAttribute('android:width'), '24dp');
    final paths = vector.findAllElements('path').toList();
    expect(paths, hasLength(1));
    expect(paths.single.getAttribute('android:fillColor'), '#00000000');
    expect(paths.single.getAttribute('android:strokeColor'), '#FFFFFFFF');
    expect(paths.single.getAttribute('android:pathData'), isNotEmpty);

    final service =
        File('lib/services/push_notification_service.dart').readAsStringSync();
    expect(
      service,
      contains("AndroidInitializationSettings('@drawable/ic_notification')"),
    );
    expect(service, isNot(contains('@mipmap/ic_launcher')));
    final notificationDetails =
        RegExp(r'AndroidNotificationDetails\(').allMatches(service).length;
    final notificationIcons = RegExp(
      r"icon:\s*'@drawable/ic_notification'",
    ).allMatches(service).length;
    expect(notificationIcons, notificationDetails);
    expect(notificationDetails, greaterThan(0));
  });
}
