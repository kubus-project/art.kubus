class AuthPasswordPolicy {
  static const int minLength = 8;
  static const int maxLength = 128;

  static bool isValid(String password) {
    if (password.length < minLength) return false;
    if (password.length > maxLength) return false;
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(password);
    final hasNumber = RegExp(r'[0-9]').hasMatch(password);
    return hasLetter && hasNumber;
  }
}

