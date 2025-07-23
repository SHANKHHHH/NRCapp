import 'package:dio/dio.dart';

class DioService {
  static final Dio _dio = Dio(BaseOptions(baseUrl: 'https://nrc-backend-his4.onrender.com'));
  static Dio get instance => _dio;
}
