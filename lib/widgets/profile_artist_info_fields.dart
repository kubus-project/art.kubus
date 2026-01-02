import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:art_kubus/l10n/app_localizations.dart';

class ProfileArtistInfoFields extends StatelessWidget {
  final List<String> fieldOfWork;
  final int yearsActive;
  final TextAlign textAlign;

  const ProfileArtistInfoFields({
    super.key,
    required this.fieldOfWork,
    required this.yearsActive,
    this.textAlign = TextAlign.center,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final normalizedField = fieldOfWork
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toList(growable: false);

    final showField = normalizedField.isNotEmpty;
    final showYears = yearsActive > 0;
    if (!showField && !showYears) return const SizedBox.shrink();

    Widget row({required IconData icon, required String label, required String value}) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.onSurface.withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurface.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
              textAlign: textAlign,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showField)
          row(
            icon: Icons.work_outline,
            label: l10n.profileFieldOfWorkLabel,
            value: normalizedField.join(', '),
          ),
        if (showField && showYears) const SizedBox(height: 8),
        if (showYears)
          row(
            icon: Icons.timelapse,
            label: l10n.profileYearsActiveLabel,
            value: l10n.profileYearsActiveValue(yearsActive),
          ),
      ],
    );
  }
}

