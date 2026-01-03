import 'share_types.dart';

class ShareLinkBuilder {
  ShareLinkBuilder({required Uri baseUri}) : _baseUri = baseUri;

  final Uri _baseUri;

  Uri build(ShareTarget target) {
    final normalizedBase = _baseUri.replace(
      path: _baseUri.path.endsWith('/') ? _baseUri.path.substring(0, _baseUri.path.length - 1) : _baseUri.path,
    );
    return normalizedBase.replace(
      path: '${normalizedBase.path}/${target.type.canonicalPathSegment}/${Uri.encodeComponent(target.shareId)}',
    );
  }
}

