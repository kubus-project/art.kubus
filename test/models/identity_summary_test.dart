import 'package:art_kubus/models/identity_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prefers display name over username and wallet fallback', () {
    final identity = IdentitySummary.fromJson({
      'author': {
        'walletAddress': 'wallet-1234567890',
        'displayName': 'Human Name',
        'username': 'human',
      },
    });

    expect(identity.label(fallback: 'Unknown author'), 'Human Name');
    expect(identity.username, 'human');
    expect(identity.walletAddress, 'wallet-1234567890');
  });

  test('ignores provisional names and falls back to compact wallet', () {
    final identity = IdentitySummary.fromJson({
      'author': {
        'walletAddress': 'abcdef1234567890',
        'displayName': 'user_abcdef1234567890',
      },
    });

    expect(identity.displayName, isNull);
    expect(identity.label(fallback: 'Unknown author'), 'abcdef...7890');
  });

  test('supports legacy flat author fields', () {
    final identity = IdentitySummary.fromJson({
      'authorWallet': 'legacy-wallet',
      'authorName': 'Legacy Name',
      'authorUsername': 'legacy',
      'authorAvatar': '/uploads/avatar.png',
    });

    expect(identity.label(fallback: 'Unknown creator'), 'Legacy Name');
    expect(identity.username, 'legacy');
    expect(identity.avatarUrl, '/uploads/avatar.png');
  });
}
