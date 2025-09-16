import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../constants/colors.dart';
import '../../../data/datasources/job_api.dart';
import 'package:fl_chart/fl_chart.dart';



class QualityBoard extends StatefulWidget {
  const QualityBoard({Key? key}) : super(key: key);

  @override
  State<QualityBoard> createState() => _QualityBoardState();
}

class _QualityBoardState extends State<QualityBoard>
    with TickerProviderStateMixin {
  late final JobApi jobApi;
  late TabController _tabController;
  bool isLoading = true;
  String? error;
  List<_QCJobInfo> qcJobs = [];
  List<_QCJobInfo> filteredJobs = [];

  // Filter and search variables
  String searchQuery = '';
  String selectedTimeFilter = 'All';
  DateTimeRange? customDateRange;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    jobApi = JobApi(Dio());
    _tabController = TabController(length: 5, vsync: this);
    _fetchQCJobs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchQCJobs() async {
    setState(() {
      isLoading = true;
      error = null;
      qcJobs = [];
    });

    try {
      final jobPlannings = await jobApi.getAllJobPlannings();
      if (jobPlannings == null || jobPlannings.isEmpty) {
        throw Exception('No job plannings found');
      }

      List<_QCJobInfo> jobs = [];
      for (final job in jobPlannings) {
        final steps = job['steps'] as List<dynamic>? ?? [];
        final qcStep = steps.firstWhere(
              (step) => step['stepName'] == 'QualityDept',
          orElse: () => null,
        );

        if (qcStep != null) {
          final nrcJobNo = job['nrcJobNo'];
          final qcDetailsRes = await jobApi.getQCDetails(nrcJobNo);
          final qcDetails = (qcDetailsRes != null &&
              qcDetailsRes['data'] is List &&
              qcDetailsRes['data'].isNotEmpty)
              ? qcDetailsRes['data'][0]
              : null;

          jobs.add(_QCJobInfo(
            nrcJobNo: nrcJobNo,
            jobDemand: job['jobDemand'],
            qcStatus: qcDetails?['status'] ?? qcStep['status'],
            qcDate: qcDetails?['date'] ?? qcStep['endDate'],
            checkedBy: qcDetails?['checkedBy'],
            passQty: qcDetails?['passQty'],
            rejectedQty: qcDetails?['rejectedQty'],
            reasonForRejection: qcDetails?['reasonForRejection'],
            remarks: qcDetails?['remarks'],
            dispatchStatus: _getDispatchStatus(qcDetails?['status'] ?? qcStep['status']),
          ));
        }
      }

      // Sort by QC status and date (most recent first)
      jobs.sort((a, b) {
        int statusCmp = (b.qcStatus ?? '').compareTo(a.qcStatus ?? '');
        if (statusCmp != 0) return statusCmp;
        DateTime? dateA = a.qcDate != null ? DateTime.tryParse(a.qcDate!) : null;
        DateTime? dateB = b.qcDate != null ? DateTime.tryParse(b.qcDate!) : null;
        if (dateA != null && dateB != null) {
          return dateB.compareTo(dateA);
        }
        return 0;
      });

      setState(() {
        qcJobs = jobs;
        filteredJobs = jobs;
        isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  String _getDispatchStatus(String? qcStatus) {
    switch (qcStatus) {
      case 'accept':
        return 'Ready for Dispatch';
      case 'stop':
        return 'Dispatched';
      case 'start':
        return 'Under Process';
      case 'planned':
        return 'Planned';
      default:
        return 'Pending';
    }
  }

  void _applyFilters() {
    List<_QCJobInfo> filtered = qcJobs;

    // Apply search filter
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((job) {
        return (job.nrcJobNo?.toLowerCase().contains(searchQuery.toLowerCase()) ?? false) ||
            (job.jobDemand?.toLowerCase().contains(searchQuery.toLowerCase()) ?? false);
      }).toList();
    }

    // Apply time filter
    DateTime now = DateTime.now();
    DateTime? startDate;

    switch (selectedTimeFilter) {
      case 'Daily':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'Weekly':
        startDate = now.subtract(Duration(days: 7));
        break;
      case 'Monthly':
        startDate = DateTime(now.year, now.month - 1, now.day);
        break;
      case 'Custom':
        if (customDateRange != null) {
          filtered = filtered.where((job) {
            if (job.qcDate == null) return false;
            DateTime? jobDate = DateTime.tryParse(job.qcDate!);
            return jobDate != null &&
                jobDate.isAfter(customDateRange!.start.subtract(Duration(days: 1))) &&
                jobDate.isBefore(customDateRange!.end.add(Duration(days: 1)));
          }).toList();
        }
        break;
      default:
      // All - no date filtering
        startDate = null;
        break;
    }

    if (selectedTimeFilter != 'All' && selectedTimeFilter != 'Custom' && startDate != null) {
      filtered = filtered.where((job) {
        if (job.qcDate == null) return false;
        DateTime? jobDate = DateTime.tryParse(job.qcDate!);
        return jobDate != null && jobDate.isAfter(startDate!);
      }).toList();
    }

    setState(() {
      filteredJobs = filtered;
    });
  }

  Future<void> _selectCustomDateRange() async {
    DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(Duration(days: 365)),
      initialDateRange: customDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.deepPurple,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        customDateRange = picked;
        selectedTimeFilter = 'Custom';
      });
      _applyFilters();
    }
  }

  Widget _buildStatsCards() {
    int totalJobs = filteredJobs.length;
    int completedJobs = filteredJobs.where((job) => job.qcStatus == 'accept').length;
    int inProgressJobs = filteredJobs.where((job) => job.qcStatus == 'start').length;

    return Container(
      height: 120,
      padding: EdgeInsets.symmetric(vertical: 6),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildStatCard('Total Jobs', totalJobs.toString(), AppColors.maincolor, Icons.work),
          _buildStatCard('Completed', completedJobs.toString(), Colors.green, Icons.check_circle),
          _buildStatCard('In Progress', inProgressJobs.toString(), Colors.orange, Icons.hourglass_empty),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Container(
      width: 120,
      margin: EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.8), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by Job Number or Demand...',
                prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey[600]),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      searchQuery = '';
                    });
                    _applyFilters();
                  },
                )
                    : null,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
                _applyFilters();
              },
            ),
          ),
          SizedBox(height: 12),
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All'),
                _buildFilterChip('Daily'),
                _buildFilterChip('Weekly'),
                _buildFilterChip('Monthly'),
                _buildCustomDateChip(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    bool isSelected = selectedTimeFilter == label;
    return Container(
      margin: EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            selectedTimeFilter = selected ? label : 'All';
            if (label != 'Custom') customDateRange = null;
          });
          _applyFilters();
        },
        backgroundColor: Colors.grey[100],
        selectedColor: AppColors.maincolor.withOpacity(0.2),
        checkmarkColor: AppColors.maincolor,
        labelStyle: TextStyle(
          color: isSelected ? AppColors.maincolor : Colors.grey[700],
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildCustomDateChip() {
    bool isSelected = selectedTimeFilter == 'Custom';
    return Container(
      margin: EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.date_range, size: 16, color: isSelected ? AppColors.maincolor : Colors.grey[700]),
            SizedBox(width: 4),
            Text(isSelected && customDateRange != null
                ? '${customDateRange!.start.day}/${customDateRange!.start.month} - ${customDateRange!.end.day}/${customDateRange!.end.month}'
                : 'Custom'),
          ],
        ),
        onPressed: _selectCustomDateRange,
        backgroundColor: isSelected ? AppColors.maincolor.withOpacity(0.2) : Colors.grey[100],
        labelStyle: TextStyle(
          color: isSelected ? AppColors.maincolor : Colors.grey[700],
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Quality Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.maincolor, AppColors.maincolor.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _fetchQCJobs,
            tooltip: 'Refresh Data',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
          unselectedLabelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          tabs: [
            Tab(text: 'All (${filteredJobs.length})'),
            Tab(text: 'Completed (${filteredJobs.where((job) => job.qcStatus == 'accept').length})'),
            Tab(text: 'In Progress (${filteredJobs.where((job) => job.qcStatus == 'start').length})'),
            Tab(text: 'Planned (${filteredJobs.where((job) => job.qcStatus == 'planned').length})'),
            Tab(text: 'Stopped (${filteredJobs.where((job) => job.qcStatus == 'stop').length})'),
          ],
        ),
      ),
      body: isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
            ),
            SizedBox(height: 16),
            Text('Loading Quality Data...', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      )
          : error != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            SizedBox(height: 16),
            Text(
              'Error Loading Data',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red[600]),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchQCJobs,
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.maincolor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      )
          : Column(
        children: [
          _buildStatsCards(),
          _buildQCStatusChart(),
          _buildSearchAndFilter(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildJobList(filteredJobs),
                _buildJobList(filteredJobs.where((job) => job.qcStatus == 'accept').toList()),
                _buildJobList(filteredJobs.where((job) => job.qcStatus == 'start').toList()),
                _buildJobList(filteredJobs.where((job) => job.qcStatus == 'planned').toList()),
                _buildJobList(filteredJobs.where((job) => job.qcStatus == 'stop').toList()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQCStatusChart() {
    final total = filteredJobs.length;
    final accepted = filteredJobs.where((j) => j.qcStatus == 'accept').length;
    final started = filteredJobs.where((j) => j.qcStatus == 'start').length;
    final planned = filteredJobs.where((j) => j.qcStatus == 'planned').length;
    final stopped = filteredJobs.where((j) => j.qcStatus == 'stop').length;

    final entries = [
      {'label': 'Completed', 'count': accepted, 'color': Colors.green},
      {'label': 'In Progress', 'count': started, 'color': Colors.orange},
      {'label': 'Planned', 'count': planned, 'color': Colors.blue},
      {'label': 'Stopped', 'count': stopped, 'color': Colors.purple},
    ].where((e) => (e['count'] as int) > 0).toList();

    return Container(
      margin: EdgeInsets.only(left: 16, right: 16, bottom: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'QC Status Overview${total > 0 ? ' ($total)' : ''}',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey[800]),
          ),
          SizedBox(height: 12),
          if (entries.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('No QC data to display', style: TextStyle(color: Colors.grey[600])),
              ),
            )
          else ...[
            SizedBox(
              height: 180,
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
            SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: entries
                  .map(
                    (e) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: e['color'] as Color, shape: BoxShape.circle)),
                        SizedBox(width: 6),
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

  Widget _buildJobList(List<_QCJobInfo> jobs) {
    if (jobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No jobs found',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            if (searchQuery.isNotEmpty || selectedTimeFilter != 'All')
              Text(
                'Try adjusting your filters',
                style: TextStyle(color: Colors.grey[500]),
              ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchQCJobs,
      color: AppColors.maincolor,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: jobs.length,
        itemBuilder: (context, index) {
          final job = jobs[index];
          return _buildJobCard(job);
        },
      ),
    );
  }

  Widget _buildJobCard(_QCJobInfo job) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          _showJobDetails(job);
        },
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _statusColor(job.qcStatus).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getStatusIcon(job.qcStatus),
                      color: _statusColor(job.qcStatus),
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.nrcJobNo ?? '-',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        Text(
                          'Demand: ${job.jobDemand ?? '-'}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _statusColor(job.qcStatus),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusDisplay(job.qcStatus),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),

              // Dispatch Status
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.local_shipping, color: Colors.deepPurple, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Dispatch Status: ',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    Text(
                      job.dispatchStatus ?? 'Unknown',
                      style: TextStyle(
                        color: Colors.deepPurple,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              if (job.qcDate != null) ...[
                SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.schedule, color: Colors.grey[600], size: 16),
                    SizedBox(width: 6),
                    Text(
                      'QC Date: ${_formatDateTime(job.qcDate!)}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ],

              if (job.checkedBy != null && job.checkedBy!.isNotEmpty) ...[
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.person, color: Colors.grey[600], size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Checked By: ${job.checkedBy}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ],

              if (job.passQty != null || job.rejectedQty != null) ...[
                SizedBox(height: 12),
                Row(
                  children: [
                    if (job.passQty != null) ...[
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '${job.passQty}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              Text(
                                'Passed',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                    ],
                    if (job.rejectedQty != null) ...[
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '${job.rejectedQty}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                              Text(
                                'Rejected',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showJobDetails(_QCJobInfo job) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Job Details',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 24),
                    _buildDetailRow('Job Number', job.nrcJobNo ?? '-'),
                    _buildDetailRow('Job Demand', job.jobDemand ?? '-'),
                    _buildDetailRow('QC Status', _statusDisplay(job.qcStatus)),
                    _buildDetailRow('Dispatch Status', job.dispatchStatus ?? 'Unknown'),
                    if (job.qcDate != null)
                      _buildDetailRow('QC Date', _formatDateTime(job.qcDate!)),
                    if (job.checkedBy != null && job.checkedBy!.isNotEmpty)
                      _buildDetailRow('Checked By', job.checkedBy!),
                    if (job.passQty != null)
                      _buildDetailRow('Pass Quantity', job.passQty.toString()),
                    if (job.rejectedQty != null)
                      _buildDetailRow('Rejected Quantity', job.rejectedQty.toString()),
                    if (job.reasonForRejection != null && job.reasonForRejection!.isNotEmpty)
                      _buildDetailRow('Reason for Rejection', job.reasonForRejection!),
                    if (job.remarks != null && job.remarks!.isNotEmpty)
                      _buildDetailRow('Remarks', job.remarks!),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'accept':
        return Icons.check_circle;
      case 'planned':
        return Icons.schedule;
      case 'start':
        return Icons.play_circle;
      case 'stop':
        return Icons.stop_circle;
      default:
        return Icons.help_outline;
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'accept':
        return Colors.green;
      case 'planned':
        return Colors.blue;
      case 'start':
        return Colors.orange;
      case 'stop':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _statusDisplay(String? status) {
    switch (status) {
      case 'accept':
        return 'Completed';
      case 'planned':
        return 'Planned';
      case 'start':
        return 'In Progress';
      case 'stop':
        return 'Stopped';
      default:
        return status ?? 'Unknown';
    }
  }

  String _formatDateTime(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }
}

class _QCJobInfo {
  final String? nrcJobNo;
  final String? jobDemand;
  final String? qcStatus;
  final String? qcDate;
  final String? checkedBy;
  final int? passQty;
  final int? rejectedQty;
  final String? reasonForRejection;
  final String? remarks;
  final String? dispatchStatus;

  _QCJobInfo({
    this.nrcJobNo,
    this.jobDemand,
    this.qcStatus,
    this.qcDate,
    this.checkedBy,
    this.passQty,
    this.rejectedQty,
    this.reasonForRejection,
    this.remarks,
    this.dispatchStatus,
  });
}