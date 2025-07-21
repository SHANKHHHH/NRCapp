import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../constants/colors.dart';
import 'package:dio/dio.dart';
import '../../../data/datasources/job_api.dart';
import '../../../data/models/job_model.dart';
import '../../../constants/strings.dart';
import '../../pages/job/PendingJobsWorkPage.dart';
import '../../pages/job/AllRecentActivitiesPage.dart';

class PlanningDashboard extends StatefulWidget {
  const PlanningDashboard({super.key});

  @override
  State<PlanningDashboard> createState() => _PlanningDashboardState();
}

class _PlanningDashboardState extends State<PlanningDashboard> {
  bool _isLoading = true;
  String? _error;
  int _activeJobs = 0;
  JobApi? _jobApi;
  List<Map<String, String>> _recentActivities = [];
  List<Map<String, dynamic>> _pendingJobsDetails = [];
  int _pendingPlanningCount = 0;
  Map<String, List<Map<String, String>>> _pendingFieldsByJob = {};
  int _completedToday = 0;

  @override
  void initState() {
    super.initState();
    _initializeApiAndLoad();
  }

  void _initializeApiAndLoad() {
    final dio = Dio();
    dio.options.baseUrl = '${AppStrings.baseUrl}/api';
    _jobApi = JobApi(dio);
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final jobs = await _jobApi!.getJobs();
      final activeJobs = jobs.where((job) => job.status.toLowerCase() == 'active').toList();
      // Recent Activities: filter active jobs, sort by updatedAt desc, map to display info
      final now = DateTime.now();
      final recent = activeJobs
          .where((job) => job.updatedAt != null)
          .toList()
          ..sort((a, b) => b.updatedAt!.compareTo(a.updatedAt!));
      _recentActivities = recent.map((job) {
        final updatedAt = job.updatedAt is String
            ? DateTime.tryParse(job.updatedAt!)
            : job.updatedAt as DateTime?;
        String timeString = '';
        if (updatedAt != null) {
          final diff = now.difference(updatedAt);
          if (diff.inSeconds < 60) {
            timeString = '${diff.inSeconds} sec ago';
          } else if (diff.inMinutes < 60) {
            timeString = '${diff.inMinutes} min ago';
          } else if (diff.inHours < 24) {
            timeString = '${diff.inHours} hr ago';
          } else {
            timeString = '${updatedAt.year}-${updatedAt.month.toString().padLeft(2, '0')}-${updatedAt.day.toString().padLeft(2, '0')}';
          }
        }
        return {
          'nrcJobNo': job.nrcJobNo?.toString() ?? '',
          'status': job.status?.toString() ?? '',
          'time': timeString,
          'artworkReceivedDate': job.artworkReceivedDate?.toString() ?? '',
          'artworkApprovedDate': job.artworkApprovedDate?.toString() ?? '',
          'shadeCardApprovalDate': job.shadeCardApprovalDate?.toString() ?? '',
          'imageURL': job.imageURL?.toString() ?? '',
        };
      }).toList();
      // Pending Jobs details: count all missing fields for each job
      _pendingJobsDetails = [];
      _pendingFieldsByJob = {};
      for (final job in activeJobs) {
        final List<Map<String, String>> pendingFields = [];
        if (job.artworkReceivedDate == null || job.artworkReceivedDate.toString().isEmpty) {
          pendingFields.add({'label': 'Artwork Received Date', 'value': 'Not yet Updated'});
        }
        if (job.artworkApprovedDate == null || job.artworkApprovedDate.toString().isEmpty) {
          pendingFields.add({'label': 'Artwork Approved Date', 'value': 'Not yet Updated'});
        }
        if (job.shadeCardApprovalDate == null || job.shadeCardApprovalDate.toString().isEmpty) {
          pendingFields.add({'label': 'Shade Card Approval Date', 'value': 'Not yet Updated'});
        }
        if (job.imageURL == null || job.imageURL.toString().isEmpty) {
          pendingFields.add({'label': 'Image URL', 'value': 'Not yet Updated'});
        }
        if (pendingFields.isNotEmpty) {
          _pendingJobsDetails.add({
            'nrcJobNo': job.nrcJobNo ?? '',
            'pendingCount': pendingFields.length,
          });
          _pendingFieldsByJob[job.nrcJobNo ?? ''] = pendingFields;
        }
      }
      final pendingPlanningCount = _pendingJobsDetails.length;
      // Completed Today logic (count completed fields today)
      final today = DateTime.now().toUtc();
      final startOfToday = DateTime.utc(today.year, today.month, today.day);
      int completedToday = 0;
      for (final job in jobs) {
        final updatedAt = job.updatedAt is String
            ? DateTime.tryParse(job.updatedAt!)?.toUtc()
            : (job.updatedAt as DateTime?)?.toUtc();
        if (updatedAt == null) continue;
        if (updatedAt.isAfter(startOfToday)) {
          if (job.artworkReceivedDate != null && job.artworkReceivedDate.toString().isNotEmpty) completedToday++;
          if (job.artworkApprovedDate != null && job.artworkApprovedDate.toString().isNotEmpty) completedToday++;
          if (job.shadeCardApprovalDate != null && job.shadeCardApprovalDate.toString().isNotEmpty) completedToday++;
          if (job.imageURL != null && job.imageURL.toString().isNotEmpty) completedToday++;
        }
      }
      setState(() {
        _activeJobs = activeJobs.length;
        _pendingPlanningCount = pendingPlanningCount;
        _completedToday = completedToday;
        _isLoading = false;
      });
    } catch (e) {
      print(e);
      setState(() {
        _error = 'Failed to load dashboard data';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPinkWhite,
      appBar: AppBar(
        title: const Text('Planning Dashboard', style: TextStyle(color: AppColors.white)),
        backgroundColor: AppColors.maincolor,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadDashboardData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDashboardData,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildQuickActions(),
                        const SizedBox(height: 24),
                        _buildMetricsGrid(),
                        const SizedBox(height: 24),
                        _buildPendingJobs(),
                        const SizedBox(height: 24),
                        _buildRecentActivities(),
                      ],
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/all-Jobs'),
        backgroundColor: AppColors.maincolor,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildActionButton(
                  icon: Icons.add_circle_outline,
                  label: 'New Job',
                  onTap: () => context.push('/all-Jobs'),
                ),
                _buildActionButton(
                  icon: Icons.list_alt,
                  label: 'Job List',
                  onTap: () => context.push('/job-list'),
                ),
                _buildActionButton(
                  icon: Icons.assignment,
                  label: 'Reports',
                  onTap: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.maincolor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.maincolor),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: AppColors.maincolor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildMetricCard(
          title: 'Active Jobs',
          value: _activeJobs.toString(),
          icon: Icons.work,
          color: Colors.blue,
        ),
        _buildMetricCard(
          title: 'Pending Planning',
          value: _pendingPlanningCount.toString(),
          icon: Icons.pending_actions,
          color: Colors.orange,
        ),
        _buildMetricCard(
          title: 'Completed Today',
          value: _completedToday.toString(),
          icon: Icons.check_circle_outline,
          color: Colors.green,
        ),
        _buildMetricCard(
          title: 'Delayed Jobs',
          value: '3', // static for now
          icon: Icons.warning_outlined,
          color: Colors.red,
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingJobs() {
    if (_pendingJobsDetails.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Text(
              'No pending jobs',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pending Jobs',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            ..._pendingJobsDetails.map((job) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: InkWell(
                    onTap: () {
                      final nrcJobNo = job['nrcJobNo'] as String;
                      final pendingFieldsRaw = _pendingFieldsByJob[nrcJobNo] ?? [];
                      // Convert to List<Map<String, String>> by replacing nulls with ''
                      final pendingFields = pendingFieldsRaw
                          .map((m) => m.map((k, v) => MapEntry(k, v ?? "")))
                          .toList();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => PendingJobsWorkPage(
                            nrcJobNo: nrcJobNo,
                            pendingFields: pendingFields,
                          ),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('Job: ${job['nrcJobNo']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${job['pendingCount']} pending works',
                            style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivities() {
    if (_recentActivities.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Text(
              'No recent activities',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }
    // Show only top 3
    final topActivities = _recentActivities.take(3).toList();
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AllRecentActivitiesPage(activities: _recentActivities),
          ),
        );
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Recent Activities',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              ...topActivities.map((activity) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Job ${activity['nrcJobNo']} - Status: ${activity['status']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          activity['time'] ?? '',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )),
              if (_recentActivities.length > 3)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Tap to see all...', style: TextStyle(color: Colors.blue)),
                ),
            ],
          ),
        ),
      ),
    );
  }
} 