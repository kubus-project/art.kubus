import '../services/storage_config.dart';

/// Shared media URL resolver for images, models, and other assets.
///
/// Centralizes IPFS and backend-relative path handling so widgets and providers
/// don't re‑implement gateway logic or base URL fallbacks.
class MediaUrlResolver {
  /// Resolves a raw media reference into an absolute URL when possible.
  ///
  /// - Passes through `data:`, `blob:`, and `asset:` URIs unchanged.
  /// - Supports `ipfs://`, `ipfs/`, `/ipfs/` and backend-relative paths via `StorageConfig`.
  /// - Normalizes protocol-relative URLs (`//...`) to `https://`.
  static String? resolve(String? raw) {
    if (raw == null) return null;
    final candidate = raw.trim();
    if (candidate.isEmpty) return null;

    final lower = candidate.toLowerCase();
    if (lower.startsWith('placeholder://')) return null;
    if (lower.startsWith('data:') ||
        lower.startsWith('blob:') ||
        lower.startsWith('asset:')) {
      return candidate;
    }

    if (candidate.startsWith('//')) {
      return StorageConfig.resolveUrl('https:$candidate');
    }

    return StorageConfig.resolveUrl(candidate);
  }
}
