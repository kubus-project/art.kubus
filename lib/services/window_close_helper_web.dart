import 'package:web/web.dart' as web;

bool attemptCloseWindowImpl() {
  try {
    web.window.close();
    return true;
  } catch (_) {
    return false;
  }
}

