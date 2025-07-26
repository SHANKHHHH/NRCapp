import 'package:flutter/material.dart';
import 'package:nrc/constants/colors.dart';
import 'package:nrc/data/datasources/job_api.dart';
import 'package:dio/dio.dart';

class ProductionBoard extends StatefulWidget {
  @override
  State<ProductionBoard> createState() => _ProductionBoardState();
}

class _ProductionBoardState extends State<ProductionBoard> {
  late final JobApi jobApi;
  List<Map<String, dynamic>> allJobSteps = [];
  List<Map<String, dynamic>> filteredJobSteps = [];
  bool isLoading = true;
  String? error;
  String selectedDateFilter = 'All'; // All, Today, Weekly, Monthly, Custom
  DateTime? customStartDate;
  DateTime? customEndDate;
  TextEditingController searchController = TextEditingController();
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    jobApi = JobApi(Dio());
    _fetchAllJobData();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllJobData() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final response = await jobApi.getAllJobPlannings();

      if (response != null && response.isNotEmpty) {
        List<Map<String, dynamic>> processedSteps = [];

        // Process each job and extract the relevant steps
        for (var job in response) {
          final steps = job['steps'] as List<dynamic>? ?? [];
          final jobInfo = {
            'jobPlanId': job['jobPlanId'],
            'nrcJobNo': job['nrcJobNo'],
            'jobDemand': job['jobDemand'],
            'createdAt': job['createdAt'],
          };

          // Filter for the 4 key manufacturing steps
          final relevantStepNames = [
            'Corrugation',
            'FluteLaminateBoardConversion',
            'Punching',
            'SideFlapPasting'
          ];

          for (var step in steps) {
            if (relevantStepNames.contains(step['stepName'])) {
              processedSteps.add({
                ...step,
                ...jobInfo,
              });
            }
          }
        }

        setState(() {
          allJobSteps = processedSteps;
          filteredJobSteps = processedSteps;
          isLoading = false;
        });
        _applyDateFilter();
      } else {
        throw Exception('No job data found');
      }
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _filterStepsByStatus(String status) {
    return filteredJobSteps.where((step) => step['status'] == status).toList();
  }

  Map<String, List<Map<String, dynamic>>> _groupStepsByName() {
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var step in filteredJobSteps) {
      final stepName = step['stepName'] as String;
      if (!grouped.containsKey(stepName)) {
        grouped[stepName] = [];
      }
      grouped[stepName]!.add(step);
    }
    return grouped;
  }

  Map<String, int> _getStatusCounts() {
    Map<String, int> counts = {
      'planned': 0,
      'start': 0,
      'stop': 0,
    };

    for (var step in filteredJobSteps) {
      final status = step['status'] as String;
      counts[status] = (counts[status] ?? 0) + 1;
    }

    return counts;
  }

  void _applyDateFilter() {
    final now = DateTime.now();
    List<Map<String, dynamic>> dateFilteredSteps = [];

    switch (selectedDateFilter) {
      case 'Today':
        dateFilteredSteps = allJobSteps.where((step) {
          return _isDateInRange(step, now, now);
        }).toList();
        break;
      case 'Weekly':
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        final weekEnd = weekStart.add(Duration(days: 6));
        dateFilteredSteps = allJobSteps.where((step) {
          return _isDateInRange(step, weekStart, weekEnd);
        }).toList();
        break;
      case 'Monthly':
        final monthStart = DateTime(now.year, now.month, 1);
        final monthEnd = DateTime(now.year, now.month + 1, 0);
        dateFilteredSteps = allJobSteps.where((step) {
          return _isDateInRange(step, monthStart, monthEnd);
        }).toList();
        break;
      case 'Custom':
        if (customStartDate != null && customEndDate != null) {
          dateFilteredSteps = allJobSteps.where((step) {
            return _isDateInRange(step, customStartDate!, customEndDate!);
          }).toList();
        } else {
          dateFilteredSteps = allJobSteps;
        }
        break;
      default: // 'All'
        dateFilteredSteps = allJobSteps;
    }

    // Apply search filter on top of date filter
    setState(() {
      if (searchQuery.isEmpty) {
        filteredJobSteps = dateFilteredSteps;
      } else {
        filteredJobSteps = dateFilteredSteps.where((step) {
          final nrcJobNo = step['nrcJobNo']?.toString().toLowerCase() ?? '';
          final stepName = step['stepName']?.toString().toLowerCase() ?? '';
          final query = searchQuery.toLowerCase();
          return nrcJobNo.contains(query) || stepName.contains(query);
        }).toList();
      }
    });
  }

  void _applySearchFilter(String query) {
    setState(() {
      searchQuery = query;
    });
    _applyDateFilter(); // Reapply both filters
  }

  bool _isDateInRange(Map<String, dynamic> step, DateTime start, DateTime end) {
    try {
      // Check createdAt, updatedAt, startDate, and endDate
      final dates = [
        step['createdAt'],
        step['updatedAt'],
        step['startDate'],
        step['endDate'],
      ].where((date) => date != null).toList();

      for (var dateStr in dates) {
        final date = DateTime.parse(dateStr);
        final dateOnly = DateTime(date.year, date.month, date.day);
        final startOnly = DateTime(start.year, start.month, start.day);
        final endOnly = DateTime(end.year, end.month, end.day);

        if (dateOnly.isAfter(startOnly.subtract(Duration(days: 1))) &&
            dateOnly.isBefore(endOnly.add(Duration(days: 1)))) {
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: AppColors.maincolor,
        elevation: 0,
        title: Text(
          'Production Dashboard',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchAllJobData,
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.maincolor))
          : error != null
          ? _buildErrorView()
          : RefreshIndicator(
        onRefresh: _fetchAllJobData,
        color: AppColors.maincolor,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeHeader(),
              SizedBox(height: 24),
              _buildSearchBar(),
              SizedBox(height: 20),
              _buildDateFilterSection(),
              SizedBox(height: 24),
              _buildStatusOverview(),
              SizedBox(height: 32),
              _buildStepsByStatus(),
              SizedBox(height: 32),
              _buildStepsByName(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.search, color: AppColors.maincolor),
              SizedBox(width: 8),
              Text(
                'Search Jobs',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          TextField(
            controller: searchController,
            onChanged: _applySearchFilter,
            decoration: InputDecoration(
              hintText: 'Search by NRC Job Number (e.g., NON25-07-12)',
              prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                icon: Icon(Icons.clear, color: Colors.grey[400]),
                onPressed: () {
                  searchController.clear();
                  _applySearchFilter('');
                },
              )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.maincolor, width: 2),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          if (searchQuery.isNotEmpty) ...[
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.maincolor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search, size: 14, color: AppColors.maincolor),
                  SizedBox(width: 6),
                  Text(
                    'Searching for: "$searchQuery"',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.maincolor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red),
          SizedBox(height: 16),
          Text(
            'Failed to load data',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: _fetchAllJobData,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.maincolor,
            ),
            child: Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.maincolor, AppColors.maincolor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.maincolor.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Production Overview',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Real-time manufacturing process monitoring',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.factory,
            size: 48,
            color: Colors.white.withOpacity(0.8),
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilterSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_list, color: AppColors.maincolor),
              SizedBox(width: 8),
              Text(
                'Filter by Date',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              Spacer(),
              Text(
                '${filteredJobSteps.length} of ${allJobSteps.length} steps',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', Icons.view_list),
                SizedBox(width: 8),
                _buildFilterChip('Today', Icons.today),
                SizedBox(width: 8),
                _buildFilterChip('Weekly', Icons.view_week),
                SizedBox(width: 8),
                _buildFilterChip('Monthly', Icons.calendar_month),
                SizedBox(width: 8),
                _buildFilterChip('Custom', Icons.calendar_today),
              ],
            ),
          ),
          if (selectedDateFilter != 'All') ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.maincolor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppColors.maincolor),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getDateRangeText(),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.maincolor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (selectedDateFilter == 'Custom') ...[
            SizedBox(height: 16),
            _buildCustomDatePicker(),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomDatePicker() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _selectDate(context, true),
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 18, color: AppColors.maincolor),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          customStartDate != null
                              ? 'From: ${_formatDateOnly(customStartDate!)}'
                              : 'Select Start Date',
                          style: TextStyle(
                            color: customStartDate != null ? Colors.black : Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => _selectDate(context, false),
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 18, color: AppColors.maincolor),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          customEndDate != null
                              ? 'To: ${_formatDateOnly(customEndDate!)}'
                              : 'Select End Date',
                          style: TextStyle(
                            color: customEndDate != null ? Colors.black : Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (customStartDate != null && customEndDate != null) ...[
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _applyDateFilter,
                  icon: Icon(Icons.filter_list, size: 18),
                  label: Text('Apply Custom Filter'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.maincolor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    customStartDate = null;
                    customEndDate = null;
                  });
                  _applyDateFilter();
                },
                icon: Icon(Icons.clear, size: 18),
                label: Text('Clear'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[100],
                  foregroundColor: Colors.grey[700],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildFilterChip(String label, IconData icon) {
    final isSelected = selectedDateFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedDateFilter = label;
        });
        _applyDateFilter();
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.maincolor : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.maincolor : Colors.grey[300]!,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDateRangeText() {
    final now = DateTime.now();
    switch (selectedDateFilter) {
      case 'Today':
        return 'Showing data for ${_formatDateOnly(now)}';
      case 'Weekly':
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        final weekEnd = weekStart.add(Duration(days: 6));
        return 'Showing data from ${_formatDateOnly(weekStart)} to ${_formatDateOnly(weekEnd)}';
      case 'Monthly':
        final monthStart = DateTime(now.year, now.month, 1);
        final monthEnd = DateTime(now.year, now.month + 1, 0);
        return 'Showing data from ${_formatDateOnly(monthStart)} to ${_formatDateOnly(monthEnd)}';
      case 'Custom':
        if (customStartDate != null && customEndDate != null) {
          return 'Showing data from ${_formatDateOnly(customStartDate!)} to ${_formatDateOnly(customEndDate!)}';
        } else {
          return 'Select custom date range';
        }
      default:
        return 'Showing all data';
    }
  }

  Widget _buildStatusOverview() {
    final statusCounts = _getStatusCounts();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Status Overview',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatusCard(
                'Planned',
                statusCounts['planned'] ?? 0,
                Colors.blue,
                Icons.schedule,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildStatusCard(
                'In Progress',
                statusCounts['start'] ?? 0,
                Colors.orange,
                Icons.play_circle_filled,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildStatusCard(
                'Completed',
                statusCounts['stop'] ?? 0,
                Colors.green,
                Icons.check_circle,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusCard(String title, int count, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          SizedBox(height: 8),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepsByStatus() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Current Production Status',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 16),
        DefaultTabController(
          length: 3,
          child: Column(
            children: [
              TabBar(
                labelColor: AppColors.maincolor,
                unselectedLabelColor: Colors.grey,
                indicatorColor: AppColors.maincolor,
                tabs: [
                  Tab(text: 'Planned'),
                  Tab(text: 'In Progress'),
                  Tab(text: 'Completed'),
                ],
              ),
              SizedBox(height: 16),
              Container(
                height: 300,
                child: TabBarView(
                  children: [
                    _buildStepsList(_filterStepsByStatus('planned')),
                    _buildStepsList(_filterStepsByStatus('start')),
                    _buildStepsList(_filterStepsByStatus('stop')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepsByName() {
    final groupedSteps = _groupStepsByName();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Manufacturing Steps Overview',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 16),
        ...groupedSteps.entries.map((entry) {
          return _buildStepNameCard(entry.key, entry.value);
        }).toList(),
      ],
    );
  }

  Widget _buildStepNameCard(String stepName, List<Map<String, dynamic>> steps) {
    final statusCounts = <String, int>{};
    for (var step in steps) {
      final status = step['status'] as String;
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ExpansionTile(
        leading: _getStepIcon(stepName),
        title: Text(
          _getStepDisplayName(stepName),
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${steps.length} jobs • ${statusCounts['stop'] ?? 0} completed • ${selectedDateFilter}'),
        children: steps.map((step) => _buildStepTile(step)).toList(),
      ),
    );
  }

  Widget _buildStepsList(List<Map<String, dynamic>> steps) {
    if (steps.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 48, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text('No steps found', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: steps.length,
      itemBuilder: (context, index) {
        return _buildStepTile(steps[index]);
      },
    );
  }

  Widget _buildStepTile(Map<String, dynamic> step) {
    final status = step['status'] as String;
    final statusColor = _getStatusColor(status);

    return Card(
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: _getStepIcon(step['stepName']),
        title: Text(
          _getStepDisplayName(step['stepName']),
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Job: ${step['nrcJobNo']} • Priority: ${step['jobDemand']}'),
            if (step['startDate'] != null)
              Text('Started: ${_formatDateTime(step['startDate'])}'),
            if (step['endDate'] != null)
              Text('Ended: ${_formatDateTime(step['endDate'])}'),
          ],
        ),
        trailing: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            _getStatusDisplayName(status),
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _getStepIcon(String stepName) {
    IconData iconData;
    Color color;

    switch (stepName) {
      case 'Corrugation':
        iconData = Icons.waves;
        color = Colors.blue;
        break;
      case 'FluteLaminateBoardConversion':
        iconData = Icons.transform;
        color = Colors.green;
        break;
      case 'Punching':
        iconData = Icons.circle;
        color = Colors.orange;
        break;
      case 'SideFlapPasting':
        iconData = Icons.content_paste;
        color = Colors.purple;
        break;
      default:
        iconData = Icons.build;
        color = Colors.grey;
    }

    return CircleAvatar(
      backgroundColor: color.withOpacity(0.1),
      child: Icon(iconData, color: color, size: 20),
      radius: 20,
    );
  }

  String _getStepDisplayName(String stepName) {
    switch (stepName) {
      case 'FluteLaminateBoardConversion':
        return 'Board Conversion';
      case 'SideFlapPasting':
        return 'Side Flap Pasting';
      default:
        return stepName;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'planned':
        return Colors.blue;
      case 'start':
        return Colors.orange;
      case 'stop':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getStatusDisplayName(String status) {
    switch (status) {
      case 'planned':
        return 'Planned';
      case 'start':
        return 'In Progress';
      case 'stop':
        return 'Completed';
      default:
        return status.toUpperCase();
    }
  }

  String _formatDateTime(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  String _formatDateOnly(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? (customStartDate ?? DateTime.now())
          : (customEndDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.maincolor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          customStartDate = picked;
          // If end date is before start date, clear it
          if (customEndDate != null && customEndDate!.isBefore(picked)) {
            customEndDate = null;
          }
        } else {
          // Only allow end date if start date is selected and end date is after start date
          if (customStartDate != null && picked.isAfter(customStartDate!.subtract(Duration(days: 1)))) {
            customEndDate = picked;
          } else if (customStartDate == null) {
            // Show error if trying to select start date first
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Please select start date first'),
                backgroundColor: Colors.orange,
              ),
            );
          } else {
            // Show error if end date is before start date
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('End date must be after start date'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      });
    }
  }
}