import 'package:art_kubus/models/profile_identity_data.dart';
import 'package:art_kubus/models/user.dart';
import 'package:art_kubus/services/user_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

User _user(
  String id, {
  bool isArtist = false,
  bool isInstitution = false,
  bool isVerified = false,
  bool? isArtistSpecified,
  bool? isInstitutionSpecified,
  bool? isVerifiedSpecified,
  String? avatar,
}) {
  return User(
    id: id,
    name: 'Name $id',
    username: id,
    bio: '',
    followersCount: 1,
    followingCount: 1,
    postsCount: 1,
    isFollowing: false,
    isVerified: isVerified,
    isArtist: isArtist,
    isInstitution: isInstitution,
    isArtistSpecified: isArtistSpecified ?? false,
    isInstitutionSpecified: isInstitutionSpecified ?? false,
    isVerifiedSpecified: isVerifiedSpecified ?? false,
    joinedDate: 'Joined recently',
    profileImageUrl: avatar,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('User role statements', () {
    test('a role built without a stated flag is unstated', () {
      final user = _user('u_unstated', isArtist: false);
      expect(user.isArtistSpecified, isFalse);
      expect(user.roleStatements.isArtistSpecified, isFalse);
      expect(user.roleStatements.isArtist, isFalse);
    });

    test('a true role counts as stated even without an explicit flag', () {
      final user = _user('u_true', isArtist: true);
      expect(user.roleStatements.isArtistSpecified, isTrue);
      expect(user.roleStatements.isArtist, isTrue);
    });

    test('copyWith marks a role stated when it is passed', () {
      final base = _user('u_copy');
      expect(base.copyWith(isArtist: false).isArtistSpecified, isTrue);
      expect(base.copyWith(joinedDate: 'x').isArtistSpecified, isFalse);
    });
  });

  group('payload role detection', () {
    test('absent role keys are unstated', () {
      final roles = ProfileIdentityRoles.fromProfileMap(
        <String, dynamic>{'id': 'u1', 'displayName': 'A'},
      );
      expect(roles.isArtistSpecified, isFalse);
      expect(roles.isInstitutionSpecified, isFalse);
      expect(roles.isVerifiedSpecified, isFalse);
    });

    test('explicit false is stated', () {
      final roles = ProfileIdentityRoles.fromProfileMap(
        <String, dynamic>{'isArtist': false, 'is_verified': 0},
      );
      expect(roles.isArtistSpecified, isTrue);
      expect(roles.isArtist, isFalse);
      expect(roles.isVerifiedSpecified, isTrue);
      expect(roles.isVerified, isFalse);
    });

    test('every key variant counts, including the roles map', () {
      expect(
        ProfileIdentityRoles.fromProfileMap(
          <String, dynamic>{'is_artist': true},
        ).isArtist,
        isTrue,
      );
      final nested = ProfileIdentityRoles.fromProfileMap(
        <String, dynamic>{
          'roles': <String, dynamic>{'artist': true, 'institution': false},
        },
      );
      expect(nested.isArtist, isTrue);
      expect(nested.isArtistSpecified, isTrue);
      expect(nested.isInstitutionSpecified, isTrue);
      expect(nested.isInstitution, isFalse);
    });
  });

  group('UserService cache role merge', () {
    test('a partial payload keeps a cached artist', () {
      UserService.setUsersInCache([_user('merge_partial', isArtist: true)]);
      UserService.setUsersInCache([_user('merge_partial', avatar: 'a.png')]);
      final cached = UserService.getCachedUser('merge_partial');
      expect(cached?.isArtist, isTrue);
      expect(cached?.isArtistSpecified, isTrue);
    });

    test('a partial payload keeps a cached verified and institution role', () {
      UserService.setUsersInCache([
        _user('merge_roles', isVerified: true, isInstitution: true),
      ]);
      UserService.setUsersInCache([_user('merge_roles')]);
      final cached = UserService.getCachedUser('merge_roles');
      expect(cached?.isVerified, isTrue);
      expect(cached?.isInstitution, isTrue);
    });

    test('an explicit false revokes a cached artist', () {
      UserService.setUsersInCache([_user('merge_revoke', isArtist: true)]);
      UserService.setUsersInCache([
        _user('merge_revoke', isArtist: false, isArtistSpecified: true),
      ]);
      expect(UserService.getCachedUser('merge_revoke')?.isArtist, isFalse);
    });

    test('an explicit false revokes on the authoritative path too', () {
      UserService.setUsersInCache([_user('merge_auth', isArtist: true)]);
      UserService.setUsersInCacheAuthoritative([
        _user('merge_auth', isArtist: false, isArtistSpecified: true),
      ]);
      expect(UserService.getCachedUser('merge_auth')?.isArtist, isFalse);
    });

    test('a stale partial arriving after a full record keeps the roles', () {
      UserService.setUsersInCache([
        _user('merge_order', isArtist: true, isArtistSpecified: true),
      ]);
      // Stale, unstated partial (for example a conversation DTO).
      UserService.setUsersInCache([_user('merge_order', isArtist: false)]);
      expect(UserService.getCachedUser('merge_order')?.isArtist, isTrue);
    });

    test('a synthetic fallback record does not revoke a cached role', () {
      UserService.setUsersInCache([_user('merge_fallback', isArtist: true)]);
      UserService.setUsersInCache([
        _user('merge_fallback', isVerified: false, isArtist: false),
      ]);
      expect(UserService.getCachedUser('merge_fallback')?.isArtist, isTrue);
    });

    test('a first record with unstated roles is cached unstated', () {
      UserService.setUsersInCache([_user('merge_new')]);
      final cached = UserService.getCachedUser('merge_new');
      expect(cached?.isArtistSpecified, isFalse);
      expect(cached?.isArtist, isFalse);
    });
  });
}
