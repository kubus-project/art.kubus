/// The single definition of a *usable public profile* for the capability model.
///
/// A profile-required action (compose, DM, group create, marker create/claim,
/// and the creator scope's profile half) needs a hydrated profile that carries
/// a display name. Bio, avatar and the like stay voluntary. Every decision that
/// asks "does this account already have the profile this action needs?" (the
/// gate before authentication, the post-auth resolver, interrupted-journey
/// recovery and pending-action return) uses this one rule, so a hydrated
/// profile with an empty display name can never slip through one of them.
///
/// This is a UX gate, not authorization; the backend remains the authority.
bool isUsablePublicProfile({
  required bool hydrated,
  required String? displayName,
}) =>
    hydrated && (displayName ?? '').trim().isNotEmpty;
