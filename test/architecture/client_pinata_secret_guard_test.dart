import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Flutter code does not reference client-side Pinata secrets', () {
    final forbiddenTokens = <String>[
      'KUBUS_PINATA_API_KEY',
      'KUBUS_PINATA_SECRET_KEY',
      'pinata_api_key',
      'pinata_secret_api_key',
      'pinataApiKey',
      'pinataSecretKey',
    ];
    final offenders = <String>[];

    for (final file in _dartFilesUnder('lib')) {
      final source = file.readAsStringSync();
      for (final token in forbiddenTokens) {
        if (source.contains(token)) {
          offenders.add('${_slash(file.path)} contains $token');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Flutter artifacts must not carry Pinata credentials. Uploads '
          'that need IPFS/hybrid storage must go through backend storage.',
    );
  });

  test('AR uploads use backend-managed storage instead of Pinata multipart',
      () {
    final source =
        File('lib/services/ar_content_service.dart').readAsStringSync();

    expect(source, contains('ArtContentService.uploadMedia'));
    expect(source, contains('targetStorage'));
    expect(source, isNot(contains('pinata_secret_api_key')));
    expect(source, isNot(contains("MultipartRequest('POST'")));
  });
}

Iterable<File> _dartFilesUnder(String root) sync* {
  final directory = Directory(root);
  if (!directory.existsSync()) return;
  for (final entity in directory.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      yield entity;
    }
  }
}

String _slash(String path) => path.replaceAll(r'\', '/');
