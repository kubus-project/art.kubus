class ProfileMediaRefUtils {
  static bool isGeneratedAvatarRef(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return true;
    final lower = raw.toLowerCase();
    return lower.contains('/api/avatar/') ||
        lower.contains('style=identicon') ||
        lower.contains('dicebear');
  }

  static String? toPersistableAvatarRef(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty || isGeneratedAvatarRef(raw)) return null;

    if (raw.startsWith('/uploads/') ||
        raw.startsWith('/profiles/') ||
        raw.startsWith('/avatars/')) {
      return raw;
    }

    if (raw.startsWith('uploads/') ||
        raw.startsWith('profiles/') ||
        raw.startsWith('avatars/')) {
      return '/$raw';
    }

    try {
      final uri = Uri.parse(raw);
      if (uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https')) {
        final path = uri.path;
        if (path.startsWith('/uploads/') ||
            path.startsWith('/profiles/') ||
            path.startsWith('/avatars/')) {
          return path;
        }
        return raw;
      }
    } catch (_) {}

    return raw.startsWith('/') ? raw : '/uploads/${raw.replaceFirst(RegExp(r'^/+'), '')}';
  }

  static bool isPersistableAvatarRef(String? value) {
    return toPersistableAvatarRef(value) != null;
  }

  static String? toPersistableCoverRef(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty || isGeneratedAvatarRef(raw)) return null;

    if (raw.startsWith('/uploads/') ||
        raw.startsWith('/profiles/') ||
        raw.startsWith('/avatars/')) {
      return raw;
    }

    if (raw.startsWith('uploads/') ||
        raw.startsWith('profiles/') ||
        raw.startsWith('avatars/')) {
      return '/$raw';
    }

    try {
      final uri = Uri.parse(raw);
      if (uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https')) {
        final path = uri.path;
        if (path.startsWith('/uploads/') ||
            path.startsWith('/profiles/') ||
            path.startsWith('/avatars/')) {
          return path;
        }
      }
    } catch (_) {}

    return null;
  }
}