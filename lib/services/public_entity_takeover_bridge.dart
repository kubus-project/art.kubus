import 'public_entity_takeover_bridge_stub.dart'
    if (dart.library.js_interop) 'public_entity_takeover_bridge_web.dart'
    as implementation;

void dispatchPublicEntityRouteParsed({
  required String type,
  required String id,
  required String path,
}) {
  implementation.dispatchPublicEntityRouteParsed(
    type: type,
    id: id,
    path: path,
  );
}

void dispatchPublicEntityReady({
  required String type,
  required String id,
  required String path,
}) {
  implementation.dispatchPublicEntityReady(type: type, id: id, path: path);
}

Map<String, dynamic>? readPublicEntityBootstrap() =>
    implementation.readPublicEntityBootstrap();

String? publicEntityDocumentTitle() => validatedPublicEntityDocumentTitle(
      bootstrap: readPublicEntityBootstrap(),
      pathname: Uri.base.path,
      title: implementation.readPublicEntityDocumentTitle(),
    );

/// Retain the server's metadata title only for the exact validated entry.
String? validatedPublicEntityDocumentTitle({
  required Map<String, dynamic>? bootstrap,
  required String pathname,
  required String? title,
}) {
  if (bootstrap == null || ![1, 2].contains(bootstrap['version'])) return null;
  final identity = bootstrap['identity'];
  final presentation = bootstrap['presentation'];
  if (identity is! Map || presentation is! Map) return null;
  if (identity['canonicalPath'] != pathname ||
      presentation['canonicalPath'] != pathname ||
      identity['id'] != presentation['id'] ||
      identity['type'] != presentation['type'] ||
      presentation['version'] != bootstrap['version'] ||
      !['en', 'sl'].contains(identity['locale']) ||
      !pathname.startsWith('/${identity['locale']}/')) {
    return null;
  }
  final normalized = title?.trim();
  return normalized == null || normalized.isEmpty || normalized.length > 512
      ? null
      : normalized;
}
