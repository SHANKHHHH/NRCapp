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
import 'JobStep.dart';
import 'ArtworkWorkflowWidget.dart';

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
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  int _refreshTick = 0;

  late JobApi _jobApi;

  @override
  void initState() {
    super.initState();
    _initializeApi();
    _loadUserRole();
    _loadJobs();
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
    print('User Role in JobDetails: $_userRole');
    setState(() {});
  }

  Future<void> _loadJobs() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Always fetch fresh to avoid stale cache after status changes elsewhere
      JobApi.clearCache();
      final jobs = await _jobApi.getJobs();

      final activeJobs = jobs
          .where((job) => job.status.trim().toLowerCase() == 'active')
          .toList();

      setState(() {
        _jobs = activeJobs;
        _isLoading = false;
      });
      // Re-apply current filters/search on fresh data
      _applyFilters();
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
      List<JobModel> filteredByStatus;
      
      if (_selectedFilters.isEmpty) {
        filteredByStatus = List.from(_jobs);
      } else {
        filteredByStatus = _jobs
            .where((job) => _selectedFilters
                .contains(job.status.trim().toLowerCase()))
            .toList();
      }
      
      // Apply search filter
      if (_searchQuery.isEmpty) {
        _filteredJobs = filteredByStatus;
      } else {
        _filteredJobs = filteredByStatus.where((job) {
          final query = _searchQuery.toLowerCase();
          return job.nrcJobNo.toLowerCase().contains(query) ||
                 job.customerName.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  Set<String> get _availableStatuses {
    return _jobs.map((job) => job.status.trim().toLowerCase()).toSet();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Jobs Planning',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),
        backgroundColor: AppColors.maincolor,
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: AppColors.maincolor,
          statusBarIconBrightness: Brightness.light,
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 4),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.filter_list_rounded,
                  size: 20,
                ),
              ),
              onPressed: () => _showFilterDialog(context),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.refresh_rounded,
                  size: 20,
                ),
              ),
              onPressed: () async {
                setState(() {
                  _refreshTick++;
                });
                await _loadJobs();
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search by job number or customer name...',
                hintStyle: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 15,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.grey[500],
                  size: 22,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: Colors.grey[500],
                          size: 20,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Body content
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.maincolor),
              strokeWidth: 3,
            ),
            const SizedBox(height: 24),
            Text(
              'Loading production jobs...',
              style: TextStyle(
                fontSize: 16,
                color: const Color(0xFF757575).withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFE8E8E8),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF000000).withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: Color(0xFF9E9E9E),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Something went wrong',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF757575),
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadJobs,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.maincolor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Try Again',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_filteredJobs.isEmpty) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  _searchQuery.isNotEmpty ? Icons.search_off_rounded : Icons.work_off_rounded,
                  size: 64,
                  color: const Color(0xFF9E9E9E).withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _searchQuery.isNotEmpty ? 'No search results found' : 'No active jobs found',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _searchQuery.isNotEmpty 
                    ? 'No jobs found matching "$_searchQuery"\nTry a different search term'
                    : 'There are no active production jobs\nat the moment',
                style: TextStyle(
                  fontSize: 16,
                  color: const Color(0xFF757575).withOpacity(0.8),
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
              if (_searchQuery.isNotEmpty) ...[
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: AppColors.maincolor.withOpacity(0.3)),
                    ),
                  ),
                  child: Text(
                    'Clear Search',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.maincolor,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        itemCount: _filteredJobs.length,
        itemBuilder: (context, index) {
          final job = _filteredJobs[index];
          return _buildJobCard(job);
        },
      ),
    );
  }

  Widget _buildJobCard(JobModel job) {
    final compatibleJob = _convertJobModelToJob(job);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: EnhancedJobCard(
        key: ValueKey('job-card-${job.nrcJobNo}-$_refreshTick'),
        job: compatibleJob,
        refreshToken: _refreshTick,
        onStatusUpdate: (updatedJob, newStatus) =>
            _onStatusUpdateFromCard(updatedJob, newStatus),
        onJobUpdate: _updateJobFromJobCard,
      ),
    );
  }

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
    );
  }

  JobModel _convertJobToJobModel(Job job, JobModel originalJobModel) {
    return JobModel(
      id: originalJobModel.id,
      nrcJobNo: originalJobModel.nrcJobNo,
      styleItemSKU: job.styleItemSKU.isNotEmpty
          ? job.styleItemSKU
          : originalJobModel.styleItemSKU,
      customerName: job.customerName.isNotEmpty
          ? job.customerName
          : originalJobModel.customerName,
      fluteType:
          job.fluteType.isNotEmpty ? job.fluteType : originalJobModel.fluteType,
      status: job.status.isNotEmpty ? job.status : originalJobModel.status,
      latestRate: job.latestRate ?? originalJobModel.latestRate,
      preRate: job.preRate ?? originalJobModel.preRate,
      length: job.length ?? originalJobModel.length,
      width: job.width ?? originalJobModel.width,
      height: job.height ?? originalJobModel.height,
      boxDimensions: job.boxDimensions ?? originalJobModel.boxDimensions,
      diePunchCode: job.diePunchCode ?? originalJobModel.diePunchCode,
      boardCategory: job.boardCategory ?? originalJobModel.boardCategory,
      noOfColor: job.noOfColor ?? originalJobModel.noOfColor,
      processColors: job.processColors ?? originalJobModel.processColors,
      specialColor1: job.specialColor1 ?? originalJobModel.specialColor1,
      specialColor2: job.specialColor2 ?? originalJobModel.specialColor2,
      specialColor3: job.specialColor3 ?? originalJobModel.specialColor3,
      specialColor4: job.specialColor4 ?? originalJobModel.specialColor4,
      overPrintFinishing:
          job.overPrintFinishing ?? originalJobModel.overPrintFinishing,
      topFaceGSM: job.topFaceGSM ?? originalJobModel.topFaceGSM,
      flutingGSM: job.flutingGSM ?? originalJobModel.flutingGSM,
      bottomLinerGSM: job.bottomLinerGSM ?? originalJobModel.bottomLinerGSM,
      decalBoardX: job.decalBoardX ?? originalJobModel.decalBoardX,
      lengthBoardY: job.lengthBoardY ?? originalJobModel.lengthBoardY,
      boardSize: job.boardSize ?? originalJobModel.boardSize,
      noUps: job.noUps ?? originalJobModel.noUps,
      artworkReceivedDate:
          job.artworkReceivedDate ?? originalJobModel.artworkReceivedDate,
      artworkApprovedDate:
          job.artworkApprovalDate ?? originalJobModel.artworkApprovedDate,
      shadeCardApprovalDate:
          job.shadeCardApprovalDate ?? originalJobModel.shadeCardApprovalDate,
      srNo: job.srNo ?? originalJobModel.srNo,
      jobDemand: job.jobDemand ?? originalJobModel.jobDemand,
      imageURL: job.imageURL ?? originalJobModel.imageURL,
      createdAt: job.createdAt ?? originalJobModel.createdAt,
      updatedAt: job.updatedAt ?? originalJobModel.updatedAt,
      userId: job.userId ?? originalJobModel.userId,
      machineId: job.machineId ?? originalJobModel.machineId,
    );
  }

  String _jobStatusToString(JobStatus status) {
    switch (status) {
      case JobStatus.active:
        return 'active';
      case JobStatus.inactive:
        return 'inactive';
      case JobStatus.hold:
        return 'hold';
      case JobStatus.workingStarted:
        return 'working started';
      case JobStatus.completed:
        return 'completed';
    }
  }

  Future<void> _onStatusUpdateFromCard(Job job, JobStatus newStatus) async {
    final newStatusString = _jobStatusToString(newStatus);
    try {
      await _jobApi.updateJobStatus(job.nrcJobNo, newStatusString);
      await _loadJobs();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Job ${job.nrcJobNo} status updated to $newStatusString',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.green,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Failed to update job status: ${e.toString()}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.red,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
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

  void _updateJobFromJobCard(Job updatedJob) {
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
      await _loadJobs();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Job ${job.nrcJobNo} status updated to $newStatus',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.green,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Failed to update job status: ${e.toString()}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.red,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
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
        return AppColors.maincolor;
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
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.6,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8E8E8),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),

                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(job.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _getStatusColor(job.status).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        job.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(job.status),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      job.nrcJobNo,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow('Customer', job.customerName),
                        _buildDetailRow('Style/SKU', job.styleItemSKU),
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
                      ],
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

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFF5F5F5),
            width: 1,
          ),
        ),
      ),
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
                color: Color(0xFF757575),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: valueColor ?? const Color(0xFF1A1A1A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSearchDialog(BuildContext context) {
    _searchController.text = _searchQuery;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    color: AppColors.maincolor,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Search Jobs',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Search by Job Number or Customer Name:',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF757575),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Enter job number or customer name...',
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: Colors.grey[500],
                    size: 20,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear_rounded,
                            color: Colors.grey[500],
                            size: 20,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                            Navigator.pop(context);
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppColors.maincolor,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                onSubmitted: (value) {
                  _onSearchChanged(value);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                        Navigator.pop(context);
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFFE8E8E8)),
                        ),
                      ),
                      child: const Text(
                        'Clear',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF757575),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _onSearchChanged(_searchController.text);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.maincolor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Search',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
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

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filter Jobs',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Filter by Status:',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF757575),
                  ),
                ),
                const SizedBox(height: 20),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: SingleChildScrollView(
                    child: Column(
                      children: _availableStatuses.map((status) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: _selectedFilters.contains(status)
                              ? AppColors.maincolor.withOpacity(0.05)
                              : const Color(0xFFFAFAFA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedFilters.contains(status)
                                ? AppColors.maincolor.withOpacity(0.3)
                                : const Color(0xFFE8E8E8),
                            width: 1,
                          ),
                        ),
                        child: CheckboxListTile(
                          title: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: _selectedFilters.contains(status)
                                  ? AppColors.maincolor
                                  : const Color(0xFF1A1A1A),
                            ),
                          ),
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
                          activeColor: AppColors.maincolor,
                          checkColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      )).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedFilters.clear();
                          });
                          Navigator.pop(context);
                          _applyFilters();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xFFE8E8E8)),
                          ),
                        ),
                        child: const Text(
                          'Clear',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF757575),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xFFE8E8E8)),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF757575),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _applyFilters();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.maincolor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Apply',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
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
      ),
    );
  }

  void _editJob(JobModel job) {
    print('Editing job: ${job.nrcJobNo}');
    _navigateToJobDetail(job);
  }

  void _deleteJob(JobModel job) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.delete_outline_rounded,
                  size: 32,
                  color: AppColors.red,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Delete Job',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to delete job ${job.nrcJobNo}?',
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF757575),
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFFE8E8E8)),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF757575),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Row(
                              children: [
                                Icon(Icons.info, color: Colors.white, size: 20),
                                SizedBox(width: 12),
                                Text(
                                  'Delete job functionality needs API implementation',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            backgroundColor: Colors.orange,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            margin: const EdgeInsets.all(16),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Delete',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
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
}