import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/utils/profile_data_key.dart';
import 'package:flutter_test/flutter_test.dart';

UserProfile _profile({String wallet = '', String? actor, String? userId}) =>
    UserProfile(
      id: '8c03b35a-a4d6-4c08-95fc-503c879fbc45',
      userId: userId,
      walletAddress: wallet,
      publicActorId: actor,
      username: 'damjan_stevovic',
      displayName: 'Damjan Stevovic',
      bio: '',
      avatar: '',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  test('wallet accounts keep addressing their data by wallet', () {
    expect(profileArtistDataKey(_profile(wallet: ' So1Wallet ')), 'So1Wallet');
  });

  test('a walletless account falls back to actor, profile then account id', () {
    expect(
      profileArtistDataKey(_profile(actor: 'actor-id')),
      'actor-id',
    );
    expect(
      profileArtistDataKey(_profile()),
      '8c03b35a-a4d6-4c08-95fc-503c879fbc45',
    );
    expect(profileArtistDataKey(null), '');
  });

  test('collections use ownerId only for UUID identifiers', () {
    expect(
      collectionsOwnerQueryKey('e10d1421-019f-481a-8065-637f1fad53ed'),
      'ownerId',
    );
    expect(
      collectionsOwnerQueryKey('8C03B35A-A4D6-4C08-95FC-503C879FBC45'),
      'ownerId',
    );
    expect(
      collectionsOwnerQueryKey('7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU'),
      'walletAddress',
    );
  });
}
