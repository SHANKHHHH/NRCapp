import 'package:dio/dio.dart';

class DioService {
  static final Dio _dio = Dio(BaseOptions(baseUrl: 'http://51.20.4.108:3000'));
  static Dio get instance => _dio;
}
