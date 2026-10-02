import 'package:art_kubus/features/spatial/spatial_transfer_presentation.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/services/node/kubus_node_transport.dart';
import 'package:art_kubus/services/spatial_node_upload.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppLocalizations en;
  late AppLocalizations sl;

  setUpAll(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
    sl = await AppLocalizations.delegate.load(const Locale('sl'));
  });

  SpatialTransferPresentation? read(
    SpatialTransferProgress progress, {
    AppLocalizations? l10n,
  }) =>
      SpatialTransferPresentation.forProgress(l10n ?? en, progress);

  group('what the user is shown', () {
    test('nothing, when nothing is being transferred', () {
      expect(read(const SpatialTransferProgress()), isNull);
      expect(
        read(const SpatialTransferProgress(
          phase: SpatialTransferPhase.complete,
        )),
        isNull,
      );
    });

    test('at the very start: 0 percent, not a blank bar', () {
      final view = read(const SpatialTransferProgress(
        phase: SpatialTransferPhase.uploading,
        totalFiles: 126,
        totalBytes: 489 * 1000 * 1000,
      ))!;

      expect(view.percentLabel, '0%');
      expect(view.fraction, 0.0);
      expect(view.indeterminate, isFalse);
      expect(view.filesLabel, '0 / 126 files');
    });

    test('mid-transfer: every measured fact, and only measured facts', () {
      final view = read(SpatialTransferProgress(
        phase: SpatialTransferPhase.uploading,
        uploadedFiles: 84,
        totalFiles: 126,
        confirmedBytes: 300 * 1000 * 1000,
        inFlightBytes: 28 * 1000 * 1000,
        totalBytes: 489 * 1000 * 1000,
        bytesPerSecond: 8.6 * 1000 * 1000,
        eta: const Duration(seconds: 19),
        route: KubusNodeTransportKind.localDirect,
      ))!;

      expect(view.percentLabel, '67%');
      expect(view.bytesLabel, isNotNull);
      expect(view.throughputLabel, isNotNull);
      expect(view.etaLabel, 'About 19 sec remaining');
      expect(view.filesLabel, '84 / 126 files');
      expect(view.routeLabel, 'Local network');
      expect(view.indeterminate, isFalse);
    });

    test('bytes in flight count towards the meter but not towards delivery',
        () {
      const progress = SpatialTransferProgress(
        phase: SpatialTransferPhase.uploading,
        uploadedFiles: 1,
        totalFiles: 2,
        confirmedBytes: 50,
        inFlightBytes: 25,
        totalBytes: 100,
      );

      // The bar moves through a large file...
      expect(read(progress)!.percentLabel, '75%');
      // ...while the durable count still reflects only what the node has.
      expect(progress.confirmedBytes, 50);
      expect(progress.uploadedFiles, 1);
    });

    test('at the end: 100 percent', () {
      final view = read(const SpatialTransferProgress(
        phase: SpatialTransferPhase.uploading,
        uploadedFiles: 126,
        totalFiles: 126,
        confirmedBytes: 489 * 1000 * 1000,
        totalBytes: 489 * 1000 * 1000,
      ))!;

      expect(view.percentLabel, '100%');
      expect(view.fraction, 1.0);
    });
  });

  group('nothing is claimed without evidence', () {
    test('no speed and no countdown before either has been measured', () {
      final view = read(const SpatialTransferProgress(
        phase: SpatialTransferPhase.uploading,
        totalFiles: 126,
        confirmedBytes: 1000,
        totalBytes: 489 * 1000 * 1000,
      ))!;

      expect(view.throughputLabel, isNull);
      expect(view.etaLabel, isNull);
      // The percentage is still real: bytes delivered over bytes known.
      expect(view.percentLabel, '0%');
    });

    test('a stalled transfer says so instead of counting down', () {
      final view = read(SpatialTransferProgress(
        phase: SpatialTransferPhase.uploading,
        uploadedFiles: 40,
        totalFiles: 126,
        confirmedBytes: 100 * 1000 * 1000,
        totalBytes: 489 * 1000 * 1000,
        bytesPerSecond: 8.6 * 1000 * 1000,
        eta: const Duration(seconds: 45),
        stalled: true,
      ))!;

      expect(view.etaLabel, 'Waiting for your node…');
      expect(view.throughputLabel, isNull);
      // Progress already made is still shown: the user has not lost it.
      expect(view.percentLabel, '20%');
    });

    test('an unknown total leaves the bar indeterminate rather than at zero',
        () {
      final view = read(const SpatialTransferProgress(
        phase: SpatialTransferPhase.uploading,
        totalFiles: 3,
      ))!;

      expect(view.fraction, isNull);
      expect(view.percentLabel, isNull);
      expect(view.indeterminate, isTrue);
    });

    test('preparing and validating are honest indeterminate phases', () {
      for (final phase in <SpatialTransferPhase>[
        SpatialTransferPhase.preparing,
        SpatialTransferPhase.validating,
      ]) {
        final view = read(SpatialTransferProgress(phase: phase))!;
        expect(view.indeterminate, isTrue, reason: '$phase');
        expect(view.percentLabel, isNull, reason: '$phase');
        expect(view.phaseLabel, isNotEmpty, reason: '$phase');
      }
    });

    test('repairing a gap still shows measured progress', () {
      final view = read(const SpatialTransferProgress(
        phase: SpatialTransferPhase.repairing,
        uploadedFiles: 124,
        totalFiles: 126,
        confirmedBytes: 480 * 1000 * 1000,
        totalBytes: 489 * 1000 * 1000,
      ))!;

      expect(view.indeterminate, isFalse);
      expect(view.percentLabel, '98%');
    });
  });

  group('accessibility and localization', () {
    test('progress is available as a sentence, not only as a bar', () {
      final view = read(SpatialTransferProgress(
        phase: SpatialTransferPhase.uploading,
        uploadedFiles: 84,
        totalFiles: 126,
        confirmedBytes: 328 * 1000 * 1000,
        totalBytes: 489 * 1000 * 1000,
        bytesPerSecond: 8.6 * 1000 * 1000,
        eta: const Duration(seconds: 19),
      ))!;

      expect(view.semanticsLabel, contains('67%'));
      expect(view.semanticsLabel, contains('19'));
      expect(view.semanticsLabel, isNot(contains(',,')));
    });

    test('every visible string is localized', () {
      final progress = SpatialTransferProgress(
        phase: SpatialTransferPhase.uploading,
        uploadedFiles: 84,
        totalFiles: 126,
        confirmedBytes: 328 * 1000 * 1000,
        totalBytes: 489 * 1000 * 1000,
        eta: const Duration(minutes: 3),
        route: KubusNodeTransportKind.webRtcRelay,
      );

      final english = read(progress)!;
      final slovene = read(progress, l10n: sl)!;

      expect(slovene.routeLabel, isNot(english.routeLabel));
      expect(slovene.etaLabel, isNot(english.etaLabel));
      expect(slovene.phaseLabel, isNotEmpty);
      expect(slovene.filesLabel, isNotNull);
    });
  });
}
