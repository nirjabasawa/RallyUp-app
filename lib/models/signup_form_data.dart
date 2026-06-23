import 'user_location.dart';

class SignupFormData {
  String firstName;
  String lastName;
  String? avatarId;
  UserLocation? location;
  Set<String> selectedSports;

  SignupFormData({
    this.firstName = '',
    this.lastName = '',
    this.avatarId,
    this.location,
    Set<String>? selectedSports,
  }) : selectedSports = selectedSports ?? <String>{};

  bool get hasName => firstName.trim().isNotEmpty;
}
