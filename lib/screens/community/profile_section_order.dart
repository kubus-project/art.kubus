/// The information hierarchy of a profile, shared by the public (viewed)
/// profile and "My profile" on mobile and desktop so the two cannot silently
/// diverge again.
///
/// The person comes first: who they are, what they make or programme, what
/// they have said, what they are recognised for, and the numbers as the
/// closing composition. Account management is not part of that narrative; the
/// owner's tools sit after it as their own, secondary block.
enum ProfileSection {
  /// Cover, avatar, name, handle, role, bio and the practice fields (field of
  /// work, years active, place). The owner's edit/settings utilities live in
  /// this header, never as a separate band.
  identity,

  /// An artist's portfolio, collections and events, or an institution's
  /// programme. Only the parts that apply to the role.
  work,

  /// Public art the person has added to the map.
  publicArt,

  /// A bounded preview of public posts, with a history destination.
  activity,

  /// Achievements and the verified role / public badges.
  recognition,

  /// The closing expressive statistic tiles.
  stats,

  /// Owner only: account health, saved items, performance and similar
  /// management content. Always after the public-facing sections.
  ownerTools,
}

/// The sections of a viewed (public) profile, in order.
const List<ProfileSection> publicProfileSections = <ProfileSection>[
  ProfileSection.identity,
  ProfileSection.work,
  ProfileSection.publicArt,
  ProfileSection.activity,
  ProfileSection.recognition,
  ProfileSection.stats,
];

/// The sections of "My profile": the public sequence, then the owner's tools.
const List<ProfileSection> ownerProfileSections = <ProfileSection>[
  ...publicProfileSections,
  ProfileSection.ownerTools,
];

/// Builds the pieces of a profile in [order], so the shared hierarchy owns the
/// rendering instead of each screen hard-coding its own widget sequence.
///
/// [build] returns what [section] contributes: nothing when the section does not
/// apply to this profile (a role without that content, or content the surface
/// shows elsewhere), so the relative order of the sections that are present is
/// always the canonical one. [gap], when given, is placed between two
/// consecutive sections that both contributed something.
List<T> composeProfileSections<T>({
  required Iterable<ProfileSection> order,
  required List<T> Function(ProfileSection section) build,
  T Function(ProfileSection previous, ProfileSection next)? gap,
}) {
  final out = <T>[];
  ProfileSection? previous;
  for (final section in order) {
    final items = build(section);
    if (items.isEmpty) continue;
    if (previous != null && gap != null) out.add(gap(previous, section));
    out.addAll(items);
    previous = section;
  }
  return out;
}
