import 'share_types.dart';
import 'share_deep_link_parser.dart';

class ShareLinkBuilder {
  ShareLinkBuilder({required Uri baseUri, this.publicPagesEnabled = true})
      : _baseUri = baseUri;

  final Uri _baseUri;
  final bool publicPagesEnabled;
  static const ShareDeepLinkCodec _codec = ShareDeepLinkCodec();

  static const Map<ShareEntityType, Map<String, String>> _publicSegments = {
    ShareEntityType.artwork: {'en': 'artworks', 'sl': 'umetnine'},
    ShareEntityType.profile: {'en': 'profiles', 'sl': 'profili'},
    ShareEntityType.event: {'en': 'events', 'sl': 'dogodki'},
    ShareEntityType.exhibition: {'en': 'exhibitions', 'sl': 'razstave'},
    ShareEntityType.post: {'en': 'posts', 'sl': 'objave'},
    ShareEntityType.collection: {'en': 'collections', 'sl': 'zbirke'},
    ShareEntityType.nft: {'en': 'collectibles', 'sl': 'zbirateljski-predmeti'},
    ShareEntityType.marker: {'en': 'map', 'sl': 'zemljevid'},
  };

  Uri build(ShareTarget target, {String locale = 'en'}) {
    if (!publicPagesEnabled) {
      return _codec.buildUriForTarget(_baseUri, target);
    }
    final language = locale.trim().toLowerCase() == 'sl' ? 'sl' : 'en';
    final segment = _publicSegments[target.type]![language]!;
    final normalizedBasePath = _baseUri.path.endsWith('/')
        ? _baseUri.path.substring(0, _baseUri.path.length - 1)
        : _baseUri.path;
    return Uri(
      scheme: _baseUri.scheme,
      userInfo: _baseUri.userInfo,
      host: _baseUri.host,
      port: _baseUri.hasPort ? _baseUri.port : null,
      path:
          '$normalizedBasePath/$language/$segment/${Uri.encodeComponent(target.shareId.trim())}',
    );
  }
}
