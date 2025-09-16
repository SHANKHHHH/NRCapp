import 'package:dio/dio.dart';

class DioService {
  static final Dio _dio = Dio(BaseOptions(baseUrl: 'http://nrc-backend-alb-174636098.ap-south-1.elb.amazonaws.com'));
  static Dio get instance => _dio;
}
