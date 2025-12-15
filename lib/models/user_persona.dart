/// User persona chosen during onboarding.
///
/// This is a UX preference (hints / surfaced entry points), not an access control.
enum UserPersona {
  lover,
  creator,
  institution,
}

extension UserPersonaX on UserPersona {
  String get storageValue {
    switch (this) {
      case UserPersona.lover:
        return 'lover';
      case UserPersona.creator:
        return 'creator';
      case UserPersona.institution:
        return 'institution';
    }
  }

  static UserPersona? tryParse(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    switch (v) {
      case 'lover':
      case 'art_lover':
      case 'artlover':
        return UserPersona.lover;
      case 'creator':
      case 'artist':
      case 'artist_collective':
      case 'collective':
        return UserPersona.creator;
      case 'institution':
      case 'gallery':
      case 'institution_gallery':
        return UserPersona.institution;
      default:
        return null;
    }
  }
}
