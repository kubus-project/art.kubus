import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:art_kubus/config/api_keys.dart';
import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/models/collab_invite.dart';
import 'package:art_kubus/models/collab_member.dart';
import 'package:art_kubus/models/collectible.dart';
import 'package:art_kubus/models/dao.dart';
import 'package:art_kubus/models/event.dart';
import 'package:art_kubus/models/promotion.dart';
import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/models/wallet.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/collab_provider.dart';
import 'package:art_kubus/providers/collectibles_provider.dart';
import 'package:art_kubus/providers/dao_provider.dart';
import 'package:art_kubus/providers/promotion_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/screens/collab/invites_inbox_screen.dart';
import 'package:art_kubus/screens/community/profile_edit_screen.dart'
    as mobile_edit;
import 'package:art_kubus/screens/desktop/community/desktop_profile_edit_screen.dart'
    as desktop_edit;
import 'package:art_kubus/screens/desktop/web3/desktop_artist_studio_screen.dart';
import 'package:art_kubus/screens/desktop/web3/desktop_governance_hub_screen.dart';
import 'package:art_kubus/screens/desktop/web3/desktop_institution_hub_screen.dart';
import 'package:art_kubus/screens/desktop/web3/desktop_marketplace_screen.dart';
import 'package:art_kubus/screens/desktop/web3/desktop_wallet_screen.dart';
import 'package:art_kubus/screens/web3/artist/artist_studio.dart';
import 'package:art_kubus/screens/web3/dao/governance_hub.dart';
import 'package:art_kubus/screens/web3/institution/institution_hub.dart';
import 'package:art_kubus/screens/web3/marketplace/marketplace.dart';
import 'package:art_kubus/screens/web3/wallet/wallet_home.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/collab_api.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/promotion/promotion_builder_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/product_surface_harness.dart';
import '../support/profile_fixtures.dart';
import '../support/qa_font_loader.dart';

/// Wave 4C PRODUCT v5 visual matrix: profile edit, collaboration inbox,
/// Artist Studio, Institution Hub, wallet, marketplace, promotion builder
/// and DAO, against local fixtures only (no network writes; the promotion
/// backend is a MockClient). Every scene exists on the Wave 4B baseline too,
/// so the same file renders BEFORE from a c07144ad checkout.
///
/// ```
/// KUBUS_RUN_VISUAL_QA=1 QA_LABEL=after flutter test test/qa/product_v5_wave4c_visual_matrix_test.dart
/// ```
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  if (Platform.environment['KUBUS_RUN_VISUAL_QA'] != '1') {
    test('visual QA matrix is opt-in', () {},
        skip: 'Set KUBUS_RUN_VISUAL_QA=1 to generate screenshot evidence.');
    return;
  }

  final label = Platform.environment['QA_LABEL'] ?? 'after';
  final outputDir = Directory('output/qa/product-v5-wave4c/$label');
  final captures = <Map<String, Object?>>[];

  setUpAll(() async {
    await QaFontLoader.ensureLoaded();
    if (outputDir.existsSync()) outputDir.deleteSync(recursive: true);
    outputDir.createSync(recursive: true);
  });

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{
        'Artist Studio_onboarding_completed': true,
        'Institution Hub_onboarding_completed': true,
        'Marketplace_onboarding_completed': true,
        'DAO_onboarding_completed': true,
        'Governance_onboarding_completed': true,
      }));

  tearDownAll(() {
    File('${outputDir.path}/report.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'label': label,
        'commit': _git(['rev-parse', 'HEAD']),
        'treeDirty': _git(['status', '--porcelain']).isNotEmpty,
        'fontFamiliesLoaded': QaFontLoader.loadedFamilies,
        'captureCount': captures.length,
        'captures': captures,
      }),
    );
  });

  Future<void> surface(
    WidgetTester tester,
    String name,
    Widget Function() build, {
    Size size = _mobile,
    Brightness brightness = Brightness.light,
    Locale locale = const Locale('en'),
    double textScale = 1,
    UserProfile? signedIn,
    Future<void> Function(WidgetTester tester)? interact,
    List<SingleChildWidget> extraProviders = const <SingleChildWidget>[],
  }) async {
    final prior = FlutterError.onError;
    final errors = await pumpProductSurface(
      tester,
      // Screens with transparent scaffolds rely on the app shell to paint
      // the ground; paint it here so light text is not captured over a
      // transparent (viewer-white) background.
      child: Builder(
        builder: (context) => ColoredBox(
          color: KubusColorRoles.of(context).ground,
          child: build(),
        ),
      ),
      extraProviders: extraProviders,
      size: size,
      brightness: brightness,
      locale: locale,
      textScale: textScale,
      signedInProfile: signedIn,
    );
    if (interact != null) {
      try {
        await interact(tester);
      } catch (error) {
        errors.add('interaction: $error');
      }
    }
    // Let theme and ink transitions finish before the capture.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    final bytes = await _captureRoot(tester);
    File('${outputDir.path}/$name.png').writeAsBytesSync(bytes);
    captures.add(<String, Object?>{
      'name': name,
      'file': '$name.png',
      'width': size.width,
      'height': size.height,
      'locale': locale.languageCode,
      'brightness': brightness.name,
      'textScale': textScale,
      'renderErrors': errors.toSet().toList(),
    });
    FlutterError.onError = prior;
  }

  final artist = _owner(isArtist: true);
  final institution = _owner(isInstitution: true);

  // ------------------------------------------------------------ profile edit
  for (final v in _variants) {
    qaCase('profile edit ${v.name}', (tester) async {
      await surface(
        tester,
        'profile-edit-${v.name}',
        () => v.size.width >= 900
            ? const desktop_edit.ProfileEditScreen()
            : const mobile_edit.ProfileEditScreen(),
        size: v.size,
        brightness: v.brightness,
        locale: v.locale,
        signedIn: artist,
      );
    });
  }

  // ----------------------------------------------------- collaboration inbox
  qaCase('collab inbox mobile', (tester) async {
    await surface(
      tester,
      'collab-inbox-mobile-light-en',
      () => const InvitesInboxScreen(),
      signedIn: artist,
      extraProviders: [
        ChangeNotifierProvider<CollabProvider>(
          create: (_) => CollabProvider(api: _FixtureCollabApi()),
        ),
      ],
    );
  });

  // ------------------------------------------------- studio / institution
  final dashboards =
      <String, (Widget Function(), Widget Function(), UserProfile)>{
    'artist-studio': (
      () => const ArtistStudio(),
      () => const DesktopArtistStudioScreen(),
      artist,
    ),
    'institution-hub': (
      () => const InstitutionHub(),
      () => const DesktopInstitutionHubScreen(),
      institution,
    ),
  };
  for (final entry in dashboards.entries) {
    qaCase('${entry.key} mobile', (tester) async {
      await surface(tester, '${entry.key}-mobile-light-en', entry.value.$1,
          signedIn: entry.value.$3);
    });
    qaCase('${entry.key} desktop', (tester) async {
      await surface(tester, '${entry.key}-desktop-light-en', entry.value.$2,
          size: _desktop, signedIn: entry.value.$3);
    });
  }

  // ------------------------------------------------------------------ wallet
  qaCase('wallet mobile', (tester) async {
    await surface(tester, 'wallet-mobile-light-en', () => const WalletHome(),
        signedIn: artist, extraProviders: [_walletProvider()]);
  });
  qaCase('wallet mobile dark', (tester) async {
    await surface(tester, 'wallet-mobile-dark-sl', () => const WalletHome(),
        brightness: Brightness.dark,
        locale: const Locale('sl'),
        signedIn: artist,
        extraProviders: [_walletProvider()]);
  });
  qaCase('wallet desktop', (tester) async {
    await surface(
        tester, 'wallet-desktop-light-en', () => const DesktopWalletScreen(),
        size: _desktop, signedIn: artist, extraProviders: [_walletProvider()]);
  });

  // ------------------------------------------------------------- marketplace
  qaCase('marketplace mobile', (tester) async {
    final (artworks, collectibles) = await tester.runAsync(_seedMarket) ??
        (ArtworkProvider(), CollectiblesProvider());
    await surface(
        tester, 'marketplace-mobile-light-en', () => const Marketplace(),
        extraProviders: [
          ChangeNotifierProvider<ArtworkProvider>.value(value: artworks),
          ChangeNotifierProvider<CollectiblesProvider>.value(
              value: collectibles),
        ]);
  });
  qaCase('marketplace desktop', (tester) async {
    final (artworks, collectibles) = await tester.runAsync(_seedMarket) ??
        (ArtworkProvider(), CollectiblesProvider());
    await surface(tester, 'marketplace-desktop-light-en',
        () => const DesktopMarketplaceScreen(),
        size: _desktop,
        extraProviders: [
          ChangeNotifierProvider<ArtworkProvider>.value(value: artworks),
          ChangeNotifierProvider<CollectiblesProvider>.value(
              value: collectibles),
        ]);
  });

  // --------------------------------------------------------------- promotion
  qaCase('promotion builder', (tester) async {
    final api = _promotionApi();
    await surface(
      tester,
      'promotion-builder-mobile-light-en',
      () => const _PromotionLauncher(),
      signedIn: artist,
      extraProviders: [
        ChangeNotifierProvider<PromotionProvider>(
          create: (_) => PromotionProvider(api: api),
        ),
        _walletProvider(kub8: 69.9996),
      ],
      interact: (tester) async {
        await tester.tap(find.text('Open promotion'));
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 150));
        }
      },
    );
  });

  // --------------------------------------------------------------------- DAO
  qaCase('dao mobile', (tester) async {
    await surface(tester, 'dao-mobile-light-en', () => const GovernanceHub(),
        signedIn: artist,
        extraProviders: [
          ChangeNotifierProvider<DAOProvider>(create: (_) => _FixtureDao()),
        ]);
  });
  qaCase('dao desktop', (tester) async {
    await surface(tester, 'dao-desktop-light-en',
        () => const DesktopGovernanceHubScreen(),
        size: _desktop,
        signedIn: artist,
        extraProviders: [
          ChangeNotifierProvider<DAOProvider>(create: (_) => _FixtureDao()),
        ]);
  });
}

void qaCase(String description, WidgetTesterCallback callback) => testWidgets(
      description,
      callback,
      timeout: const Timeout(Duration(seconds: 120)),
    );

const Size _mobile = Size(390, 844);
const Size _desktop = Size(1440, 900);

class _Variant {
  const _Variant(this.name, this.size, this.brightness, this.locale);
  final String name;
  final Size size;
  final Brightness brightness;
  final Locale locale;
}

const List<_Variant> _variants = <_Variant>[
  _Variant('mobile-light-en', _mobile, Brightness.light, Locale('en')),
  _Variant('mobile-dark-sl', _mobile, Brightness.dark, Locale('sl')),
  _Variant('desktop-light-en', _desktop, Brightness.light, Locale('en')),
  _Variant('narrow-light-sl', Size(320, 700), Brightness.light, Locale('sl')),
];

UserProfile _owner({bool isArtist = false, bool isInstitution = false}) {
  return UserProfile(
    id: ProfileFixtures.wallet,
    userId: ProfileFixtures.wallet,
    walletAddress: ProfileFixtures.wallet,
    username: isInstitution ? 'galerija_vzigalica' : 'ana_kovac',
    displayName: isInstitution ? 'Galerija Vžigalica' : 'Ana Kovač',
    bio: 'Street muralist working across Ljubljana and Trieste.',
    avatar: '',
    isArtist: isArtist,
    isInstitution: isInstitution,
    createdAt: ProfileFixtures.fetchedAt,
    updatedAt: ProfileFixtures.fetchedAt,
  );
}

class _FixtureWallet extends WalletProvider {
  _FixtureWallet(this._tokens) : super(deferInit: true) {
    setCurrentWalletAddressForTesting(ProfileFixtures.wallet);
  }

  final List<Token> _tokens;

  @override
  List<Token> get tokens => List<Token>.unmodifiable(_tokens);

  @override
  String? get currentWalletAddress => ProfileFixtures.wallet;

  @override
  bool get hasFiatValuation => false;
}

Token _token(String mint, String symbol, String name, double balance) => Token(
      id: 'spl_$mint',
      name: name,
      symbol: symbol,
      type: TokenType.erc20,
      balance: balance,
      value: 0,
      changePercentage: 0,
      contractAddress: mint,
      decimals: 6,
      network: 'Solana',
    );

SingleChildWidget _walletProvider({double kub8 = 1234.5}) {
  return ChangeNotifierProvider<WalletProvider>(
    create: (_) => _FixtureWallet(<Token>[
      _token(ApiKeys.kub8MintAddress, 'KUB8', 'kubus', kub8),
      _token(
          'So11111111111111111111111111111111111111112', 'SOL', 'Solana', 0.75),
    ]),
  );
}

Future<(ArtworkProvider, CollectiblesProvider)> _seedMarket() async {
  final artworks = ArtworkProvider();
  final provider = CollectiblesProvider()..bindArtworkProvider(artworks);
  Artwork art(String id, String title, String artist) => Artwork(
        id: id,
        title: title,
        artist: artist,
        description: 'Fixture.',
        imageUrl: '',
        position: const LatLng(46.05, 14.5),
        rewards: 0,
        createdAt: DateTime.utc(2025, 1, 1),
        category: 'Mural',
      );
  artworks.addOrUpdateArtwork(art('art-a', 'Riverside mural', 'Ana Kovač'));
  final listed = await provider.createNFTSeries(
    artworkId: 'art-a',
    name: 'Riverside mural',
    description: 'Digital edition.',
    creatorAddress: 'creator-a',
    totalSupply: 10,
    rarity: CollectibleRarity.legendary,
    mintPrice: 14,
    imageUrl: '',
  );
  final edition = await provider.mintCollectible(
    seriesId: listed.id,
    ownerAddress: 'collector-1',
    transactionHash: 'tx-a',
  );
  await provider.listCollectibleForSale(collectibleId: edition.id, price: '55');
  artworks.addOrUpdateArtwork(art('art-b', 'Metelkova wall', 'Maja Novak'));
  final quiet = await provider.createNFTSeries(
    artworkId: 'art-b',
    name: 'Metelkova wall',
    description: 'Digital edition.',
    creatorAddress: 'creator-b',
    totalSupply: 5,
    rarity: CollectibleRarity.epic,
    mintPrice: 20,
    imageUrl: '',
    requiresARInteraction: true,
  );
  await provider.mintCollectible(
    seriesId: quiet.id,
    ownerAddress: 'collector-2',
    transactionHash: 'tx-b',
  );
  return (artworks, provider);
}

class _FixtureCollabApi implements CollabApi {
  @override
  Future<void> acceptInvite(String inviteId) async {}

  @override
  Future<void> declineInvite(String inviteId) async {}

  @override
  String? getAuthToken() => 'qa-token';

  @override
  Future<CollabInvite?> inviteCollaborator(
    String entityType,
    String entityId,
    String invitedIdentifier,
    String role,
  ) async =>
      null;

  @override
  Future<List<CollabMember>> listCollaborators(
    String entityType,
    String entityId,
  ) async =>
      const <CollabMember>[];

  @override
  Future<List<CollabInvite>> listMyCollabInvites() async => <CollabInvite>[
        CollabInvite(
          id: 'inv-1',
          entityType: 'exhibition',
          entityId: 'ex-1',
          invitedUserId: 'me',
          invitedByUserId: 'u-maja',
          invitedBy: UserSummaryDto.fromJson(const {
            'id': 'u-maja',
            'displayName': 'Maja Novak',
            'username': 'maja_walks',
          }),
          role: 'editor',
          status: 'pending',
          createdAt: DateTime.utc(2026, 9, 20),
          expiresAt: DateTime.utc(2026, 10, 20),
        ),
      ];

  @override
  Future<void> removeCollaborator(
    String entityType,
    String entityId,
    String memberUserId,
  ) async {}

  @override
  Future<void> updateCollaboratorRole(
    String entityType,
    String entityId,
    String memberUserId,
    String role,
  ) async {}
}

class _FixtureDao extends DAOProvider {
  final List<Proposal> _active = <Proposal>[
    Proposal(
      id: 'p-1',
      title: 'Open the winter mural fund',
      description:
          'Allocate a small budget to restore two public murals before the '
          'winter season, with an open call for local painters.',
      type: ProposalType.community,
      status: ProposalStatus.voting,
      proposer: 'wallet-proposer',
      createdAt: DateTime.utc(2026, 9, 1),
      votingEndDate: DateTime.utc(2099, 1, 10),
      yesVotes: 30,
      noVotes: 10,
      quorumRequired: 0.1,
    ),
  ];

  @override
  List<Proposal> get proposals => _active;

  @override
  List<Proposal> getActiveProposals() => _active;

  @override
  List<DAOReview> get reviews => const <DAOReview>[];

  @override
  List<Delegate> get delegates => const <Delegate>[];

  @override
  bool get isLoading => false;

  @override
  Future<void> refreshData({bool force = false}) async {}
}

class _PromotionLauncher extends StatelessWidget {
  const _PromotionLauncher();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => showPromotionBuilderSheet(
            context: context,
            entityType: PromotionEntityType.artwork,
            entityId: 'art-1',
            entityLabel: 'Riverside mural',
          ),
          child: const Text('Open promotion'),
        ),
      ),
    );
  }
}

/// Local promotion backend: config, one rate card, a quote for 70 KUB8.
BackendApiService _promotionApi() {
  final api = BackendApiService();
  api.setAuthTokenForTesting('qa-token');
  api.setHttpClient(MockClient((request) async {
    Map<String, Object?> body() => request.body.isEmpty
        ? <String, Object?>{}
        : (jsonDecode(request.body) as Map<String, dynamic>);
    http.Response ok(Object data, [int status = 200]) => http.Response(
          jsonEncode(<String, Object?>{'success': true, 'data': data}),
          status,
          headers: const <String, String>{'content-type': 'application/json'},
        );
    final path = request.url.path;
    if (request.method != 'GET' && path != '/api/app/promotion-price-quote') {
      // No writes leave the matrix.
      return http.Response('{"success":false}', 405);
    }
    if (path == '/api/app/promotion-config') {
      return ok(<String, Object?>{
        'maxBookingDaysAhead': 90,
        'cancellationWindowHours': 24,
        'quoteTtlSeconds': 900,
        'fiatCurrency': 'EUR',
        'paymentMethods': <String, Object?>{
          'fiat': <String, Object?>{'method': 'fiat_card', 'enabled': true},
          'kub8': <String, Object?>{
            'method': 'kub8_spl',
            'enabled': true,
            'mintAddress': ApiKeys.kub8MintAddress,
            'decimals': 6,
            'cluster': 'devnet',
          },
        },
      });
    }
    if (path == '/api/app/promotion-rate-cards') {
      return ok(<Object?>[
        <String, Object?>{
          'id': 'rate-1',
          'code': 'artwork_boost',
          'entityType': PromotionEntityType.artwork.apiValue,
          'placementTier': PromotionPlacementTier.boost.apiValue,
          'fiatPricePerDay': 4.00,
          'kub8PricePerDay': 10.00,
          'minDays': 3,
          'maxDays': 30,
          'slotCount': null,
          'isActive': true,
          'volumeDiscounts': const <Object?>[],
        },
      ]);
    }
    if (path == '/api/app/promotion-price-quote') {
      return ok(<String, Object?>{
        'quoteId': 'quote-1',
        'rateCardId': 'rate-1',
        'rateCardVersion': 'v1',
        'entityType': 'artwork',
        'entityId': 'art-1',
        'placementTier': PromotionPlacementTier.boost.apiValue,
        'durationDays': body()['durationDays'] ?? 7,
        'slotAvailable': true,
        'allowedPaymentMethods': <Object?>['fiat_card', 'kub8_spl'],
        'pricing': <String, Object?>{
          'fiatPricePerDay': '4.00',
          'kub8PricePerDay': '10.00',
          'baseFiatAmount': '28.00',
          'baseKub8Amount': '70',
          'discountPercent': '0',
          'finalFiatAmount': '28.00',
          'fiatCurrency': 'EUR',
          'finalKub8Amount': '70',
          'finalKub8AmountRaw': '70000000',
        },
        'kub8': <String, Object?>{
          'mintAddress': ApiKeys.kub8MintAddress,
          'decimals': 6,
          'amountRaw': '70000000',
          'amount': '70',
          'cluster': 'devnet',
          'destinationOwner': 'F81jSXoiB15kcEERt8nxYabm5kgZ37jGbC9fmAQZMSws',
          'destinationTokenAccount': 'TreasuryTokenAccount1111',
        },
        'schedule': <String, Object?>{
          'startAt': '2026-10-01T00:00:00.000Z',
          'endAt': '2026-10-08T00:00:00.000Z',
          'cancellationDeadlineAt': '2026-09-30T00:00:00.000Z',
        },
        'isRefundable': true,
        'expiresAt': '2099-01-01T00:00:00.000Z',
      });
    }
    if (path == '/api/app/promotion-requests/me') {
      return ok(const <Object?>[]);
    }
    return http.Response('{"success":false}', 404);
  }));
  return api;
}

Future<List<int>> _captureRoot(WidgetTester tester) async {
  final boundary = tester.binding.rootElement!.renderObject!;
  final layer = boundary.debugLayer! as OffsetLayer;
  late final List<int> bytes;
  await tester.runAsync(() async {
    final image = await layer.toImage(boundary.paintBounds);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    bytes = data!.buffer.asUint8List();
    image.dispose();
  });
  return bytes;
}

String _git(List<String> args) {
  try {
    final result = Process.runSync('git', args);
    return (result.stdout as String).trim();
  } catch (_) {
    return '';
  }
}
