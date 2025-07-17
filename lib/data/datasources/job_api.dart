import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../models/job_model.dart';

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
}
