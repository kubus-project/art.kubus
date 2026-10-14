import 'package:flutter_test/flutter_test.dart';
import 'package:art_kubus/models/dao.dart';
import 'package:art_kubus/models/user_persona.dart';
import 'package:art_kubus/widgets/community/contextual_contribution_card.dart';

DAOReview _review({
  required String wallet,
  required String role,
  required String status,
}) =>
    DAOReview(
      id: 'review-$role',
      walletAddress: wallet,
      portfolioUrl: '',
      medium: '',
      statement: '',
      status: status,
      createdAt: DateTime.utc(2026),
      metadata: {'role': role},
    );

void main() {
  group('resolveContributionCardAction', () {
    test('guests are invited to join before wallet or persona is considered',
        () {
      expect(
        resolveContributionCardAction(
          signedIn: false,
          walletAddress: '',
          persona: null,
          review: null,
          streetArtEnabled: false,
          exhibitionsEnabled: false,
        ),
        ContributionCardAction.join,
      );
    });

    test('a signed-in art lover needs a wallet before documenting art', () {
      expect(
        resolveContributionCardAction(
          signedIn: true,
          walletAddress: '',
          persona: UserPersona.lover,
          review: null,
          streetArtEnabled: true,
          exhibitionsEnabled: true,
        ),
        isNull,
      );
    });

    test('art lover documentation follows the street-art feature gate', () {
      expect(
        resolveContributionCardAction(
          signedIn: true,
          walletAddress: '0xabc',
          persona: UserPersona.lover,
          review: null,
          streetArtEnabled: false,
          exhibitionsEnabled: true,
        ),
        isNull,
      );
      expect(
        resolveContributionCardAction(
          signedIn: true,
          walletAddress: '0xabc',
          persona: UserPersona.lover,
          review: null,
          streetArtEnabled: true,
          exhibitionsEnabled: false,
        ),
        ContributionCardAction.document,
      );
    });

    test('artist persona alone does not grant publishing authority', () {
      expect(
        resolveContributionCardAction(
          signedIn: true,
          walletAddress: '0xartist',
          persona: UserPersona.creator,
          review: null,
          streetArtEnabled: false,
          exhibitionsEnabled: true,
        ),
        isNull,
      );
    });

    test('an approved review for a different wallet grants no authority', () {
      expect(
        resolveContributionCardAction(
          signedIn: true,
          walletAddress: '0xcurrent',
          persona: UserPersona.creator,
          review: _review(
            wallet: '0xother',
            role: 'artist',
            status: 'approved',
          ),
          streetArtEnabled: false,
          exhibitionsEnabled: true,
        ),
        isNull,
      );
    });

    test('pending DAO review routes to application status', () {
      expect(
        resolveContributionCardAction(
          signedIn: true,
          walletAddress: '0xartist',
          persona: UserPersona.creator,
          review: _review(
            wallet: '0xartist',
            role: 'artist',
            status: 'pending',
          ),
          streetArtEnabled: false,
          exhibitionsEnabled: false,
        ),
        ContributionCardAction.application,
      );
    });

    test('approved artist review enables artwork creation', () {
      expect(
        resolveContributionCardAction(
          signedIn: true,
          walletAddress: '0xartist',
          persona: UserPersona.lover,
          review: _review(
            wallet: '0xartist',
            role: 'artist',
            status: 'approved',
          ),
          streetArtEnabled: false,
          exhibitionsEnabled: false,
        ),
        ContributionCardAction.artwork,
      );
    });

    test('approved institution review enables exhibitions only when enabled',
        () {
      final review = _review(
        wallet: '0xinstitution',
        role: 'institution',
        status: 'approved',
      );
      expect(
        resolveContributionCardAction(
          signedIn: true,
          walletAddress: '0xinstitution',
          persona: UserPersona.institution,
          review: review,
          streetArtEnabled: false,
          exhibitionsEnabled: false,
        ),
        isNull,
      );
      expect(
        resolveContributionCardAction(
          signedIn: true,
          walletAddress: '0xinstitution',
          persona: UserPersona.institution,
          review: review,
          streetArtEnabled: false,
          exhibitionsEnabled: true,
        ),
        ContributionCardAction.exhibition,
      );
    });
  });
}
