import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class UserRoleManager {
  static final UserRoleManager _instance = UserRoleManager._internal();
  factory UserRoleManager() => _instance;

  UserRoleManager._internal();

  List<String> _userRoles = [];
  String? _userRole; // For backward compatibility

  Future<void> loadUserRole() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    
    // Try to load multiple roles first
    final rolesJson = prefs.getString('userRoles');
    print('UserRoleManager: Loading roles from SharedPreferences');
    print('UserRoleManager: userRoles JSON: $rolesJson');
    
    if (rolesJson != null) {
      try {
        final List<dynamic> rolesList = jsonDecode(rolesJson);
        _userRoles = rolesList.cast<String>();
        // Set the first role as the primary role for backward compatibility
        _userRole = _userRoles.isNotEmpty ? _userRoles.first : null;
        print('UserRoleManager: Successfully loaded roles: $_userRoles');
      } catch (e) {
        print('Error parsing user roles: $e');
        _userRoles = [];
        _userRole = null;
      }
    } else {
      // Fallback to single role for backward compatibility
      _userRole = prefs.getString('userRole');
      print('UserRoleManager: Fallback to single role: $_userRole');
      if (_userRole != null) {
        _userRoles = [_userRole!];
        print('UserRoleManager: Set roles from single role: $_userRoles');
      }
    }
    
    print('UserRoleManager: Final roles: $_userRoles');
    print('UserRoleManager: Final primary role: $_userRole');
  }

  // Get all user roles
  List<String> get userRoles => List.unmodifiable(_userRoles);

  // Get primary role (first role) for backward compatibility
  String? get userRole => _userRole;

  // Set multiple roles
  Future<void> setUserRoles(List<String> roles) async {
    print('UserRoleManager: Setting user roles: $roles');
    _userRoles = roles;
    _userRole = roles.isNotEmpty ? roles.first : null;
    
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final rolesJson = jsonEncode(roles);
    await prefs.setString('userRoles', rolesJson);
    print('UserRoleManager: Saved userRoles to SharedPreferences: $rolesJson');
    
    // Also save the first role for backward compatibility
    if (_userRole != null) {
      await prefs.setString('userRole', _userRole!);
      print('UserRoleManager: Saved userRole to SharedPreferences: $_userRole');
    } else {
      await prefs.remove('userRole');
      print('UserRoleManager: Removed userRole from SharedPreferences');
    }
  }

  // Set single role (for backward compatibility)
  Future<void> setUserRole(String role) async {
    await setUserRoles([role]);
  }

  // Add a role to existing roles
  Future<void> addUserRole(String role) async {
    if (!_userRoles.contains(role)) {
      _userRoles.add(role);
      await setUserRoles(_userRoles);
    }
  }

  // Remove a specific role
  Future<void> removeUserRole(String role) async {
    _userRoles.remove(role);
    await setUserRoles(_userRoles);
  }

  // Check if user has a specific role
  bool hasRole(String role) {
    return _userRoles.contains(role);
  }

  // Check if user has any of the specified roles
  bool hasAnyRole(List<String> roles) {
    return _userRoles.any((role) => roles.contains(role));
  }

  // Check if user has all of the specified roles
  bool hasAllRoles(List<String> roles) {
    return roles.every((role) => _userRoles.contains(role));
  }

  // Get roles as a formatted string for display
  String get rolesDisplayString {
    if (_userRoles.isEmpty) return 'No roles assigned';
    return _userRoles.join(', ');
  }

  // Get the number of roles
  int get roleCount => _userRoles.length;

  // Check if user has multiple roles
  bool get hasMultipleRoles => _userRoles.length > 1;

  Future<void> clearUserRole() async {
    _userRoles = [];
    _userRole = null;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('userRole');
    await prefs.remove('userRoles');
  }
}
