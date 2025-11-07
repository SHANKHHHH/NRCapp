import 'package:dio/dio.dart';
import 'dio_service.dart';
import '../../constants/strings.dart';

class AuthService {
  // Test backend connectivity
  Future<bool> testConnection() async {
    try {
      print('🔍 [AuthService] Testing connection to: ${AppStrings.baseUrl}');
      
      // Try different URL formats that might work
      List<String> baseUrls = [
        AppStrings.baseUrl,
        AppStrings.productionUrl,
        AppStrings.awsUrl,
        AppStrings.awsUrlAlt1,
        AppStrings.awsUrlAlt2,
      ];
      
      for (String baseUrl in baseUrls) {
        print('🔍 [AuthService] Trying base URL: $baseUrl');
        
        // Create a temporary Dio instance with this URL
        final testDio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ));
        
        // Try multiple endpoints to test connectivity (baseUrl already has /api)
        List<String> testEndpoints = ['/auth/login', '/job-planning/', '/machines'];
        
        for (String endpoint in testEndpoints) {
          try {
            print('🔍 [AuthService] Testing $baseUrl$endpoint');
            final response = await testDio.get(endpoint);
            print('🔍 [AuthService] Connection test response: ${response.statusCode}');
            
            // Even if we get 401/403, it means the server is reachable
            if (response.statusCode != null && response.statusCode! < 500) {
              print('✅ [AuthService] Backend is reachable at $baseUrl!');
              return true;
            }
          } catch (e) {
            print('🔍 [AuthService] Endpoint $endpoint failed: $e');
            if (e is DioException && e.response?.statusCode != null) {
              // If we get a response (even 401/403), server is reachable
              print('✅ [AuthService] Backend is reachable at $baseUrl (got response)!');
              return true;
            }
          }
        }
      }
      
      print('❌ [AuthService] All URLs and endpoints failed');
      return false;
    } catch (e) {
      print('❌ [AuthService] Connection test failed: $e');
      return false;
    }
  }

  Future<Response> login({required String email, required String password}) async {
    try {
      print('🔐 [AuthService] Attempting login to: ${AppStrings.baseUrl}/auth/login');
      print('🔐 [AuthService] Email: $email');
      
      final response = await DioService.instance.post(
        '/auth/login',
        data: {'email': email, 'password': password},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      
      print('🔐 [AuthService] Login response: ${response.statusCode}');
      print('🔐 [AuthService] Response data: ${response.data}');
      
      return response;
    } catch (e) {
      print('❌ [AuthService] Login error: $e');
      if (e is DioException) {
        print('❌ [AuthService] Dio error type: ${e.type}');
        print('❌ [AuthService] Dio error message: ${e.message}');
        print('❌ [AuthService] Dio response: ${e.response?.data}');
        print('❌ [AuthService] Dio status code: ${e.response?.statusCode}');
      }
      rethrow;
    }
  }

  Future<Response> logout(String token) async {
    try {
      print('🔒 [AuthService] Calling logout API to clear session...');
      
      final response = await DioService.instance.post(
        '/auth/logout',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      
      print('✅ [AuthService] Logout response: ${response.statusCode}');
      return response;
    } catch (e) {
      print('❌ [AuthService] Logout error: $e');
      rethrow;
    }
  }
} 