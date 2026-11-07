import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Authenticated requests read the account-closure receipt from secure storage.
/// Widget tests run in fake time, where a call to an unhandled platform channel
/// waits on the real engine and never completes. This answers the secure-storage
/// channel from the mock messenger as "nothing stored".
void installEmptySecureStorage() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async => null,
  );
}
