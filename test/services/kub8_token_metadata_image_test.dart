import 'dart:async';
import 'dart:io';

import 'package:art_kubus/config/api_keys.dart';
import 'package:art_kubus/services/solana_wallet_service.dart';
import 'package:art_kubus/utils/token_identity_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// Canonical KUB8 is metadata-image-first: the service hands the wallet the
/// token metadata's image when one resolves and the bundled lattice logo
/// otherwise, while the mint keeps the configured name, symbol and decimals.
/// Every lookup is stubbed; no test touches Solana RPC or an IPFS gateway.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const metadataUri = 'ipfs://bafykub8metadata';
  const imageUrl = 'https://gateway.example/ipfs/bafykub8image';

  SolanaWalletService serviceWith({
    required Future<TokenOnChainMetadata?> Function(String mint) onChain,
    Future<Map<String, dynamic>?> Function(String? uri)? offChain,
  }) {
    return SolanaWalletService()
      ..onChainMetadataLookupForTesting = onChain
      ..offChainMetadataResolverForTesting = offChain ?? (_) async => null;
  }

  // Remote metadata that disagrees with the configured identity, so a test
  // can tell which one the service kept.
  Future<TokenOnChainMetadata?> impostorOnChain(String _) async =>
      (symbol: 'SCAM', name: 'Not kubus', uri: metadataUri);

  group('canonical KUB8', () {
    test('a resolvable metadata image becomes the logoUrl', () async {
      final service = serviceWith(
        onChain: impostorOnChain,
        offChain: (uri) async =>
            uri == metadataUri ? {'image': imageUrl, 'name': 'Wrong'} : null,
      );
      final info =
          await service.getTokenInfoForTesting(ApiKeys.kub8MintAddress);
      expect(info['logoUrl'], imageUrl);
    });

    test('an ipfs:// metadata image resolves through the gateway resolver',
        () async {
      final service = serviceWith(
        onChain: impostorOnChain,
        offChain: (_) async => {'image': 'ipfs://bafykub8image'},
      );
      final info =
          await service.getTokenInfoForTesting(ApiKeys.kub8MintAddress);
      final logo = info['logoUrl'] as String;
      expect(TokenIdentityRules.isUsableMetadataImage(logo), isTrue);
      expect(logo, contains('bafykub8image'));
    });

    test('an unavailable metadata image falls back to the bundled logo',
        () async {
      final service = serviceWith(
        onChain: impostorOnChain,
        offChain: (_) async => null,
      );
      final info =
          await service.getTokenInfoForTesting(ApiKeys.kub8MintAddress);
      expect(info['logoUrl'], TokenIdentityRules.kub8LogoAsset);
    });

    test('metadata without an image falls back to the bundled logo', () async {
      final service = serviceWith(
        onChain: impostorOnChain,
        offChain: (_) async => {'description': 'no image here'},
      );
      final info =
          await service.getTokenInfoForTesting(ApiKeys.kub8MintAddress);
      expect(info['logoUrl'], TokenIdentityRules.kub8LogoAsset);
    });

    test('an unusable metadata image falls back to the bundled logo', () async {
      final service = serviceWith(
        onChain: impostorOnChain,
        offChain: (_) async => {'image': 'javascript:alert(1)'},
      );
      final info =
          await service.getTokenInfoForTesting(ApiKeys.kub8MintAddress);
      expect(info['logoUrl'], TokenIdentityRules.kub8LogoAsset);
    });

    test('absent on-chain metadata falls back to the bundled logo', () async {
      final service = serviceWith(onChain: (_) async => null);
      final info =
          await service.getTokenInfoForTesting(ApiKeys.kub8MintAddress);
      expect(info['logoUrl'], TokenIdentityRules.kub8LogoAsset);
    });

    test('a metadata exception falls back to the bundled logo', () async {
      final service = serviceWith(
        onChain: (_) async => throw StateError('rpc down'),
      );
      final info =
          await service.getTokenInfoForTesting(ApiKeys.kub8MintAddress);
      expect(info['logoUrl'], TokenIdentityRules.kub8LogoAsset);
      expect(info['symbol'], 'KUB8');
    });

    testWidgets('a metadata lookup that never answers is cut off by the budget',
        (tester) async {
      final never = Completer<TokenOnChainMetadata?>();
      final service = serviceWith(onChain: (_) => never.future);
      Map<String, dynamic>? info;
      unawaited(service
          .getTokenInfoForTesting(ApiKeys.kub8MintAddress)
          .then((value) => info = value));
      await tester.pump(const Duration(seconds: 4));
      expect(info, isNull);
      await tester.pump(const Duration(seconds: 2));
      expect(info, isNotNull);
      expect(info!['logoUrl'], TokenIdentityRules.kub8LogoAsset);
      expect(info!['symbol'], 'KUB8');
    });

    test('the configured name, symbol and decimals survive remote metadata',
        () async {
      final service = serviceWith(
        onChain: impostorOnChain,
        offChain: (_) async =>
            {'image': imageUrl, 'name': 'Wrong', 'symbol': 'WRONG'},
      );
      final info =
          await service.getTokenInfoForTesting(ApiKeys.kub8MintAddress);
      expect(info['symbol'], 'KUB8');
      expect(info['name'], 'kubus Governance Token');
      expect(info['decimals'], ApiKeys.kub8Decimals);
      expect(info.containsKey('rawOffChainMetadata'), isFalse);
    });

    test('the result is cached: a second read does not look up again',
        () async {
      var lookups = 0;
      final service = serviceWith(
        onChain: (mint) async {
          lookups++;
          return impostorOnChain(mint);
        },
        offChain: (_) async => {'image': imageUrl},
      );
      await service.getTokenInfoForTesting(ApiKeys.kub8MintAddress);
      final second =
          await service.getTokenInfoForTesting(ApiKeys.kub8MintAddress);
      expect(lookups, 1);
      expect(second['logoUrl'], imageUrl);
    });
  });

  test('a wrong mint claiming KUB8 keeps its own metadata, not the canon',
      () async {
    const wrongMint = 'Fake1111111111111111111111111111111111111111';
    final service = serviceWith(
      onChain: (_) async => (symbol: 'KUB8', name: 'kubus', uri: metadataUri),
      offChain: (_) async => {'image': imageUrl},
    );
    final info = await service.getTokenInfoForTesting(wrongMint);
    expect(info['symbol'], 'KUB8');
    expect(info['logoUrl'], imageUrl);
    expect(info['logoUrl'], isNot(TokenIdentityRules.kub8LogoAsset));
    expect(TokenIdentityRules.isCanonicalKub8(wrongMint), isFalse);
  });

  // Native SOL never reaches the SPL token lookup; wrapped SOL takes the
  // ordinary metadata path, unchanged by the KUB8 branch, and keeps its own
  // canonical mark in the wallet by mint.
  test('wrapped SOL takes the ordinary metadata path', () async {
    final service = serviceWith(
      onChain: (_) async =>
          (symbol: 'SOL', name: 'Wrapped SOL', uri: metadataUri),
      offChain: (_) async => {'image': imageUrl},
    );
    final info =
        await service.getTokenInfoForTesting(TokenIdentityRules.wrappedSolMint);
    expect(info['symbol'], 'SOL');
    expect(info['name'], 'Wrapped SOL');
    expect(info['logoUrl'], imageUrl);
    expect(TokenIdentityRules.isCanonicalSol(TokenIdentityRules.wrappedSolMint),
        isTrue);
    expect(
        TokenIdentityRules.isCanonicalKub8(TokenIdentityRules.wrappedSolMint),
        isFalse);
  });

  test('a generic token takes its name, symbol and image from metadata',
      () async {
    const genericMint = 'Gen11111111111111111111111111111111111111111';
    final service = serviceWith(
      onChain: (_) async =>
          (symbol: 'ONC', name: 'On-chain name', uri: metadataUri),
      offChain: (_) async => {
        'name': 'Off-chain name',
        'symbol': 'OFF',
        'image': imageUrl,
        'description': 'A generic token',
      },
    );
    final info = await service.getTokenInfoForTesting(genericMint);
    expect(info['name'], 'Off-chain name');
    expect(info['symbol'], 'OFF');
    expect(info['logoUrl'], imageUrl);
    expect(info['uri'], metadataUri);
    expect(info['description'], 'A generic token');
    expect(info['rawOffChainMetadata'], isA<Map<String, dynamic>>());
  });

  test('a generic token without metadata falls back to its short mint label',
      () async {
    const genericMint = 'Gen11111111111111111111111111111111111111111';
    final service = serviceWith(
      onChain: (_) async => throw StateError('rpc down'),
    );
    final info = await service.getTokenInfoForTesting(genericMint);
    expect(info['name'], startsWith('Token '));
    expect(info.containsKey('logoUrl'), isFalse);
  });

  // lib/services/AGENTS.md: services must not depend on widgets. The shared
  // KUB8 rules live in lib/utils/token_identity_rules.dart for that reason.
  test('the wallet service imports no widget or screen code', () {
    final imports = File('lib/services/solana_wallet_service.dart')
        .readAsLinesSync()
        .where((line) => line.startsWith('import '));
    expect(
      imports.where(
          (line) => line.contains('/widgets/') || line.contains('/screens/')),
      isEmpty,
    );
  });
}
