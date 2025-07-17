import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/auth_service.dart';

class AuthRepository {
  static const _tokenKey = 'accessToken';
  final AuthService _authService;

  AuthRepository(this._authService);

  Future<bool> login({required String id, required String password}) async {
    try {
      final response = await _authService.login(id: id, password: password);
      if (response.data['success'] == true && response.data['acessToken'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, response.data['acessToken']);
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

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
} 