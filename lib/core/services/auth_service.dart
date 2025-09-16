import 'package:dio/dio.dart';
import 'dio_service.dart';

class AuthService {
  Future<Response> login({required String id, required String password}) {
    return DioService.instance.post(
      '/api/auth/login',
      data: {'id': id, 'password': password},
    );
  }
} 