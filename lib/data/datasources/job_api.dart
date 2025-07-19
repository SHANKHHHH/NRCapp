import 'package:nrc/constants/strings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../models/job_model.dart';
import '../models/Machine.dart'; // Make sure this import exists

class JobApi {
  final Dio dio;

  JobApi(this.dio);

  Future<List<JobModel>> getJobs() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    final response = await dio.get(
      '/jobs',
      options: Options(
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    final List<dynamic> jobList = response.data['data'];
    return jobList.map((e) => JobModel.fromJson(e)).toList();
  }

  Future<void> updateJobStatus(String nrcJobNo, String status) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    print(nrcJobNo);
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
    print(nrcJobNo);
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
    final response = await dio.post(
      'http://51.20.4.108:3000/api/purchase-orders/create',
      data: purchaseOrderData,
      options: Options(
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    return response;
  }

  Future<List<Machine>> getMachines() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    final response = await dio.get(
      'http://51.20.4.108:3000/api/machines',
      options: Options(
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    final List<dynamic> machineList = response.data['data'];
    return machineList.map((e) => Machine.fromJson(e)).toList();
  }

  Future<Response> submitJobPlanning(Map<String, dynamic> body) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    final response = await dio.post(
      'http://51.20.4.108:3000/api/job-planning/',
      data: body,
      options: Options(
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    return response;
  }

  Future<Map<String, dynamic>?> getJobPlanningByNrcJobNo(String nrcJobNo) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    final response = await dio.get(
      'http://51.20.4.108:3000/api/job-planning/',
      queryParameters: {'nrcJobNo': nrcJobNo},
      options: Options(
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    if (response.data['success'] == true && response.data['count'] > 0) {
      return response.data['data'][0];
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getAllJobPlannings() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    final response = await dio.get(
      'http://51.20.4.108:3000/api/job-planning/',
      options: Options(
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    if (response.data['success'] == true && response.data['count'] > 0) {
      return List<Map<String, dynamic>>.from(response.data['data']);
    }
    return [];
  }

  Future<Map<String, dynamic>?> getJobByNrcJobNo(String nrcJobNo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      final response = await dio.get(
        'http://51.20.4.108:3000/api/jobs',
        options: Options(
          headers: {
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );
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
      print('Error in getJobByNrcJobNo: $e');
      return null;
    }
  }
}
