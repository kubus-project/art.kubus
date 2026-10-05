import 'package:art_kubus/core/startup_trace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('entry trace retains public identity without URI secrets', () {
    expect(
        StartupTrace.safeEntryPath(Uri.parse(
          'https://user:secret@app.kubus.site/sl/umetnine/art-1?token=secret#proof',
        )),
        '/sl/umetnine/art-1');
    for (final route in ['reset-password', 'verify-email', 'wallet-return']) {
      expect(
          StartupTrace.safeEntryPath(Uri.parse(
            'https://app.kubus.site/$route/private-token?proof=secret',
          )),
          '/$route');
    }
  });
}
