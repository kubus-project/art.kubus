import 'package:flutter/foundation.dart';

import '../../services/spatial_library_store.dart';

/// Everything a spatial record can be asked to do.
///
/// Replaces the old flat six-value enum, which could only describe a capture
/// as something to process, publish, share or delete — and so produced a
/// screen where every possibility was an equally large button.
enum SpatialLibraryAction {
  /// Reopen the raw source and add more samples to the same record.
  continueCapture,

  /// Branch a new private draft from a published archive.
  newRevision,

  /// Change which artwork/marker the capture is filed under.
  editAssociation,

  /// Rename the capture or edit its private note.
  editMetadata,

  /// Choose a processor and start reconstruction.
  process,

  /// Withdraw an open network compute request.
  cancelProcessingRequest,

  /// Try the same processing again after a failure.
  retryProcessing,

  /// Try a different processor after a failure.
  changeProcessor,

  /// Open the locally processed scene.
  viewResult,

  /// Publish the processed result to the public archive.
  publish,

  /// Open the published archive.
  viewPublicArchive,

  /// Share the published archive.
  share,

  /// Delete the raw capture, keeping the processed result.
  deleteRaw,

  /// Delete the processed result, keeping the raw capture.
  deleteProcessed,

  /// Remove the record from this device.
  deleteLocalRecord,
}

/// The actions available for one record, already sorted by prominence.
///
/// A capture is usually waiting on exactly one thing. Surfacing that as the
/// single primary action — and demoting storage and cleanup behind an overflow
/// — is the difference between a control panel and a task.
@immutable
class SpatialRecordActions {
  const SpatialRecordActions({
    required this.primary,
    required this.secondary,
    required this.overflow,
  });

  /// The one obvious next step, or null when the record is mid-flight and the
  /// honest answer is "wait".
  final SpatialLibraryAction? primary;

  /// Supporting actions shown in their own sections.
  final List<SpatialLibraryAction> secondary;

  /// Destructive and storage actions, behind the overflow menu.
  final List<SpatialLibraryAction> overflow;

  /// Every action, regardless of prominence.
  Set<SpatialLibraryAction> get all => <SpatialLibraryAction>{
        if (primary != null) primary!,
        ...secondary,
        ...overflow,
      };

  bool contains(SpatialLibraryAction action) => all.contains(action);

  /// Resolves the action set from the record's own state.
  ///
  /// [processorConfigured] reflects whether the device has any processor to
  /// offer at all — an unpaired Node with the Node feature off. It never
  /// gates the *network* request, which is deliberately available even when
  /// no provider is reachable at this instant.
  static SpatialRecordActions of(
    SpatialLibraryRecord record, {
    bool processorConfigured = true,
  }) {
    final request = record.networkRequest;
    final requestActive = request?.isActive == true;
    final busy = record.isBusy;
    final published = record.isPublished;

    final secondary = <SpatialLibraryAction>[];
    final overflow = <SpatialLibraryAction>[];
    SpatialLibraryAction? primary;

    final canReopenSource =
        record.canContinueCapture && !busy && !requestActive;

    // --- Capture -------------------------------------------------------
    if (canReopenSource && !published) {
      secondary.add(SpatialLibraryAction.continueCapture);
    }
    if (published && record.rawPresent && !busy && !requestActive) {
      secondary.add(SpatialLibraryAction.newRevision);
    }
    if (!published && !busy) {
      secondary.add(SpatialLibraryAction.editAssociation);
    }
    secondary.add(SpatialLibraryAction.editMetadata);

    // --- Processing ----------------------------------------------------
    final needsProcessing =
        record.rawPresent && !busy && !record.hasCurrentResult;
    if (requestActive) {
      if (request!.isCancellable) {
        secondary.add(SpatialLibraryAction.cancelProcessingRequest);
      }
    } else if (record.processingState ==
        SpatialLibraryProcessingState.failedRetryable) {
      if (record.rawPresent && processorConfigured) {
        primary = SpatialLibraryAction.retryProcessing;
        secondary.add(SpatialLibraryAction.changeProcessor);
      }
    } else if (needsProcessing && processorConfigured) {
      primary = SpatialLibraryAction.process;
    }

    if (record.hasLocalResult) {
      secondary.add(SpatialLibraryAction.viewResult);
    }

    // --- Archive -------------------------------------------------------
    if (record.hasCurrentResult && !published && !busy && primary == null) {
      primary = SpatialLibraryAction.publish;
    } else if (record.hasCurrentResult && !published && !busy) {
      secondary.add(SpatialLibraryAction.publish);
    }
    if (published) {
      secondary.add(SpatialLibraryAction.viewPublicArchive);
      secondary.add(SpatialLibraryAction.share);
      // Once published, the useful next step is a new revision rather than
      // anything that would touch the immutable archive.
      if (primary == null && record.rawPresent && !busy && !requestActive) {
        primary = SpatialLibraryAction.newRevision;
        secondary.remove(SpatialLibraryAction.newRevision);
      }
    }

    // --- Storage and removal -------------------------------------------
    if (record.rawPresent && record.hasLocalResult && !busy && !requestActive) {
      // Raw is only ever offered for deletion once something else can stand
      // in for it. Deleting the only copy of a capture is not a storage tidy.
      overflow.add(SpatialLibraryAction.deleteRaw);
    }
    if (record.hasLocalResult && !busy) {
      overflow.add(SpatialLibraryAction.deleteProcessed);
    }
    if (!busy) {
      overflow.add(SpatialLibraryAction.deleteLocalRecord);
    }

    // The primary never repeats itself lower down the screen.
    if (primary != null) secondary.remove(primary);

    return SpatialRecordActions(
      primary: primary,
      secondary: List<SpatialLibraryAction>.unmodifiable(secondary),
      overflow: List<SpatialLibraryAction>.unmodifiable(overflow),
    );
  }
}
