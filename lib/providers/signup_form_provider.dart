import 'package:flutter/foundation.dart';

import '../models/signup_form_data.dart';
import '../models/user_location.dart';

class SignupFormProvider extends ChangeNotifier {
  final SignupFormData _data = SignupFormData();

  String get firstName => _data.firstName;
  String get lastName => _data.lastName;
  String? get avatarId => _data.avatarId;
  UserLocation? get location => _data.location;
  Set<String> get selectedSports => _data.selectedSports;
  SignupFormData get data => _data;

  void setName({required String firstName, String lastName = ''}) {
    _data.firstName = firstName.trim();
    _data.lastName = lastName.trim();
    notifyListeners();
  }

  void setAvatarId(String? avatarId) {
    _data.avatarId = avatarId;
    notifyListeners();
  }

  void setLocation(UserLocation? location) {
    _data.location = location;
    notifyListeners();
  }

  void toggleSport(String sport) {
    if (_data.selectedSports.contains(sport)) {
      _data.selectedSports.remove(sport);
    } else {
      _data.selectedSports.add(sport);
    }
    notifyListeners();
  }

  void clear() {
    _data.firstName = '';
    _data.lastName = '';
    _data.avatarId = null;
    _data.location = null;
    _data.selectedSports = <String>{};
    notifyListeners();
  }
}
