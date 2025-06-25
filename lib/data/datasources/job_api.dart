import 'package:dio/dio.dart';
import '../models/job_model.dart';

class JobApi {
  final Dio dio;

  JobApi(this.dio);

  Future<List<JobModel>> getJobs() async {
    final response = await dio.get('/jobs');
    return (response.data as List).map((e) => JobModel.fromJson(e)).toList();
  }
}
