import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nrc/constants/colors.dart';
import '../../../data/models/Job.dart';
import '../../../data/models/purchase_order.dart';
import '../../../data/models/WorkStepAssignment.dart';
import '../job/JobStep.dart';
import 'WorkDetailsScreen.dart';
import '../../../data/datasources/job_api.dart';
import '../../routes/UserRoleManager.dart';
import '../../../core/services/dio_service.dart';
import '../process/JobApiService.dart';

class WorkScreen extends StatefulWidget {
  const WorkScreen({Key? key}) : super(key: key);

  @override
  State<WorkScreen> createState() => _WorkScreenState();
}

class _WorkScreenState extends State<WorkScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  List<Map<String, dynamic>> jobPlannings = [];
  List<Map<String, dynamic>> filteredJobPlannings = [];
  bool _isLoading = true;
  String? _error;
  Map<String, String> jobStatuses = {}; // nrcJobNo -> status
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;
  final Set<String> _expandedJobNos = {};
  String? _userRole;

  bool get _isAdminOrPlanner {
    final role = _userRole?.toLowerCase() ?? UserRoleManager().userRole?.toLowerCase();
    return role == 'admin' || role == 'planner';
  }

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
    WidgetsBinding.instance.addObserver(this);
    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _blinkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );
    _blinkController.repeat(reverse: true);
    _searchController.addListener(_filterJobs);
    _initializePage();
  }

  Future<void> _initializePage() async {
    await UserRoleManager().loadUserRole();
    
    // Clear all caches to prevent cross-user contamination
    await _clearAllCaches();
    
    // Check if widget is still mounted before setting state
    if (!mounted) return;
    setState(() {
      _userRole = UserRoleManager().userRole;
    });
    await _fetchAllJobPlannings();
  }

  DateTime? _lastResumeRefresh;
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Only refresh if it's been more than 30 seconds since last refresh
      final now = DateTime.now();
      if (_lastResumeRefresh == null || 
          now.difference(_lastResumeRefresh!) > const Duration(seconds: 30)) {
        _lastResumeRefresh = now;
        // Refresh data when app becomes active again (throttled)
        _fetchAllJobPlannings(); // Don't clear cache on resume, just refresh data
      }
    }
  }

  @override
  void dispose() {
    // Cancel any ongoing operations to prevent setState calls after dispose
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  void _filterJobs() {
    final query = _searchController.text.toLowerCase();
    print('Search query: "$query"');
    print('Total jobs: ${jobPlannings.length}');
    
    // Check if widget is still mounted before setting state
    if (!mounted) return;
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

  Future<void> _clearAllCaches() async {
    print('DEBUG: Manual cache clear triggered...');
    
    // Clear JobApi cache (data cache only)
    JobApi.clearCache();
    print('DEBUG: Cleared JobApi cache');
    
    // Clear JobApiService cache
    try {
      final dio = DioService.instance;
      final jobApi = JobApi(dio);
      final jobApiService = JobApiService(jobApi);
      jobApiService.invalidateJobCaches('ALL_JOBS');
      print('DEBUG: Cleared JobApiService cache');
    } catch (e) {
      print('DEBUG: Error clearing JobApiService cache: $e');
    }
    
    // Clear only data-related SharedPreferences, keep auth data
    final prefs = await SharedPreferences.getInstance();
    // Remove only data cache keys, keep authentication
    await prefs.remove('cached_jobs');
    await prefs.remove('cached_job_plannings');
    await prefs.remove('cached_machines');
    await prefs.remove('cached_users');
    await prefs.remove('cached_dashboard');
    await prefs.remove('cached_purchase_orders');
    print('DEBUG: Cleared data cache, kept authentication');
    
    // Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jobs reloaded successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
    
    // Refresh the data immediately
    await _fetchAllJobPlannings();
    
    print('DEBUG: Data cache cleared and refreshed.');
  }

  Future<void> _fetchAllJobPlannings() async {
    // Check if widget is still mounted before setting state
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final dio = DioService.instance;
      final jobApi = JobApi(dio);
      // Force clear all caches to ensure fresh data
      JobApi.clearCache();
      
      // DEBUG: Clear all SharedPreferences cache
      final prefs = await SharedPreferences.getInstance();
      print('🔍 [Frontend] Clearing all cached data...');
      print('🔍 [Frontend] Current user ID: ${await prefs.getString('userId')}');
      print('🔍 [Frontend] Current access token: ${await prefs.getString('accessToken')}');
      print('🔍 [Frontend] Current user role: ${await prefs.getString('userRole')}');
      print('🔍 [Frontend] Current user roles: ${await prefs.getString('userRoles')}');
      
      // Clear ALL data caches, keep only authentication
      await prefs.remove('cached_jobs');
      await prefs.remove('cached_job_plannings');
      await prefs.remove('cached_machines');
      await prefs.remove('cached_users');
      await prefs.remove('cached_dashboard');
      await prefs.remove('cached_purchase_orders');
      await prefs.remove('cached_activity_logs');
      await prefs.remove('cached_status_overview');
      print('🔍 [Frontend] Cleared all data cache, kept authentication');
      
      // Clear JobApiService cache as well
      try {
        final jobApiService = JobApiService(jobApi);
        // Clear all caches in JobApiService
        jobApiService.invalidateJobCaches('ALL_JOBS');
        print('DEBUG: Cleared JobApiService cache');
      } catch (e) {
        print('DEBUG: Error clearing JobApiService cache: $e');
      }
      
      // Show debug info
      print('🔍 [Frontend] Data cache cleared, proceeding with fresh data fetch...');
      final plannings = await jobApi.getAllJobPlanningsFresh();

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

      // For specific operator roles, show all jobs assigned to them (backend already filters correctly)
      // The backend filtering is sufficient - no need for additional frontend filtering
      Future<List<Map<String, dynamic>>> _filterPlanningsForOperatorRoles(
          List<Map<String, dynamic>> allPlannings) async {
        // Return all plannings as backend already handles proper filtering based on user role and machine access
        return allPlannings;
      }

      final roleFilteredPlannings = await _filterPlanningsForOperatorRoles(plannings);

      // Use only job plannings data (backend already filters by role)
      // Don't fetch additional jobs as it returns unfiltered data (5921 jobs)
      print('🔍 [Frontend] Using only job plannings data: ${roleFilteredPlannings.length} jobs');
      
      // Job plannings are already filtered by backend based on user role
      
      // Use job plannings directly (already filtered by backend)
      List<Map<String, dynamic>> finalJobList = [];
      List<Map<String, dynamic>> highDemandJobs = [];
      List<Map<String, dynamic>> regularJobs = [];
      
      for (var planning in roleFilteredPlannings) {
        final nrcJobNo = planning['nrcJobNo'] as String;
        final jobDemand = planning['jobDemand'] as String?;
        print('🔍 [Frontend] Processing planning: $nrcJobNo, demand: $jobDemand');
        
        // Add job status
        planning['status'] = statuses[nrcJobNo] ?? 'UNKNOWN';
        
        // Separate high-demand jobs from regular jobs
        if (jobDemand?.toLowerCase() == 'high') {
          highDemandJobs.add(planning);
          print('🔍 [Frontend] High-demand job found: $nrcJobNo');
        } else {
          regularJobs.add(planning);
        }
      }
      
      // Prioritize high-demand jobs at the top
      finalJobList = [...highDemandJobs, ...regularJobs];
      print('🔍 [Frontend] Total jobs: ${finalJobList.length}, High-demand: ${highDemandJobs.length}');

      // Check if widget is still mounted before setting state
      if (!mounted) return;
      setState(() {
        jobPlannings = finalJobList;
        filteredJobPlannings = finalJobList; // Initialize filtered list
        jobStatuses = statuses;
        _isLoading = false;
      });
    } catch (e) {
      // Check if widget is still mounted before setting state
      if (!mounted) return;
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
          // Debug clear cache button
          IconButton(
            icon: const Icon(Icons.clear_all, color: Colors.white),
            onPressed: _isLoading ? null : _clearAllCaches,
            tooltip: 'Clear All Caches',
          ),
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
            onPressed: _isLoading ? null : _clearAllCaches,
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
    final nrcJobNo = jobPlanning['nrcJobNo']?.toString() ?? '';
    final status = jobStatuses[nrcJobNo] ?? '';
    final isHold = status == 'HOLD';
    final jobDemand = jobPlanning['jobDemand']?.toString() ?? '';
    
    // Debug logging for high-demand jobs
    if (jobDemand.toLowerCase() == 'high') {
      print('🔍 [Frontend] High-demand job card: $nrcJobNo, demand: $jobDemand');
    }

    return Card
      (
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
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(12),
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
                    return;
                  }
                  // Navigate to JobTimelinePage
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const Center(child: CircularProgressIndicator()),
                  );
                  final dio = Dio();
                  final jobApi = JobApi(dio);
                  final planning = await jobApi.getJobPlanningStepsByNrcJobNo(nrcJobNo);
                  if (mounted) Navigator.of(context).pop();
                  final steps = planning?['steps'] ?? [];
                  if (!mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => JobTimelinePage(
                        jobNumber: nrcJobNo,
                        assignedSteps: steps,
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
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
                            const SizedBox(height: 6),
                            Tooltip(
                              message: 'NRC Job No: $nrcJobNo',
                              child: Text(
                                'NRC Job No: $nrcJobNo',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[800],
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Tooltip(
                              message: 'Job Plan ID: ${jobPlanning['jobPlanId']}',
                              child: Text(
                                'Job Plan ID: ${jobPlanning['jobPlanId']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isHold)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
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
                              child: const Text(
                                'U',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            );
                          },
                        ),
                      IconButton(
                        tooltip: _expandedJobNos.contains(nrcJobNo) ? 'Collapse' : 'Expand',
                        icon: Icon(
                          _expandedJobNos.contains(nrcJobNo)
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: Colors.grey[700],
                        ),
                        onPressed: () {
                          setState(() {
                            if (_expandedJobNos.contains(nrcJobNo)) {
                              _expandedJobNos.remove(nrcJobNo);
                            } else {
                              _expandedJobNos.add(nrcJobNo);
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              if (_expandedJobNos.contains(nrcJobNo))
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      _buildSummaryItem(
                        icon: Icons.trending_up,
                        title: 'Job Demand',
                        value: _formatJobDemand(jobPlanning['jobDemand'] ?? ''),
                        color: Colors.purple,
                      ),
                      const SizedBox(height: 10),
                      if (_isAdminOrPlanner)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => WorkDetailsScreen(
                                    nrcJobNo: nrcJobNo,
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
            ],
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
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Tooltip(
                  message: value,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
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