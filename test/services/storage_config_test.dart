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
      'https://public-kubus-site.ipns.dweb.link/public-index.json',
    );
  });

  test('ipns resolution exposes ordered fallback candidates', () {
    final candidates = StorageConfig.resolveAllUrls(
      'ipns://public.kubus.site/public-index.json',
    );

    expect(candidates, isNotEmpty);
    expect(
      candidates.first,
      'https://public-kubus-site.ipns.dweb.link/public-index.json',
    );
    expect(
      candidates,
      contains('https://dweb.link/ipns/public.kubus.site/public-index.json'),
    );
  });
}
