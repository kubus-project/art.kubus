import 'package:art_kubus/services/guest_session_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('isGuestActiveSync defaults to false with no stored flag', () async {
    final prefs = await SharedPreferences.getInstance();
    expect(GuestSessionService.isGuestActiveSync(prefs), isFalse);
  });

  test('isGuestActiveSync reads the persisted guest flag', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      GuestSessionService.guestModeKey: true,
    });
    final prefs = await SharedPreferences.getInstance();
    expect(GuestSessionService.isGuestActiveSync(prefs), isTrue);
  });

  test('entryIntentSync returns the persisted intent', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      GuestSessionService.intentKey: 'contribute',
    });
    final prefs = await SharedPreferences.getInstance();
    expect(GuestSessionService.entryIntentSync(prefs), 'contribute');
  });

  test('entryUtmSync returns only the persisted UTM values', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'kubus_entry_utm_utm_source': 'facebook',
      'kubus_entry_utm_utm_campaign': 'early-access',
    });
    final prefs = await SharedPreferences.getInstance();
    final utm = GuestSessionService.entryUtmSync(prefs);
    expect(utm, <String, String>{
      'utm_source': 'facebook',
      'utm_campaign': 'early-access',
    });
  });

  test('clearGuestMode removes the guest flag', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      GuestSessionService.guestModeKey: true,
    });
    final prefs = await SharedPreferences.getInstance();
    await GuestSessionService.clearGuestMode(prefs: prefs);
    expect(GuestSessionService.isGuestActiveSync(prefs), isFalse);
  });
}
