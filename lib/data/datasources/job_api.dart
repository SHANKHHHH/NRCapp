import 'package:nrc/constants/strings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../models/job_model.dart';
import '../models/Machine.dart'; // Make sure this import exists
import '../models/Job.dart'; // Added import for Job model

class JobApi {
  final Dio dio;

  JobApi(this.dio);

  Future<List<JobModel>> getJobs() async {
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
    return jobList.map((e) => JobModel.fromJson(e)).toList();
  }

  Future<List<Job>> getJobsByNo(String nrcJobNo) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    print('[getJobs] Token: $token');
    final response = await dio.get(
      'https://nrc-backend-his4.onrender.com/api/jobs/$nrcJobNo',
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
  }

  Future<void> updateJobField(String nrcJobNo, Map<String, dynamic> fields) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    print('[updateJobField] Token: $token');
    print('[updateJobField] nrcJobNo: $nrcJobNo, fields: $fields');
    await dio.put(
      '/api/jobs/$nrcJobNo',
      data: fields,
      options: Options(
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
  }

  Future<Response> createPurchaseOrder(Map<String, dynamic> purchaseOrderData) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    print('[createPurchaseOrder] Token: $token');
    print('[createPurchaseOrder] Data: $purchaseOrderData');
    final response = await dio.post(
      'https://nrc-backend-his4.onrender.com/api/purchase-orders/create',
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
      'https://nrc-backend-his4.onrender.com/api/machines',
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
      'http://nrc-backend-his4.onrender.com/api/job-planning/',
      data: body,
      options: Options(
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    print('[submitJobPlanning] Response: ${response.statusCode} ${response.data}');
    return response;
  }

  Future<Map<String, dynamic>?> getJobPlanningByNrcJobNo(String nrcJobNo) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    print('[getJobPlanningByNrcJobNo] Token: $token');
    print('[getJobPlanningByNrcJobNo] nrcJobNo: $nrcJobNo');
    final response = await dio.get(
      'https://nrc-backend-his4.onrender.com/api/job-planning/',
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
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    print('[getAllJobPlannings] Token: $token');
    final response = await dio.get(
      'https://nrc-backend-his4.onrender.com/api/job-planning/',
      options: Options(
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    print('[getAllJobPlannings] Response: ${response.statusCode} ${response.data}');
    if (response.data['success'] == true && response.data['count'] > 0) {
      return List<Map<String, dynamic>>.from(response.data['data']);
    }
    return [];
  }

  Future<Map<String, dynamic>?> getJobPlanningStepsByNrcJobNo(String nrcJobNo) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    print('[getJobPlanningStepsByNrcJobNo] Token: $token');
    print('[getJobPlanningStepsByNrcJobNo] nrcJobNo: $nrcJobNo');
    final response = await dio.get(
      'https://nrc-backend-his4.onrender.com/api/job-planning/$nrcJobNo',
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
        'https://nrc-backend-his4.onrender.com/api/jobs',
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
      'https://nrc-backend-his4.onrender.com/api/paper-store',
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
      'https://nrc-backend-his4.onrender.com/api/auth/add-member',
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
      'https://nrc-backend-his4.onrender.com/api/auth/users',
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
      'https://nrc-backend-his4.onrender.com/api/auth/users/$id',
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
      'https://nrc-backend-his4.onrender.com/api/auth/users/$userId',
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
      'https://nrc-backend-his4.onrender.com/api/paper-store/by-job/$jobNrcJobNo',
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

  Future<Response> putPaperStore(String jobNrcJobNo, Map<String, dynamic> body) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    print('[putPaperStore] Token: $token');
    print('[putPaperStore] jobNrcJobNo: $jobNrcJobNo, Body: $body');
    final response = await dio.put(
      'https://nrc-backend-his4.onrender.com/api/paper-store/$jobNrcJobNo',
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
      'https://nrc-backend-his4.onrender.com/api/job-planning/$jobNumber/steps/$stepId',
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
        'https://nrc-backend-his4.onrender.com/api/job-planning/$jobNumber/$planningId/steps/$stepId/status',
        data: {'status': status},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );
      print('[updateJobPlanningStepStatus] Response: ${response.statusCode} ${response.data}');
      return response;
    } on DioError catch (e) {
      print('[updateJobPlanningStepStatus] Error: $e');
      if (e.response != null) {
        print('[updateJobPlanningStepStatus] Status code: ${e.response?.statusCode}');
        print('[updateJobPlanningStepStatus] Response: ${e.response?.data}');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _postWithAuth(String endpoint, Map<String, dynamic> body) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    print('[_postWithAuth] Endpoint: $endpoint');
    print('[_postWithAuth] Token: $token');
    print('[_postWithAuth] Body: $body');
    try {
      final response = await Dio().post(
        '${AppStrings.baseUrl}/api$endpoint',
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
      final response = await Dio().put(
        '${AppStrings.baseUrl}/api$endpoint',
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
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> putPrintingDetails(Map<String, dynamic> body) {
    return _postWithAuth('/printing-details/', body);
  }

  Future<Map<String, dynamic>?> putCorrugationDetails(Map<String, dynamic> body) {
    return _postWithAuth('/corrugation/', body);
  }

  Future<Map<String, dynamic>?> putFluteLaminationDetails(Map<String, dynamic> body) {
    return _postWithAuth('/flute-laminate-board-conversion/', body);
  }

  Future<Map<String, dynamic>?> putPunchingDetails(Map<String, dynamic> body) {
    return _postWithAuth('/punching/', body);
  }

  Future<Map<String, dynamic>?> putFlapPastingDetails(Map<String, dynamic> body) {
    return _postWithAuth('/side-flap-pasting/', body);
  }

  Future<Map<String, dynamic>?> putQCDetails(Map<String, dynamic> body) {
    return _postWithAuth('/quality-dept/', body);
  }

  Future<Map<String, dynamic>?> putDispatchDetails(Map<String, dynamic> body) {
    return _postWithAuth('/dispatch-process/', body);
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

  Future<void> updateJobPlanningStepComplete(String jobNumber,int stepNo, String status) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      print('[updateJobPlanningStepComplete] Token: $token');
      print('[updateJobPlanningStepComplete] jobNumber: $jobNumber, stepNo: $stepNo, status: $status');
      final url = '${AppStrings.baseUrl}/api/job-planning/${jobNumber}/steps/$stepNo';
      final body = {
        'endDate': DateTime.now().toUtc().toIso8601String(),
        'status': status
      };
      print('[updateJobPlanningStepComplete] URL: $url');
      print('[updateJobPlanningStepComplete] Body: $body');
      final response = await dio.patch(url, data: body, options: Options(
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
      );
      print('[updateJobPlanningStepComplete] Response: ${response.statusCode} ${response.data}');
    } catch (e) {
      print('[updateJobPlanningStepComplete] Error: $e');
      throw e;
    }
  }

}
