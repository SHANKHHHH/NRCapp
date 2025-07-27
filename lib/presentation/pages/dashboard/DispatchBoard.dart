import 'dart:math' as MainSize;

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../data/datasources/job_api.dart';

class DispatchBoard extends StatefulWidget {
  const DispatchBoard({Key? key}) : super(key: key);

  @override
  State<DispatchBoard> createState() => _DispatchBoardState();
}

class _DispatchBoardState extends State<DispatchBoard>
    with TickerProviderStateMixin {
  late final JobApi jobApi;
  late TabController _tabController;

  bool isLoading = true;
  String? error;
  List<_DispatchJobInfo> allDispatchJobs = [];
  List<_DispatchJobInfo> filteredJobs = [];

  String searchQuery = '';
  String selectedFilter = 'All';
  DateTimeRange? customDateRange;

  final TextEditingController _searchController = TextEditingController();
  final List<String> filterOptions = ['All', 'Daily', 'Weekly', 'Monthly', 'Custom'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    jobApi = JobApi(Dio());
    _fetchDispatchJobs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchDispatchJobs() async {
    setState(() {
      isLoading = true;
      error = null;
      allDispatchJobs = [];
      filteredJobs = [];
    });

    try {
      final jobPlannings = await jobApi.getAllJobPlannings();
      if (jobPlannings == null || jobPlannings.isEmpty) {
        throw Exception('No job plannings found');
      }

      List<_DispatchJobInfo> jobs = [];

      for (final job in jobPlannings) {
        final steps = job['steps'] as List<dynamic>? ?? [];
        final dispatchStep = steps.firstWhere(
              (step) => step['stepName'] == 'DispatchProcess',
          orElse: () => null,
        );

        if (dispatchStep != null) {
          final nrcJobNo = job['nrcJobNo'];
          final dispatchDetailsRes = await jobApi.getDispatchDetails(nrcJobNo);
          final dispatchDetails = (dispatchDetailsRes != null &&
              dispatchDetailsRes['data'] is List &&
              dispatchDetailsRes['data'].isNotEmpty)
              ? dispatchDetailsRes['data'][0]
              : null;

          jobs.add(_DispatchJobInfo(
            nrcJobNo: nrcJobNo,
            jobDemand: job['jobDemand'],
            dispatchStatus: dispatchDetails?['status'] ?? dispatchStep['status'],
            dispatchDate: dispatchDetails?['dispatchDate'] ?? dispatchStep['endDate'],
            dispatchNo: dispatchDetails?['dispatchNo'],
            operatorName: dispatchDetails?['operatorName'],
            noOfBoxes: dispatchDetails?['noOfBoxes'],
            remarks: dispatchDetails?['remarks'],
          ));
        }
      }

      // Sort by dispatch status priority and date
      jobs.sort((a, b) {
        final statusPriorityA = _getStatusPriority(a.dispatchStatus);
        final statusPriorityB = _getStatusPriority(b.dispatchStatus);

        if (statusPriorityA != statusPriorityB) {
          return statusPriorityA.compareTo(statusPriorityB);
        }

        DateTime? dateA = a.dispatchDate != null ? DateTime.tryParse(a.dispatchDate!) : null;
        DateTime? dateB = b.dispatchDate != null ? DateTime.tryParse(b.dispatchDate!) : null;

        if (dateA != null && dateB != null) {
          return dateB.compareTo(dateA);
        }
        return 0;
      });

      setState(() {
        allDispatchJobs = jobs;
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

  int _getStatusPriority(String? status) {
    switch (status?.toLowerCase()) {
      case 'start':
        return 1;
      case 'planned':
        return 2;
      case 'accept':
        return 3;
      case 'stop':
        return 4;
      default:
        return 5;
    }
  }

  void _applyFilters() {
    List<_DispatchJobInfo> filtered = List.from(allDispatchJobs);

    // Apply search filter
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((job) {
        return job.nrcJobNo?.toLowerCase().contains(searchQuery.toLowerCase()) ?? false;
      }).toList();
    }

    // Apply date filter
    final now = DateTime.now();
    switch (selectedFilter) {
      case 'Daily':
        filtered = filtered.where((job) {
          if (job.dispatchDate == null) return false;
          final jobDate = DateTime.tryParse(job.dispatchDate!);
          if (jobDate == null) return false;
          return jobDate.year == now.year &&
              jobDate.month == now.month &&
              jobDate.day == now.day;
        }).toList();
        break;

      case 'Weekly':
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 6));
        filtered = filtered.where((job) {
          if (job.dispatchDate == null) return false;
          final jobDate = DateTime.tryParse(job.dispatchDate!);
          if (jobDate == null) return false;
          return jobDate.isAfter(weekStart.subtract(const Duration(days: 1))) &&
              jobDate.isBefore(weekEnd.add(const Duration(days: 1)));
        }).toList();
        break;

      case 'Monthly':
        filtered = filtered.where((job) {
          if (job.dispatchDate == null) return false;
          final jobDate = DateTime.tryParse(job.dispatchDate!);
          if (jobDate == null) return false;
          return jobDate.year == now.year && jobDate.month == now.month;
        }).toList();
        break;

      case 'Custom':
        if (customDateRange != null) {
          filtered = filtered.where((job) {
            if (job.dispatchDate == null) return false;
            final jobDate = DateTime.tryParse(job.dispatchDate!);
            if (jobDate == null) return false;
            return jobDate.isAfter(customDateRange!.start.subtract(const Duration(days: 1))) &&
                jobDate.isBefore(customDateRange!.end.add(const Duration(days: 1)));
          }).toList();
        }
        break;
    }

    setState(() {
      filteredJobs = filtered;
    });
  }

  void _selectCustomDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: customDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blueAccent,
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        customDateRange = picked;
        selectedFilter = 'Custom';
      });
      _applyFilters();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text(
          'Dispatch Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.blueAccent),
            onPressed: _fetchDispatchJobs,
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                      });
                      _applyFilters();
                    },
                    decoration: InputDecoration(
                      hintText: 'Search by Job Number...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
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
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),

              // Filter Tabs
              Container(
                height: 50,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: TabBar(
          controller: _tabController,
                  isScrollable: true,
                  indicatorColor: Colors.blueAccent,
                  indicatorWeight: 3,
                  labelColor: Colors.blueAccent,
                  unselectedLabelColor: Colors.grey[600],
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                  onTap: (index) {
                    setState(() {
                      selectedFilter = filterOptions[index];
                      if (selectedFilter == 'Custom' && customDateRange == null) {
                        _selectCustomDateRange();
                      }
                    });
                    _applyFilters();
                  },
                  tabs: filterOptions.map((filter) {
                    return Tab(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Text(filter),
                            if (filter == 'Custom' && customDateRange != null)
                              GestureDetector(
                                onTap: _selectCustomDateRange,
                                child: const Icon(Icons.edit, size: 16),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      body: isLoading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.blueAccent),
            SizedBox(height: 16),
            Text(
              'Loading dispatch jobs...',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      )
          : error != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Error Loading Data',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red[700],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red[600]),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchDispatchJobs,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      )
          : filteredJobs.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              searchQuery.isNotEmpty
                  ? 'No jobs found for "$searchQuery"'
                  : 'No dispatch jobs found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            if (searchQuery.isNotEmpty || selectedFilter != 'All') ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    searchQuery = '';
                    selectedFilter = 'All';
                    _tabController.animateTo(0);
                  });
                  _applyFilters();
                },
                child: const Text('Clear Filters'),
              ),
            ],
          ],
        ),
      )
          : Column(
        children: [
          // Stats Header
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _buildStatsRow(),
          ),

          // Job List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchDispatchJobs,
              color: Colors.blueAccent,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: filteredJobs.length,
                itemBuilder: (context, index) {
                  final job = filteredJobs[index];
                  return _buildJobCard(job);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final stats = _calculateStats();
    return Row(
      children: [
        Expanded(child: _buildStatItem('Total', filteredJobs.length, Colors.blue)),
        Expanded(child: _buildStatItem('In Progress', stats['start'] ?? 0, Colors.orange)),
        Expanded(child: _buildStatItem('Planned', stats['planned'] ?? 0, Colors.blue)),
        Expanded(child: _buildStatItem('Completed', stats['stop'] ?? 0, Colors.green)),
      ],
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Map<String, int> _calculateStats() {
    Map<String, int> stats = {};
    for (final job in filteredJobs) {
      final status = job.dispatchStatus?.toLowerCase() ?? 'unknown';
      stats[status] = (stats[status] ?? 0) + 1;
    }
    return stats;
  }

  Widget _buildJobCard(_DispatchJobInfo job) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _statusColor(job.dispatchStatus).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.local_shipping_outlined,
                    color: _statusColor(job.dispatchStatus),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.nrcJobNo ?? '-',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Demand: ${job.jobDemand ?? '-'}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _statusColor(job.dispatchStatus),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusDisplay(job.dispatchStatus),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Details Grid
            _buildDetailsGrid(job),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsGrid(_DispatchJobInfo job) {
    return Column(
      children: [
        if (job.dispatchDate != null)
          _buildDetailRow(Icons.schedule, 'Dispatch Date', _formatDateTime(job.dispatchDate!)),
        if (job.dispatchNo != null && job.dispatchNo!.isNotEmpty)
          _buildDetailRow(Icons.receipt_long, 'Dispatch No', job.dispatchNo!),
        if (job.operatorName != null && job.operatorName!.isNotEmpty)
          _buildDetailRow(Icons.person, 'Operator', job.operatorName!),
        if (job.noOfBoxes != null)
          _buildDetailRow(Icons.inventory_2, 'Boxes', job.noOfBoxes.toString()),
        if (job.remarks != null && job.remarks!.isNotEmpty)
          _buildDetailRow(Icons.note, 'Remarks', job.remarks!),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'accept':
        return Colors.green;
      case 'planned':
        return Colors.blue;
      case 'start':
        return Colors.orange;
      case 'stop':
        return Colors.grey[700]!;
      default:
        return Colors.grey;
    }
  }

  String _statusDisplay(String? status) {
    switch (status?.toLowerCase()) {
      case 'accept':
        return 'Accepted';
      case 'planned':
        return 'Planned';
      case 'start':
        return 'In Progress';
      case 'stop':
        return 'Completed';
      default:
        return status?.toUpperCase() ?? '-';
    }
  }

  String _formatDateTime(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }
}

class _DispatchJobInfo {
  final String? nrcJobNo;
  final String? jobDemand;
  final String? dispatchStatus;
  final String? dispatchDate;
  final String? dispatchNo;
  final String? operatorName;
  final int? noOfBoxes;
  final String? remarks;

  _DispatchJobInfo({
    this.nrcJobNo,
    this.jobDemand,
    this.dispatchStatus,
    this.dispatchDate,
    this.dispatchNo,
    this.operatorName,
    this.noOfBoxes,
    this.remarks,
  });
}