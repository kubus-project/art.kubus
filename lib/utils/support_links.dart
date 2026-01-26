import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// External donation links used across the app.
///
/// Keep these centralized so both mobile + desktop UIs stay consistent.
class SupportLinks {
  SupportLinks._();

  static const String kofiUrl = 'https://ko-fi.com/artkubus';
  static const String githubSponsorsUrl =
      'https://github.com/kubus-project/art.kubus';

  /// PayPal donate flow using the recipient email.
  ///
  /// We intentionally use PayPal's classic donations endpoint because it works
  /// reliably across platforms (mobile/web/desktop) without requiring a hosted
  /// button ID.
  ///
  /// Recipient: theraxig@gmail.com
  static final Uri paypalDonateUri = Uri.https(
    'www.paypal.com',
    '/cgi-bin/webscr',
    <String, String>{
      'cmd': '_donations',
      'business': 'theraxig@gmail.com',
      'currency_code': 'EUR',
      'item_name': 'Support Kubus',
    },
  );

  static String get paypalDonateUrl => paypalDonateUri.toString();

  /// A compact label suitable for debug logs (never contains PII beyond the
  /// publicly-shared donation email).
  static String get paypalRecipientLabel => 'theraxig@gmail.com';

  static bool isHttpUrl(String url) {
    final lower = url.trim().toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  /// Choose a safe [LaunchMode] for the current platform.
  static LaunchMode get preferredLaunchMode {
    return kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication;
  }
}
