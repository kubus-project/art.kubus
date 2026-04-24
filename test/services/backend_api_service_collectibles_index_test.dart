import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:art_kubus/services/backend_api_service.dart';

void main() {
  test('getWalletCollectibleIndex fetches the wallet-scoped backend index', () async {
    final api = BackendApiService();
    api.setHttpClient(
      MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/profiles/TestWallet111111111111111111111111111111111/collectibles');
        expect(request.headers['Authorization'], isNull);
        return http.Response(
          jsonEncode({
            'success': true,
            'source': 'postgresql',
            'data': {
              'walletAddress': 'TestWallet111111111111111111111111111111111',
              'count': 1,
              'ownershipIndex': {
                'status': 'wallet_scoped_indexed',
                'confidence': 'backend_indexed',
              },
              'collectibles': [
                {
                  'artworkId': 'artwork-1',
                  'collectibleId': 'artwork_collectible_artwork-1',
                  'ownerAddress': 'TestWallet111111111111111111111111111111111',
                  'ownershipState': {
                    'status': 'wallet_scoped_indexed',
                    'confidence': 'backend_indexed',
                  },
                },
              ],
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final response = await api.getWalletCollectibleIndex('TestWallet111111111111111111111111111111111');

    expect(response['success'], isTrue);
    final data = response['data'] as Map<String, dynamic>;
    expect(data['walletAddress'], 'TestWallet111111111111111111111111111111111');
    expect(data['count'], 1);
    expect((data['collectibles'] as List).length, 1);
    expect((data['ownershipIndex'] as Map<String, dynamic>)['status'], 'wallet_scoped_indexed');
  });
}
