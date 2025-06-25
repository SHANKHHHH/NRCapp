import 'package:dio/dio.dart';

class DioService {
  static final Dio _dio = Dio(BaseOptions(baseUrl: 'https://your.api.base.url'));
  static Dio get instance => _dio;
}
