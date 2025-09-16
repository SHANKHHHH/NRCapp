import 'package:flutter/material.dart';
import 'package:nrc/constants/colors.dart';
import 'package:nrc/data/datasources/job_api.dart';
import 'package:dio/dio.dart';
import 'package:nrc/constants/strings.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class PrintingManagerBoard extends StatefulWidget {
  @override
  State<PrintingManagerBoard> createState() => _PrintingManagerBoardState();
}

class _PrintingManagerBoardState extends State<PrintingManagerBoard>
    with TickerProviderStateMixin {
  late final JobApi _jobApi;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allJobs = [];
  List<Map<String, dynamic>> _filteredJobs = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';
  DateTimeRange? _customDateRange;
  
  // Cache for API responses to avoid redundant calls
  Map<String, dynamic>? _cachedPlannings;
  Map<String, Map<String, dynamic>> _cachedPrintingDetails = {};
  DateTime? _lastCacheTime;
  static const Duration _cacheValidity = Duration(minutes: 5);

  final List<String> _filterOptions = ['All', 'Daily', 'Weekly', 'Monthly', 'Custom'];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    final dio = Dio();
    dio.options.baseUrl = '${AppStrings.baseUrl}/api';
    _jobApi = JobApi(dio);

    _loadJobs();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _applyFilters();
  }

  Future<void> _loadJobs() async {
    setState(() => _isLoading = true);
    try {
      final jobs = await _fetchActiveJobsWithDetails();
      setState(() {
        _allJobs = jobs;
        _filteredJobs = jobs;
        _isLoading = false;
      });
      _animationController.forward();
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load jobs: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchActiveJobsWithDetails() async {
    // Check if cache is still valid
    if (_lastCacheTime != null && 
        DateTime.now().difference(_lastCacheTime!) < _cacheValidity &&
        _cachedPlannings != null) {
      print('Using cached data');
      return _processJobsWithCachedData();
    }

    print('Fetching fresh data');
    final jobs = await _jobApi.getJobs();
    final plannings = await _jobApi.getAllJobPlannings();
    
    // Cache the plannings data
    _cachedPlannings = {
      'data': plannings,
      'timestamp': DateTime.now(),
    };
    _lastCacheTime = DateTime.now();
    
    return _processJobsWithPlannings(jobs, plannings);
  }

  List<Map<String, dynamic>> _processJobsWithCachedData() {
    final jobs = _allJobs.map((jobData) => jobData['job']).toList();
    final plannings = _cachedPlannings!['data'] as List<Map<String, dynamic>>;
    return _processJobsWithPlannings(jobs, plannings);
  }

  List<Map<String, dynamic>> _processJobsWithPlannings(List jobs, List<Map<String, dynamic>> plannings) {
    List<Map<String, dynamic>> result = [];

    for (final job in jobs) {
      if (job.status == 'ACTIVE') {
        final nrcJobNo = job.nrcJobNo;
        final planning = plannings.firstWhereOrNull((p) => p['nrcJobNo'] == nrcJobNo);

        Map<String, dynamic>? printingStep;
        String workflowStatus = 'Not Started';
        
        if (planning != null && planning['steps'] != null) {
          final steps = planning['steps'] as List<dynamic>;
          printingStep = steps.firstWhereOrNull(
                (s) => s['stepName'] == 'PrintingDetails',
          );
          
          // Determine workflow status based on printing step
          if (printingStep != null) {
            final status = printingStep['status']?.toString().toLowerCase() ?? '';
            switch (status) {
              case 'start':
                workflowStatus = 'In Progress';
                break;
              case 'stop':
                workflowStatus = 'Completed';
                break;
              case 'planned':
              default:
                workflowStatus = 'Not Started';
                break;
            }
          }
        }

        // Only fetch printing details if not cached or if cache is old
        Map<String, dynamic>? printingDetails;
        if (!_cachedPrintingDetails.containsKey(nrcJobNo) || 
            DateTime.now().difference(_lastCacheTime!) > _cacheValidity) {
          try {
            _jobApi.getPrintingDetails(nrcJobNo).then((printingRes) {
              if (printingRes != null &&
                  printingRes['data'] is List &&
                  printingRes['data'].isNotEmpty) {
                _cachedPrintingDetails[nrcJobNo] = printingRes['data'][0];
              }
            });
          } catch (e) {
            print('Error fetching printing details for $nrcJobNo: $e');
          }
        } else {
          printingDetails = _cachedPrintingDetails[nrcJobNo];
        }

        final artworkStatus = _determineArtworkStatus(job);

        result.add({
          'job': job,
          'artworkStatus': artworkStatus,
          'workflowStatus': workflowStatus,
          'printingStep': printingStep,
          'printingDetails': printingDetails,
        });
      }
    }
    return result;
  }

  String _determineArtworkStatus(dynamic job) {
    final allArtworkNull = job.artworkReceivedDate == null &&
        job.artworkApprovedDate == null &&
        job.shadeCardApprovalDate == null &&
        job.imageURL == null;

    if (allArtworkNull) return 'Pending';

    if (job.artworkReceivedDate != null &&
        job.artworkApprovedDate != null &&
        job.shadeCardApprovalDate != null) {
      return 'Artwork Complete';
    }

    return 'In Progress';
  }

  void _applyFilters() {
    String searchQuery = _searchController.text.toLowerCase();
    DateTime now = DateTime.now();

    setState(() {
      _filteredJobs = _allJobs.where((jobData) {
        final job = jobData['job'];
        final jobCreatedAt = DateTime.parse(job.createdAt);

        // Search filter
        bool matchesSearch = searchQuery.isEmpty ||
            (job.nrcJobNo?.toLowerCase().contains(searchQuery) ?? false) ||
            (job.customerName?.toLowerCase().contains(searchQuery) ?? false) ||
            (job.styleItemSKU?.toLowerCase().contains(searchQuery) ?? false);

        if (!matchesSearch) return false;

        // Date filter
        switch (_selectedFilter) {
          case 'Daily':
            return _isSameDay(jobCreatedAt, now);
          case 'Weekly':
            return _isWithinWeek(jobCreatedAt, now);
          case 'Monthly':
            return _isSameMonth(jobCreatedAt, now);
          case 'Custom':
            if (_customDateRange != null) {
              return jobCreatedAt.isAfter(_customDateRange!.start.subtract(Duration(days: 1))) &&
                  jobCreatedAt.isBefore(_customDateRange!.end.add(Duration(days: 1)));
            }
            return true;
          default:
            return true;
        }
      }).toList();
    });
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  bool _isWithinWeek(DateTime date1, DateTime date2) {
    DateTime startOfWeek = date2.subtract(Duration(days: date2.weekday - 1));
    DateTime endOfWeek = startOfWeek.add(Duration(days: 6));
    return date1.isAfter(startOfWeek.subtract(Duration(days: 1))) &&
        date1.isBefore(endOfWeek.add(Duration(days: 1)));
  }

  bool _isSameMonth(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month;
  }

  Future<void> _selectCustomDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(Duration(days: 365)),
      initialDateRange: _customDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.maincolor,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _selectedFilter = 'Custom';
      });
      _applyFilters();
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'artwork complete':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'in progress':
        return Colors.blue;
      case 'not started':
        return Colors.grey;
      case 'completed':
        return Colors.green;
      case 'start':
        return Colors.green;
      case 'stop':
        return Colors.red;
      case 'planned':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(child: _buildSearchAndFilters()),
          SliverToBoxAdapter(child: _buildStatsCard()),
          SliverToBoxAdapter(child: _buildStatusChart()),
          _buildJobsList(),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.maincolor,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'Printing Manager',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.maincolor,
                AppColors.maincolor.withOpacity(0.8),
              ],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.refresh, color: Colors.white),
          onPressed: () {
            // Clear cache and reload
            _cachedPlannings = null;
            _cachedPrintingDetails.clear();
            _lastCacheTime = null;
            _loadJobs();
          },
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by Job No, Customer, or SKU...',
                prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey[600]),
                  onPressed: () {
                    _searchController.clear();
                    _applyFilters();
                  },
                )
                    : null,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          SizedBox(height: 16),
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filterOptions.map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      filter == 'Custom' && _customDateRange != null
                          ? 'Custom (${DateFormat('MMM dd').format(_customDateRange!.start)} - ${DateFormat('MMM dd').format(_customDateRange!.end)})'
                          : filter,
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppColors.maincolor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (filter == 'Custom') {
                        _selectCustomDateRange();
                      } else {
                        setState(() {
                          _selectedFilter = filter;
                          if (filter != 'Custom') _customDateRange = null;
                        });
                        _applyFilters();
                      }
                    },
                    selectedColor: AppColors.maincolor,
                    backgroundColor: Colors.white,
                    checkmarkColor: Colors.white,
                    elevation: isSelected ? 4 : 2,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.indigo.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            'Total Jobs',
            _filteredJobs.length.toString(),
            Icons.work_outline,
            Colors.blue,
          ),
          _buildStatItem(
            'Completed',
            _filteredJobs.where((j) => j['workflowStatus'] == 'Completed').length.toString(),
            Icons.check_circle_outline,
            Colors.green,
          ),
          _buildStatItem(
            'In Progress',
            _filteredJobs.where((j) => j['workflowStatus'] == 'In Progress').length.toString(),
            Icons.hourglass_empty,
            Colors.orange,
          ),
          _buildStatItem(
            'Not Started',
            _filteredJobs.where((j) => j['workflowStatus'] == 'Not Started').length.toString(),
            Icons.pending_outlined,
            Colors.grey,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChart() {
    final int completed = _filteredJobs.where((j) => (j['workflowStatus'] as String).toLowerCase() == 'completed').length;
    final int inProgress = _filteredJobs.where((j) => (j['workflowStatus'] as String).toLowerCase() == 'in progress').length;
    final int notStarted = _filteredJobs.where((j) => (j['workflowStatus'] as String).toLowerCase() == 'not started').length;

    final entries = [
      {
        'label': 'Completed',
        'count': completed,
        'color': Colors.green,
      },
      {
        'label': 'In Progress',
        'count': inProgress,
        'color': Colors.orange,
      },
      {
        'label': 'Not Started',
        'count': notStarted,
        'color': Colors.grey,
      },
    ].where((e) => (e['count'] as int) > 0).toList();

    if (entries.isEmpty) {
      return Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'No status data to display',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Workflow Status',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.grey[800],
              ),
            ),
          ),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 36,
                sections: entries
                    .map(
                      (e) => PieChartSectionData(
                        color: e['color'] as Color,
                        value: (e['count'] as int).toDouble(),
                        title: (e['count'] as int).toString(),
                        titleStyle: TextStyle(
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
          SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: entries
                .map(
                  (e) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: e['color'] as Color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        '${e['label']}: ${e['count']}',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String title, String count, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        SizedBox(height: 8),
        Text(
          count,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildJobsList() {
    if (_isLoading) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.maincolor),
              SizedBox(height: 16),
              Text('Loading jobs...', style: TextStyle(color: Colors.grey[600])),
            ],
          ),
        ),
      );
    }

    if (_filteredJobs.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
              SizedBox(height: 16),
              Text(
                'No jobs found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Try adjusting your search or filter criteria',
                style: TextStyle(color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset(0, 0.3),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: _animationController,
                curve: Interval(
                  (index / _filteredJobs.length) * 0.5,
                  1,
                  curve: Curves.easeOutQuart,
                ),
              )),
              child: _buildJobCard(_filteredJobs[index], index),
            ),
          );
        },
        childCount: _filteredJobs.length,
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> jobData, int index) {
    final job = jobData['job'];
    final artworkStatus = jobData['artworkStatus'];
    final workflowStatus = jobData['workflowStatus'];
    final printingStep = jobData['printingStep'];
    final printingDetails = jobData['printingDetails'];

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ExpansionTile(
          tilePadding: EdgeInsets.all(20),
          childrenPadding: EdgeInsets.fromLTRB(20, 0, 20, 20),
          leading: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: _getStatusColor(workflowStatus).withOpacity(0.1),
            ),
            child: job.imageURL != null
                ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                job.imageURL,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.image,
                  color: _getStatusColor(workflowStatus),
                  size: 30,
                ),
              ),
            )
                : Icon(
              Icons.work,
              color: _getStatusColor(workflowStatus),
              size: 30,
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                job.nrcJobNo ?? 'N/A',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 4),
              Text(
                job.customerName ?? 'N/A',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(workflowStatus).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      workflowStatus,
                      style: TextStyle(
                        color: _getStatusColor(workflowStatus),
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(artworkStatus).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      artworkStatus,
                      style: TextStyle(
                        color: _getStatusColor(artworkStatus),
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          children: [
            _buildJobDetails(job, printingStep, printingDetails, workflowStatus),
          ],
        ),
      ),
    );
  }

  Widget _buildJobDetails(dynamic job, Map<String, dynamic>? printingStep, Map<String, dynamic>? printingDetails, String workflowStatus) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: Colors.grey[200]),
        SizedBox(height: 12),

        // Job Information
        _buildSectionTitle('Job Information'),
        _buildDetailRow('Style Item SKU', job.styleItemSKU ?? 'N/A'),
        _buildDetailRow('Flute Type', job.fluteType ?? 'N/A'),
        _buildDetailRow('Box Dimensions', job.boxDimensions ?? 'N/A'),
        _buildDetailRow('Job Demand', job.jobDemand ?? 'N/A'),

        SizedBox(height: 16),

        // Workflow Status
        _buildSectionTitle('Workflow Status'),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _getStatusColor(workflowStatus).withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _getStatusColor(workflowStatus).withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(
                _getWorkflowIcon(workflowStatus),
                color: _getStatusColor(workflowStatus),
                size: 24,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workflowStatus,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: _getStatusColor(workflowStatus),
                      ),
                    ),
                    Text(
                      _getWorkflowDescription(workflowStatus),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 16),

        // Artwork Dates
        _buildSectionTitle('Artwork Timeline'),
        Row(
          children: [
            Expanded(child: _buildArtworkDateTile('Received', job.artworkReceivedDate)),
            Expanded(child: _buildArtworkDateTile('Approved', job.artworkApprovedDate)),
            Expanded(child: _buildArtworkDateTile('Shade Card', job.shadeCardApprovalDate)),
          ],
        ),

        SizedBox(height: 16),

        // Printing Step Information
        if (printingStep != null) ...[
          _buildSectionTitle('Printing Step Status'),
          _buildPrintingStepInfo(printingStep),
          SizedBox(height: 16),
        ],

        // Printing Details
        if (printingDetails != null) ...[
          _buildSectionTitle('Printing Details'),
          _buildPrintingDetailsInfo(printingDetails),
        ],
      ],
    );
  }

  IconData _getWorkflowIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Icons.check_circle;
      case 'in progress':
        return Icons.play_circle;
      case 'not started':
        return Icons.schedule;
      default:
        return Icons.help;
    }
  }

  String _getWorkflowDescription(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'Printing workflow has been completed';
      case 'in progress':
        return 'Printing workflow is currently in progress';
      case 'not started':
        return 'Printing workflow has not started yet';
      default:
        return 'Status unknown';
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: AppColors.maincolor,
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtworkDateTile(String label, dynamic date) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: date != null ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: date != null ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4),
          Text(
            date != null ? DateFormat('MMM dd, yy').format(DateTime.parse(date)) : 'Pending',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: date != null ? Colors.green[700] : Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPrintingStepInfo(Map<String, dynamic> printingStep) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(printingStep['status'] ?? '').withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  (printingStep['status'] ?? 'N/A').toUpperCase(),
                  style: TextStyle(
                    color: _getStatusColor(printingStep['status'] ?? ''),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              Spacer(),
              Text(
                'Step ${printingStep['stepNo'] ?? 'N/A'}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTimeInfo(
                  'Start Date',
                  printingStep['startDate'],
                  Icons.play_arrow,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildTimeInfo(
                  'End Date',
                  printingStep['endDate'],
                  Icons.stop,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeInfo(String label, dynamic date, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey[600]),
            SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        Text(
          date != null ? DateFormat('MMM dd, yy HH:mm').format(DateTime.parse(date)) : 'N/A',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Widget _buildPrintingDetailsInfo(Map<String, dynamic> printingDetails) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildDetailItem('Machine', printingDetails['machine'], Icons.precision_manufacturing)),
              Expanded(child: _buildDetailItem('Operator', printingDetails['oprName'], Icons.person)),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildDetailItem('OK Qty', printingDetails['postPrintingFinishingOkQty']?.toString(), Icons.check_circle)),
              Expanded(child: SizedBox()), // Empty space for alignment
            ],
          ),
          if (printingDetails['inksUsed'] != null) ...[
            SizedBox(height: 12),
            _buildDetailItem('Inks Used', printingDetails['inksUsed'], Icons.colorize),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, dynamic value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey[600]),
            SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        Text(
          value?.toString() ?? 'N/A',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }
}