import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/auth_service.dart';
import 'package:dio/dio.dart';
import 'dart:convert';

class AuthRepository {
  static const _tokenKey = 'accessToken';
  static const _userIdKey = 'userId';
  static const _userRoleKey = 'userRole';
  final AuthService _authService;

  AuthRepository(this._authService);

  Future<bool> login({required String id, required String password}) async {
    try {
      final response = await _authService.login(id: id, password: password);
      if (response.data['success'] == true && response.data['acessToken'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, response.data['acessToken']);
        // Save user id as well
        if (response.data['data'] != null && response.data['data']['id'] != null) {
          await prefs.setString(_userIdKey, response.data['data']['id']);
        }
        // Remove saving user role here
        return true;
      }
      return false;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userRoleKey);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userRoleKey);
  }

  Future<Map<String, dynamic>?> checkUserValidAndGetData(String id, String accessToken) async {
    try {
      final dio = Dio();
      final response = await dio.get(
        'http://nrc-backend-alb-174636098.ap-south-1.elb.amazonaws.com/api/auth/users/$id',
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        print('AuthRepository: User validation successful');
        print('AuthRepository: Response data: ${response.data}');
        
        // Save user role if present
        if (response.data['data'] != null) {
          final prefs = await SharedPreferences.getInstance();
          final data = response.data['data'];
          print('AuthRepository: User data: $data');
          
          // Check for both 'role' and 'roles' fields
          dynamic role = data['role'] ?? data['roles'];
          print('AuthRepository: Found role/roles: $role');
          
          // Handle multiple roles - check if it's a JSON array or comma-separated string
          List<String> roles = [];
          print('AuthRepository: Processing role data: $role (type: ${role.runtimeType})');
          
          if (role is String) {
            print('AuthRepository: Role is String: $role');
            if (role.startsWith('[') && role.endsWith(']')) {
              // JSON array format
              try {
                final List<dynamic> rolesList = jsonDecode(role);
                roles = rolesList.cast<String>();
                print('AuthRepository: Parsed JSON array: $roles');
              } catch (e) {
                // If parsing fails, treat as single role
                roles = [role];
                print('AuthRepository: JSON parsing failed, treating as single role: $roles');
              }
            } else if (role.contains(',')) {
              // Comma-separated format
              roles = role.split(',').map((r) => r.trim()).where((r) => r.isNotEmpty).toList();
              print('AuthRepository: Parsed comma-separated: $roles');
            } else {
              // Single role
              roles = [role];
              print('AuthRepository: Single role: $roles');
            }
          } else if (role is List) {
            // Already a list
            roles = role.cast<String>();
            print('AuthRepository: Role is already List: $roles');
          } else {
            print('AuthRepository: Role is neither String nor List, type: ${role.runtimeType}');
          }
          
          print('AuthRepository: Final processed roles: $roles');
          
          // Save roles as JSON array
          if (roles.isNotEmpty) {
            await prefs.setString('userRoles', jsonEncode(roles));
            print('AuthRepository: Saved userRoles to SharedPreferences: ${jsonEncode(roles)}');
            
            // Also save the first role for backward compatibility
            await prefs.setString(_userRoleKey, roles.first);
            print('AuthRepository: Saved userRole to SharedPreferences: ${roles.first}');
          } else {
            print('AuthRepository: No roles to save');
          }
        }
        return response.data['data'];
      }
      return null;
    } catch (e) {
      print('User validation error: $e');
      return null;
    }
  }
} 