import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../constants/colors.dart';
import '../../../constants/strings.dart';
import '../../../data/datasources/job_api.dart';
import '../stepsselections/FlyingSquadStepUpdate.dart';
import 'package:dio/dio.dart';
import 'dart:convert';

class FlyingSquadDashboard extends StatefulWidget {
  const FlyingSquadDashboard({Key? key}) : super(key: key);

  @override
  State<FlyingSquadDashboard> createState() => _FlyingSquadDashboardState();
}

class _FlyingSquadDashboardState extends State<FlyingSquadDashboard> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  JobApi? _jobApi;
  
  // Dashboard data
  List<Map<String, dynamic>> allJobSteps = [];
  List<Map<String, dynamic>> qcPendingSteps = [];
  List<Map<String, dynamic>> recentActivities = [];
  Map<String, dynamic> qcStats = {};
  bool isLoading = false;
  String selectedFilter = 'all';
  String selectedStatus = 'all';

  @override
  void initState() {
    super.initState();
    _initializeApi();
    _loadDashboardData();
  }

  void _initializeApi() {
    final dio = Dio();
    dio.options.baseUrl = '${AppStrings.baseUrl}/api';
    _jobApi = JobApi(dio);
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      isLoading = true;
    });

    try {
      await Future.wait([
        _loadAllJobSteps(),
        _loadQCPendingSteps(),
        _loadRecentActivities(),
        _loadQCStats(),
      ]);
      
      // Show success message when data is loaded successfully
      if (mounted) {
        _showSuccessSnackBar('Jobs reloaded successfully!');
      }
    } catch (e) {
      print('Error loading dashboard data: $e');
      _showErrorSnackBar('Failed to load dashboard data');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadAllJobSteps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      
      final dio = Dio();
      final response = await dio.get(
        '${AppStrings.baseUrl}/flying-squad/job-steps',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        print('✅ Flying Squad API Response:');
        print('Success: ${response.data['success']}');
        print('Count: ${response.data['count']}');
        print('Total: ${response.data['total']}');
        print('Data length: ${response.data['data']?.length ?? 0}');
        
        if (response.data['data'] != null && response.data['data'].isNotEmpty) {
          print('First step data: ${response.data['data'][0]}');
        }
        
        setState(() {
          allJobSteps = List<Map<String, dynamic>>.from(response.data['data']);
        });
        
        print('✅ allJobSteps updated with ${allJobSteps.length} steps');
      } else {
        print('❌ API Response Error:');
        print('Status Code: ${response.statusCode}');
        print('Response: ${response.data}');
      }
    } catch (e) {
      print('Error loading job steps: $e');
    }
  }

  Future<void> _loadQCPendingSteps() async {
    // Prepare shared resources for both try and catch blocks
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    final dio = Dio();

    try {
      final response = await dio.get(
        '${AppStrings.baseUrl}/flying-squad/qc-pending',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        print('✅ QC Pending API Response:');
        print('Success: ${response.data['success']}');
        print('Count: ${response.data['count']}');
        print('Data length: ${response.data['data']?.length ?? 0}');
        
        if (response.data['data'] != null && response.data['data'].isNotEmpty) {
          print('First QC pending step: ${response.data['data'][0]}');
        }
        
        setState(() {
          qcPendingSteps = List<Map<String, dynamic>>.from(response.data['data']);
        });
        
        print('✅ qcPendingSteps updated with ${qcPendingSteps.length} steps');
      } else {
        print('❌ QC Pending API Response Error:');
        print('Status Code: ${response.statusCode}');
        print('Response: ${response.data}');
      }
    } catch (e) {
      print('Error loading QC pending steps: $e');
      // Fallback to job-steps/needing-qc if qc-pending fails
      try {
        final response = await dio.get(
          '${AppStrings.baseUrl}/flying-squad/job-steps/needing-qc',
          options: Options(
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          ),
        );
        if (response.statusCode == 200 && response.data['success'] == true) {
          setState(() {
            qcPendingSteps = List<Map<String, dynamic>>.from(response.data['data']);
          });
        }
      } catch (fallbackError) {
        print('Error loading QC pending steps (fallback): $fallbackError');
      }
    }
  }

  Future<void> _loadRecentActivities() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      
      final dio = Dio();
      final response = await dio.get(
        '${AppStrings.baseUrl}/flying-squad/recent-activities',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        setState(() {
          recentActivities = List<Map<String, dynamic>>.from(response.data['data']);
        });
      }
    } catch (e) {
      print('Error loading recent activities: $e');
    }
  }

  Future<void> _loadQCStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      
      final dio = Dio();
      final response = await dio.get(
        '${AppStrings.baseUrl}/flying-squad/qc-stats',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        setState(() {
          qcStats = response.data['data'];
        });
      }
    } catch (e) {
      print('Error loading QC stats: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    // Error logging only - no UI display
    print('Error: $message');
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  List<Map<String, dynamic>> get filteredJobSteps {
    List<Map<String, dynamic>> filtered = allJobSteps;

    if (selectedFilter != 'all') {
      filtered = filtered.where((step) => step['stepName'] == selectedFilter).toList();
    }

    if (selectedStatus != 'all') {
      filtered = filtered.where((step) => step['status'] == selectedStatus).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Flying Squad Dashboard',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.maincolor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsCards(),
                    const SizedBox(height: 20),
                    _buildFilterSection(),
                    const SizedBox(height: 20),
                    _buildJobStepsSection(),
                    const SizedBox(height: 20),
                    _buildQCPendingSection(),
                    const SizedBox(height: 20),
                    _buildRecentActivitiesSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Steps',
            allJobSteps.length.toString(),
            Icons.assignment,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'QC Pending',
            qcPendingSteps.length.toString(),
            Icons.verified_user,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'In Progress',
            allJobSteps.where((step) => step['status'] == 'in_progress').length.toString(),
            Icons.hourglass_empty,
            Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filters',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: selectedFilter,
                  decoration: const InputDecoration(
                    labelText: 'Step Type',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('All Steps')),
                    const DropdownMenuItem(value: 'Printing', child: Text('Printing')),
                    const DropdownMenuItem(value: 'Corrugation', child: Text('Corrugation')),
                    const DropdownMenuItem(value: 'Punching', child: Text('Punching')),
                    const DropdownMenuItem(value: 'Quality Check', child: Text('Quality Check')),
                    const DropdownMenuItem(value: 'Dispatch', child: Text('Dispatch')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedFilter = value ?? 'all';
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('All Status')),
                    const DropdownMenuItem(value: 'planned', child: Text('Planned')),
                    const DropdownMenuItem(value: 'in_progress', child: Text('In Progress')),
                    const DropdownMenuItem(value: 'completed', child: Text('Completed')),
                    const DropdownMenuItem(value: 'on_hold', child: Text('On Hold')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedStatus = value ?? 'all';
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildJobStepsSection() {
    final filteredSteps = filteredJobSteps;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
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
              const Text(
                'All Job Steps',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${filteredSteps.length} steps',
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (filteredSteps.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No job steps found',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredSteps.length,
              itemBuilder: (context, index) {
                final step = filteredSteps[index];
                return _buildJobStepCard(step);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildJobStepCard(Map<String, dynamic> step) {
    final qcStatus = _getQCStatus(step);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: qcStatus == 'Completed' ? Colors.green : Colors.orange,
          child: Icon(
            qcStatus == 'Completed' ? Icons.check : Icons.pending,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          step['stepName'] ?? 'Unknown Step',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Job: ${step['jobPlanning']?['nrcJobNo'] ?? 'N/A'}'),
            Text('Status: ${step['status'] ?? 'N/A'}'),
            if (step['machineDetails'] != null && step['machineDetails'].isNotEmpty)
              Text('Machine: ${step['machineDetails'][0]['machineCode'] ?? 'N/A'}'),
            Text('QC: $qcStatus'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildQCStatusChip(qcStatus),
            const SizedBox(width: 8),
            _buildStatusChip(step['status']),
          ],
        ),
        onTap: () {
          // Navigate to step details
          _showStepDetails(step);
        },
      ),
    );
  }

  Widget _buildQCPendingSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'QC Pending Steps',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (qcPendingSteps.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No QC pending steps',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: qcPendingSteps.length,
              itemBuilder: (context, index) {
                final step = qcPendingSteps[index];
                return _buildQCPendingCard(step);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildQCPendingCard(Map<String, dynamic> step) {
    // Check if step is in planned status
    final stepStatus = step['status']?.toString().toLowerCase();
    final isPlanned = stepStatus == 'planned';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isPlanned ? Colors.grey[50] : Colors.orange[50],
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isPlanned ? Colors.grey : Colors.orange,
          child: const Icon(Icons.verified_user, color: Colors.white),
        ),
        title: Text(
          step['stepName'] ?? 'Unknown Step',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Job: ${step['jobPlanning']?['nrcJobNo'] ?? 'N/A'}'),
            if (isPlanned)
              const Text(
                'Status: Planned (not started)',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: isPlanned ? null : () => _navigateToQCUpdate(step),
          style: ElevatedButton.styleFrom(
            backgroundColor: isPlanned ? Colors.grey : AppColors.maincolor,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey[300],
            disabledForegroundColor: Colors.grey[600],
          ),
          child: Text(isPlanned ? 'Not Started' : 'QC Check'),
        ),
      ),
    );
  }

  Widget _buildRecentActivitiesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Activities',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (recentActivities.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No recent activities',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentActivities.length,
              itemBuilder: (context, index) {
                final activity = recentActivities[index];
                return _buildActivityCard(activity);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> activity) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.blue,
          child: Icon(Icons.history, color: Colors.white),
        ),
        title: Text(activity['action'] ?? 'Unknown Action'),
        subtitle: Text(activity['description'] ?? 'No description'),
        trailing: Text(
          _formatDateTime(activity['createdAt']),
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String? status) {
    Color color;
    switch (status) {
      case 'completed':
        color = Colors.green;
        break;
      case 'in_progress':
        color = Colors.blue;
        break;
      case 'on_hold':
        color = Colors.orange;
        break;
      case 'planned':
        color = Colors.grey;
        break;
      default:
        color = Colors.grey;
    }

    return Chip(
      label: Text(
        status ?? 'Unknown',
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: color,
    );
  }

  Widget _buildQCStatusChip(String qcStatus) {
    Color color;
    switch (qcStatus) {
      case 'Completed':
        color = Colors.green;
        break;
      case 'Pending':
        color = Colors.orange;
        break;
      default:
        color = Colors.grey;
    }

    return Chip(
      label: Text(
        qcStatus,
        style: const TextStyle(color: Colors.white, fontSize: 10),
      ),
      backgroundColor: color,
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'in_progress':
        return Colors.blue;
      case 'on_hold':
        return Colors.orange;
      case 'planned':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getStepIcon(String stepName) {
    switch (stepName) {
      case 'Printing':
        return Icons.print;
      case 'Corrugation':
        return Icons.construction;
      case 'Punching':
        return Icons.crop_free;
      case 'Quality Check':
        return Icons.verified_user;
      case 'Dispatch':
        return Icons.local_shipping;
      default:
        return Icons.assignment;
    }
  }

  String _formatDateTime(String? dateTime) {
    if (dateTime == null) return 'N/A';
    try {
      final dt = DateTime.parse(dateTime);
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid Date';
    }
  }

  String _getQCStatus(Map<String, dynamic> step) {
    // Extract QC fields from the appropriate step-specific table
    final stepDetail = _getStepDetail(step);
    print('🔍 _getQCStatus for step: ${step['stepName']}');
    print('Step detail: $stepDetail');
    
    if (stepDetail != null) {
      print('QC Check Sign By: ${stepDetail['qcCheckSignBy']}');
      print('QC Check At: ${stepDetail['qcCheckAt']}');
      
      if (stepDetail['qcCheckSignBy'] != null && stepDetail['qcCheckAt'] != null) {
        print('✅ QC Status: Completed');
        return 'Completed';
      }
    }
    
    print('⏳ QC Status: Pending');
    return 'Pending';
  }

  Map<String, dynamic>? _getStepDetail(Map<String, dynamic> step) {
    // Get the step-specific detail based on step name
    final stepName = step['stepName']?.toString().toLowerCase() ?? '';
    print('🔍 _getStepDetail for step: $stepName');
    print('Available step data keys: ${step.keys.toList()}');
    
    if (stepName.contains('paper') && step['paperStore'] != null) {
      print('✅ Found paperStore data: ${step['paperStore']}');
      return step['paperStore'];
    } else if (stepName.contains('printing') && step['printingDetails'] != null) {
      print('✅ Found printingDetails data: ${step['printingDetails']}');
      return step['printingDetails'];
    } else if (stepName.contains('corrugation') && step['corrugation'] != null) {
      print('✅ Found corrugation data: ${step['corrugation']}');
      return step['corrugation'];
    } else if (stepName.contains('flute') && step['flutelam'] != null) {
      print('✅ Found flutelam data: ${step['flutelam']}');
      return step['flutelam'];
    } else if (stepName.contains('punching') && step['punching'] != null) {
      print('✅ Found punching data: ${step['punching']}');
      return step['punching'];
    } else if (stepName.contains('flap') && step['sideFlapPasting'] != null) {
      print('✅ Found sideFlapPasting data: ${step['sideFlapPasting']}');
      return step['sideFlapPasting'];
    } else if (stepName.contains('quality') && step['qualityDept'] != null) {
      print('✅ Found qualityDept data: ${step['qualityDept']}');
      return step['qualityDept'];
    } else if (stepName.contains('dispatch') && step['dispatchProcess'] != null) {
      print('✅ Found dispatchProcess data: ${step['dispatchProcess']}');
      return step['dispatchProcess'];
    }
    
    print('❌ No step detail found for: $stepName');
    return null;
  }

  void _navigateToQCUpdate(Map<String, dynamic> step) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FlyingSquadStepUpdate(
          step: step,
          onUpdate: () {
            _loadDashboardData(); // Refresh data after update
          },
        ),
      ),
    );
  }

  void _showStepDetails(Map<String, dynamic> step) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(step['stepName'] ?? 'Step Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Job: ${step['jobPlanning']?['nrcJobNo'] ?? 'N/A'}'),
              Text('Status: ${step['status'] ?? 'N/A'}'),
              if (step['machineDetails'] != null && step['machineDetails'].isNotEmpty)
                Text('Machine: ${step['machineDetails'][0]['machineCode'] ?? 'N/A'}'),
              Text('Step No: ${step['stepNo'] ?? 'N/A'}'),
              if (step['startDate'] != null)
                Text('Start Date: ${_formatDateTime(step['startDate'])}'),
              if (step['endDate'] != null)
                Text('End Date: ${_formatDateTime(step['endDate'])}'),
              const Divider(),
              const Text(
                'QC Information:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('QC Status: ${_getQCStatus(step)}'),
              Builder(
                builder: (context) {
                  final stepDetail = _getStepDetail(step);
                  if (stepDetail != null) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (stepDetail['qcCheckSignBy'] != null)
                          Text('QC Checked By: ${stepDetail['qcCheckSignBy']}'),
                        if (stepDetail['qcCheckAt'] != null)
                          Text('QC Checked At: ${_formatDateTime(stepDetail['qcCheckAt'])}'),
                        if (stepDetail['remarks'] != null)
                          Text('Remarks: ${stepDetail['remarks']}'),
                      ],
                    );
                  }
                  return const Text('No QC information available');
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          if (_getQCStatus(step) == 'Pending')
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToQCUpdate(step);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.maincolor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Perform QC'),
            ),
        ],
      ),
    );
  }

  void _performQCCheck(Map<String, dynamic> step) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Perform QC Check'),
        content: const Text('Are you sure you want to perform QC check on this step?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _performQCAction(step);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.maincolor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm QC'),
          ),
        ],
      ),
    );
  }

  void _performQCAction(Map<String, dynamic> step) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      
      final dio = Dio();
      
      // Try the new QC-only endpoint first
      String qcEndpoint = '${AppStrings.baseUrl}/flying-squad/qc-check';
      Map<String, dynamic> qcData = {
        'stepId': step['id'],
        'remarks': 'QC check completed by Flying Squad',
      };

      // If we have job planning info, try the QC-only step endpoint
      if (step['jobPlanning']?['nrcJobNo'] != null && step['stepNo'] != null) {
        try {
          final response = await dio.patch(
            '${AppStrings.baseUrl}/api/job-planning/${step['jobPlanning']?['nrcJobNo']}/steps/${step['stepNo']}/qc',
            data: {
              'qcCheckSignBy': 'flying-squad-user', // Will be overridden by backend
              'qcCheckAt': DateTime.now().toIso8601String(),
              'remarks': 'QC check completed by Flying Squad',
            },
            options: Options(
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
            ),
          );

          if (response.statusCode == 200) {
            _showSuccessSnackBar('QC check completed successfully');
            _loadDashboardData(); // Refresh data
            return;
          }
        } catch (e) {
          print('QC-only endpoint failed, trying fallback: $e');
        }
      }

      // Fallback to original endpoint
      final response = await dio.post(
        qcEndpoint,
        data: qcData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        _showSuccessSnackBar('QC check completed successfully');
        _loadDashboardData(); // Refresh data
      } else {
        _showErrorSnackBar('Failed to perform QC check');
      }
    } catch (e) {
      print('Error performing QC check: $e');
      _showErrorSnackBar('Error performing QC check: ${e.toString()}');
    }
  }
}
