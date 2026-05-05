import 'dart:async';
import 'dart:convert';

import 'package:art_kubus/config/api_keys.dart';
import 'package:art_kubus/services/ipfs_metadata_resolver.dart';
import 'package:art_kubus/services/solana_wallet_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('IPFS metadata resolver returns JSON from the first healthy gateway',
      () async {
    var attempts = 0;
    final resolver = IpfsMetadataResolver(
      client: MockClient((request) async {
        attempts++;
        return http.Response(
          jsonEncode(<String, Object?>{
            'name': 'kubus Governance Token',
            'symbol': 'KUB8',
            'image': 'ipfs://QmW8P69VpxdTipU46keFmcfrd2VeLg8E6eXEJcCWVNaqoR/logo.png',
          }),
          200,
          headers: const <String, String>{
            'content-type': 'application/json',
          },
        );
      }),
    );

    final metadata = await resolver.resolveJson(
      'ipfs://QmW8P69VpxdTipU46keFmcfrd2VeLg8E6eXEJcCWVNaqoR/kub8_metadata.json',
    );

    expect(metadata?['symbol'], 'KUB8');
    expect(attempts, 1);
  });

  test('IPFS metadata resolver negative-caches failed lookups', () async {
    var attempts = 0;
    final resolver = IpfsMetadataResolver(
      client: MockClient((request) async {
        attempts++;
        throw TimeoutException('gateway timed out');
      }),
      gatewayTimeout: const Duration(milliseconds: 1),
    );

    final first = await resolver.resolveJson(
      'ipfs://QmW8P69VpxdTipU46keFmcfrd2VeLg8E6eXEJcCWVNaqoR/kub8_metadata.json',
    );
    final attemptsAfterFirst = attempts;
    final second = await resolver.resolveJson(
      'ipfs://QmW8P69VpxdTipU46keFmcfrd2VeLg8E6eXEJcCWVNaqoR/kub8_metadata.json',
    );

    expect(first, isNull);
    expect(second, isNull);
    expect(attemptsAfterFirst, greaterThan(0));
    expect(attempts, attemptsAfterFirst);
  });

  test('KUB8 token info returns static fallback metadata without IPFS', () async {
    final service = SolanaWalletService();

    final metadata = await service.getTokenInfoForTesting(
      ApiKeys.kub8MintAddress,
    );

    expect(metadata['symbol'], 'KUB8');
    expect(metadata['name'], 'kubus Governance Token');
    expect(metadata['decimals'], ApiKeys.kub8Decimals);
    expect(metadata['logoUrl'], 'assets/images/logo.png');
  });
}
