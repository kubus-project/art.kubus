import 'dart:convert';
import 'dart:io';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/l10n/app_localizations_en.dart';
import 'package:art_kubus/l10n/app_localizations_sl.dart';
import 'package:art_kubus/providers/spatial_capture_provider.dart';
import 'package:art_kubus/services/ar_placement_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reads a `.arb` file, tolerating the byte-order mark the checked-in files
/// carry.
Map<String, dynamic> readArb(String path) =>
    jsonDecode(File(path).readAsStringSync().replaceFirst('﻿', ''))
        as Map<String, dynamic>;

/// Every capture guidance case, mapped exactly as the AR screen maps it.
///
/// Kept beside the screen's own switch so a new [SpatialCaptureGuidance] case
/// cannot ship without a string in both languages: the switch below is
/// exhaustive, so adding an enum value breaks compilation here too.
String guidanceString(AppLocalizations l10n, SpatialCaptureGuidance guidance) {
  switch (guidance) {
    case SpatialCaptureGuidance.idle:
      return l10n.spatialCaptureGuideIdle;
    case SpatialCaptureGuidance.trackingLost:
      return l10n.spatialCaptureGuideTrackingLost;
    case SpatialCaptureGuidance.limitReached:
      return l10n.spatialCaptureGuideFull;
    case SpatialCaptureGuidance.paused:
      return l10n.spatialCaptureGuidePaused;
    case SpatialCaptureGuidance.coverageLow:
      return l10n.spatialCaptureGuideStart;
    case SpatialCaptureGuidance.coverageFair:
      return l10n.spatialCaptureGuideOverlap;
    case SpatialCaptureGuidance.coverageGood:
      return l10n.spatialCaptureGuideDetails;
    case SpatialCaptureGuidance.coverageReady:
      return l10n.spatialCaptureGuideReady;
  }
}

String placementString(AppLocalizations l10n, ArPlacementState state) {
  switch (state) {
    case ArPlacementState.none:
      return l10n.arPlacementSelectArtwork;
    case ArPlacementState.selected:
    case ArPlacementState.searchingSurface:
      return l10n.arPlacementFindingSurface;
    case ArPlacementState.previewing:
      return l10n.arPlacementTapToPlace;
    case ArPlacementState.placed:
    case ArPlacementState.adjusting:
      return l10n.arPlacementAdjustHint;
    case ArPlacementState.confirmed:
    case ArPlacementState.error:
      return l10n.arPlacementTrackingLost;
  }
}

void main() {
  final en = AppLocalizationsEn();
  final sl = AppLocalizationsSl();

  group('capture guidance exists in EN and SL', () {
    for (final guidance in SpatialCaptureGuidance.values) {
      test('${guidance.name} resolves in both languages', () {
        final english = guidanceString(en, guidance);
        final slovene = guidanceString(sl, guidance);

        expect(english, isNotEmpty);
        expect(slovene, isNotEmpty);
        expect(
          slovene,
          isNot(english),
          reason: 'an untranslated Slovene string is an English string',
        );
        // The guidance surface bounds itself to three lines.
        expect(english.length, lessThan(140));
        expect(slovene.length, lessThan(160));
      });
    }
  });

  group('placement guidance exists in EN and SL', () {
    for (final state in ArPlacementState.values) {
      test('${state.name} resolves in both languages', () {
        expect(placementString(en, state), isNotEmpty);
        expect(placementString(sl, state), isNotEmpty);
      });
    }
  });

  group('every AR and spatial string added for capture is translated', () {
    // The strings the capture, placement and transfer surfaces reach for. A
    // missing Slovene entry here means a user sees English mid-flow.
    const keys = <String>[
      'spatialCaptureGuideIdle',
      'spatialCaptureGuidePaused',
      'spatialCaptureGuideTrackingLost',
      'spatialCaptureGuideFull',
      'spatialCaptureResume',
      'spatialCaptureStart',
      'spatialCaptureFinish',
      'spatialCaptureContributorOnly',
      'spatialCaptureChooseArtwork',
      'spatialCaptureNotReadyToast',
      'spatialCaptureNodeRequired',
      'spatialCaptureNodeOutdated',
      'spatialCaptureTransferFailed',
      'spatialCaptureRetryTransfer',
      'spatialTransferPreparing',
      'spatialTransferCommitting',
      'spatialTransferUploading',
      'spatialArchiveEmptyTitle',
      'spatialArchiveEmptyBody',
      'spatialArchiveRecord',
      'spatialRecoveryTitle',
      'spatialRecoveryBody',
      'spatialRecoveryResume',
      'spatialRecoveryDiscard',
      'spatialRecoveryKeep',
      'arPlacementScaleUp',
      'arPlacementScaleDown',
      'arPlacementReposition',
      'arPlacementConfirm',
      'arPlacementRepositionHint',
      'arPlacementAdjustHint',
      'arPlacementTrackingLost',
      'arPlacementPreviewFailed',
      'arCameraSwitching',
      'spatialCaptureDiscardAndRestart',
      'spatialCaptureGuideFullUnusable',
    ];

    late Map<String, dynamic> enArb;
    late Map<String, dynamic> slArb;

    setUpAll(() {
      enArb = readArb('lib/l10n/app_en.arb');
      slArb = readArb('lib/l10n/app_sl.arb');
    });

    for (final key in keys) {
      test('$key is present in both ARB files', () {
        expect(enArb.containsKey(key), isTrue, reason: '$key missing from EN');
        expect(slArb.containsKey(key), isTrue, reason: '$key missing from SL');
        expect((enArb[key] as String).trim(), isNotEmpty);
        expect((slArb[key] as String).trim(), isNotEmpty);
        expect(
          slArb[key],
          isNot(enArb[key]),
          reason: '$key looks untranslated',
        );
      });
    }

    test('the two ARB files stay in key parity', () {
      final enKeys = enArb.keys.where((k) => !k.startsWith('@')).toSet();
      final slKeys = slArb.keys.where((k) => !k.startsWith('@')).toSet();
      expect(
        enKeys.difference(slKeys),
        isEmpty,
        reason: 'keys present in EN but missing from SL',
      );
    });
  });

  group('transfer progress is localized with real numbers', () {
    test('the uploading line carries both counts in both languages', () {
      expect(en.spatialTransferUploading(3, 40), contains('3'));
      expect(en.spatialTransferUploading(3, 40), contains('40'));
      expect(sl.spatialTransferUploading(3, 40), contains('3'));
      expect(sl.spatialTransferUploading(3, 40), contains('40'));
    });

    test('recovery states the amount of work at stake', () {
      expect(en.spatialRecoveryBody(24), contains('24'));
      expect(sl.spatialRecoveryBody(24), contains('24'));
    });
  });
}
