import 'package:art_kubus/config/api_keys.dart';
import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/models/collab_invite.dart';
import 'package:art_kubus/models/collab_member.dart';
import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/models/wallet.dart';
import 'package:art_kubus/providers/email_preferences_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/screens/desktop/desktop_shell_scope.dart';
import 'package:art_kubus/services/collab_api.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'profile_fixtures.dart';

/// Local fixtures shared by the Wave 5A visual matrix and the responsive
/// sweep. No network, no production data.

SingleChildWidget qaEmailPreferences() =>
    ChangeNotifierProvider<EmailPreferencesProvider>(
      create: (_) => EmailPreferencesProvider(),
    );

/// A shell scope that can pop, as inside the real desktop shell.
Widget qaShellHost(Widget child) {
  return DesktopShellScope(
    pushScreen: (_) {},
    popScreen: () {},
    navigateToRoute: (_) {},
    openNotifications: () {},
    openFunctionsPanel: (_, {content}) {},
    setFunctionsPanelContent: (_) {},
    closeFunctionsPanel: () {},
    canPop: true,
    // The real shell paints a Material ground under every pushed screen.
    child: Material(type: MaterialType.transparency, child: child),
  );
}

UserProfile qaOwner({bool isArtist = false, bool isInstitution = false}) {
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
    stats: UserStats(
      artworksDiscovered: 18,
      artworksCreated: 6,
      nftsOwned: 2,
      followersCount: 1284,
      followingCount: 312,
    ),
    createdAt: ProfileFixtures.fetchedAt,
    updatedAt: ProfileFixtures.fetchedAt,
  );
}

Artwork qaArtwork() => Artwork(
      id: 'art-a',
      title: 'Riverside mural',
      artist: 'Ana Kovač',
      description: 'A long wall along the Ljubljanica, painted in 2025.',
      imageUrl: '',
      position: const LatLng(46.05, 14.5),
      rewards: 0,
      createdAt: DateTime.utc(2025, 1, 1),
      category: 'Mural',
    );

class QaFixtureWallet extends WalletProvider {
  QaFixtureWallet(this._tokens) : super(deferInit: true) {
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

Token qaToken(String mint, String symbol, String name, double balance) => Token(
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

SingleChildWidget qaWalletProvider() {
  return ChangeNotifierProvider<WalletProvider>(
    create: (_) => QaFixtureWallet(<Token>[
      qaToken(ApiKeys.kub8MintAddress, 'KUB8', 'kubit', 1234.5),
      qaToken(
          'So11111111111111111111111111111111111111112', 'SOL', 'Solana', 0.75),
      // An impostor: KUB8 symbol, wrong mint. Must never wear the KUB8 mark.
      qaToken('Fake1111111111111111111111111111111111111111', 'KUB8',
          'Not kubit', 5000),
    ]),
  );
}

class QaFixtureCollabApi implements CollabApi {
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
  Future<List<CollabInvite>> listMyCollabInvites() async =>
      const <CollabInvite>[];

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
