import 'dart:async';

class Debouncer {
  Timer? _timer;

  bool get isScheduled => _timer?.isActive ?? false;

  void call(Duration delay, void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    cancel();
  }
}
