import 'dart:convert';

import 'package:art_kubus/models/dao.dart';
import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/providers/dao_provider.dart';
import 'package:art_kubus/providers/institution_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _wallet = 'WalletInstitution1111111111111111111111111';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() {
    BackendApiService().setHttpClient(createPlatformHttpClient());
  });

  group('wallet-derived institution identity merge', () {
    test('backend record with the same id is kept instead of the derived entry',
        () async {
      _mockBackendInstitutions([
        _backendInstitution(id: _wallet, name: 'Backend Gallery'),
      ]);
      final provider = _bind(
        profile: _profile(),
        review: _institutionReview(status: 'approved'),
      );
      await provider.initialize();

      final matches =
          provider.institutions.where((i) => i.id == _wallet).toList();
      expect(matches, hasLength(1));
      expect(matches.single.name, 'Backend Gallery');
      expect(matches.single.latitude, 46.0511);
      expect(matches.single.longitude, 14.5051);
    });

    test('derived entry is placed first when no backend record shares its id',
        () async {
      _mockBackendInstitutions([
        _backendInstitution(id: 'inst-other', name: 'Other Institution'),
      ]);
      final provider = _bind(
        profile: _profile(),
        review: _institutionReview(status: 'approved'),
      );
      await provider.initialize();

      final ids = provider.institutions.map((i) => i.id).toList();
      expect(ids, <String>[_wallet, 'inst-other']);
      expect(provider.getInstitutionById(_wallet)?.name, 'Wallet Gallery');
    });
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

void _mockBackendInstitutions(List<Map<String, Object?>> institutions) {
  BackendApiService().setHttpClient(MockClient((request) async {
    if (request.url.path == '/api/institutions') {
      return _jsonResponse({'institutions': institutions});
    }
    if (request.url.path == '/api/events') {
      return _jsonResponse({
        'data': {'events': <Object?>[]},
      });
    }
    return http.Response('Unexpected request ${request.url}', 500);
  }));
}

http.Response _jsonResponse(Map<String, Object?> body) {
  return http.Response(
    jsonEncode(body),
    200,
    headers: const <String, String>{'content-type': 'application/json'},
  );
}

Map<String, Object?> _backendInstitution({
  required String id,
  required String name,
}) {
  return {
    'id': id,
    'name': name,
    'description': 'Backend institution',
    'type': 'gallery',
    'address': 'Main Street 1',
    'latitude': 46.0511,
    'longitude': 14.5051,
    'contactEmail': 'hello@example.com',
    'website': 'https://example.com',
    'imageUrls': <String>[],
    'stats': {
      'totalVisitors': 0,
      'activeEvents': 0,
      'artworkViews': 0,
      'revenue': 0,
      'visitorGrowth': 0,
      'revenueGrowth': 0,
    },
    'isVerified': false,
    'createdAt': '2026-07-01T10:00:00.000Z',
  };
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
