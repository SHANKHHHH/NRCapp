import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../constants/colors.dart';
import 'package:dio/dio.dart';
import '../../../data/datasources/job_api.dart';
import '../../../constants/strings.dart';
import '../../pages/job/PendingJobsWorkPage.dart';
import '../../pages/job/AllRecentActivitiesPage.dart';
import 'package:fl_chart/fl_chart.dart';

class PlanningDashboard extends StatefulWidget {
  const PlanningDashboard({super.key});

  @override
  State<PlanningDashboard> createState() => _PlanningDashboardState();
}

class _PlanningDashboardState extends State<PlanningDashboard> with TickerProviderStateMixin {
  bool _isLoading = true;
  String? _error;
  int _activeJobs = 0;
  JobApi? _jobApi;
  List<Map<String, String>> _recentActivities = [];
  List<Map<String, dynamic>> _pendingJobsDetails = [];
  int _pendingPlanningCount = 0;
  Map<String, List<Map<String, String>>> _pendingFieldsByJob = {};
  int _completedToday = 0;
  int _artworkPending = 0;
  int _artworkComplete = 0;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Additional colors for the palette
  static const Color lightGrey = Color(0xFFF5F5F5);
  static const Color successGreen = Color(0xFF4CAF50);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _initializeApiAndLoad();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
      int artworkPending = 0;
      int artworkComplete = 0;
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
          artworkPending++;
        } else {
          artworkComplete++;
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
        _artworkPending = artworkPending;
        _artworkComplete = artworkComplete;
        _isLoading = false;
      });

      _animationController.forward();
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
      backgroundColor: Colors.white,
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: lightGrey,
                borderRadius: BorderRadius.circular(20),
              ),
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.maincolor),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Loading Dashboard...',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      )
          : _error != null
          ? Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _error!,
                style: TextStyle(
                  color: Colors.grey[800],
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadDashboardData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.maincolor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      )
          : FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          slivers: [
            _buildSliverAppBar(),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeSection(),
                    const SizedBox(height: 32),
                    _buildQuickActions(),
                    const SizedBox(height: 32),
                    _buildMetricsGrid(),
                    const SizedBox(height: 32),
                    _buildPlanningStatusChart(),
                    const SizedBox(height: 24),
                    _buildMissingFieldsBarChart(),
                    const SizedBox(height: 32),
                    _buildPendingJobs(),
                    const SizedBox(height: 32),
                    _buildRecentActivities(),
                    const SizedBox(height: 32), // Reduced bottom padding
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.maincolor.withOpacity(0.05),
                Colors.white,
              ],
            ),
          ),
        ),
      ),
      title: const Text(
        'Planning Dashboard',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: lightGrey,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.refresh_rounded,
                color: AppColors.maincolor,
                size: 20,
              ),
            ),
            onPressed: _loadDashboardData,
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeSection() {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good Morning!';
    } else if (hour < 17) {
      greeting = 'Good Afternoon!';
    } else {
      greeting = 'Good Evening!';
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.maincolor.withOpacity(0.08),
            AppColors.maincolor.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.maincolor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ready to manage your projects efficiently today?',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.maincolor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.insights_rounded,
              color: AppColors.maincolor,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.add_circle_outline_rounded,
                label: 'New Job',
                onTap: () => context.push('/all-Jobs'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionButton(
                icon: Icons.list_alt_rounded,
                label: 'Job List',
                onTap: () => context.push('/job-list'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: lightGrey,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.maincolor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: AppColors.maincolor,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[800],
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          childAspectRatio: 1, // Increased aspect ratio to reduce height
          children: [
            _buildMetricCard(
              title: 'Active Jobs',
              value: _activeJobs.toString(),
              icon: Icons.work_outline_rounded,
              color: AppColors.maincolor,
              trend: '+12%',
            ),
            _buildMetricCard(
              title: 'Pending Planning',
              value: _pendingPlanningCount.toString(),
              icon: Icons.pending_actions_rounded,
              color: Colors.orange,
            ),
            _buildMetricCard(
              title: 'Completed Today',
              value: _completedToday.toString(),
              icon: Icons.check_circle_outline_rounded,
              color: successGreen,
              trend: '+5',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlanningStatusChart() {
    final entries = [
      {
        'label': 'Artwork Complete',
        'count': _artworkComplete,
        'color': const Color(0xFF4CAF50),
      },
      {
        'label': 'Pending Artwork',
        'count': _artworkPending,
        'color': Colors.orange,
      },
    ].where((e) => (e['count'] as int) > 0).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: lightGrey, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Artwork Status',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('No data to display', style: TextStyle(color: Colors.grey[600])),
              ),
            )
          else ...[
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 4,
                  centerSpaceRadius: 36,
                  sections: entries
                      .map(
                        (e) => PieChartSectionData(
                          color: e['color'] as Color,
                          value: (e['count'] as int).toDouble(),
                          title: (e['count'] as int).toString(),
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: entries
                  .map(
                    (e) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: e['color'] as Color, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text('${e['label']}: ${e['count']}', style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600)),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMissingFieldsBarChart() {
    if (_pendingJobsDetails.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(color: lightGrey, width: 1.5),
        ),
        child: Center(
          child: Text('No pending fields to display', style: TextStyle(color: Colors.grey[600])),
        ),
      );
    }

    final top = _pendingJobsDetails.take(5).toList();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: lightGrey, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Pending Jobs (by missing fields)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                barGroups: [
                  for (int i = 0; i < top.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: (top[i]['pendingCount'] as int).toDouble(),
                          color: AppColors.maincolor,
                          width: 14,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                ],
                gridData: FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= top.length) return SizedBox.shrink();
                        final jobNo = (top[idx]['nrcJobNo'] as String);
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            jobNo,
                            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                          ),
                        );
                      },
                      reservedSize: 44,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? trend,
  }) {
    return Container(
      padding: const EdgeInsets.all(16), // Reduced padding
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: lightGrey,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween, // Better distribution
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 40, // Slightly smaller
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20, // Smaller icon
                ),
              ),
              if (trend != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: successGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    trend,
                    style: TextStyle(
                      color: successGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8), // Fixed spacing
          Text(
            value,
            style: TextStyle(
              fontSize: 24, // Smaller font
              fontWeight: FontWeight.w700,
              color: Colors.grey[800],
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
              fontSize: 13, // Smaller font
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPendingJobs() {
    final topPendingJobs = _pendingJobsDetails.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Pending Jobs',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.grey[800],
              ),
            ),
            if (_pendingJobsDetails.length > 3)
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => AllPendingJobsPage(
                        pendingJobs: _pendingJobsDetails,
                        pendingFieldsByJob: _pendingFieldsByJob,
                      ),
                    ),
                  );
                },
                child: Text(
                  'View All (${_pendingJobsDetails.length})',
                  style: TextStyle(
                    color: AppColors.maincolor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_pendingJobsDetails.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: lightGrey,
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: successGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.check_circle_outline_rounded,
                    color: successGreen,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No pending jobs',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'All jobs are up to date!',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: lightGrey,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: topPendingJobs.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: lightGrey,
              ),
              itemBuilder: (context, index) {
                final job = topPendingJobs[index];
                return InkWell(
                  onTap: () {
                    final nrcJobNo = job['nrcJobNo'] as String;
                    final pendingFieldsRaw = _pendingFieldsByJob[nrcJobNo] ?? [];
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
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.pending_actions_rounded,
                            color: Colors.orange,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Job ${job['nrcJobNo']}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${job['pendingCount']} pending tasks',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.grey[400],
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildRecentActivities() {
    final topActivities = _recentActivities.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Activities',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.grey[800],
              ),
            ),
            if (_recentActivities.length > 3)
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => AllRecentActivitiesPage(activities: _recentActivities),
                    ),
                  );
                },
                child: Text(
                  'View All',
                  style: TextStyle(
                    color: AppColors.maincolor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_recentActivities.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: lightGrey,
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.timeline_rounded,
                    color: Colors.grey[500],
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No recent activities',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: lightGrey,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: topActivities.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: lightGrey,
              ),
              itemBuilder: (context, index) {
                final activity = topActivities[index];
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.maincolor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Job ${activity['nrcJobNo']}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Status: ${activity['status']}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: lightGrey,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          activity['time'] ?? '',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

// All Pending Jobs Page
class AllPendingJobsPage extends StatelessWidget {
  final List<Map<String, dynamic>> pendingJobs;
  final Map<String, List<Map<String, String>>> pendingFieldsByJob;

  const AllPendingJobsPage({
    super.key,
    required this.pendingJobs,
    required this.pendingFieldsByJob,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'All Pending Jobs',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: pendingJobs.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                color: Color(0xFF4CAF50),
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No pending jobs',
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'All jobs are up to date!',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.orange.withOpacity(0.08),
                    Colors.orange.withOpacity(0.02),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.pending_actions_rounded,
                      color: Colors.orange,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${pendingJobs.length} Pending Jobs',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Jobs requiring your attention',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: pendingJobs.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final job = pendingJobs[index];
                final nrcJobNo = job['nrcJobNo'] as String;
                final pendingCount = job['pendingCount'] as int;
                final pendingFields = pendingFieldsByJob[nrcJobNo] ?? [];

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFF5F5F5),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: InkWell(
                    onTap: () {
                      final pendingFieldsFormatted = pendingFields
                          .map((m) => m.map((k, v) => MapEntry(k, v ?? "")))
                          .toList();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              PendingJobsWorkPage(
                                nrcJobNo: nrcJobNo,
                                pendingFields: pendingFieldsFormatted,
                              ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.work_outline_rounded,
                                  color: Colors.orange,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Job $nrcJobNo',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$pendingCount pending tasks',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$pendingCount',
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: Colors.grey[400],
                                size: 16,
                              ),
                            ],
                          ),
                          if (pendingFields.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Divider(height: 1, color: Color(0xFFF5F5F5)),
                            const SizedBox(height: 16),
                            Text(
                              'Pending Tasks:',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...pendingFields.take(3).map((field) =>
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: Colors.orange,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          field['label'] ?? '',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                            if (pendingFields.length > 3)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '+${pendingFields.length - 3} more tasks',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}