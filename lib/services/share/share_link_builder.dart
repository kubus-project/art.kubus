import 'share_types.dart';
import 'share_deep_link_parser.dart';

class ShareLinkBuilder {
  ShareLinkBuilder({required Uri baseUri}) : _baseUri = baseUri;

  final Uri _baseUri;
  static const ShareDeepLinkCodec _codec = ShareDeepLinkCodec();

  Uri build(ShareTarget target) {
    return _codec.buildUriForTarget(_baseUri, target);
  }
}

