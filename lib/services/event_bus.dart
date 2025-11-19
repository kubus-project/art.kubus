import 'dart:async';

/// Simple singleton event bus to broadcast app-wide events.
class EventBus {
  static final EventBus _instance = EventBus._internal();
  factory EventBus() => _instance;
  EventBus._internal();

  final StreamController<Map<String, dynamic>> _controller = StreamController.broadcast();

  void emit(String event, dynamic payload) {
    try {
      _controller.add({'event': event, 'payload': payload});
    } catch (_) {}
  }

  Stream<Map<String, dynamic>> on(String event) {
    return _controller.stream.where((m) => m['event'] == event).map((m) => m);
  }

  // Convenience wrappers for common events
  void emitProfileUpdated(dynamic payload) => emit('profile_updated', payload);
  void emitProfilesUpdated(List<dynamic> payload) => emit('profiles_updated', payload);
}
