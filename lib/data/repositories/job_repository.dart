import '../datasources/job_api.dart';
import '../models/job_model.dart';

class JobRepository {
  final JobApi api;

  JobRepository(this.api);

  Future<List<JobModel>> fetchJobs() => api.getJobs();
}
