import 'package:art_kubus/services/third_party_licenses.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the spatial viewer notices reach the in-app licence registry',
      () async {
    resetSpatialViewerLicenseRegistrationForTest();
    registerSpatialViewerLicenses();
    registerSpatialViewerLicenses(); // idempotent
    final entries = await LicenseRegistry.licenses
        .where((e) => e.packages.contains('@sparkjsdev/spark'))
        .toList();
    expect(entries, hasLength(1));
    final entry = entries.single;
    expect(entry.packages, containsAll(spatialViewerLicensePackages));
    final text = entry.paragraphs.map((p) => p.text).join('\n');
    // Spark, three.js and fflate holders, and the Rust crate list, from the real asset.
    expect(text, contains('WORLD LABS TECHNOLOGIES'));
    expect(text, contains('three.js authors'));
    expect(text, contains('Arjun Barrett'));
    expect(text, contains('Rust crates compiled into the WebAssembly module'));
    expect(text, contains('Permission is hereby granted'));
  });
}
