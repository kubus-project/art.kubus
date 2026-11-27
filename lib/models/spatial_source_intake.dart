class SpatialSourceFile {
  SpatialSourceFile.fromJson(Map<String, dynamic> value)
      : id = value['id'] as String,
        name = value['fileName'] as String,
        size = value['sizeBytes'] as int,
        received = value['receivedBytes'] as int,
        sha256 = value['sha256'] as String;

  final String id;
  final String name;
  final int size;
  final int received;
  final String sha256;

  bool get ready => received == size;
}

class SpatialSourceIntake {
  SpatialSourceIntake.fromJson(Map<String, dynamic> value)
      : maxBytes = value['maxSourceBytes'] as int,
        chunkSize = value['chunkSizeBytes'] as int,
        maxFiles = value['maxFiles'] as int,
        workspaceId = (value['workspace'] as Map?)?['id'] as String?,
        revision = (value['workspace'] as Map?)?['revision'] as int?,
        files = [
          for (final file
              in ((value['workspace'] as Map?)?['files'] as List? ?? const []))
            SpatialSourceFile.fromJson(file as Map<String, dynamic>),
        ];

  final int maxBytes;
  final int chunkSize;
  final int maxFiles;
  final String? workspaceId;
  final int? revision;
  final List<SpatialSourceFile> files;
}

/// How one source file fared in the last reconstruction attempt.
class SpatialSourceFeedback {
  SpatialSourceFeedback.fromJson(Map<String, dynamic> value)
      : fileId = value['fileId'] as String,
        usable = value['usable'] == true,
        usableViews = value['usableViews'] as int?,
        reason = value['reason'] as String?;

  final String fileId;
  final bool usable;
  final int? usableViews;
  final String? reason;

  /// The requester refused to send this file because face masking flagged it.
  bool get faceReview => reason == SpatialReconstruction.faceReviewReason;
}

/// The artist's latest reconstruction attempt for an artwork.
class SpatialReconstruction {
  SpatialReconstruction.fromJson(Map<String, dynamic> value)
      : id = value['id'] as String,
        attempt = value['attempt'] as int,
        state = value['state'] as String,
        stage = value['stage'] as String?,
        cancelRequested = value['cancelRequested'] == true,
        problemCode = value['problemCode'] as String?,
        candidateDraftId = value['candidateDraftId'] as String?,
        usableViews = (value['feedback'] as Map?)?['usableViews'] as int?,
        requiredViews = (value['feedback'] as Map?)?['requiredViews'] as int?,
        inputs = {
          for (final item
              in ((value['feedback'] as Map?)?['inputs'] as List? ?? const []))
            (item as Map<String, dynamic>)['fileId'] as String:
                SpatialSourceFeedback.fromJson(item),
        };

  /// Problem codes for a capture that may show a person's face. The artist
  /// removes or replaces the marked files; the platform never retries them.
  static const faceReviewProblemCodes = {
    'face_review_required',
    'provider_face_review_required',
  };

  /// Per-file feedback reason for a file flagged by face masking.
  static const faceReviewReason = 'face_review';

  static const activeStates = {
    'queued',
    'preparing',
    'waiting_for_node',
    'processing',
    'importing',
  };

  final String id;
  final int attempt;
  final String state;
  final String? stage;
  final bool cancelRequested;
  final String? problemCode;
  final String? candidateDraftId;
  final int? usableViews;
  final int? requiredViews;
  final Map<String, SpatialSourceFeedback> inputs;

  bool get active => activeStates.contains(state);

  bool get faceReviewRequired => faceReviewProblemCodes.contains(problemCode);
}

class SpatialReconstructionStatus {
  SpatialReconstructionStatus.fromJson(Map<String, dynamic> value)
      : remoteProcessingEnabled = value['remoteProcessingEnabled'] == true,
        reconstruction = value['reconstruction'] is Map<String, dynamic>
            ? SpatialReconstruction.fromJson(
                value['reconstruction'] as Map<String, dynamic>)
            : null;

  final bool remoteProcessingEnabled;
  final SpatialReconstruction? reconstruction;
}
