import 'package:shared_preferences/shared_preferences.dart';

class UserRoleManager {
  static final UserRoleManager _instance = UserRoleManager._internal();
  factory UserRoleManager() => _instance;

  UserRoleManager._internal();

  String? _userRole;

  Future<void> loadUserRole() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _userRole = prefs.getString('userRole'); // Default to 'Guest'
  }

  String? get userRole => _userRole;

  Future<void> setUserRole(String role) async {
    _userRole = role;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('userRole', role);
  }

  Future<void> clearUserRole() async {
    _userRole = null;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('userRole');
  }
}
