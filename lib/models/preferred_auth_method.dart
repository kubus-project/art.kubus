/// Auth method a visitor already chose on the contextual activation sheet.
///
/// Carried into structured onboarding so the embedded account step can enter
/// that method's state directly instead of asking the visitor to pick again
/// from Google/email/wallet a second time.
enum PreferredAuthMethod {
  google,
  email,
  wallet;

  String get storageValue => name;

  static PreferredAuthMethod? fromStorage(String? value) {
    final normalized = (value ?? '').trim();
    for (final method in PreferredAuthMethod.values) {
      if (method.storageValue == normalized) return method;
    }
    return null;
  }
}
