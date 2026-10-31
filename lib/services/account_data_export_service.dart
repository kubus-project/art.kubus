import 'dart:async';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import 'backend_api_service.dart';

enum AccountDataExportOutcome { saved, signInRequired, tooManyRequests, failed }

typedef AccountDataExportFetch = Future<List<int>> Function();
typedef AccountDataExportDeliver = Future<void> Function(
    Uint8List bytes, String fileName);

/// Downloads the signed-in account's own data as one JSON file and hands it to
/// the platform (share sheet on devices, a download in the browser).
///
/// Only the server decides what the file contains; the app never assembles a
/// partial copy from local caches.
class AccountDataExportService {
  AccountDataExportService({
    AccountDataExportFetch? fetch,
    AccountDataExportDeliver? deliver,
    DateTime Function()? clock,
  })  : _fetch = fetch ?? BackendApiService().fetchAccountDataExport,
        _deliver = deliver ?? _shareFile,
        _clock = clock ?? DateTime.now;

  final AccountDataExportFetch _fetch;
  final AccountDataExportDeliver _deliver;
  final DateTime Function() _clock;
  Future<AccountDataExportOutcome>? _running;

  static String fileNameFor(DateTime now) {
    final utc = now.toUtc();
    String two(int value) => value.toString().padLeft(2, '0');
    return 'art-kubus-data-export-${utc.year}-${two(utc.month)}-${two(utc.day)}.json';
  }

  /// One export at a time: a second tap joins the one in progress.
  Future<AccountDataExportOutcome> run() =>
      _running ??= _run().whenComplete(() {
        _running = null;
      });

  Future<AccountDataExportOutcome> _run() async {
    final List<int> bytes;
    try {
      bytes = await _fetch();
    } on BackendApiRequestException catch (error) {
      switch (error.statusCode) {
        case 401:
        case 403:
          return AccountDataExportOutcome.signInRequired;
        case 429:
          return AccountDataExportOutcome.tooManyRequests;
        default:
          return AccountDataExportOutcome.failed;
      }
    } catch (_) {
      return AccountDataExportOutcome.failed;
    }
    if (bytes.isEmpty) return AccountDataExportOutcome.failed;
    try {
      await _deliver(Uint8List.fromList(bytes), fileNameFor(_clock()));
      return AccountDataExportOutcome.saved;
    } catch (_) {
      return AccountDataExportOutcome.failed;
    }
  }

  static Future<void> _shareFile(Uint8List bytes, String fileName) async {
    await SharePlus.instance.share(ShareParams(
      files: [
        XFile.fromData(bytes, mimeType: 'application/json', name: fileName)
      ],
      fileNameOverrides: [fileName],
    ));
  }
}
