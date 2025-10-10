import 'package:dio/dio.dart';
import '../../constants/strings.dart';

class DioService {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: AppStrings.baseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 30),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));
  
  static Dio get instance => _dio;
}
