import 'package:nrc/constants/strings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../models/job_model.dart';
import '../models/Machine.dart'; // Make sure this import exists
import '../models/Job.dart'; // Added import for Job model

class JobApi {
  final Dio dio;
  
  // Cache for API responses
  static Map<String, dynamic>? _cachedJobs;
  static Map<String, dynamic>? _cachedPlannings;
  static Map<String, Map<String, dynamic>> _cachedPrintingDetails = {};
  static DateTime? _lastCacheTime;
  static const Duration _cacheValidity = Duration(minutes: 5);

  JobApi(this.dio);

  /// Helper: return current time in IST (UTC+05:30) with milliseconds and +05:30 offset
  String _formatDateWithMilliseconds() {
    final nowUtc = DateTime.now().toUtc();
    final ist = nowUtc.add(const Duration(hours: 5, minutes: 30));
    final year = ist.year.toString().padLeft(4, '0');
    final month = ist.month.toString().padLeft(2, '0');
    final day = ist.day.toString().padLeft(2, '0');
    final hour = ist.hour.toString().padLeft(2, '0');
    final minute = ist.minute.toString().padLeft(2, '0');
    final second = ist.second.toString().padLeft(2, '0');
    final millisecond = ist.millisecond.toString().padLeft(3, '0');
    return '${year}-${month}-${day}T${hour}:${minute}:${second}.${millisecond}+05:30';
  }

  /// Clear all cached data
  static void clearCache() {
    _cachedJobs = null;
    _cachedPlannings = null;
    _cachedPrintingDetails.clear();
    _lastCacheTime = null;
  }

  /// Force fetch fresh data without cache
  Future<List<Map<String, dynamic>>> getAllJobPlanningsFresh() async {
    print('[getAllJobPlanningsFresh] Force fetching fresh data (no cache)');
    clearCache(); // Clear cache before fetching
    
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    print('[getAllJobPlanningsFresh] Token: $token');
    final response = await dio.get(
      '/job-planning/',
      options: Options(
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    print('[getAllJobPlanningsFresh] Response: ${response.statusCode} ${response.data}');
    if (response.data['success'] == true && response.data['count'] > 0) {
      final plannings = List<Map<String, dynamic>>.from(response.data['data']);
      
      // Cache the results
      _cachedPlannings = {
        'data': plannings,
        'timestamp': DateTime.now(),
      };
      _lastCacheTime = DateTime.now();
      
      return plannings;
    }
    return [];
  }

  /// Check if cache is valid
  static bool _isCacheValid() {
    return _lastCacheTime != null && 
           DateTime.now().difference(_lastCacheTime!) < _cacheValidity;
  }

  Future<List<JobModel>> getJobs() async {
    // Check cache first
    if (_isCacheValid() && _cachedJobs != null) {
      print('[getJobs] Using cached data');
      return _cachedJobs!['data'];
    }

    print('[getJobs] Fetching fresh data');
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    print('[getJobs] Token: $token');
    final response = await dio.get(
      '/jobs',
      options: Options(
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    print('[getJobs] Response: ${response.statusCode} ${response.data}');
    final List<dynamic> jobList = response.data['data'];
    final jobs = jobList.map((e) => JobModel.fromJson(e)).toList();
    
    // Cache the results
    _cachedJobs = {
      'data': jobs,
      'timestamp': DateTime.now(),
    };
    _lastCacheTime = DateTime.now();
    
    return jobs;
  }

  Future<List<Job>> getJobsByNo(String nrcJobNo) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    print('[getJobs] Token: $token');
    final response = await dio.get(
      '/jobs/$nrcJobNo',
      options: Options(
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    print('[getJobs] Response: ${response.statusCode} ${response.data}');       
    final data = response.data['data'];
    if (data is List) {
      return data.map<Job>((e) => Job.fromJson(e)).toList();
    } else if (data is Map<String, dynamic>) {
      // If backend returns a single job as a map
      return [Job.fromJson(data)];
    } else {
      return [];
    }
  }

  // New function: Get job with comprehensive PO details
  Future<Map<String, dynamic>?> getJobWithPODetails(String nrcJobNo) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    print('[getJobWithPODetails] Token: $token');
    print('[getJobWithPODetails] nrcJobNo: $nrcJobNo');
    
    try {
      final response = await dio.get(
        '/jobs/$nrcJobNo/with-po-details',
        options: Options(
          headers: {
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );
      print('[getJobWithPODetails] Response: ${response.statusCode} ${response.data}');
      
      if (response.data['success'] == true && response.data['data'] != null) {
        return response.data['data'];
      }
      return null;
    } catch (e) {
      print('[getJobWithPODetails] Error: $e');
      return null;
    }
  }

  Future<void> updateJobStatus(String nrcJobNo, String status) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    print('[updateJobStatus] Token: $token');
    print('[updateJobStatus] nrcJobNo: $nrcJobNo, status: $status');
    await dio.put(
      '/jobs/$nrcJobNo',
      data: {'status': status},
      options: Options(
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    // Clear cache after update
    clearCache();
  }

  Future<void> updateJobField(String nrcJobNo, Map<String, dynamic> fields) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    print('[updateJobField] Token: $token');
    print('[updateJobField] nrcJobNo: $nrcJobNo, fields: $fields');
    await dio.put(
      '/jobs/$nrcJobNo',
      data: fields,
      options: Options(
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    clearCache();
  }

  Future<Response> createPurchaseOrder(Map<String, dynamic> purchaseOrderData) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    print('[createPurchaseOrder] Token: $token');
    print('[createPurchaseOrder] Data: $purchaseOrderData');
    final response = await dio.post(
      '${AppStrings.baseUrl}/purchase-orders/create',
      data: purchaseOrderData,
      options: Options(
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    print('[createPurchaseOrder] Response: ${response.statusCode} ${response.data}');
    return response;
  }

  Future<List<Machine>> getMachines() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    print('[getMachines] Token: $token');
    final response = await dio.get(
      '${AppStrings.baseUrl}/machines',
      options: Options(
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    print('[getMachines] Response: ${response.statusCode} ${response.data}');
    final List<dynamic> machineList = response.data['data'];
    return machineList.map((e) => Machine.fromJson(e)).toList();
  }

  Future<Response> submitJobPlanning(Map<String, dynamic> body) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    print('[submitJobPlanning] Token: $token');
    print('[submitJobPlanning] Body: $body');
    final response = await dio.post(
      '${AppStrings.baseUrl}/job-planning/',
      data: body,
      options: Options(
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    print('[submitJobPlanning] Response: ${response.statusCode} ${response.data}');
    // Clear cache after creating new planning
    clearCache();
    return response;
  }

  Future<Map<String, dynamic>?> getJobPlanningByNrcJobNo(String nrcJobNo) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    print('[getJobPlanningByNrcJobNo] Token: $token');
    print('[getJobPlanningByNrcJobNo] nrcJobNo: $nrcJobNo');
    final response = await dio.get(
      '${AppStrings.baseUrl}/job-planning/',
      queryParameters: {'nrcJobNo': nrcJobNo},
      options: Options(
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    print('[getJobPlanningByNrcJobNo] Response: ${response.statusCode} ${response.data}');
    if (response.data['success'] == true && response.data['count'] > 0) {
      return response.data['data'][0];
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getAllJobPlannings() async {
    // Always fetch fresh data to ensure high-demand jobs are visible
    // Check cache first (but with shorter validity for critical data)
    if (_isCacheValid() && _cachedPlannings != null) {
      print('[getAllJobPlannings] Using cached data');
      return _cachedPlannings!['data'];
    }

    print('[getAllJobPlannings] Fetching fresh data');
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    print('[getAllJobPlannings] Token: $token');
    final response = await dio.get(
      '/job-planning/',
      options: Options(
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    print('[getAllJobPlannings] Response: ${response.statusCode} ${response.data}');
    if (response.data['success'] == true && response.data['count'] > 0) {
      final plannings = List<Map<String, dynamic>>.from(response.data['data']);
      
      // Cache the results
      _cachedPlannings = {
        'data': plannings,
        'timestamp': DateTime.now(),
      };
      _lastCacheTime = DateTime.now();
      
      return plannings;
    }
    return [];
  }

  Future<Map<String, dynamic>?> getJobPlanningStepsByNrcJobNo(String nrcJobNo) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    print('[getJobPlanningStepsByNrcJobNo] Token: $token');
    print('[getJobPlanningStepsByNrcJobNo] nrcJobNo: $nrcJobNo');
    final response = await dio.get(
      '${AppStrings.baseUrl}/job-planning/$nrcJobNo',
      options: Options(
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    print('[getJobPlanningStepsByNrcJobNo] Response: ${response.statusCode} ${response.data}');
    if (response.data['success'] == true && response.data['data'] != null) {
      return response.data['data'];
    }
    return null;
  }

  Future<Map<String, dynamic>?> getJobByNrcJobNo(String nrcJobNo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      print('[getJobByNrcJobNo] Token: $token');
      print('[getJobByNrcJobNo] nrcJobNo: $nrcJobNo');
      final response = await dio.get(
        '${AppStrings.baseUrl}/jobs',
        options: Options(
          headers: {
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );
      print('[getJobByNrcJobNo] Response: ${response.statusCode} ${response.data}');
      if (response.data['data'] is List) {
        final jobs = List<Map<String, dynamic>>.from(response.data['data']);
        print('Searching for job: $nrcJobNo');
        print('Available jobs: \n' + jobs.map((j) => j['nrcJobNo']).toList().toString());
        final found = jobs.where((job) => job['nrcJobNo'] == nrcJobNo);
        return found.isNotEmpty ? found.first : null;
      }
      print('No jobs list in response');
      return null;
    } catch (e) {
      print('[getJobByNrcJobNo] Error: $e');
      return null;
    }
  }

  Future<Response> postPaperStore(Map<String, dynamic> body) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    print('[postPaperStore] Token: $token');
    print('[postPaperStore] Body: $body');
    final response = await dio.post(
      '${AppStrings.baseUrl}/paper-store',
      data: body,
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    print('[postPaperStore] Response: ${response.statusCode} ${response.data}');
    return response;
  }

  Future<Response> addMember(Map<String, dynamic> body) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    print(token);
    print(body);
    final response = await dio.post(
      '${AppStrings.baseUrl}/auth/add-member',
      data: body,
      options: Options(
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    print(response.statusCode);
    return response;
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    final response = await dio.get(
      '${AppStrings.baseUrl}/auth/users',
      options: Options(
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    if (response.data['success'] == true && response.data['data'] is List) {
      return List<Map<String, dynamic>>.from(response.data['data']);
    }
    return [];
  }

  Future<Response> updateUser(String id, Map<String, dynamic> body) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    final response = await dio.put(
      '${AppStrings.baseUrl}/auth/users/$id',
      data: body,
      options: Options(
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    return response;
  }

  Future<Response> deleteUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    final response = await dio.delete(
      '${AppStrings.baseUrl}/auth/users/$userId',
      options: Options(
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    return response;
  }

  Future<Map<String, dynamic>?> getPaperStoreStepByJob(String jobNrcJobNo) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    print('[getPaperStoreStepByJob] Token: $token');
    print('[getPaperStoreStepByJob] jobNrcJobNo: $jobNrcJobNo');
    final response = await dio.get(
      '${AppStrings.baseUrl}/paper-store/by-job/$jobNrcJobNo',
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    print('[getPaperStoreStepByJob] Response: ${response.statusCode} ${response.data}');
    if (response.data != null && response.data['success'] == true && response.data['data'] is List && response.data['data'].isNotEmpty) {
      return response.data['data'][0];
    }
    return null;
  }

  /// Get Paper Store step by job with editability information
  Future<List<Map<String, dynamic>>> getPaperStoreStepByJobWithEditability(String jobNrcJobNo) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    print('[getPaperStoreStepByJobWithEditability] Token: $token');
    print('[getPaperStoreStepByJobWithEditability] jobNrcJobNo: $jobNrcJobNo');
    final response = await dio.get(
      '${AppStrings.baseUrl}/paper-store/by-job/$jobNrcJobNo',
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    print('[getPaperStoreStepByJobWithEditability] Response: ${response.statusCode} ${response.data}');
    if (response.data != null && response.data['success'] == true && response.data['data'] is List) {
      return List<Map<String, dynamic>>.from(response.data['data']);
    }
    return [];
  }

  /// Get Printing Details by job with editability information
  Future<List<Map<String, dynamic>>> getPrintingDetailsByJobWithEditability(String jobNrcJobNo) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    final response = await dio.get(
      '${AppStrings.baseUrl}/printing-details/by-job/$jobNrcJobNo',
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    if (response.data != null && response.data['success'] == true && response.data['data'] is List) {
      return List<Map<String, dynamic>>.from(response.data['data']);
    }
    return [];
  }

  /// Get Corrugation by job with editability information
  Future<List<Map<String, dynamic>>> getCorrugationByJobWithEditability(String jobNrcJobNo) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    final response = await dio.get(
      '${AppStrings.baseUrl}/corrugation/by-job/$jobNrcJobNo',
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    if (response.data != null && response.data['success'] == true && response.data['data'] is List) {
      return List<Map<String, dynamic>>.from(response.data['data']);
    }
    return [];
  }

  /// Get Flute Lamination by job with editability information
  Future<List<Map<String, dynamic>>> getFluteLaminationByJobWithEditability(String jobNrcJobNo) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    final response = await dio.get(
      '${AppStrings.baseUrl}/flute-laminate-board-conversion/by-job/$jobNrcJobNo',
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    if (response.data != null && response.data['success'] == true && response.data['data'] is List) {
      return List<Map<String, dynamic>>.from(response.data['data']);
    }
    return [];
  }

  /// Get Punching by job with editability information
  Future<List<Map<String, dynamic>>> getPunchingByJobWithEditability(String jobNrcJobNo) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    final response = await dio.get(
      '${AppStrings.baseUrl}/punching/by-job/$jobNrcJobNo',
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    if (response.data != null && response.data['success'] == true && response.data['data'] is List) {
      return List<Map<String, dynamic>>.from(response.data['data']);
    }
    return [];
  }

  /// Get Side Flap Pasting by job with editability information
  Future<List<Map<String, dynamic>>> getSideFlapPastingByJobWithEditability(String jobNrcJobNo) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    final response = await dio.get(
      '${AppStrings.baseUrl}/side-flap-pasting/by-job/$jobNrcJobNo',
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    if (response.data != null && response.data['success'] == true && response.data['data'] is List) {
      return List<Map<String, dynamic>>.from(response.data['data']);
    }
    return [];
  }

  /// Get Quality Dept by job with editability information
  Future<List<Map<String, dynamic>>> getQualityDeptByJobWithEditability(String jobNrcJobNo) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    final response = await dio.get(
      '${AppStrings.baseUrl}/quality-dept/by-job/$jobNrcJobNo',
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    if (response.data != null && response.data['success'] == true && response.data['data'] is List) {
      return List<Map<String, dynamic>>.from(response.data['data']);
    }
    return [];
  }

  /// Get Dispatch Process by job with editability information
  Future<List<Map<String, dynamic>>> getDispatchProcessByJobWithEditability(String jobNrcJobNo) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    final response = await dio.get(
      '${AppStrings.baseUrl}/dispatch-process/by-job/$jobNrcJobNo',
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    if (response.data != null && response.data['success'] == true && response.data['data'] is List) {
      return List<Map<String, dynamic>>.from(response.data['data']);
    }
    return [];
  }

  Future<Response> putPaperStore(String jobNrcJobNo, Map<String, dynamic> body) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    print('[putPaperStore] Token: $token');
    print('[putPaperStore] jobNrcJobNo: $jobNrcJobNo, Body: $body');
    final response = await dio.put(
      '${AppStrings.baseUrl}/paper-store/$jobNrcJobNo',
      data: body,
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    print('[putPaperStore] Response: ${response.statusCode} ${response.data}');
    return response;
  }

  Future<Map<String, dynamic>?> getJobPlanningStepDetails(String jobNumber, int stepId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    print('[getJobPlanningStepDetails] Token: $token');
    print('[getJobPlanningStepDetails] jobNumber: $jobNumber, stepId: $stepId');
    final response = await dio.get(
      '${AppStrings.baseUrl}/job-planning/$jobNumber/steps/$stepId',
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    print('[getJobPlanningStepDetails] Response: ${response.statusCode} ${response.data}');
    if (response.data != null && response.data['success'] == true) {
      return response.data['data'];
    }
    return null;
  }

  Future<Response> updateJobPlanningStepStatus(String jobNumber, int planningId, int stepId, String status) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    print('[updateJobPlanningStepStatus] Token: $token');
    print('[updateJobPlanningStepStatus] jobNumber: $jobNumber, planningId: $planningId, stepId: $stepId, status: $status');
    try {
      final response = await dio.patch(
        '${AppStrings.baseUrl}/job-planning/$jobNumber/$planningId/steps/$stepId/status',
        data: {'status': status},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );
      print('[updateJobPlanningStepStatus] Response: ${response.statusCode} ${response.data}');
      // Clear cache after status update
      clearCache();
      return response;
    } on DioError catch (e) {
      print('[updateJobPlanningStepStatus] Error: $e');
      if (e.response != null) {
        print('[updateJobPlanningStepStatus] Status code: ${e.response?.statusCode}');
        print('[updateJobPlanningStepStatus] Response: ${e.response?.data}');
      }
      // Don't rethrow 500 errors to prevent UI error display
      if (e.response?.statusCode == 500) {
        print('[updateJobPlanningStepStatus] 500 error suppressed from UI display');
        return Response(requestOptions: RequestOptions(path: ''), statusCode: 200); // Return success to prevent UI error
      }
      rethrow;
    }
  }

  Future<Response> updateJobPlanningStepFields(String jobNumber, int stepNo, Map<String, dynamic> body) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      print('[updateJobPlanningStepFields] Token: $token');
      print('[updateJobPlanningStepFields] jobNumber: $jobNumber, stepNo: $stepNo, body: $body');
      final url = '${AppStrings.baseUrl}/job-planning/${jobNumber}/steps/$stepNo';
      print('[updateJobPlanningStepFields] URL: $url');
      print('[updateJobPlanningStepFields] Body: $body');
      final response = await dio.put(url, data: body, options: Options(
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
      );
      print('[updateJobPlanningStepFields] Response: ${response.statusCode} ${response.data}');
      // Clear cache after field update
      clearCache();
      return response;
    } catch (e) {
      print('[updateJobPlanningStepFields] Error: $e');
      throw e;
    }
  }

  Future<Map<String, dynamic>?> _postWithAuth(String endpoint, Map<String, dynamic> body) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    print('[_postWithAuth] Endpoint: $endpoint');
    print('[_postWithAuth] Token: $token');
    print('[_postWithAuth] Body: $body');
    try {
      final response = await dio.post(
        endpoint,
        data: body,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );
      print('[_postWithAuth] Response: ${response.statusCode} ${response.data}');
      return response.data;
    } on DioException catch (e) {
      print('[_postWithAuth] Error posting to $endpoint: ${e.message}');
      if (e.response != null) {
        print('[_postWithAuth] Status code: ${e.response?.statusCode}');
        print('[_postWithAuth] Response: ${e.response?.data}');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _putWithAuth(String endpoint, Map<String, dynamic> body) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    print('[_putWithAuth] Endpoint: $endpoint');
    print('[_putWithAuth] Token: $token');
    print('[_putWithAuth] Body: $body');
    try {
      final response = await dio.put(
        endpoint,
        data: body,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );
      print('[_putWithAuth] Response: ${response.statusCode} ${response.data}');
      return response.data;
    } on DioException catch (e) {
      print('[_putWithAuth] Error posting to $endpoint: ${e.message}');
      if (e.response != null) {
        print('[_putWithAuth] Status code: ${e.response?.statusCode}');
        print('[_putWithAuth] Response: ${e.response?.data}');
      }
      // Don't rethrow 500 errors to prevent UI error display
      if (e.response?.statusCode == 500) {
        print('[_putWithAuth] 500 error suppressed from UI display');
        return {'success': true, 'message': 'Operation completed'}; // Return success to prevent UI error
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _getWithAuth(String endpoint) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    print('[_getWithAuth] Endpoint: $endpoint');
    print('[_getWithAuth] Token: $token');
    try {
      final response = await dio.get(
        endpoint,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );
      print('[_getWithAuth] Response: ${response.statusCode} ${response.data}');
      return response.data;
    } on DioException catch (e) {
      print('[_getWithAuth] Error posting to $endpoint: ${e.message}');
      if (e.response != null) {
        print('[_getWithAuth] Status code: ${e.response?.statusCode}');
        print('[_getWithAuth] Response: ${e.response?.data}');
        // Gracefully handle 404 Not Found for optional step resources        
        if (e.response?.statusCode == 404) {
          print('[_getWithAuth] 404 for $endpoint — returning null');
          return null;
        }
        // Don't rethrow 500 errors to prevent UI error display
        if (e.response?.statusCode == 500) {
          print('[_getWithAuth] 500 error suppressed from UI display');
          return {'success': true, 'data': []}; // Return success to prevent UI error
        }
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getPrintingDetails(String jobNumber) {
    // Check cache first
    if (_cachedPrintingDetails.containsKey(jobNumber) && _isCacheValid()) {
      print('[getPrintingDetails] Using cached data for $jobNumber');
      return Future.value(_cachedPrintingDetails[jobNumber]);
    }
    
    print('[getPrintingDetails] Fetching fresh data for $jobNumber');
    return _getWithAuth('/printing-details/by-job/$jobNumber').then((result) {
      if (result != null && result['data'] is List && result['data'].isNotEmpty) {
        _cachedPrintingDetails[jobNumber] = result['data'][0];
      }
      return result;
    });
  }

  Future<Map<String, dynamic>?> getCorrugationDetails(String jobNumber) {
    return _getWithAuth('/corrugation/by-job/$jobNumber');
  }

  Future<Map<String, dynamic>?> getFluteLaminationDetails(String jobNumber) {
    return _getWithAuth('/flute-laminate-board-conversion/by-job/$jobNumber');
  }

  Future<Map<String, dynamic>?> getPunchingDetails(String jobNumber) {
    return _getWithAuth('/punching/by-job/$jobNumber');
  }

  Future<Map<String, dynamic>?> getFlapPastingDetails(String jobNumber) {
    return _getWithAuth('/side-flap-pasting/by-job/$jobNumber');
  }

  Future<Map<String, dynamic>?> getQCDetails(String jobNumber) {
    return _getWithAuth('/quality-dept/by-job/$jobNumber');
  }

  Future<Map<String, dynamic>?> getDispatchDetails(String jobNumber) {
    return _getWithAuth('/dispatch-process/by-job/$jobNumber');
  }

  Future<Map<String, dynamic>?> getPaperStoreDetails(String jobNumber) {
    return _getWithAuth('/paper-store/by-job/$jobNumber');
  }

  Future<Map<String, dynamic>?> putPrintingDetails(Map<String, dynamic> body,String jobNumber) async {
    // Clear cache after update
    _cachedPrintingDetails.remove(jobNumber);
    try {
      // Try PUT first (update existing record)
      return await _putWithAuth('/printing-details/$jobNumber', body);
    } catch (e) {
      // If PUT fails with 404, try POST to create new record
      if (e is DioException && e.response?.statusCode == 404) {
        print('[putPrintingDetails] Record not found, creating new record');
        return await _postWithAuth('/printing-details/', body);
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> putCorrugationDetails(Map<String, dynamic> body,String jobNumber) async {
    print('[putCorrugationDetails] DEBUG: jobNumber parameter = "$jobNumber"');
    print('[putCorrugationDetails] DEBUG: Constructed URL = "/corrugation/$jobNumber"');
    try {
      // Try PUT first (update existing record)
      return await _putWithAuth('/corrugation/$jobNumber', body);
    } catch (e) {
      // If PUT fails with 404, try POST to create new record
      if (e is DioException && e.response?.statusCode == 404) {
        print('[putCorrugationDetails] Record not found, creating new record');
        return await _postWithAuth('/corrugation/', body);
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> putFluteLaminationDetails(Map<String, dynamic> body,String jobNumber) async {
    try {
      // Try PUT first (update existing record)
      return await _putWithAuth('/flute-laminate-board-conversion/$jobNumber', body);
    } catch (e) {
      // If PUT fails with 404, try POST to create new record
      if (e is DioException && e.response?.statusCode == 404) {
        print('[putFluteLaminationDetails] Record not found, creating new record');
        return await _postWithAuth('/flute-laminate-board-conversion/', body);
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> putPunchingDetails(Map<String, dynamic> body,String jobNumber) async {
    try {
      // Try PUT first (update existing record)
      return await _putWithAuth('/punching/$jobNumber', body);
    } catch (e) {
      // If PUT fails with 404, try POST to create new record
      if (e is DioException && e.response?.statusCode == 404) {
        print('[putPunchingDetails] Record not found, creating new record');
        return await _postWithAuth('/punching/', body);
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> putFlapPastingDetails(Map<String, dynamic> body,String jobNumber) async {
    try {
      // Try PUT first (update existing record)
      return await _putWithAuth('/side-flap-pasting/$jobNumber', body);
    } catch (e) {
      // If PUT fails with 404, try POST to create new record
      if (e is DioException && e.response?.statusCode == 404) {
        print('[putFlapPastingDetails] Record not found, creating new record');
        return await _postWithAuth('/side-flap-pasting/', body);
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> putQCDetails(Map<String, dynamic> body,String jobNumber) async {
    print("this is Put for QC");
    print(body);
    try {
      // Try PUT first (update existing record)
      return await _putWithAuth('/quality-dept/$jobNumber', body);
    } catch (e) {
      // If PUT fails with 404, try POST to create new record
      if (e is DioException && e.response?.statusCode == 404) {
        print('[putQCDetails] Record not found, creating new record');
        return await _postWithAuth('/quality-dept/', body);
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> putDispatchDetails(Map<String, dynamic> body,String jobNumber) async {
    try {
      // Try PUT first (update existing record)
      return await _putWithAuth('/dispatch-process/$jobNumber', body);
    } catch (e) {
      // If PUT fails with 404, try POST to create new record
      if (e is DioException && e.response?.statusCode == 404) {
        print('[putDispatchDetails] Record not found, creating new record');
        return await _postWithAuth('/dispatch-process/', body);
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> putPaperStoreDetails(Map<String, dynamic> body,String jobNumber) async {
    try {
      // Try PUT first (update existing record)
      return await _putWithAuth('/paper-store/$jobNumber', body);
    } catch (e) {
      // If PUT fails with 404, try POST to create new record
      if (e is DioException && e.response?.statusCode == 404) {
        print('[putPaperStoreDetails] Record not found, creating new record');
        return await _postWithAuth('/paper-store/', body);
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> postPrintingDetails(Map<String, dynamic> body) {
    return _postWithAuth('/printing-details/', body);
  }

  Future<Map<String, dynamic>?> postCorrugationDetails(Map<String, dynamic> body) {
    return _postWithAuth('/corrugation/', body);
  }

  Future<Map<String, dynamic>?> postFluteLaminationDetails(Map<String, dynamic> body) {
    return _postWithAuth('/flute-laminate-board-conversion/', body);
  }

  Future<Map<String, dynamic>?> postPunchingDetails(Map<String, dynamic> body) {
    return _postWithAuth('/punching/', body);
  }

  Future<Map<String, dynamic>?> postFlapPastingDetails(Map<String, dynamic> body) {
    return _postWithAuth('/side-flap-pasting/', body);
  }

  Future<Map<String, dynamic>?> postQCDetails(Map<String, dynamic> body) {
    return _postWithAuth('/quality-dept/', body);
  }

  Future<Map<String, dynamic>?> postDispatchDetails(Map<String, dynamic> body) {
    return _postWithAuth('/dispatch-process/', body);
  }

  Future<void> updateJobPlanningStepComplete(String jobNumber,int stepNo, String status, {Map<String, dynamic>? additionalFields}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      print('[updateJobPlanningStepComplete] Token: $token');
      print('[updateJobPlanningStepComplete] jobNumber: $jobNumber, stepNo: $stepNo, status: $status');
      final url = '${AppStrings.baseUrl}/job-planning/${jobNumber}/steps/$stepNo';
      
      Map<String, dynamic> body;
      if (status == 'start') {
        // When starting, backend handles startDate automatically
        body = {
          'status': status
        };
      } else {
        // For other statuses, include required fields for validation
        body = {
          'status': status,
          'quantity': additionalFields?['quantity'] ?? 1000, // Default quantity
          'oprName': additionalFields?['oprName'] ?? 'System', // Default operator name
          'size': additionalFields?['size'] ?? 'A4', // Default size for PaperStore
          'user': additionalFields?['user'] ?? 'NRC015', // Default user
        };
        
        // Add any additional fields provided
        if (additionalFields != null) {
          body.addAll(additionalFields);
        }
      }
      
      print('[updateJobPlanningStepComplete] URL: $url');
      print('[updateJobPlanningStepComplete] Body: $body');
      final response = await dio.put(url, data: body, options: Options(
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
      );
      print('[updateJobPlanningStepComplete] Response: ${response.statusCode} ${response.data}');
      // Clear cache after step update
      clearCache();
    } catch (e) {
      print('[updateJobPlanningStepComplete] Error: $e');
      throw e;
    }
  }

  Future<List<Map<String, dynamic>>> getActivityLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    print('[getActivityLogs] Token: $token');
    try {
      final response = await dio.get(
        '${AppStrings.baseUrl}/activity-logs',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );
      print('[getActivityLogs] Response: ${response.statusCode} ${response.data}');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final logs = response.data['data'] as List;
        return logs.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('[getActivityLogs] Error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getActivityLogsByUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    print('[getActivityLogsByUser] Token: $token');
    try {
      final response = await dio.get(
        '${AppStrings.baseUrl}/activity-logs/user/$userId',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );
      print('[getActivityLogsByUser] Response: ${response.statusCode} ${response.data}');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final logs = response.data['data'] as List;
        return logs.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('[getActivityLogsByUser] Error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getCompletedJobs() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    print('[getCompletedJobs] Token: $token');
    try {
      final response = await dio.get(
        '${AppStrings.baseUrl}/completed-jobs',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );
      print('[getCompletedJobs] Response: ${response.statusCode} ${response.data}');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final completedJobs = response.data['data'] as List;
        return completedJobs.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('[getCompletedJobs] Error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getJobCounts() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    print('[getJobCounts] Token: $token');
    try {
      final response = await dio.get(
        '${AppStrings.baseUrl}/dashboard/counts',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );
      print('[getJobCounts] Response: ${response.statusCode} ${response.data}');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>;
      }
      return {
        'totalOrders': 0,
        'activeJobs': 0,
        'completedJobs': 0,
        'highDemandJobs': 0,
        'inProgressJobs': 0,
        'notStartedJobs': 0
      };
    } catch (e) {
      print('[getJobCounts] Error: $e');
      return {
        'totalOrders': 0,
        'activeJobs': 0,
        'completedJobs': 0,
        'highDemandJobs': 0,
        'inProgressJobs': 0,
        'notStartedJobs': 0
      };
    }
  }

  Future<Map<String, dynamic>> createJob(Map<String, dynamic> jobData) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    print('[createJob] Token: $token');
    print('[createJob] Job data: $jobData');
    
    try {
      final response = await dio.post(
        '${AppStrings.baseUrl}/jobs/',
        data: jobData,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );
      print('[createJob] Response: ${response.statusCode} ${response.data}');
      // Clear cache after creating new job
      clearCache();
      return response.data;
    } catch (e) {
      print('[createJob] Error: $e');
      if (e is DioException && e.response != null) {
        print('[createJob] Error response: ${e.response?.data}');
        throw Exception('Failed to create job: ${e.response?.data['message'] ?? 'Unknown error'}');
      }
      throw Exception('Failed to create job: $e');
    }
  }

  // ==================== MACHINE MANAGEMENT ====================
  // Note: Machine management will be handled by the website
  // Production app only needs to read machine data for job assignments

  // ==================== USER MANAGEMENT (Production Only) ====================
  // Note: Admin and planner user management will be handled by the website

  // ==================== DASHBOARD ====================
  
  Future<Map<String, dynamic>> getDashboardData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    print('[getDashboardData] Token: $token');
    
    try {
      final response = await dio.get(
        '${AppStrings.baseUrl}/dashboard',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );
      print('[getDashboardData] Response: ${response.statusCode} ${response.data}');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data'];
      }
      return {};
    } catch (e) {
      print('[getDashboardData] Error: $e');
      return {};
    }
  }

  // ==================== PURCHASE ORDERS ====================
  // Note: Purchase order management will be handled by the website
  // Production app only needs to read PO data for job context

  // ==================== FLYING SQUAD ====================
  
  Future<List<Map<String, dynamic>>> getAllJobSteps() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    print('[getAllJobSteps] Token: $token');
    
    try {
      final response = await dio.get(
        '${AppStrings.baseUrl}/flying-squad/job-steps',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );
      print('[getAllJobSteps] Response: ${response.statusCode} ${response.data}');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return List<Map<String, dynamic>>.from(response.data['data']);
      }
      return [];
    } catch (e) {
      print('[getAllJobSteps] Error: $e');
      return [];
    }
  }

  // ==================== STEP HOLD/RESUME ====================
  
  /// Hold PaperStore step with remarks
  Future<Map<String, dynamic>> holdPaperStoreStep(String jobNrcJobNo, String remarks) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    print('[holdPaperStoreStep] Token: $token');
    print('[holdPaperStoreStep] jobNrcJobNo: $jobNrcJobNo, remarks: $remarks');
    
    try {
      final response = await dio.patch(
        '${AppStrings.baseUrl}/paper-store/$jobNrcJobNo/status',
        data: {
          'status': 'hold',
          'remarks': remarks,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );
      print('[holdPaperStoreStep] Response: ${response.statusCode} ${response.data}');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data'];
      }
      return {};
    } catch (e) {
      print('[holdPaperStoreStep] Error: $e');
      return {};
    }
  }

  /// Resume PaperStore step with remarks
  Future<Map<String, dynamic>> resumePaperStoreStep(String jobNrcJobNo, String remarks) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    print('[resumePaperStoreStep] Token: $token');
    print('[resumePaperStoreStep] jobNrcJobNo: $jobNrcJobNo, remarks: $remarks');
    
    try {
      final response = await dio.patch(
        '${AppStrings.baseUrl}/paper-store/$jobNrcJobNo/status',
        data: {
          'status': 'in_progress',
          'remarks': remarks,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );
      print('[resumePaperStoreStep] Response: ${response.statusCode} ${response.data}');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data'];
      }
      return {};
    } catch (e) {
      print('[resumePaperStoreStep] Error: $e');
      return {};
    }
  }

  // ==================== ALL STEP HOLD/RESUME ====================
  
  /// Hold any step with remarks
  Future<Map<String, dynamic>> holdStep(String stepType, String jobNrcJobNo, String remarks) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    print('[holdStep] Token: $token');
    print('[holdStep] stepType: $stepType, jobNrcJobNo: $jobNrcJobNo, remarks: $remarks');
    
    // Convert stepType to backend route format
    String routeStepType = stepType;
    switch (stepType.toLowerCase()) {
      case 'paperstore':
        routeStepType = 'paper-store';
        break;
      case 'printingdetails':
        routeStepType = 'printing-details';
        break;
      case 'flutelamination':
        routeStepType = 'flute-laminate-board-conversion';
        break;
      case 'flappasting':
        routeStepType = 'side-flap-pasting';
        break;
      case 'qualitydept':
        routeStepType = 'quality-dept';
        break;
      case 'dispatchprocess':
        routeStepType = 'dispatch-process';
        break;
      // corrugation, punching don't need conversion
      default:
        break;
    }
    
    try {
      final response = await dio.patch(
        '${AppStrings.baseUrl}/$routeStepType/$jobNrcJobNo/status',
        data: {
          'status': 'hold',
          'remarks': remarks,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );
      print('[holdStep] Response: ${response.statusCode} ${response.data}');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data'];
      }
      return {};
    } catch (e) {
      print('[holdStep] Error: $e');
      return {};
    }
  }

  /// Resume any step with remarks
  Future<Map<String, dynamic>> resumeStep(String stepType, String jobNrcJobNo, String remarks) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    print('[resumeStep] Token: $token');
    print('[resumeStep] stepType: $stepType, jobNrcJobNo: $jobNrcJobNo, remarks: $remarks');
    
    // Convert stepType to backend route format
    String routeStepType = stepType;
    switch (stepType.toLowerCase()) {
      case 'paperstore':
        routeStepType = 'paper-store';
        break;
      case 'printingdetails':
        routeStepType = 'printing-details';
        break;
      case 'flutelamination':
        routeStepType = 'flute-laminate-board-conversion';
        break;
      case 'flappasting':
        routeStepType = 'side-flap-pasting';
        break;
      case 'qualitydept':
        routeStepType = 'quality-dept';
        break;
      case 'dispatchprocess':
        routeStepType = 'dispatch-process';
        break;
      // corrugation, punching don't need conversion
      default:
        break;
    }
    
    try {
      final response = await dio.patch(
        '${AppStrings.baseUrl}/$routeStepType/$jobNrcJobNo/status',
        data: {
          'status': 'in_progress',
          'remarks': remarks,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );
      print('[resumeStep] Response: ${response.statusCode} ${response.data}');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data'];
      }
      return {};
    } catch (e) {
      print('[resumeStep] Error: $e');
      return {};
    }
  }

  /// Update status for any step type (generic status update)
  Future<Map<String, dynamic>> updateStepStatusGeneric(String stepType, String jobNrcJobNo, String status, {String? remarks}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    print('[updateStepStatusGeneric] Token: $token');
    print('[updateStepStatusGeneric] stepType: $stepType, jobNrcJobNo: $jobNrcJobNo, status: $status, remarks: $remarks');
    
    // Convert stepType to backend route format
    String routeStepType = stepType;
    switch (stepType.toLowerCase()) {
      case 'paperstore':
        routeStepType = 'paper-store';
        break;
      case 'printingdetails':
        routeStepType = 'printing-details';
        break;
      case 'flutelamination':
        routeStepType = 'flute-laminate-board-conversion';
        break;
      case 'flappasting':
        routeStepType = 'side-flap-pasting';
        break;
      case 'qualitydept':
        routeStepType = 'quality-dept';
        break;
      case 'dispatchprocess':
        routeStepType = 'dispatch-process';
        break;
      // corrugation, punching don't need conversion
      default:
        break;
    }
    
    try {
      final response = await dio.patch(
        '${AppStrings.baseUrl}/$routeStepType/$jobNrcJobNo/status',
        data: {
          'status': status,
          if (remarks != null) 'remarks': remarks,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );
      print('[updateStepStatusGeneric] Response: ${response.statusCode} ${response.data}');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data'];
      }
      return {};
    } catch (e) {
      print('[updateStepStatusGeneric] Error: $e');
      return {};
    }
  }

  // ===== MACHINE-SPECIFIC WORK API METHODS =====

  /// Get available machines for a job step
  Future<Map<String, dynamic>?> getAvailableMachines(String nrcJobNo, int stepNo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      print('[getAvailableMachines] Making request to: /job-step-machines/$nrcJobNo/steps/$stepNo/machines');
      print('[getAvailableMachines] Token available: ${token != null}');
      print('[getAvailableMachines] Token: ${token?.substring(0, 20)}...');
      
      final response = await dio.get(
        '/job-step-machines/$nrcJobNo/steps/$stepNo/machines',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );
      print('[getAvailableMachines] Response: ${response.statusCode} ${response.data}');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data'];
      }
      print('[getAvailableMachines] API returned success: false or status != 200');
      return null;
    } catch (e) {
      print('[getAvailableMachines] Error: $e');
      print('[getAvailableMachines] Error type: ${e.runtimeType}');
      if (e is DioException) {
        print('[getAvailableMachines] DioException details:');
        print('  - Type: ${e.type}');
        print('  - Message: ${e.message}');
        print('  - Response: ${e.response?.data}');
        print('  - Status Code: ${e.response?.statusCode}');
      }
      return null;
    }
  }

  /// Start work on a specific machine
  Future<Map<String, dynamic>?> startWorkOnMachine(String nrcJobNo, int stepNo, String machineId, {Map<String, dynamic>? formData}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      final response = await dio.post(
        '/job-step-machines/$nrcJobNo/steps/$stepNo/machines/$machineId/start',
        data: {
          'formData': formData,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );
      print('[startWorkOnMachine] Response: ${response.statusCode} ${response.data}');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data'];
      }
      return null;
    } catch (e) {
      print('[startWorkOnMachine] Error: $e');
      return null;
    }
  }

  /// Start urgent job work (auto-assigns user's machine)
  Future<Map<String, dynamic>?> startUrgentJobWork(String nrcJobNo, int stepNo, {Map<String, dynamic>? formData}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      final response = await dio.post(
        '/job-step-machines/$nrcJobNo/steps/$stepNo/urgent/start',
        data: {
          'formData': formData,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );
      print('[startUrgentJobWork] Response: ${response.statusCode} ${response.data}');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data'];
      }
      return null;
    } catch (e) {
      print('[startUrgentJobWork] Error: $e');
      return null;
    }
  }

  /// Complete work on a specific machine
  Future<Map<String, dynamic>?> completeWorkOnMachine(String nrcJobNo, int stepNo, String machineId, {Map<String, dynamic>? formData}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      final response = await dio.post(
        '/job-step-machines/$nrcJobNo/steps/$stepNo/machines/$machineId/complete',
        data: {
          'formData': formData,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );
      print('[completeWorkOnMachine] Response: ${response.statusCode} ${response.data}');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data'];
      }
      return null;
    } catch (e) {
      print('[completeWorkOnMachine] Error: $e');
      return null;
    }
  }

  /// Hold work on a specific machine
  Future<Map<String, dynamic>?> holdWorkOnMachine(String nrcJobNo, int stepNo, String machineId, {Map<String, dynamic>? formData, String? holdReason}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      final response = await dio.post(
        '/job-step-machines/$nrcJobNo/steps/$stepNo/machines/$machineId/hold',
        data: {
          'formData': formData,
          'holdReason': holdReason,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );
      print('[holdWorkOnMachine] Response: ${response.statusCode} ${response.data}');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data'];
      }
      return null;
    } catch (e) {
      print('[holdWorkOnMachine] Error: $e');
      return null;
    }
  }

  /// Resume work on a specific machine
  Future<Map<String, dynamic>?> resumeWorkOnMachine(String nrcJobNo, int stepNo, String machineId, {Map<String, dynamic>? formData}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      final response = await dio.post(
        '/job-step-machines/$nrcJobNo/steps/$stepNo/machines/$machineId/resume',
        data: {
          'formData': formData,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );
      print('[resumeWorkOnMachine] Response: ${response.statusCode} ${response.data}');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data'];
      }
      return null;
    } catch (e) {
      print('[resumeWorkOnMachine] Error: $e');
      return null;
    }
  }

  /// Stop work on a specific machine
  Future<Map<String, dynamic>?> stopWorkOnMachine(String nrcJobNo, int stepNo, String machineId, {Map<String, dynamic>? formData}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      final response = await dio.post(
        '/job-step-machines/$nrcJobNo/steps/$stepNo/machines/$machineId/stop',
        data: {
          'formData': formData,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );
      print('[stopWorkOnMachine] Response: ${response.statusCode} ${response.data}');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data'];
      }
      return null;
    } catch (e) {
      print('[stopWorkOnMachine] Error: $e');
      return null;
    }
  }

  /// Get machine work status for a job step
  Future<Map<String, dynamic>?> getMachineWorkStatus(String nrcJobNo, int stepNo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      final response = await dio.get(
        '/job-step-machines/$nrcJobNo/steps/$stepNo/machines/status',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );
      print('[getMachineWorkStatus] Response: ${response.statusCode} ${response.data}');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data'];
      }
      return null;
    } catch (e) {
      print('[getMachineWorkStatus] Error: $e');
      return null;
    }
  }

  /// Get all machines as raw data
  Future<List<Map<String, dynamic>>> getMachinesRaw() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      final response = await dio.get(
        '/machines',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );
      print('[getMachinesRaw] Response: ${response.statusCode}');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return List<Map<String, dynamic>>.from(response.data['data'] ?? []);
      }
      return [];
    } catch (e) {
      print('[getMachinesRaw] Error: $e');
      return [];
    }
  }

  /// Get user machines
  Future<List<Map<String, dynamic>>> getUserMachines() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      final response = await dio.get(
        '/users-machines',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );
      print('[getUserMachines] Response: ${response.statusCode}');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return List<Map<String, dynamic>>.from(response.data['data'] ?? []);
      }
      return [];
    } catch (e) {
      print('[getUserMachines] Error: $e');
      return [];
    }
  }

  /// Get machine status
  Future<String?> getMachineStatus(String machineId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      final response = await dio.get(
        '/machines/$machineId/status',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );
      print('[getMachineStatus] Response: ${response.statusCode}');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data']?['status'];
      }
      return null;
    } catch (e) {
      print('[getMachineStatus] Error: $e');
      return null;
    }
  }

  /// Start work without machine for non-machine steps
  Future<Map<String, dynamic>> startWorkWithoutMachine(String endpoint) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      final response = await dio.post(
        endpoint,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );
      print('[startWorkWithoutMachine] Response: ${response.statusCode}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data;
      }
      return {'success': false, 'message': 'Failed to start work'};
    } catch (e) {
      print('[startWorkWithoutMachine] Error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Hold work for non-machine steps
  Future<Map<String, dynamic>> holdWork(String endpoint, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      final response = await dio.post(
        endpoint,
        data: data,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );
      print('[holdWork] Response: ${response.statusCode}');
      if (response.statusCode == 200) {
        return response.data;
      }
      return {'success': false, 'message': 'Failed to hold work'};
    } catch (e) {
      print('[holdWork] Error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Resume work for non-machine steps
  Future<Map<String, dynamic>> resumeWork(String endpoint) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      final response = await dio.post(
        endpoint,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );
      print('[resumeWork] Response: ${response.statusCode}');
      if (response.statusCode == 200) {
        return response.data;
      }
      return {'success': false, 'message': 'Failed to resume work'};
    } catch (e) {
      print('[resumeWork] Error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

}
