import 'package:shared_preferences/shared_preferences.dart';

class AlphaNoticeService {
  AlphaNoticeService._();

  static const String acknowledgementKey = 'kubus_alpha_notice_ack_v1';

  static Future<bool> isAcknowledged({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    return p.getBool(acknowledgementKey) ?? false;
  }

  static Future<void> acknowledge({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.setBool(acknowledgementKey, true);
  }
}
