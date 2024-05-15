import 'package:flutter/foundation.dart';
import 'profile/profile.dart';

class ProfileProvider extends ChangeNotifier {
  Profile? _profile;

  Profile? get profile => _profile;

  void saveProfile(Profile profile) {
    _profile = profile;
    notifyListeners();
  }
}
