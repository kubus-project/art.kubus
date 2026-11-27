import 'dart:ui' show Locale;
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/spatial_source_intake.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _attempt(String? problem, [String? reason]) => {
      'id': 'a',
      'attempt': 1,
      'state': 'needs_more_views',
      'problemCode': problem,
      'feedback': {
        'inputs': [
          {'fileId': 'f1', 'usable': false, 'reason': reason},
        ],
      },
    };

void main() {
  test('parses the face review problem codes and per-file reason', () {
    for (final code in [
      'face_review_required',
      'provider_face_review_required'
    ]) {
      final attempt =
          SpatialReconstruction.fromJson(_attempt(code, 'face_review'));
      expect(attempt.faceReviewRequired, isTrue);
      expect(attempt.inputs['f1']!.faceReview, isTrue);
    }
  });

  test('other codes and reasons are not face review', () {
    final attempt = SpatialReconstruction.fromJson(
        _attempt('sfm_failed', 'frames_too_blurry'));
    expect(attempt.faceReviewRequired, isFalse);
    expect(attempt.inputs['f1']!.faceReview, isFalse);
    final none = SpatialReconstruction.fromJson(_attempt(null));
    expect(none.faceReviewRequired, isFalse);
    expect(none.inputs['f1']!.faceReview, isFalse);
  });

  test('face review strings exist in English and Slovenian', () async {
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    final sl = await AppLocalizations.delegate.load(const Locale('sl'));
    expect(en.spatialReconstructionFaceReview, contains("person's face"));
    expect(en.spatialSourceFaceReview, 'May show a face');
    expect(en.spatialSourceFaceReviewSemantics('a.jpg'), startsWith('a.jpg:'));
    expect(sl.spatialReconstructionFaceReview, contains('obraz'));
    expect(sl.spatialReconstructionFaceReview,
        isNot(en.spatialReconstructionFaceReview));
    expect(sl.spatialSourceFaceReview, isNot(en.spatialSourceFaceReview));
    expect(sl.spatialSourceFaceReviewSemantics('a.jpg'), startsWith('a.jpg:'));
  });
}
