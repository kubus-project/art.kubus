import 'package:art_kubus/services/auth/auth_deep_link_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = AuthDeepLinkParser();
  test('explicit auth entry remains auth, independent of public read policy',
      () {
    expect(parser.parse(Uri.parse('https://app.kubus.site/sign-in'))?.type,
        AuthDeepLinkType.signIn);
    expect(parser.parse(Uri.parse('https://app.kubus.site/register'))?.type,
        AuthDeepLinkType.register);
    final verification = parser.parse(Uri.parse(
        'https://app.kubus.site/verify-email?token=test-only&email=test@example.invalid'));
    expect(verification?.type, AuthDeepLinkType.verifyEmail);
    expect(verification?.token, 'test-only');
    expect(verification?.email, 'test@example.invalid');
    final reset = parser.parse(
        Uri.parse('https://app.kubus.site/reset-password?token=test-only'));
    expect(reset?.type, AuthDeepLinkType.resetPassword);
    expect(reset?.token, 'test-only');
    expect(parser.parse(Uri.parse('https://app.kubus.site/en/artworks/a1')),
        isNull);
    expect(
        parser.parse(Uri.parse('https://app.kubus.site/verify-email')), isNull);
  });
}
