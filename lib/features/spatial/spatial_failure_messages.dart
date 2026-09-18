import '../../l10n/app_localizations.dart';

/// Turns a stored failure code into plain language.
///
/// The codes are engineering facts written by the pipeline. The user needs to
/// know what went wrong, that their capture is safe, and what to do — not
/// `processor_unavailable`.
class SpatialFailureMessages {
  const SpatialFailureMessages._();

  /// A one-line reason for [code], or null when there is nothing to explain.
  static String? reason(AppLocalizations l10n, String? code) {
    final normalized = (code ?? '').trim();
    if (normalized.isEmpty) return null;
    switch (normalized) {
      // The capture on this device cannot make a complete package. Neither
      // the node nor the processor can do anything about it, and offering a
      // retry of either sends the user round a loop that cannot succeed.
      case 'source_incomplete':
        return l10n.spatialFailureSourceIncomplete;
      case 'source_frames_unrepairable':
        return l10n.spatialFailureSourceUnrepairable;
      // The node holds an incomplete copy. The source is still here, so the
      // remedy is finishing the upload — not reprocessing.
      case 'node_capture_incomplete':
      case 'capture_package_incomplete':
      case 'capture_frame_file_missing':
      case 'capture_frames_missing':
        return l10n.spatialFailureNodeCaptureIncomplete;
      case 'node_validation_failed':
      case 'capture_frames_invalid':
        return l10n.spatialFailureNodeValidation;
      case 'node_unavailable':
      case 'processor_unavailable':
        return l10n.spatialFailureNodeUnavailable;
      case 'node_identity_mismatch':
        return l10n.spatialFailureNodeUnavailable;
      case 'upload_interrupted':
      case 'upload_failed':
        return l10n.spatialFailureUploadInterrupted;
      case 'provider_declined':
        return l10n.spatialFailureProcessorDeclined;
      case 'processing_failed':
      case 'processing_interrupted':
      case 'network_compute_failed':
        return l10n.spatialFailureProcessingFailed;
      case 'result_download_interrupted':
      case 'spatial_result_missing':
        return l10n.spatialFailureResultDownload;
      case 'result_validation_failed':
        return l10n.spatialFailureResultVerification;
      case 'network_request_expired':
        return l10n.spatialFailureRequestExpired;
      case 'publication_interrupted':
      case 'publication_failed':
        return l10n.spatialFailureGeneric;
      default:
        // Result verification codes come from the importer and all describe
        // the same user-visible problem: what came back could not be trusted.
        if (normalized.startsWith('result_') ||
            normalized.contains('manifest') ||
            normalized.contains('integrity') ||
            normalized.contains('cid')) {
          return l10n.spatialFailureResultVerification;
        }
        return l10n.spatialFailureGeneric;
    }
  }

  /// Whether [code] means the capture on the node is incomplete.
  ///
  /// The one failure class whose remedy is finishing the transfer rather than
  /// retrying the processor, so the UI can offer the action that can actually
  /// work.
  static bool isRepairableUpload(String? code) => const <String>{
        'node_capture_incomplete',
        'capture_package_incomplete',
        'capture_frame_file_missing',
        'capture_frames_missing',
        'upload_interrupted',
        'upload_failed',
      }.contains((code ?? '').trim());

  /// The reassurance that belongs beside every failure: nothing was lost.
  static String? rawIntact(AppLocalizations l10n, {required bool rawPresent}) =>
      rawPresent ? l10n.spatialFailureRawIntact : null;
}
