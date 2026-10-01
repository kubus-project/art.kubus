import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../models/artwork.dart';
import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';

/// A compact, readable register for image credits associated with an artwork.
///
/// These fields describe the image, not the cultural creator of the artwork.
/// Source identifiers and record contributors are omitted until the artwork
/// presentation contract exposes those semantics explicitly.
class ArtworkProvenanceSection extends StatelessWidget {
  const ArtworkProvenanceSection({required this.artwork, super.key});

  final Artwork artwork;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    final creator = _clean(artwork.imageAuthor);
    final license = _clean(artwork.imageLicense);
    final credit = _clean(artwork.imageAttribution);
    final source = _clean(artwork.imageSourceUrl);
    if (creator == null &&
        license == null &&
        credit == null &&
        source == null) {
      return const SizedBox.shrink();
    }

    final rows = <(String, String)>[
      if (creator != null) (l10n.artworkProvenanceImageCreator, creator),
      if (license != null) (l10n.artworkProvenanceLicense, license),
      if (credit != null) (l10n.artworkProvenanceCredit, credit),
      if (source != null) (l10n.artworkProvenanceSource, source),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: KubusSpacing.lg),
        Text(
          l10n.subjectActionsProvenanceHeading,
          style: KubusTextStyles.sectionTitle.copyWith(color: roles.foreground),
        ),
        const SizedBox(height: KubusSpacing.sm),
        Divider(height: 1, thickness: 1, color: roles.rule),
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.only(top: KubusSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 116,
                  child: Text(
                    label,
                    style: KubusTextStyles.metadataRegister.copyWith(
                      color: roles.foregroundMuted,
                    ),
                  ),
                ),
                const SizedBox(width: KubusSpacing.sm),
                Expanded(
                  child: _ProvenanceValue(value: value, roles: roles),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String? _clean(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }
}

class _ProvenanceValue extends StatelessWidget {
  const _ProvenanceValue({required this.value, required this.roles});

  final String value;
  final KubusColorRoles roles;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(value);
    final safeUri = uri != null &&
            uri.hasAuthority &&
            (uri.scheme == 'http' || uri.scheme == 'https')
        ? uri
        : null;
    final style = KubusTypography.content(
      fontSize: 14,
      color: safeUri == null ? roles.foreground : roles.active,
      height: 1.4,
    );
    return InkWell(
      onTap: safeUri == null
          ? null
          : () => launchUrl(safeUri, mode: LaunchMode.externalApplication),
      child: Text(
        value,
        style: safeUri == null
            ? style
            : style.copyWith(decoration: TextDecoration.underline),
      ),
    );
  }
}
