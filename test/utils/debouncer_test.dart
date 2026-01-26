import 'package:art_kubus/utils/debouncer.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Debouncer runs only the latest scheduled action', () {
    fakeAsync((async) {
      final debouncer = Debouncer();
      var calls = 0;

      debouncer(const Duration(milliseconds: 100), () => calls++);
      async.elapse(const Duration(milliseconds: 50));

      debouncer(const Duration(milliseconds: 100), () => calls++);
      async.elapse(const Duration(milliseconds: 99));
      expect(calls, 0);

      async.elapse(const Duration(milliseconds: 1));
      expect(calls, 1);
    });
  });

  test('Debouncer cancel prevents the action from running', () {
    fakeAsync((async) {
      final debouncer = Debouncer();
      var called = false;

      debouncer(const Duration(milliseconds: 50), () => called = true);
      debouncer.cancel();
      async.elapse(const Duration(milliseconds: 60));

      expect(called, isFalse);
    });
  });
}

