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
