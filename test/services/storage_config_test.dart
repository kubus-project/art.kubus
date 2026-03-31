import 'package:art_kubus/services/storage_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default gateway list excludes retired cloudflare-ipfs.com', () {
    expect(
      StorageConfig.ipfsGateways,
      isNot(contains('https://cloudflare-ipfs.com/ipfs/')),
    );
  });

  test('ipns resolution uses normalized ipns gateway path', () {
    final resolved =
        StorageConfig.resolveUrl('ipns://public.kubus.site/public-index.json');
    expect(
      resolved,
      'https://ipfs.io/ipns/public.kubus.site/public-index.json',
    );
  });
}
