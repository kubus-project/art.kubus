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
      case 'node_unavailable':
      case 'processor_unavailable':
      case 'node_identity_mismatch':
        return l10n.spatialFailureNodeUnavailable;
      case 'upload_interrupted':
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

  /// The reassurance that belongs beside every failure: nothing was lost.
  static String? rawIntact(AppLocalizations l10n, {required bool rawPresent}) =>
      rawPresent ? l10n.spatialFailureRawIntact : null;
}
