import 'package:flutter/foundation.dart';

enum AuthDeepLinkType {
  verifyEmail,
  resetPassword,
}

@immutable
class AuthDeepLinkTarget {
  const AuthDeepLinkTarget._({
    required this.type,
    required this.token,
    this.email,
  });

  const AuthDeepLinkTarget.verifyEmail({
    required String token,
    String? email,
  }) : this._(
          type: AuthDeepLinkType.verifyEmail,
          token: token,
          email: email,
        );

  const AuthDeepLinkTarget.resetPassword({
    required String token,
  }) : this._(
          type: AuthDeepLinkType.resetPassword,
          token: token,
        );

  final AuthDeepLinkType type;
  final String token;
  final String? email;

  String signature() => '${type.name}:$token';
}

class AuthDeepLinkParser {
  const AuthDeepLinkParser();

  AuthDeepLinkTarget? parse(Uri uri) {
    final path = (uri.path).trim();
    if (path.isEmpty) return null;

    final normalizedPath = path.toLowerCase();
    if (normalizedPath == '/verify-email') {
      final token = (uri.queryParameters['token'] ?? '').trim();
      if (token.isEmpty) return null;
      final email = (uri.queryParameters['email'] ?? '').trim();
      return AuthDeepLinkTarget.verifyEmail(
        token: token,
        email: email.isEmpty ? null : email,
      );
    }

    if (normalizedPath == '/reset-password') {
      final token = (uri.queryParameters['token'] ?? '').trim();
      if (token.isEmpty) return null;
      return AuthDeepLinkTarget.resetPassword(token: token);
    }

    return null;
  }
}

