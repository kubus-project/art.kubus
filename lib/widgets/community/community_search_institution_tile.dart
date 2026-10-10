import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import '../../utils/media_url_resolver.dart';

/// One institution row in the community search picker, read from the migrated
/// backend shape: `institutionType` and `location` can be null, `artworkCount`
/// is null on the migrated schema, and the cover is `bannerUrl` with
/// `logoUrl` as the fallback. The row's `type` is the result kind, never a
/// label, so it is not shown.
class CommunitySearchInstitutionTile extends StatelessWidget {
  const CommunitySearchInstitutionTile({
    super.key,
    required this.institution,
    required this.accentColor,
    required this.fallbackName,
    required this.onTap,
  });

  final Map<String, dynamic> institution;
  final Color accentColor;
  final String fallbackName;
  final VoidCallback onTap;

  static String? _text(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = _text(institution, const ['name', 'title']) ?? fallbackName;
    final subtitle = [
      _text(institution, const ['institutionType']),
      _text(institution, const ['location', 'address']),
    ].whereType<String>().join(' - ');

    final coverRaw = _text(institution, const ['bannerUrl', 'logoUrl']);
    final coverUrl = coverRaw == null
        ? null
        : MediaUrlResolver.resolveDisplayUrl(coverRaw) ??
            MediaUrlResolver.resolve(coverRaw);
    final fallbackIcon =
        Icon(Icons.location_city, color: accentColor, size: 20);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: coverUrl == null
            ? Center(child: fallbackIcon)
            : Image.network(
                coverUrl,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(child: fallbackIcon),
              ),
      ),
      title: Text(
        name,
        style: KubusTypography.inter(
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: subtitle.isEmpty
          ? null
          : Text(
              subtitle,
              style: KubusTypography.inter(
                fontSize: 12,
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: Icon(
        Icons.chevron_right,
        size: 20,
        color: scheme.onSurface.withValues(alpha: 0.68),
      ),
      onTap: onTap,
    );
  }
}
