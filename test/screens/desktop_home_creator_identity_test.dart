import 'package:art_kubus/screens/desktop/desktop_home_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('directory profiles are unique by id and keep the supplied ranking', () {
    final rows = selectDesktopTopArtists([
      {
        'id': 'admin',
        'isArtist': true,
        'displayName': 'Same Name',
        'username': 'first'
      },
      {
        'id': 'dao',
        'isArtist': true,
        'displayName': 'Same Name',
        'username': 'second'
      },
      {'id': 'admin', 'isArtist': true, 'displayName': 'Duplicate'},
      {'id': 'uploader', 'isArtist': false, 'isVerified': true},
      {'id': '', 'isArtist': true},
      {'id': 'wallet', 'isArtist': true, 'walletAddress': 'wallet'},
    ]);
    expect(rows.map((row) => row['id']), ['admin', 'dao', 'wallet']);
    final first = desktopArtistIdentity(rows.first, fallbackLabel: 'Artist');
    expect(first.label, 'Same Name');
    expect(first.handle, '@first');
    expect(first.navigationIdentifier, 'admin');
    expect(first.isArtist, isTrue);
    expect(first.isVerified, isFalse);
    expect(
        desktopArtistIdentity(rows[1], fallbackLabel: 'Artist')
            .navigationIdentifier,
        'dao');
  });

  test('profile identity falls back to real handle then neutral label', () {
    final handle = desktopArtistIdentity(
        {'id': 'a', 'username': 'real_handle', 'avatar': '/avatar.png'},
        fallbackLabel: 'Artist');
    expect(handle.label, 'real_handle');
    expect(handle.handle, '@real_handle');
    expect(handle.avatarUrl, '/avatar.png');
    final unnamed = desktopArtistIdentity({'id': 'b', 'isVerified': true},
        fallbackLabel: 'Artist');
    expect(unnamed.label, 'Artist');
    expect(unnamed.handle, isNull);
    expect(unnamed.navigationIdentifier, 'b');
    expect(unnamed.isVerified, isTrue);
  });

  test('empty directory stays empty and output is limited to five profiles',
      () {
    expect(selectDesktopTopArtists([]), isEmpty);
    final rows = List.generate(
        6, (index) => <String, dynamic>{'id': '$index', 'isArtist': true});
    expect(selectDesktopTopArtists(rows).length, 5);
  });
}
