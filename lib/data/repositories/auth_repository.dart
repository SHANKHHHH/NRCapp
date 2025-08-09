import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/auth_service.dart';
import 'package:dio/dio.dart';

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
        // Save user role if present
        if (response.data['data'] != null && response.data['data']['role'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_userRoleKey, response.data['data']['role']);
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