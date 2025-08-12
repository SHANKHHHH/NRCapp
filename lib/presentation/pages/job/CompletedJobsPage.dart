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
  final Set<String> _expandedJobNos = {};

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
        title: const Text(
          'Completed Jobs',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppColors.maincolor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
                : const Icon(Icons.refresh_rounded),
            onPressed: _isLoading ? null : _loadCompletedJobs,
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, 2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by job number, customer, or style...',
                  hintStyle: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: AppColors.maincolor,
                    size: 20,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                    icon: Icon(
                      Icons.clear_rounded,
                      color: Colors.grey[400],
                      size: 20,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      _filterJobs();
                    },
                  )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(
          color: AppColors.maincolor,
        ),
      )
          : _error != null
          ? _buildErrorState()
          : _filteredJobs.isEmpty
          ? _buildEmptyState()
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

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
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
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadCompletedJobs,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.maincolor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchController.text.isNotEmpty
                ? Icons.search_off_rounded
                : Icons.assignment_turned_in_rounded,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isNotEmpty
                ? 'No jobs found matching "${_searchController.text}"'
                : 'No completed jobs available',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          if (_searchController.text.isNotEmpty) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                _searchController.clear();
                _filterJobs();
              },
              child: const Text('Clear search'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompletedJobCard(BuildContext context, Map<String, dynamic> job) {
    final jobDetails = job['jobDetails'] as Map<String, dynamic>? ?? {};
    final purchaseOrderDetails = job['purchaseOrderDetails'] as Map<String, dynamic>? ?? {};
    final jobNo = (job['nrcJobNo'] ?? 'N/A').toString();
    final isExpanded = _expandedJobNos.contains(jobNo);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        children: [
          // Header (small card always visible)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.maincolor.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.maincolor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        jobNo,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'COMPLETED',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.maincolor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.maincolor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${job['totalDuration'] ?? 0}m',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: isExpanded ? 'Collapse' : 'Expand',
                  icon: Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.grey[700],
                  ),
                  onPressed: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedJobNos.remove(jobNo);
                      } else {
                        _expandedJobNos.add(jobNo);
                      }
                    });
                  },
                ),
              ],
            ),
          ),

          // Expanded details (visible only when dropdown is open)
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildInfoSection(
                    title: 'Job Information',
                    children: [
                      _buildInfoRow('Customer', jobDetails['customerName'] ?? 'N/A'),
                      _buildInfoRow('Style/SKU', jobDetails['styleItemSKU'] ?? 'N/A'),
                      _buildInfoRow('Demand Level', job['jobDemand']?.toString().toUpperCase() ?? 'N/A'),
                      _buildInfoRow('Latest Rate', jobDetails['latestRate'] != null ? '₹${jobDetails['latestRate']}' : 'N/A'),
                    ],
                  ),

                  const SizedBox(height: 16),

                  _buildInfoSection(
                    title: 'Specifications',
                    children: [
                      _buildInfoRow('Dimensions (L×W×H)',
                          '${jobDetails['length'] ?? 'N/A'}×${jobDetails['width'] ?? 'N/A'}×${jobDetails['height'] ?? 'N/A'} mm'),
                      _buildInfoRow('Board Size', jobDetails['boardSize'] ?? 'N/A'),
                      _buildInfoRow('Board Category', jobDetails['boardCategory'] ?? 'N/A'),
                      _buildInfoRow('Flute Type', jobDetails['fluteType'] ?? 'N/A'),
                      _buildInfoRow('Process Colors', jobDetails['processColors'] ?? 'N/A'),
                      _buildInfoRow('No. of UPS', jobDetails['noUps']?.toString() ?? 'N/A'),
                    ],
                  ),

                  const SizedBox(height: 16),

                  if (purchaseOrderDetails.isNotEmpty)
                    _buildInfoSection(
                      title: 'Purchase Order',
                      children: [
                        _buildInfoRow('PO Quantity', purchaseOrderDetails['totalPOQuantity']?.toString() ?? 'N/A'),
                        _buildInfoRow('No. of Sheets', purchaseOrderDetails['noOfSheets']?.toString() ?? 'N/A'),
                        _buildInfoRow('Unit', purchaseOrderDetails['unit'] ?? 'N/A'),
                        _buildInfoRow('Delivery Date', _formatDate(purchaseOrderDetails['deliveryDate'])),
                        _buildInfoRow('Dispatch Date', _formatDate(purchaseOrderDetails['dispatchDate'])),
                      ],
                    ),

                  const SizedBox(height: 16),

                  _buildInfoSection(
                    title: 'Completion Details',
                    children: [
                      _buildInfoRow('Completed By', job['completedBy'] ?? 'N/A'),
                      _buildInfoRow('Completed At', _formatDate(job['completedAt'])),
                      _buildInfoRow('Total Duration', '${job['totalDuration'] ?? 0} minutes'),
                      _buildInfoRow('Final Status', (job['finalStatus'] ?? 'N/A').toString().toUpperCase()),
                      if (job['remarks'] != null && job['remarks'].toString().isNotEmpty)
                        _buildInfoRow('Remarks', job['remarks']),
                    ],
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showProcessSteps(context, job),
                          icon: const Icon(Icons.timeline_rounded, size: 18),
                          label: const Text('Process Steps'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.maincolor,
                            side: BorderSide(color: AppColors.maincolor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showDetailedView(context, job),
                          icon: const Icon(Icons.visibility_rounded, size: 18),
                          label: const Text('Full Details'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black,
                            side: const BorderSide(color: Colors.black),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  void _showProcessSteps(BuildContext context, Map<String, dynamic> job) {
    final allSteps = job['allSteps'] as List<dynamic>? ?? [];
    // Sort steps by stepNo
    allSteps.sort((a, b) => (a['stepNo'] ?? 0).compareTo(b['stepNo'] ?? 0));

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.maincolor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.timeline_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Process Steps',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            job['nrcJobNo'] ?? 'N/A',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // Steps List
              Flexible(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: allSteps.length,
                  itemBuilder: (context, index) {
                    final step = allSteps[index] as Map<String, dynamic>;
                    return _buildStepCard(step, index == allSteps.length - 1);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepCard(Map<String, dynamic> step, bool isLast) {
    final stepName = step['stepName'] ?? 'Unknown Step';
    final status = step['status'] ?? 'unknown';
    final stepNo = step['stepNo'] ?? 0;
    final startDate = step['startDate'];
    final endDate = step['endDate'];

    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: status.toLowerCase() == 'stop'
                      ? AppColors.maincolor
                      : Colors.grey[300],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  status.toLowerCase() == 'stop'
                      ? Icons.check_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 40,
                  color: Colors.grey[300],
                ),
            ],
          ),

          const SizedBox(width: 16),

          // Step Content
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Step $stepNo',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.maincolor,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: status.toLowerCase() == 'stop'
                              ? AppColors.maincolor.withOpacity(0.1)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: status.toLowerCase() == 'stop'
                                ? AppColors.maincolor
                                : Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stepName.replaceAllMapped(
                      RegExp(r'([A-Z])'),
                          (match) => ' ${match.group(0)}',
                    ).trim(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  if (startDate != null || endDate != null) ...[
                    const SizedBox(height: 8),
                    if (startDate != null)
                      _buildStepInfo('Started', _formatDate(startDate)),
                    if (endDate != null)
                      _buildStepInfo('Completed', _formatDate(endDate)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showDetailedView(BuildContext context, Map<String, dynamic> job) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxHeight: 700),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.visibility_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Complete Job Details',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            job['nrcJobNo'] ?? 'N/A',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // Detailed Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailedSection('Job Overview', [
                        'Job Number: ${job['nrcJobNo'] ?? 'N/A'}',
                        'Job Plan ID: ${job['jobPlanId'] ?? 'N/A'}',
                        'Job Demand: ${(job['jobDemand'] ?? 'N/A').toString().toUpperCase()}',
                        'Final Status: ${(job['finalStatus'] ?? 'N/A').toString().toUpperCase()}',
                        'Total Duration: ${job['totalDuration'] ?? 0} minutes',
                        'Completed By: ${job['completedBy'] ?? 'N/A'}',
                        'Completed At: ${_formatDate(job['completedAt'])}',
                        if (job['remarks'] != null) 'Remarks: ${job['remarks']}',
                      ]),

                      _buildDetailedJobDetails(job['jobDetails'] as Map<String, dynamic>? ?? {}),

                      _buildDetailedPODetails(job['purchaseOrderDetails'] as Map<String, dynamic>? ?? {}),

                      _buildStepDetails(job['allStepDetails'] as Map<String, dynamic>? ?? {}),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailedSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                item,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black,
                ),
              ),
            )).toList(),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildDetailedJobDetails(Map<String, dynamic> jobDetails) {
    if (jobDetails.isEmpty) return const SizedBox.shrink();

    final details = [
      'Customer: ${jobDetails['customerName'] ?? 'N/A'}',
      'Style/SKU: ${jobDetails['styleItemSKU'] ?? 'N/A'}',
      'Board Size: ${jobDetails['boardSize'] ?? 'N/A'}',
      'Board Category: ${jobDetails['boardCategory'] ?? 'N/A'}',
      'Dimensions (L×W×H): ${jobDetails['length'] ?? 'N/A'}×${jobDetails['width'] ?? 'N/A'}×${jobDetails['height'] ?? 'N/A'} mm',
      'Box Dimensions: ${jobDetails['boxDimensions'] ?? 'N/A'}',
      'No. of UPS: ${jobDetails['noUps'] ?? 'N/A'}',
      'Flute Type: ${jobDetails['fluteType'] ?? 'N/A'}',
      'Process Colors: ${jobDetails['processColors'] ?? 'N/A'}',
      'No. of Colors: ${jobDetails['noOfColor'] ?? 'N/A'}',
      'Latest Rate: ${jobDetails['latestRate'] != null ? '₹${jobDetails['latestRate']}' : 'N/A'}',
      'Pre Rate: ${jobDetails['preRate'] ?? 'N/A'}',
      'Job Demand: ${(jobDetails['jobDemand'] ?? 'N/A').toString().toUpperCase()}',
      'Status: ${(jobDetails['status'] ?? 'N/A').toString().toUpperCase()}',
      'Die Punch Code: ${jobDetails['diePunchCode'] ?? 'N/A'}',
      'Decal Board X: ${jobDetails['decalBoardX'] ?? 'N/A'}',
      'Length Board Y: ${jobDetails['lengthBoardY'] ?? 'N/A'}',
      'Top Face GSM: ${jobDetails['topFaceGSM'] ?? 'N/A'}',
      'Bottom Liner GSM: ${jobDetails['bottomLinerGSM'] ?? 'N/A'}',
      'Fluting GSM: ${jobDetails['flutingGSM'] ?? 'N/A'}',
      'Special Color 1: ${jobDetails['specialColor1'] ?? 'N/A'}',
      'Special Color 2: ${jobDetails['specialColor2'] ?? 'N/A'}',
      'Special Color 3: ${jobDetails['specialColor3'] ?? 'N/A'}',
      'Special Color 4: ${jobDetails['specialColor4'] ?? 'N/A'}',
      'Over Print Finishing: ${jobDetails['overPrintFinishing'] ?? 'N/A'}',
      'Artwork Received Date: ${_formatDate(jobDetails['artworkReceivedDate'])}',
      'Artwork Approved Date: ${_formatDate(jobDetails['artworkApprovedDate'])}',
      'Shade Card Approval Date: ${_formatDate(jobDetails['shadeCardApprovalDate'])}',
      'Created At: ${_formatDate(jobDetails['createdAt'])}',
      'Updated At: ${_formatDate(jobDetails['updatedAt'])}',
    ];

    return _buildDetailedSection('Job Details', details);
  }

  Widget _buildDetailedPODetails(Map<String, dynamic> poDetails) {
    if (poDetails.isEmpty) return const SizedBox.shrink();

    final details = [
      'Customer: ${poDetails['customer'] ?? 'N/A'}',
      'PO Number: ${poDetails['poNumber'] ?? 'N/A'}',
      'PO Date: ${_formatDate(poDetails['poDate'])}',
      'Total PO Quantity: ${poDetails['totalPOQuantity'] ?? 'N/A'}',
      'No. of Sheets: ${poDetails['noOfSheets'] ?? 'N/A'}',
      'Unit: ${poDetails['unit'] ?? 'N/A'}',
      'Status: ${(poDetails['status'] ?? 'N/A').toString().toUpperCase()}',
      'Delivery Date: ${_formatDate(poDetails['deliveryDate'])}',
      'Dispatch Date: ${_formatDate(poDetails['dispatchDate'])}',
      'NRC Delivery Date: ${_formatDate(poDetails['nrcDeliveryDate'])}',
      'Dispatch Quantity: ${poDetails['dispatchQuantity'] ?? 'N/A'}',
      'Pending Quantity: ${poDetails['pendingQuantity'] ?? 'N/A'}',
      'Pending Validity: ${poDetails['pendingValidity'] ?? 'N/A'}',
      'Plant: ${poDetails['plant'] ?? 'N/A'}',
      'Style: ${poDetails['style'] ?? 'N/A'}',
      'Die Code: ${poDetails['dieCode'] ?? 'N/A'}',
      'No. of UPS: ${poDetails['noOfUps'] ?? 'N/A'}',
      'Board Size: ${poDetails['boardSize'] ?? 'N/A'}',
      'Flute Type: ${poDetails['fluteType'] ?? 'N/A'}',
      'Jockey Month: ${poDetails['jockeyMonth'] ?? 'N/A'}',
      'Shade Card Approval Date: ${_formatDate(poDetails['shadeCardApprovalDate'])}',
      'Created At: ${_formatDate(poDetails['createdAt'])}',
      'Updated At: ${_formatDate(poDetails['updatedAt'])}',
    ];

    return _buildDetailedSection('Purchase Order Details', details);
  }

  Widget _buildStepDetails(Map<String, dynamic> stepDetails) {
    if (stepDetails.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Process Step Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),

        // Paper Store Details
        if (stepDetails['paperStore'] != null && (stepDetails['paperStore'] as List).isNotEmpty)
          _buildStepDetailCard('Paper Store', stepDetails['paperStore'][0] as Map<String, dynamic>),

        // Printing Details
        if (stepDetails['printingDetails'] != null && (stepDetails['printingDetails'] as List).isNotEmpty)
          _buildStepDetailCard('Printing Details', stepDetails['printingDetails'][0] as Map<String, dynamic>),

        // Corrugation Details
        if (stepDetails['corrugation'] != null && (stepDetails['corrugation'] as List).isNotEmpty)
          _buildStepDetailCard('Corrugation', stepDetails['corrugation'][0] as Map<String, dynamic>),

        // Flute Lamination Details
        if (stepDetails['flutelam'] != null && (stepDetails['flutelam'] as List).isNotEmpty)
          _buildStepDetailCard('Flute Lamination', stepDetails['flutelam'][0] as Map<String, dynamic>),

        // Punching Details
        if (stepDetails['punching'] != null && (stepDetails['punching'] as List).isNotEmpty)
          _buildStepDetailCard('Punching', stepDetails['punching'][0] as Map<String, dynamic>),

        // Side Flap Pasting Details
        if (stepDetails['sideFlapPasting'] != null && (stepDetails['sideFlapPasting'] as List).isNotEmpty)
          _buildStepDetailCard('Side Flap Pasting', stepDetails['sideFlapPasting'][0] as Map<String, dynamic>),

        // Quality Department Details
        if (stepDetails['qualityDept'] != null && (stepDetails['qualityDept'] as List).isNotEmpty)
          _buildStepDetailCard('Quality Department', stepDetails['qualityDept'][0] as Map<String, dynamic>),

        // Dispatch Process Details
        if (stepDetails['dispatchProcess'] != null && (stepDetails['dispatchProcess'] as List).isNotEmpty)
          _buildStepDetailCard('Dispatch Process', stepDetails['dispatchProcess'][0] as Map<String, dynamic>),
      ],
    );
  }

  Widget _buildStepDetailCard(String title, Map<String, dynamic> stepData) {
    final details = <String>[];

    stepData.forEach((key, value) {
      if (key != 'id' && key != 'jobStepId' && key != 'jobNrcJobNo' && value != null) {
        String displayKey = key.replaceAllMapped(
          RegExp(r'([A-Z])'),
              (match) => ' ${match.group(0)}',
        ).replaceAll('_', ' ').trim();
        displayKey = displayKey[0].toUpperCase() + displayKey.substring(1);

        String displayValue = value.toString();
        if (key.toLowerCase().contains('date') && displayValue != 'null') {
          displayValue = _formatDate(displayValue);
        }

        details.add('$displayKey: $displayValue');
      }
    });

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.maincolor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              border: Border.all(color: AppColors.maincolor.withOpacity(0.3)),
            ),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.maincolor,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: details.map((detail) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black,
                  ),
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}