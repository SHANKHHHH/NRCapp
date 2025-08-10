import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:nrc/constants/colors.dart';
import '../../../data/models/Job.dart';
import '../../../data/models/purchase_order.dart';
import '../../../data/models/WorkStepAssignment.dart';
import '../job/JobStep.dart';
import 'WorkDetailsScreen.dart';
import '../../../data/datasources/job_api.dart';

class WorkScreen extends StatefulWidget {
  const WorkScreen({Key? key}) : super(key: key);

  @override
  State<WorkScreen> createState() => _WorkScreenState();
}

class _WorkScreenState extends State<WorkScreen> with TickerProviderStateMixin {
  List<Map<String, dynamic>> jobPlannings = [];
  List<Map<String, dynamic>> filteredJobPlannings = [];
  bool _isLoading = true;
  String? _error;
  Map<String, String> jobStatuses = {}; // nrcJobNo -> status
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;

  String _formatJobDemand(String demand) {
    switch (demand.toLowerCase()) {
      case 'high':
        return 'Urgent';
      case 'medium':
        return 'Regular';
      default:
        return demand;
    }
  }

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _blinkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );
    _blinkController.repeat(reverse: true);
    _fetchAllJobPlannings();
    _searchController.addListener(_filterJobs);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  void _filterJobs() {
    final query = _searchController.text.toLowerCase();
    print('Search query: "$query"');
    print('Total jobs: ${jobPlannings.length}');
    
    setState(() {
      if (query.isEmpty) {
        filteredJobPlannings = jobPlannings;
        print('No query - showing all jobs: ${filteredJobPlannings.length}');
      } else {
        filteredJobPlannings = jobPlannings
            .where((job) {
              // Search across multiple fields
              final nrcJobNo = job['nrcJobNo']?.toString().toLowerCase() ?? '';
              final jobPlanId = job['jobPlanId']?.toString().toLowerCase() ?? '';
              final jobDemand = job['jobDemand']?.toString().toLowerCase() ?? '';
              final createdAt = job['createdAt']?.toString().toLowerCase() ?? '';
              
              final matches = nrcJobNo.contains(query) ||
                             jobPlanId.contains(query) ||
                             jobDemand.contains(query) ||
                             createdAt.contains(query);
              
              print('Job ${job['nrcJobNo']}: nrcJobNo="$nrcJobNo", jobPlanId="$jobPlanId", jobDemand="$jobDemand" - contains "$query" = $matches');
              return matches;
            })
            .toList();
        print('Filtered jobs: ${filteredJobPlannings.length}');
      }
    });
  }

  Future<void> _fetchAllJobPlannings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final dio = Dio();
      final jobApi = JobApi(dio);
      // Ensure fresh data from endpoint instead of cached data
      JobApi.clearCache();
      final plannings = await jobApi.getAllJobPlannings();

      // Fetch statuses in small batches to avoid server overload
      Future<Map<String, String>> fetchStatusesInChunks(
          List<Map<String, dynamic>> items, int chunkSize) async {
        final Map<String, String> statuses = {};
        for (int i = 0; i < items.length; i += chunkSize) {
          final chunk = items.sublist(i, i + chunkSize > items.length ? items.length : i + chunkSize);
          final results = await Future.wait(chunk.map((planning) async {
            final nrcJobNo = planning['nrcJobNo'];
            try {
              final jobs = await jobApi.getJobsByNo(nrcJobNo);
              if (jobs.isNotEmpty) {
                return MapEntry(nrcJobNo, jobs[0].status.toString().toUpperCase());
              }
            } catch (_) {}
            return null;
          }));
          for (final entry in results) {
            if (entry != null) {
              statuses[entry.key] = entry.value;
            }
          }
        }
        return statuses;
      }

      final statuses = await fetchStatusesInChunks(plannings, 5);

      setState(() {
        jobPlannings = plannings;
        filteredJobPlannings = plannings; // Initialize filtered list
        jobStatuses = statuses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load job plannings';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Work Assignment'),
        backgroundColor: AppColors.maincolor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            )
                : const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchAllJobPlannings,
            tooltip: 'Reload',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    offset: const Offset(0, 2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  _filterJobs();
                },
                decoration: InputDecoration(
                  hintText: 'Search by Job Number, Plan ID, Demand...',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  prefixIcon: Icon(Icons.search, color: Colors.blue),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.grey[600]),
                    onPressed: () {
                      _searchController.clear();
                      _filterJobs(); // Also trigger filter when clearing
                    },
                  )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : filteredJobPlannings.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchController.text.isNotEmpty
                  ? Icons.search_off
                  : Icons.work_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isNotEmpty
                  ? 'No jobs found matching "${_searchController.text}"'
                  : 'No job plannings found.',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredJobPlannings.length,
        itemBuilder: (context, index) {
          final planning = filteredJobPlannings[index];
          return _buildSummaryCard(context, planning);
        },
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, Map<String, dynamic> jobPlanning) {
    print(jobStatuses);
    print('this is Jon Status');
    final nrcJobNo = jobPlanning['nrcJobNo'];
    final status = jobStatuses[nrcJobNo] ?? '';
    // Avoid triggering network calls during build; fetch on tap only
    final isHold = status == 'HOLD';

    return GestureDetector(
      onTap: () async {
        if (isHold) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Work on Hold'),
              content: const Text('This Work is in hold, Contact to admin'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          // Fetch job planning steps and navigate to JobTimelinePage
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(child: CircularProgressIndicator()),
          );
          final dio = Dio();
          final jobApi = JobApi(dio);
          final planning = await jobApi.getJobPlanningStepsByNrcJobNo(jobPlanning['nrcJobNo']);
          Navigator.of(context).pop(); // Remove loader
          final steps = planning?['steps'] ?? [];
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => JobTimelinePage(
                jobNumber: jobPlanning['nrcJobNo'],
                assignedSteps: steps,
              ),
            ),
          );
        }
      },
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.only(bottom: 16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.grey[50]!,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WORK ASSIGNMENT',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.maincolor,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        if (isHold)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'HOLD',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        if (_formatJobDemand(jobPlanning['jobDemand'] ?? '').toLowerCase() == 'urgent')
                          AnimatedBuilder(
                            animation: _blinkAnimation,
                            builder: (context, child) {
                              return Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.red.withOpacity(_blinkAnimation.value * 0.6),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  'U',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildSummaryItem(
                  icon: Icons.confirmation_number,
                  title: 'Job Plan ID',
                  value: jobPlanning['jobPlanId'].toString(),
                  color: Colors.blue,
                ),
                _buildSummaryItem(
                  icon: Icons.work,
                  title: 'NRC Job No',
                  value: jobPlanning['nrcJobNo'] ?? '',
                  color: Colors.blue,
                ),
                _buildSummaryItem(
                  icon: Icons.trending_up,
                  title: 'Job Demand',
                  value: _formatJobDemand(jobPlanning['jobDemand'] ?? ''),
                  color: Colors.purple,
                ),
                _buildSummaryItem(
                  icon: Icons.calendar_today,
                  title: 'Created At',
                  value: jobPlanning['createdAt'] ?? '',
                  color: Colors.green,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WorkDetailsScreen(
                            nrcJobNo: jobPlanning['nrcJobNo'],
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.maincolor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 2,
                    ),
                    child: const Text(
                      'View Complete Details',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}