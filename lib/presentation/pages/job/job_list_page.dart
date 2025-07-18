import 'package:flutter/material.dart';
import 'package:nrc/constants/colors.dart';
import 'package:nrc/constants/strings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../../../data/datasources/job_api.dart';
import '../../routes/UserRoleManager.dart';
import '../../../data/models/job_model.dart';
import '../../../data/models/Job.dart'; // Add this import for Job model
import 'JobDetailScreen.dart';
import 'JobCard.dart';
import 'JobStep.dart';
import 'ArtworkWorkflowWidget.dart'; // Add this import for ArtworkWorkflowWidget

class JobListPage extends StatefulWidget {
  const JobListPage({super.key, String? userRole});

  @override
  _JobListPageState createState() => _JobListPageState();
}

class _JobListPageState extends State<JobListPage> {
  late String _userRole;
  List<JobModel> _jobs = [];
  List<JobModel> _filteredJobs = [];
  Set<String> _selectedFilters = {};
  bool _isLoading = true;
  String? _error;

  late JobApi _jobApi;

  @override
  void initState() {
    super.initState();
    _initializeApi();
    _loadUserRole();
    _loadJobs();
  }

  void _initializeApi() {
    final dio = Dio();
    // Set your base URL here
    dio.options.baseUrl = '${AppStrings.baseUrl}/api';
    _jobApi = JobApi(dio);
  }

  void _loadUserRole() async {
    _userRole = UserRoleManager().userRole ?? 'Guest';
    print('User Role in JobDetails: $_userRole');
    setState(() {});
  }

  Future<void> _loadJobs() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final jobs = await _jobApi.getJobs();

      // Filter jobs with status 'Active' (case-insensitive)
      final activeJobs = jobs.where((job) =>
      job.status.toLowerCase() == 'active'
      ).toList();

      setState(() {
        _jobs = activeJobs;
        _filteredJobs = List.from(activeJobs);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load jobs: ${e.toString()}';
        _isLoading = false;
      });
      print('Error loading jobs: $e');
    }
  }

  void _applyFilters() {
    setState(() {
      if (_selectedFilters.isEmpty) {
        _filteredJobs = List.from(_jobs);
      } else {
        _filteredJobs = _jobs.where((job) =>
            _selectedFilters.contains(job.status.toLowerCase())
        ).toList();
      }
    });
  }

  // Get unique statuses from the current jobs
  Set<String> get _availableStatuses {
    return _jobs.map((job) => job.status.toLowerCase()).toSet();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Production Jobs'),
        backgroundColor: AppColors.maincolor,
        foregroundColor: AppColors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadJobs,
          ),
          if (_userRole == 'Admin' || _userRole == 'Planner')
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showAddJobDialog(context),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadJobs,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_filteredJobs.isEmpty) {
      return const Center(
        child: Text(
          'No active jobs found',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredJobs.length,
      itemBuilder: (context, index) {
        final job = _filteredJobs[index];
        return _buildJobCard(job);
      },
    );
  }

  Widget _buildJobCard(JobModel job) {
    // Convert JobModel to Job for compatibility with existing JobCard
    final compatibleJob = _convertJobModelToJob(job);

    return EnhancedJobCard(
      job: compatibleJob,
      onJobUpdate: _updateJobFromJobCard,
    );
  }

  // Helper method to convert JobModel to Job for existing UI components
  Job _convertJobModelToJob(JobModel jobModel) {
    return Job(
      id: jobModel.id,
      nrcJobNo: jobModel.nrcJobNo,
      styleItemSKU: jobModel.styleItemSKU,
      customerName: jobModel.customerName,
      fluteType: jobModel.fluteType,
      status: jobModel.status,
      latestRate: jobModel.latestRate,
      preRate: jobModel.preRate,
      length: jobModel.length,
      width: jobModel.width,
      height: jobModel.height,
      boxDimensions: jobModel.boxDimensions,
      diePunchCode: jobModel.diePunchCode,
      boardCategory: jobModel.boardCategory,
      noOfColor: jobModel.noOfColor,
      processColors: jobModel.processColors,
      specialColor1: jobModel.specialColor1,
      specialColor2: jobModel.specialColor2,
      specialColor3: jobModel.specialColor3,
      specialColor4: jobModel.specialColor4,
      overPrintFinishing: jobModel.overPrintFinishing,
      topFaceGSM: jobModel.topFaceGSM,
      flutingGSM: jobModel.flutingGSM,
      bottomLinerGSM: jobModel.bottomLinerGSM,
      decalBoardX: jobModel.decalBoardX,
      lengthBoardY: jobModel.lengthBoardY,
      boardSize: jobModel.boardSize,
      noUps: jobModel.noUps,
      artworkReceivedDate: jobModel.artworkReceivedDate,
      artworkApprovalDate: jobModel.artworkApprovedDate,
      shadeCardApprovalDate: jobModel.shadeCardApprovalDate,
      srNo: jobModel.srNo,
      jobDemand: jobModel.jobDemand,
      imageURL: jobModel.imageURL,
      createdAt: jobModel.createdAt,
      updatedAt: jobModel.updatedAt,
      userId: jobModel.userId,
      machineId: jobModel.machineId,
      purchaseOrder: null, // Set this if you have PO data
    );
  }

  // Helper method to convert Job back to JobModel (for updates)
  JobModel _convertJobToJobModel(Job job, JobModel originalJobModel) {
    return JobModel(
      id: originalJobModel.id,
      nrcJobNo: originalJobModel.nrcJobNo,
      styleItemSKU: originalJobModel.styleItemSKU,
      customerName: originalJobModel.customerName,
      fluteType: originalJobModel.fluteType,
      status: originalJobModel.status,
      latestRate: originalJobModel.latestRate,
      preRate: originalJobModel.preRate,
      length: originalJobModel.length,
      width: originalJobModel.width,
      height: originalJobModel.height,
      boxDimensions: originalJobModel.boxDimensions,
      diePunchCode: originalJobModel.diePunchCode,
      boardCategory: originalJobModel.boardCategory,
      noOfColor: originalJobModel.noOfColor,
      processColors: originalJobModel.processColors,
      specialColor1: originalJobModel.specialColor1,
      specialColor2: originalJobModel.specialColor2,
      specialColor3: originalJobModel.specialColor3,
      specialColor4: originalJobModel.specialColor4,
      overPrintFinishing: originalJobModel.overPrintFinishing,
      topFaceGSM: originalJobModel.topFaceGSM,
      flutingGSM: originalJobModel.flutingGSM,
      bottomLinerGSM: originalJobModel.bottomLinerGSM,
      decalBoardX: originalJobModel.decalBoardX,
      lengthBoardY: originalJobModel.lengthBoardY,
      boardSize: originalJobModel.boardSize,
      noUps: originalJobModel.noUps,
      artworkReceivedDate: originalJobModel.artworkReceivedDate,
      artworkApprovedDate: originalJobModel.artworkApprovedDate,
      shadeCardApprovalDate: originalJobModel.shadeCardApprovalDate,
      srNo: originalJobModel.srNo,
      jobDemand: originalJobModel.jobDemand,
      imageURL: originalJobModel.imageURL,
      createdAt: originalJobModel.createdAt,
      updatedAt: originalJobModel.updatedAt,
      userId: originalJobModel.userId,
      machineId: originalJobModel.machineId,
    );
  }

  JobStatus _convertStringToJobStatus(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return JobStatus.active;
      case 'inactive':
        return JobStatus.inactive;
      case 'hold':
        return JobStatus.hold;
      case 'working started':
      case 'workingstarted':
        return JobStatus.workingStarted;
      case 'completed':
        return JobStatus.completed;
      default:
        return JobStatus.inactive;
    }
  }

  JobDemand? _convertStringToJobDemand(String demand) {
    switch (demand.toLowerCase()) {
      case 'high':
        return JobDemand.high;
      case 'medium':
        return JobDemand.medium;
      case 'low':
        return JobDemand.low;
      default:
        return null;
    }
  }

  String _getMonthFromDate(String? dateString) {
    if (dateString == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateString);
      const months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      return months[date.month - 1];
    } catch (e) {
      return 'Unknown';
    }
  }

  void _navigateToJobDetail(JobModel job) {
    // Navigate to job detail screen
  }

  void _updateJob(JobModel updatedJob) {
    setState(() {
      final index = _jobs.indexWhere((j) => j.nrcJobNo == updatedJob.nrcJobNo);
      if (index != -1) {
        _jobs[index] = updatedJob;
      }
    });
    _applyFilters();
  }

  // Keep the original method signature for compatibility with JobCard
  void _updateJobFromJobCard(Job updatedJob) {
    // Find the original JobModel to preserve API-specific fields
    final originalJobModel = _jobs.firstWhere(
          (j) => j.nrcJobNo == updatedJob.nrcJobNo,
      orElse: () => throw Exception('Job not found'),
    );

    final updatedJobModel = _convertJobToJobModel(updatedJob, originalJobModel);
    _updateJob(updatedJobModel);
  }

  Future<void> _updateJobStatus(JobModel job, String newStatus) async {
    try {
      await _jobApi.updateJobStatus(job.nrcJobNo, newStatus);

      // Reload jobs to get updated data
      await _loadJobs();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Job ${job.nrcJobNo} status updated to $newStatus'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update job status: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return AppColors.green;
      case 'inactive':
        return AppColors.red;
      case 'hold':
        return AppColors.grey;
      case 'working started':
      case 'workingstarted':
        return Colors.blue;
      case 'completed':
        return Colors.purple;
      default:
        return AppColors.grey;
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'TBD';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  void _showJobDetails(BuildContext context, JobModel job) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildDetailRow('Job Number', job.nrcJobNo),
                _buildDetailRow('Customer', job.customerName),
                _buildDetailRow('Style/SKU', job.styleItemSKU),
                _buildDetailRow('Status', job.status.toUpperCase(),
                    valueColor: _getStatusColor(job.status)),
                _buildDetailRow('Flute Type', job.fluteType),
                if (job.jobDemand != null && job.jobDemand!.isNotEmpty)
                  _buildDetailRow('Job Demand', job.jobDemand!.toUpperCase()),
                if (job.latestRate != null)
                  _buildDetailRow('Latest Rate', '₹${job.latestRate!.toStringAsFixed(2)}'),
                if (job.preRate != null)
                  _buildDetailRow('Previous Rate', '₹${job.preRate!.toStringAsFixed(2)}'),
                if (job.length != null && job.width != null && job.height != null)
                  _buildDetailRow('Dimensions', '${job.length} x ${job.width} x ${job.height}'),
                if (job.boardSize != null && job.boardSize!.isNotEmpty)
                  _buildDetailRow('Board Size', job.boardSize!),
                if (job.noUps != null && job.noUps!.isNotEmpty)
                  _buildDetailRow('No. of Ups', job.noUps!),
                if (job.diePunchCode != null)
                  _buildDetailRow('Die Punch Code', job.diePunchCode.toString()),
                if (job.boardCategory != null && job.boardCategory!.isNotEmpty)
                  _buildDetailRow('Board Category', job.boardCategory!),
                if (job.noOfColor != null && job.noOfColor!.isNotEmpty)
                  _buildDetailRow('No. of Colors', job.noOfColor!),
                if (job.processColors != null && job.processColors!.isNotEmpty)
                  _buildDetailRow('Process Colors', job.processColors!),
                if (job.artworkReceivedDate != null)
                  _buildDetailRow('Artwork Received', _formatDate(job.artworkReceivedDate)),
                if (job.artworkApprovedDate != null)
                  _buildDetailRow('Artwork Approved', _formatDate(job.artworkApprovedDate)),
                if (job.shadeCardApprovalDate != null)
                  _buildDetailRow('Shade Card Approval', _formatDate(job.shadeCardApprovalDate)),
                if (job.createdAt != null)
                  _buildDetailRow('Created At', _formatDate(job.createdAt)),
                if (job.updatedAt != null)
                  _buildDetailRow('Updated At', _formatDate(job.updatedAt)),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: valueColor ?? Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Filter Jobs'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filter by Status:'),
              const SizedBox(height: 16),
              ..._availableStatuses.map((status) => CheckboxListTile(
                title: Text(status.toUpperCase()),
                value: _selectedFilters.contains(status),
                onChanged: (value) {
                  setDialogState(() {
                    if (value == true) {
                      _selectedFilters.add(status);
                    } else {
                      _selectedFilters.remove(status);
                    }
                  });
                },
              )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedFilters.clear();
                });
                Navigator.pop(context);
                _applyFilters();
              },
              child: const Text('Clear'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _applyFilters();
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddJobDialog(BuildContext context) {
    final TextEditingController jobNumberController = TextEditingController();
    final TextEditingController customerController = TextEditingController();
    final TextEditingController styleController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Job'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: jobNumberController,
                decoration: const InputDecoration(
                  labelText: 'Job Number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: customerController,
                decoration: const InputDecoration(
                  labelText: 'Customer',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: styleController,
                decoration: const InputDecoration(
                  labelText: 'Style/SKU',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (jobNumberController.text.isNotEmpty &&
                  customerController.text.isNotEmpty &&
                  styleController.text.isNotEmpty) {
                // Note: You'll need to implement the API call to add a new job
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Add job functionality needs API implementation'),
                    backgroundColor: Colors.orange,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill all required fields'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _editJob(JobModel job) {
    print('Editing job: ${job.nrcJobNo}');
    // Navigate to edit screen or show edit dialog
    _navigateToJobDetail(job);
  }

  void _deleteJob(JobModel job) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Job'),
        content: Text('Are you sure you want to delete job ${job.nrcJobNo}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Note: You'll need to implement the API call to delete a job
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Delete job functionality needs API implementation'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}