import 'package:art_kubus/models/dao.dart';
import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/providers/dao_provider.dart';
import 'package:art_kubus/providers/institution_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _wallet = 'WalletInstitution1111111111111111111111111';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('wallet-derived institution verification', () {
    test('profile isInstitution flag alone does not verify the derived entry',
        () {
      final provider = _bind(profile: _profile(isInstitution: true));

      final derived = provider.getInstitutionById(_wallet);
      expect(derived, isNotNull);
      expect(derived!.isVerified, isFalse);
    });

    test('DAO-approved institution review verifies the derived entry', () {
      final provider = _bind(
        profile: _profile(),
        review: _institutionReview(status: 'approved'),
      );

      expect(provider.getInstitutionById(_wallet)?.isVerified, isTrue);
    });

    test('pending institution review does not verify the derived entry', () {
      final provider = _bind(
        profile: _profile(isInstitution: true),
        review: _institutionReview(status: 'pending'),
      );

      expect(provider.getInstitutionById(_wallet)?.isVerified, isFalse);
    });
  });
}

InstitutionProvider _bind({
  required UserProfile profile,
  DAOReview? review,
}) {
  final profiles = ProfileProvider()..setCurrentUser(profile);
  final provider = InstitutionProvider()
    ..bindProfileProvider(profiles)
    ..bindDaoProvider(_ReviewDao(review: review));
  return provider;
}

UserProfile _profile({bool isInstitution = false}) {
  return UserProfile(
    id: 'profile-$_wallet',
    walletAddress: _wallet,
    username: 'wallet_gallery',
    displayName: 'Wallet Gallery',
    bio: 'Gallery bio',
    avatar: '',
    isInstitution: isInstitution,
    createdAt: DateTime.utc(2026, 7, 1),
    updatedAt: DateTime.utc(2026, 7, 1),
  );
}

DAOReview _institutionReview({required String status}) {
  return DAOReview(
    id: 'review-institution',
    walletAddress: _wallet,
    portfolioUrl: 'https://example.org/portfolio',
    medium: 'Gallery',
    statement: 'Institution application',
    status: status,
    createdAt: DateTime.utc(2026, 9, 1),
    metadata: const <String, dynamic>{'role': 'institution'},
  );
}

class _ReviewDao extends DAOProvider {
  _ReviewDao({this.review});

  final DAOReview? review;

  @override
  DAOReview? findReviewForWallet(String walletAddress) {
    final target = review;
    if (target == null) return null;
    return walletAddress.trim().toLowerCase() ==
            target.walletAddress.trim().toLowerCase()
        ? target
        : null;
  }
}
