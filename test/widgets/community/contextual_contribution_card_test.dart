import 'package:art_kubus/models/account_verification.dart';
import 'package:art_kubus/models/user_persona.dart';
import 'package:art_kubus/widgets/community/contextual_contribution_card.dart';
import 'package:flutter_test/flutter_test.dart';

ContributionCardAction? resolve({
  bool signedIn = true,
  ArtistVerificationStatus artist = ArtistVerificationStatus.notApplied,
  InstitutionAccessStatus institution = InstitutionAccessStatus.none,
  bool hasWallet = false,
  UserPersona? persona,
  bool streetArt = false,
  bool exhibitions = false,
}) =>
    resolveContributionCardAction(
      signedIn: signedIn,
      artistStatus: artist,
      institutionAccess: institution,
      hasWallet: hasWallet,
      persona: persona,
      streetArtEnabled: streetArt,
      exhibitionsEnabled: exhibitions,
    );

void main() {
  group('resolveContributionCardAction', () {
    test('guests are invited to join before anything else is considered', () {
      expect(resolve(signedIn: false), ContributionCardAction.join);
    });

    test(
        'a verified artist is offered artwork creation with or without a wallet',
        () {
      for (final wallet in [false, true]) {
        expect(
          resolve(
            artist: ArtistVerificationStatus.approved,
            hasWallet: wallet,
            persona: UserPersona.lover,
          ),
          ContributionCardAction.artwork,
        );
      }
    });

    test('artist and institution persona alone grant no publishing authority',
        () {
      expect(resolve(persona: UserPersona.creator, hasWallet: true), isNull);
      expect(
        resolve(
            persona: UserPersona.institution,
            hasWallet: true,
            exhibitions: true),
        isNull,
      );
    });

    test('a pending application routes to its status, for either role', () {
      expect(
        resolve(artist: ArtistVerificationStatus.pending),
        ContributionCardAction.application,
      );
      expect(
        resolve(institution: InstitutionAccessStatus.requestPending),
        ContributionCardAction.application,
      );
    });

    test('rejected and revoked artists are offered nothing to publish', () {
      expect(resolve(artist: ArtistVerificationStatus.rejected), isNull);
      expect(resolve(artist: ArtistVerificationStatus.revoked), isNull);
    });

    test('an institution member gets exhibitions only when they are enabled',
        () {
      expect(
        resolve(institution: InstitutionAccessStatus.member),
        isNull,
      );
      expect(
        resolve(institution: InstitutionAccessStatus.member, exhibitions: true),
        ContributionCardAction.exhibition,
      );
    });

    test(
        'roles are additive: an artist who is also a member is offered artwork',
        () {
      expect(
        resolve(
          artist: ArtistVerificationStatus.approved,
          institution: InstitutionAccessStatus.member,
          exhibitions: true,
        ),
        ContributionCardAction.artwork,
      );
    });

    test('art lover documentation needs the street-art gate and a wallet', () {
      expect(
        resolve(persona: UserPersona.lover, streetArt: true),
        isNull,
        reason: 'documenting street art still needs a linked wallet',
      );
      expect(
        resolve(persona: UserPersona.lover, hasWallet: true),
        isNull,
        reason: 'the street-art feature gate is closed',
      );
      expect(
        resolve(persona: UserPersona.lover, hasWallet: true, streetArt: true),
        ContributionCardAction.document,
      );
    });
  });
}
