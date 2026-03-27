/// Simple in-memory singleton to hold the logged-in user's details.
/// Populated at login and read anywhere in the app.
class UserSession {
  UserSession._();
  static final UserSession instance = UserSession._();

  String name   = '';
  String email  = '';
  String phone  = '';
  String gender = 'Male';
}
