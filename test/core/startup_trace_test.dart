import 'package:art_kubus/core/startup_trace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(StartupTrace.reset);

  test('records marks in chronological order with monotonic timestamps', () {
    StartupTrace.mark('main start');
    StartupTrace.mark('binding ready');
    StartupTrace.mark('first frame');

    final marks = StartupTrace.marks;
    expect(
      marks.map((m) => m.label).toList(),
      <String>['main start', 'binding ready', 'first frame'],
    );
    expect(marks[1].elapsedMs, greaterThanOrEqualTo(marks[0].elapsedMs));
    expect(marks[2].elapsedMs, greaterThanOrEqualTo(marks[1].elapsedMs));
  });

  test('marks getter exposes an unmodifiable view', () {
    StartupTrace.mark('a');
    expect(
      () => StartupTrace.marks
          .add(const StartupTraceMark(label: 'x', elapsedMs: 0)),
      throwsUnsupportedError,
    );
  });

  test('reset clears recorded marks', () {
    StartupTrace.mark('a');
    expect(StartupTrace.marks, isNotEmpty);
    StartupTrace.reset();
    expect(StartupTrace.marks, isEmpty);
  });

  test('StartupTraceMark stringifies in the [BOOT] log format', () {
    const mark = StartupTraceMark(label: 'critical bootstrap end', elapsedMs: 1234);
    expect(mark.toString(), '[BOOT] 1234ms critical bootstrap end');
  });
}
