import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:share_plus/share_plus.dart';

import 'backend_api_service.dart';

enum AccountDataExportOutcome { saved, signInRequired, tooManyRequests, failed }

typedef AccountDataExportFetch = Future<List<int>> Function();
typedef AccountDataExportDeliver = Future<void> Function(
    Uint8List bytes, String fileName);

/// Delivery that also receives the on-screen rectangle of the control that
/// started the export. iPadOS presents the share sheet as a popover and refuses
/// to open it without an anchor.
typedef AccountDataExportAnchoredDeliver = Future<void> Function(
    Uint8List bytes, String fileName, Rect? shareOrigin);

/// Downloads the signed-in account's own data as one JSON file and hands it to
/// the platform (share sheet on devices, a download in the browser).
///
/// Only the server decides what the file contains; the app never assembles a
/// partial copy from local caches.
class AccountDataExportService {
  AccountDataExportService({
    AccountDataExportFetch? fetch,
    AccountDataExportDeliver? deliver,
    AccountDataExportAnchoredDeliver? anchoredDeliver,
    DateTime Function()? clock,
  })  : _fetch = fetch ?? BackendApiService().fetchAccountDataExport,
        _deliver = anchoredDeliver ??
            (deliver == null
                ? _shareFile
                : (bytes, fileName, _) => deliver(bytes, fileName)),
        _clock = clock ?? DateTime.now;

  final AccountDataExportFetch _fetch;
  final AccountDataExportAnchoredDeliver _deliver;
  final DateTime Function() _clock;
  Future<AccountDataExportOutcome>? _running;

  static String fileNameFor(DateTime now) {
    final utc = now.toUtc();
    String two(int value) => value.toString().padLeft(2, '0');
    return 'art-kubus-data-export-${utc.year}-${two(utc.month)}-${two(utc.day)}.json';
  }

  /// One export at a time: a second tap joins the one in progress.
  ///
  /// [shareOrigin] is the on-screen rectangle of the control that started the
  /// export; it anchors the share popover on iPad.
  Future<AccountDataExportOutcome> run({Rect? shareOrigin}) =>
      _running ??= _run(shareOrigin).whenComplete(() {
        _running = null;
      });

  Future<AccountDataExportOutcome> _run(Rect? shareOrigin) async {
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
      await _deliver(
          Uint8List.fromList(bytes), fileNameFor(_clock()), shareOrigin);
      return AccountDataExportOutcome.saved;
    } catch (_) {
      return AccountDataExportOutcome.failed;
    }
  }

  static Future<void> _shareFile(
      Uint8List bytes, String fileName, Rect? shareOrigin) async {
    await SharePlus.instance.share(ShareParams(
      files: [
        XFile.fromData(bytes, mimeType: 'application/json', name: fileName)
      ],
      fileNameOverrides: [fileName],
      sharePositionOrigin: shareOrigin,
    ));
  }
}
