import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../constants/colors.dart';
import '../../routes/UserRoleManager.dart';
import 'package:dio/dio.dart';
import '../../../constants/strings.dart';
import '../../../data/datasources/job_api.dart';
import 'dart:convert'; // Added for jsonDecode

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late String _userRole = '';

  // Status Overview state
  int totalOrders = 0;
  int activeJobs = 0;
  int inProgress = 0;
  int completedOrders = 0;
  bool isLoadingStatus = false;
  JobApi? _jobApi;

  // Activity logs state
  List<Map<String, dynamic>> activityLogs = [];
  bool isLoadingLogs = false;
  int activeMemberCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _initializeApiAndFetch();
  }

  void _loadUserRole() async {
    await UserRoleManager().loadUserRole();
    final role = UserRoleManager().userRole;
    if (role == null || role.isEmpty) {
      if (mounted) {
        // No role should mean not logged in; redirect to login
        context.pushReplacement('/');
      }
      return;
    }
    setState(() {
      _userRole = role;
    });
    print('User Role in HomeScreen: $_userRole');
  }

  void _initializeApiAndFetch() {
    print('Initializing JobApi...');
    final dio = Dio();
    dio.options.baseUrl = '${AppStrings.baseUrl}/api';
    _jobApi = JobApi(dio);
    print('JobApi initialized, calling _fetchStatusOverviewData...');
    _fetchStatusOverviewData();
    _fetchActivityLogs();
  }

  Future<void> _fetchActivityLogs() async {
    if (_jobApi == null) {
      print('JobApi not initialized for activity logs!');
      return;
    }
    setState(() { isLoadingLogs = true; });
    try {
      final allLogs = await _jobApi!.getActivityLogs();

      // Filter out "User Login" actions
      final filteredLogs = allLogs.where((log) => 
        log['action'] != null && 
        log['action'] != 'User Login'
      ).toList();

      // Get unique users for active member count (excluding login actions)
      final uniqueUsers = <String>{};
      for (var log in filteredLogs) {
        if (log['userId'] != null) {
          uniqueUsers.add(log['userId']);
        }
      }

      setState(() {
        activityLogs = filteredLogs;
        activeMemberCount = uniqueUsers.length;
      });
    } catch (e) {
      print('Error fetching activity logs: $e');
      setState(() {
        activityLogs = [];
        activeMemberCount = 0;
      });
    }
    setState(() { isLoadingLogs = false; });
  }

  Future<void> _fetchStatusOverviewData() async {
    print('_fetchStatusOverviewData called, _jobApi is: ${_jobApi == null ? "null" : "initialized"}');
    if (_jobApi == null) {
      print('JobApi not initialized!');
      return;
    }
    setState(() { isLoadingStatus = true; });
    try {
      print('Fetching job plannings...');
      final planningList = await _jobApi!.getAllJobPlannings();
      print('Planning List: ' + planningList.toString());
      totalOrders = planningList.length;
      
      // Fetch completed jobs using getCompletedJobs endpoint
      print('Fetching completed jobs...');
      final completedJobsList = await _jobApi!.getCompletedJobs();
      completedOrders = completedJobsList.length;
      print('Completed Jobs Count: $completedOrders');
      
      inProgress = 0;
      for (var job in planningList) {
        if (job['steps'] is List) {
          final steps = job['steps'] as List;
          final dispatchStep = steps.firstWhere(
                (step) => step['stepName'] == 'DispatchProcess',
            orElse: () => null,
          );
          if (dispatchStep != null && dispatchStep['status'] != 'stop') {
            inProgress++;
          }
        }
      }
      print('Fetching jobs...');
      final jobs = await _jobApi!.getJobs();
      print('Jobs List: ' + jobs.toString());
      // Only count jobs where status == ACTIVE (case-insensitive)
      activeJobs = jobs.where((j) => (j.status).toString().toUpperCase() == 'ACTIVE').length;
    } catch (e) {
      print('Error fetching status overview: ' + e.toString());
      totalOrders = 0;
      activeJobs = 0;
      inProgress = 0;
      completedOrders = 0;
    }
    setState(() { isLoadingStatus = false; });
  }

  void _logout() async {
    // Clear in-memory and persisted role to avoid stale role on next login
    await UserRoleManager().clearUserRole();

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('accessToken');
    await prefs.remove('userId');

    print('All authentication data cleared during logout');
    if (mounted) context.pushReplacement('/'); // Navigate back to the login screen
  }

  String _getTimeAgo(String createdAt) {
    try {
      final dateTime = DateTime.parse(createdAt);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes} mins ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours} hours ago';
      } else {
        return '${difference.inDays} days ago';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  Color _getActionColor(String action) {
    if (action.contains('Login')) {
      return Colors.blue;
    } else if (action.contains('Created')) {
      return Colors.green;
    } else if (action.contains('Updated')) {
      return Colors.orange;
    } else {
      return Colors.grey;
    }
  }

  String _formatActivityDetails(String details) {
    try {
      // Check if details contains JSON
      if (details.contains('{') && details.contains('}')) {
        // Extract JSON part and optional Resource part
        final parts = details.split(' | Resource:');
        final jsonPart = parts[0].trim();
        final resourcePart = parts.length > 1 ? parts[1].trim() : null; // e.g., "JobStep (6)"

        // Try to parse the JSON
        final dynamic parsed = jsonDecode(jsonPart);
        if (parsed is Map<String, dynamic>) {
          final jsonData = parsed;
          final message = (jsonData['message'] ?? '').toString();
          final jobNo = (jsonData['nrcJobNo'] ?? jsonData['jobNo'] ?? '').toString();
          final planId = (jsonData['jobPlanId'] ?? '').toString();
          final stepNo = (jsonData['stepNo'] ?? '').toString();
          final status = (jsonData['status'] ?? '').toString();

          // Build a concise, human-friendly line
          final List<String> chunks = [];
          if (message.isNotEmpty) {
            chunks.add(message);
          } else if (status.isNotEmpty) {
            chunks.add('Status: $status');
          }
          if (stepNo.isNotEmpty) chunks.add('Step #$stepNo');
          if (jobNo.isNotEmpty) chunks.add('Job: $jobNo');
          if (planId.isNotEmpty) chunks.add('Plan: $planId');
          if (resourcePart != null && resourcePart.isNotEmpty) chunks.add(resourcePart);

          if (chunks.isNotEmpty) {
            return chunks.join(' — ');
          }
        }
      }
      
      // For non-JSON details, clean up common patterns
      String cleaned = details;
      
      // Remove jobStepId patterns
      cleaned = cleaned.replaceAll(RegExp(r'for jobStepId: \d+'), '');
      cleaned = cleaned.replaceAll(RegExp(r'jobStepId: \d+'), '');
      
      // Remove extra spaces and clean up
      cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
      
      // Remove trailing | Resource part if present
      if (cleaned.contains(' | Resource:')) {
        cleaned = cleaned.split(' | Resource:')[0].trim();
      }
      
      return cleaned;
    } catch (e) {
      // If parsing fails, clean up the original details
      String cleaned = details;
      cleaned = cleaned.replaceAll(RegExp(r'for jobStepId: \d+'), '');
      cleaned = cleaned.replaceAll(RegExp(r'jobStepId: \d+'), '');
      cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (cleaned.contains(' | Resource:')) {
        cleaned = cleaned.split(' | Resource:')[0].trim();
      }
      return cleaned;
    }
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: AppColors.white,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Menu',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.maincolor),
            ),
            const SizedBox(height: 24),
            if (_userRole == 'admin')...[
              Expanded(
                child: ElevatedButton(
                  onPressed: () => context.push('/create-id'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.maincolor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text(
                    'Add New Account',
                    style: TextStyle(color: AppColors.white),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  context.push('/user-activity');
                },
                icon: const Icon(Icons.people,color: AppColors.white),
                label: const Text('User Activity',style: TextStyle(color: AppColors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.maincolor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],

            if (_userRole == 'planner' || _userRole == 'admin') ...[
              ElevatedButton.icon(
                onPressed: () {
                  context.push('/job-input');
                },
                icon: const Icon(Icons.add,color: AppColors.white),
                label: const Text('Add New Customer',style: TextStyle(color: AppColors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.maincolor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  context.push('/job-list', extra: _userRole);
                },
                icon: const Icon(Icons.list_alt,color: AppColors.white),
                label: const Text('Jobs',style: TextStyle(color: AppColors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.maincolor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  context.push('/completed-jobs');
                },
                icon: const Icon(Icons.check_circle,color: AppColors.white),
                label: const Text('Completed Jobs',style: TextStyle(color: AppColors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.maincolor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  context.push('/edit-machines');
                },
                icon: const Icon(Icons.build,color: AppColors.white),
                label: const Text('Edit Machines',style: TextStyle(color: AppColors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.maincolor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  context.push('/user-activity');
                },
                icon: const Icon(Icons.people,color: AppColors.white),
                label: const Text('User Activity',style: TextStyle(color: AppColors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.maincolor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
            ElevatedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: AppColors.white,),
              label: const Text('Logout',style: TextStyle(color: AppColors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.maincolor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: _buildDrawer(),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.menu, color: Colors.black87, size: 28),
            onPressed: () {
              _scaffoldKey.currentState!.openDrawer();
            },
          ),
          title: const Text(
            'Factory Portal',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_userRole.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      'Logged in as: $_userRole',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blue[800]),
                    ),
                  ],
                ),
              ),
            ],
            if (_userRole == 'planner' || _userRole == 'admin') ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => context.push('/all-Jobs'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: const Text(
                        'Create New Job',
                        style: TextStyle(color: AppColors.maincolor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8), // Space between the buttons
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => context.push('/job-list'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: const Text(
                        'Jobs',
                        style: TextStyle(color: AppColors.maincolor),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (_userRole == 'admin') ...[
              _buildDepartmentCards(),
              const SizedBox(height: 28),
            ], _buildLiveUpdates(),
            const SizedBox(height: 28),
            _buildStatusOverview(),
            const SizedBox(height: 28),
            _buildDailySnapshots(),
            const SizedBox(height: 28),
            _buildActiveMemberCount(),
          ],
        ),
      ),
    );
  }

  Widget _buildDepartmentCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Department Overview',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => context.push('/planning-dashboard'),
                child: _buildDepartmentCard(
                  'Planning',
                  'Get comprehensive overview of planning activities',
                  Icons.analytics_outlined,
                  Colors.blue,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => context.push('/printing-dashboard'),
                child: _buildDepartmentCard(
                  'Printing Manager',
                  'Manage printing operations and schedules',
                  Icons.print_outlined,
                  Colors.indigo,
                ),
              ),
            ), // Empty space for alignment
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => context.push('/production-dashboard'),
                child: _buildDepartmentCard(
                  'Production Head',
                  'Monitor production metrics and performance',
                  Icons.factory_outlined,
                  Colors.cyan,
                ),
              ),
            ),

            Expanded(
              child: GestureDetector(
                onTap: () => context.push('/dispatch-dashboard'),
                child: _buildDepartmentCard(
                  'Dispatch Executive',
                  'Manage dispatch operations and logistics',
                  Icons.local_shipping_outlined,
                  Colors.blue,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => context.push('/qc-dashboard'),
                child: _buildDepartmentCard(
                  'QC Manager',
                  'Quality control and assurance management',
                  Icons.verified_outlined,
                  Colors.cyan,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: SizedBox()), // Empty space for alignment
          ],
        ),
      ],
    );
  }

  Widget _buildDepartmentCard(String title, String description, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildLiveUpdates() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Live Updates',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: isLoadingLogs
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh),
                onPressed: isLoadingLogs ? null : _fetchActivityLogs,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isLoadingLogs)
            const Center(child: CircularProgressIndicator())
          else if (activityLogs.isEmpty)
            const Center(
              child: Text(
                'No recent activity',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ...activityLogs.take(3).map((log) => _buildUpdateItem(
              _formatActivityDetails(log['details'] ?? log['action'] ?? 'Unknown action'),
              _getTimeAgo(log['createdAt'] ?? ''),
              _getActionColor(log['action'] ?? ''),
            )).toList(),
        ],
      ),
    );
  }

  Widget _buildUpdateItem(String title, String time, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusOverview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Status Overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Spacer(),
              IconButton(
                icon: isLoadingStatus
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.refresh),
                onPressed: isLoadingStatus ? null : () {
                  if (_jobApi == null) {
                    _initializeApiAndFetch();
                  } else {
                    _fetchStatusOverviewData();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildOverviewCard('Total Orders', '$totalOrders', Colors.purple),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOverviewCard('Active Jobs', '$activeJobs', Colors.teal),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildOverviewCard('In Progress', '$inProgress', Colors.orange),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOverviewCard('Completed Orders', '$completedOrders', Colors.blue),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 4),
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
    );
  }

  Widget _buildDailySnapshots() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Daily Snapshots',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: isLoadingLogs
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh),
                onPressed: isLoadingLogs ? null : _fetchActivityLogs,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isLoadingLogs)
            const Center(child: CircularProgressIndicator())
          else if (activityLogs.isEmpty)
            const Center(
              child: Text(
                'No recent activity',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            Column(
              children: activityLogs.take(5).map((log) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _getActionColor(log['action'] ?? ''),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatActivityDetails(log['details'] ?? log['action'] ?? 'Unknown action'),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                        ],
                      ),
                    ),
                    Text(
                      _getTimeAgo(log['createdAt'] ?? ''),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ),
        ],
      ),
    );
  }


  Widget _buildActiveMemberCount() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.people, color: Colors.green, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Active Members',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$activeMemberCount members currently active',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$activeMemberCount',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}