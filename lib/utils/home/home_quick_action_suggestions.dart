import '../../models/user_persona.dart';
import '../../models/user_profile.dart';

List<String> resolveSuggestedQuickActionKeys(
  UserPersona? persona,
  UserProfile? currentUser,
) {
  List<String> suggestions;
  switch (persona) {
    case UserPersona.lover:
      suggestions = const ['map', 'community', 'marketplace'];
      break;
    case UserPersona.creator:
      suggestions = const ['studio', 'ar', 'map'];
      break;
    case UserPersona.institution:
      suggestions = const ['institution_hub', 'map', 'community'];
      break;
    case null:
      suggestions = const ['map', 'studio', 'institution_hub'];
      break;
  }

  final isArtist = currentUser?.isArtist ?? false;
  final isInstitution = currentUser?.isInstitution ?? false;

  if (isArtist && isInstitution) {
    suggestions =
        suggestions.where((key) => key != 'institution_hub').toList();
  } else if (isInstitution && !isArtist) {
    suggestions = suggestions.where((key) => key != 'studio').toList();
  } else if (isArtist && !isInstitution) {
    suggestions =
        suggestions.where((key) => key != 'institution_hub').toList();
  }

  return suggestions;
}
