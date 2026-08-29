/// How onboarding should navigate on completion.
///
/// Onboarding can be entered in two different navigational situations, and
/// treating them the same produced a duplicate destination route with a dead
/// Back press on top of it:
///
/// * [returnToOrigin] — onboarding was pushed *above* a route that is still
///   on the stack (a protected action opened it over the artwork/marker/
///   wallet screen the visitor was already on). Completion should reveal
///   that existing route, not push a second copy of it.
/// * [replaceWithDestination] — the stack no longer has that origin route to
///   reveal (a standalone auth screen removed the auth stack, or the app
///   resumed externally / from a cold deep link). Completion must navigate to
///   the destination because there is nothing to pop back to.
enum OnboardingCompletionNavigation {
  returnToOrigin,
  replaceWithDestination;

  String get storageValue => name;

  static OnboardingCompletionNavigation fromStorage(String? value) {
    final normalized = (value ?? '').trim();
    for (final mode in OnboardingCompletionNavigation.values) {
      if (mode.storageValue == normalized) return mode;
    }
    return OnboardingCompletionNavigation.replaceWithDestination;
  }
}
