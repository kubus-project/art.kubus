import 'dart:convert';
import 'dart:typed_data';

import 'package:art_kubus/services/account_data_export_service.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter_test/flutter_test.dart';

BackendApiRequestException _status(int code) => BackendApiRequestException(
      statusCode: code,
      path: '/api/account/data-export',
    );

void main() {
  final fixedNow = DateTime.utc(2026, 10, 31, 23, 59);
  final payload = utf8.encode('{"format":"art.kubus-account-data-export"}');

  test('the downloaded file is named by date only', () {
    expect(AccountDataExportService.fileNameFor(fixedNow),
        'art-kubus-data-export-2026-10-31.json');
  });

  test('a successful export hands the exact bytes to the delivery step',
      () async {
    Uint8List? delivered;
    String? deliveredName;
    final service = AccountDataExportService(
      fetch: () async => payload,
      deliver: (bytes, name) async {
        delivered = bytes;
        deliveredName = name;
      },
      clock: () => fixedNow,
    );

    expect(await service.run(), AccountDataExportOutcome.saved);
    expect(delivered, orderedEquals(payload));
    expect(deliveredName, 'art-kubus-data-export-2026-10-31.json');
  });

  test('a signed-out or expired session asks for sign-in and delivers nothing',
      () async {
    for (final code in [401, 403]) {
      var delivered = false;
      final service = AccountDataExportService(
        fetch: () async => throw _status(code),
        deliver: (_, __) async => delivered = true,
        clock: () => fixedNow,
      );
      expect(await service.run(), AccountDataExportOutcome.signInRequired,
          reason: 'status $code');
      expect(delivered, isFalse);
    }
  });

  test('the server rate limit is reported as such', () async {
    final service = AccountDataExportService(
      fetch: () async => throw _status(429),
      deliver: (_, __) async {},
      clock: () => fixedNow,
    );
    expect(await service.run(), AccountDataExportOutcome.tooManyRequests);
  });

  test('any other failure is a plain failure, never a partial file', () async {
    for (final failure in <Object>[
      _status(500),
      _status(404),
      StateError('network down'),
    ]) {
      var delivered = false;
      final service = AccountDataExportService(
        fetch: () async => throw failure,
        deliver: (_, __) async => delivered = true,
        clock: () => fixedNow,
      );
      expect(await service.run(), AccountDataExportOutcome.failed);
      expect(delivered, isFalse);
    }
  });

  test('an empty answer is not delivered as a file', () async {
    var delivered = false;
    final service = AccountDataExportService(
      fetch: () async => <int>[],
      deliver: (_, __) async => delivered = true,
      clock: () => fixedNow,
    );
    expect(await service.run(), AccountDataExportOutcome.failed);
    expect(delivered, isFalse);
  });

  test('a delivery that fails after a good fetch is reported as a failure',
      () async {
    final service = AccountDataExportService(
      fetch: () async => payload,
      deliver: (_, __) async => throw StateError('share sheet unavailable'),
      clock: () => fixedNow,
    );
    expect(await service.run(), AccountDataExportOutcome.failed);
  });

  test('a second tap while one export is running joins it instead of repeating',
      () async {
    var fetches = 0;
    final service = AccountDataExportService(
      fetch: () async {
        fetches += 1;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return payload;
      },
      deliver: (_, __) async {},
      clock: () => fixedNow,
    );
    final results = await Future.wait([service.run(), service.run()]);
    expect(results, everyElement(AccountDataExportOutcome.saved));
    expect(fetches, 1);
  });
}
