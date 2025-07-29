import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nrc/constants/colors.dart';
import 'package:nrc/constants/strings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../../../data/datasources/job_api.dart';
import '../../routes/UserRoleManager.dart';
import '../../../data/models/job_model.dart';
import '../../../data/models/Job.dart';
import 'JobDetailScreen.dart';
import 'JobCard.dart';

class CompletedJobsPage extends StatefulWidget {
  const CompletedJobsPage({super.key});

  @override
  _CompletedJobsPageState createState() => _CompletedJobsPageState();
}

class _CompletedJobsPageState extends State<CompletedJobsPage> {
  late String _userRole;
  List<Map<String, dynamic>> _completedJobs = [];
  List<Map<String, dynamic>> _filteredJobs = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  late JobApi _jobApi;

  @override
  void initState() {
    super.initState();
    _initializeApi();
    _loadUserRole();
    _loadCompletedJobs();
    _searchController.addListener(_filterJobs);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _initializeApi() {
    final dio = Dio();
    dio.options.baseUrl = '${AppStrings.baseUrl}/api';
    _jobApi = JobApi(dio);
  }

  void _loadUserRole() async {
    _userRole = UserRoleManager().userRole ?? 'Guest';
    print('User Role in CompletedJobsPage: $_userRole');
    setState(() {});
  }

  Future<void> _loadCompletedJobs() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final completedJobs = await _jobApi.getCompletedJobs();

      setState(() {
        _completedJobs = completedJobs;
        _filteredJobs = List.from(completedJobs);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load completed jobs: ${e.toString()}';
        _isLoading = false;
      });
      print('Error loading completed jobs: $e');
    }
  }

  void _filterJobs() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredJobs = List.from(_completedJobs);
      } else {
        _filteredJobs = _completedJobs.where((job) {
          final jobDetails = job['jobDetails'] as Map<String, dynamic>?;
          final nrcJobNo = job['nrcJobNo']?.toString().toLowerCase() ?? '';
          final customerName = jobDetails?['customerName']?.toString().toLowerCase() ?? '';
          final styleItemSKU = jobDetails?['styleItemSKU']?.toString().toLowerCase() ?? '';
          final finalStatus = job['finalStatus']?.toString().toLowerCase() ?? '';
          
          return nrcJobNo.contains(query) ||
                 customerName.contains(query) ||
                 styleItemSKU.contains(query) ||
                 finalStatus.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Completed Jobs'),
        backgroundColor: Colors.green,
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
            onPressed: _isLoading ? null : _loadCompletedJobs,
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
                  hintText: 'Search completed jobs...',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  prefixIcon: Icon(Icons.search, color: Colors.green),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.grey[600]),
                          onPressed: () {
                            _searchController.clear();
                            _filterJobs();
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
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadCompletedJobs,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _filteredJobs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _searchController.text.isNotEmpty
                                ? Icons.search_off
                                : Icons.check_circle_outline,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchController.text.isNotEmpty
                                ? 'No completed jobs found matching "${_searchController.text}"'
                                : 'No completed jobs found.',
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
                      itemCount: _filteredJobs.length,
                      itemBuilder: (context, index) {
                        final job = _filteredJobs[index];
                        return _buildCompletedJobCard(context, job);
                      },
                    ),
    );
  }

  Widget _buildCompletedJobCard(BuildContext context, Map<String, dynamic> job) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.green[50]!,
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'COMPLETED JOB',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.green[600],
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          job['nrcJobNo'] ?? 'N/A',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green[300]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green[700],
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'COMPLETED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildJobInfoRow(
                icon: Icons.person,
                label: 'Customer',
                value: (job['jobDetails'] as Map<String, dynamic>?)?['customerName'] ?? 'N/A',
                color: Colors.blue,
              ),
              _buildJobInfoRow(
                icon: Icons.inventory,
                label: 'Style/SKU',
                value: (job['jobDetails'] as Map<String, dynamic>?)?['styleItemSKU'] ?? 'N/A',
                color: Colors.purple,
              ),
              _buildJobInfoRow(
                icon: Icons.category,
                label: 'Flute Type',
                value: (job['jobDetails'] as Map<String, dynamic>?)?['fluteType'] ?? 'N/A',
                color: Colors.orange,
              ),
              if (job['jobDemand'] != null)
                _buildJobInfoRow(
                  icon: Icons.trending_up,
                  label: 'Demand',
                  value: job['jobDemand'].toString(),
                  color: Colors.teal,
                ),
              _buildJobInfoRow(
                icon: Icons.schedule,
                label: 'Duration',
                value: '${job['totalDuration'] ?? 0} minutes',
                color: Colors.indigo,
              ),
              _buildJobInfoRow(
                icon: Icons.person_pin,
                label: 'Completed By',
                value: job['completedBy'] ?? 'N/A',
                color: Colors.green,
              ),
              if (job['completedAt'] != null)
                _buildJobInfoRow(
                  icon: Icons.calendar_today,
                  label: 'Completed At',
                  value: _formatDate(job['completedAt']),
                  color: Colors.red,
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _showJobSummary(context, job);
                      },
                      icon: const Icon(Icons.summarize),
                      label: const Text('Summary'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: BorderSide(color: Colors.green),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _showJobSteps(context, job);
                      },
                      icon: const Icon(Icons.list),
                      label: const Text('Steps'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        side: BorderSide(color: Colors.blue),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJobInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: color,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  void _showJobSummary(BuildContext context, Map<String, dynamic> job) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.summarize, color: Colors.green),
            const SizedBox(width: 8),
            const Text('Job Summary'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryItem('Job Number', job['nrcJobNo'] ?? 'N/A'),
            _buildSummaryItem('Customer', (job['jobDetails'] as Map<String, dynamic>?)?['customerName'] ?? 'N/A'),
            _buildSummaryItem('Style/SKU', (job['jobDetails'] as Map<String, dynamic>?)?['styleItemSKU'] ?? 'N/A'),
            _buildSummaryItem('Flute Type', (job['jobDetails'] as Map<String, dynamic>?)?['fluteType'] ?? 'N/A'),
            _buildSummaryItem('Final Status', (job['finalStatus'] ?? 'N/A').toString().toUpperCase()),
            _buildSummaryItem('Demand', job['jobDemand']?.toString() ?? 'N/A'),
            _buildSummaryItem('Total Duration', '${job['totalDuration'] ?? 0} minutes'),
            _buildSummaryItem('Completed By', job['completedBy'] ?? 'N/A'),
            if (job['completedAt'] != null)
              _buildSummaryItem('Completed At', _formatDate(job['completedAt'])),
            if (job['remarks'] != null)
              _buildSummaryItem('Remarks', job['remarks']),
            if ((job['jobDetails'] as Map<String, dynamic>?)?['latestRate'] != null)
              _buildSummaryItem('Latest Rate', '₹${(job['jobDetails'] as Map<String, dynamic>?)?['latestRate']}'),
            if ((job['jobDetails'] as Map<String, dynamic>?)?['length'] != null && 
                 (job['jobDetails'] as Map<String, dynamic>?)?['width'] != null && 
                 (job['jobDetails'] as Map<String, dynamic>?)?['height'] != null)
              _buildSummaryItem('Dimensions', '${(job['jobDetails'] as Map<String, dynamic>?)?['length']}×${(job['jobDetails'] as Map<String, dynamic>?)?['width']}×${(job['jobDetails'] as Map<String, dynamic>?)?['height']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showJobSteps(BuildContext context, Map<String, dynamic> job) {
    final allSteps = job['allSteps'] as List<dynamic>? ?? [];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.list, color: Colors.blue),
            const SizedBox(width: 8),
            Text('Job Steps - ${job['nrcJobNo']}'),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          height: 400,
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: allSteps.length,
                  itemBuilder: (context, index) {
                    final step = allSteps[index] as Map<String, dynamic>;
                    return _buildStepCard(step);
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard(Map<String, dynamic> step) {
    final stepName = step['stepName'] ?? 'Unknown';
    final status = step['status'] ?? 'unknown';
    final stepNo = step['stepNo'] ?? 0;
    final startDate = step['startDate'];
    final endDate = step['endDate'];
    
    Color statusColor;
    IconData statusIcon;
    
    switch (status.toLowerCase()) {
      case 'stop':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'start':
        statusColor = Colors.blue;
        statusIcon = Icons.play_circle;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Step $stepNo: $stepName',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Status: ${status.toUpperCase()}',
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (startDate != null || endDate != null) ...[
              const SizedBox(height: 8),
              if (startDate != null)
                Text(
                  'Started: ${_formatDate(startDate)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              if (endDate != null)
                Text(
                  'Completed: ${_formatDate(endDate)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
} 