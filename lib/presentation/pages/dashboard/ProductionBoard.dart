import 'package:flutter/material.dart';
import 'package:nrc/constants/colors.dart';
import 'package:nrc/data/datasources/job_api.dart';
import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';

class ProductionBoard extends StatefulWidget {
  @override
  State<ProductionBoard> createState() => _ProductionBoardState();
}

class _ProductionBoardState extends State<ProductionBoard>
    with TickerProviderStateMixin {
  late final JobApi jobApi;
  late final AnimationController _mainAnimationController;
  late final AnimationController _refreshAnimationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _refreshAnimation;

  List<Map<String, dynamic>> allJobSteps = [];
  List<Map<String, dynamic>> filteredJobSteps = [];
  bool isLoading = true;
  String? error;
  String selectedDateFilter = 'All';
  String selectedViewMode = 'flow'; // 'flow', 'kanban', 'grid', 'list'
  DateTime? customStartDate;
  DateTime? customEndDate;
  TextEditingController searchController = TextEditingController();
  String searchQuery = '';
  int selectedStatusIndex = 0; // 0: All, 1: Planned, 2: In Progress, 3: Completed

  // Manufacturing process order
  final List<String> stepOrder = [
    'Corrugation',
    'FluteLaminateBoardConversion',
    'Punching',
    'SideFlapPasting'
  ];

  // Performance caching
  Map<String, int>? _cachedStatusCounts;
  Map<String, List<Map<String, dynamic>>>? _cachedGroupedSteps;

  @override
  void initState() {
    super.initState();
    jobApi = JobApi(Dio());

    _mainAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );
    _refreshAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainAnimationController, curve: Curves.easeOutCubic),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _mainAnimationController, curve: Curves.elasticOut),
    );
    _refreshAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _refreshAnimationController, curve: Curves.elasticOut),
    );

    _fetchAllJobData();
  }

  @override
  void dispose() {
    searchController.dispose();
    _mainAnimationController.dispose();
    _refreshAnimationController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllJobData() async {
    try {
      _refreshAnimationController.forward().then((_) {
        _refreshAnimationController.reset();
      });

      setState(() {
        isLoading = true;
        error = null;
        _cachedStatusCounts = null;
        _cachedGroupedSteps = null;
      });

      final response = await jobApi.getAllJobPlannings();

      if (response != null && response.isNotEmpty) {
        List<Map<String, dynamic>> processedSteps = [];

        for (var job in response) {
          final steps = job['steps'] as List<dynamic>? ?? [];
          final jobInfo = {
            'jobPlanId': job['jobPlanId'],
            'nrcJobNo': job['nrcJobNo'],
            'jobDemand': job['jobDemand'],
            'createdAt': job['createdAt'],
          };

          final relevantStepNames = [
            'Corrugation',
            'FluteLaminateBoardConversion',
            'Punching',
            'SideFlapPasting'
          ];

          for (var step in steps) {
            if (relevantStepNames.contains(step['stepName'])) {
              processedSteps.add({...step, ...jobInfo});
            }
          }
        }

        setState(() {
          allJobSteps = processedSteps;
          filteredJobSteps = processedSteps;
          isLoading = false;
        });

        _applyFilters();
        _mainAnimationController.forward();
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

  Map<String, int> _getStatusCounts() {
    if (_cachedStatusCounts == null) {
      _cachedStatusCounts = {
        'planned': 0,
        'start': 0,
        'stop': 0,
      };

      for (var step in filteredJobSteps) {
        final status = step['status'] as String;
        _cachedStatusCounts![status] = (_cachedStatusCounts![status] ?? 0) + 1;
      }
    }
    return _cachedStatusCounts!;
  }

  Map<String, List<Map<String, dynamic>>> _groupStepsByName() {
    if (_cachedGroupedSteps == null) {
      _cachedGroupedSteps = {};
      for (var step in filteredJobSteps) {
        final stepName = step['stepName'] as String;
        if (!_cachedGroupedSteps!.containsKey(stepName)) {
          _cachedGroupedSteps![stepName] = [];
        }
        _cachedGroupedSteps![stepName]!.add(step);
      }
    }
    return _cachedGroupedSteps!;
  }

  // Group jobs by job number for flow view
  Map<String, List<Map<String, dynamic>>> _groupJobsByNumber() {
    Map<String, List<Map<String, dynamic>>> jobGroups = {};

    for (var step in filteredJobSteps) {
      final jobNo = step['nrcJobNo'] as String;
      if (!jobGroups.containsKey(jobNo)) {
        jobGroups[jobNo] = [];
      }
      jobGroups[jobNo]!.add(step);
    }

    // Sort steps within each job by the predefined order
    jobGroups.forEach((jobNo, steps) {
      steps.sort((a, b) {
        final aIndex = stepOrder.indexOf(a['stepName']);
        final bIndex = stepOrder.indexOf(b['stepName']);
        return aIndex.compareTo(bIndex);
      });
    });

    return jobGroups;
  }

  void _applyFilters() {
    final now = DateTime.now();
    List<Map<String, dynamic>> dateFilteredSteps = [];

    // Date filtering
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
      default:
        dateFilteredSteps = allJobSteps;
    }

    // Search filtering
    if (searchQuery.isNotEmpty) {
      dateFilteredSteps = dateFilteredSteps.where((step) {
        final nrcJobNo = step['nrcJobNo']?.toString().toLowerCase() ?? '';
        final stepName = step['stepName']?.toString().toLowerCase() ?? '';
        final query = searchQuery.toLowerCase();
        return nrcJobNo.contains(query) || stepName.contains(query);
      }).toList();
    }

    // Status filtering
    if (selectedStatusIndex != 0) {
      final statusMap = {1: 'planned', 2: 'start', 3: 'stop'};
      final targetStatus = statusMap[selectedStatusIndex];
      dateFilteredSteps = dateFilteredSteps.where((step) {
        return step['status'] == targetStatus;
      }).toList();
    }

    setState(() {
      filteredJobSteps = dateFilteredSteps;
      _cachedStatusCounts = null;
      _cachedGroupedSteps = null;
    });
  }

  bool _isDateInRange(Map<String, dynamic> step, DateTime start, DateTime end) {
    try {
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
      body: isLoading ? _buildLoadingView() : error != null ? _buildErrorView() : _buildMainContent(),
      floatingActionButton: _buildFloatingActions(),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.maincolor,
                strokeWidth: 3,
              ),
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Loading Production Data',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Please wait while we fetch the latest information...',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Container(
        margin: EdgeInsets.all(32),
        padding: EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 30,
              offset: Offset(0, 15),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.error_outline_rounded, size: 40, color: Colors.red),
            ),
            SizedBox(height: 24),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 12),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _fetchAllJobData,
              icon: Icon(Icons.refresh_rounded),
              label: Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.maincolor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: CustomScrollView(
          physics: BouncingScrollPhysics(),
          slivers: [
            _buildCustomAppBar(),
            SliverPadding(
              padding: EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildSearchAndFilter(),
                  SizedBox(height: 24),
                  _buildQuickStats(),
                  SizedBox(height: 24),
                  _buildStatusPieChart(),
                  SizedBox(height: 24),
                  _buildStepBarChart(),
                  SizedBox(height: 24),
                  _buildViewModeSelector(),
                  SizedBox(height: 24),
                  _buildContentBasedOnMode(),
                  SizedBox(height: 100), // Space for FAB
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
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
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.factory_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Production Dashboard',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      _buildQuickStat('Active Steps', filteredJobSteps.length.toString(), Icons.play_circle_filled_rounded),
                      SizedBox(width: 16),
                      _buildQuickStat('Total Jobs', _groupJobsByNumber().length.toString(), Icons.work_rounded),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 25,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: TextField(
              controller: searchController,
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
                _applyFilters();
              },
              decoration: InputDecoration(
                hintText: 'Search jobs, steps, or job numbers...',
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: Icon(Icons.search_rounded, color: AppColors.maincolor),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                  icon: Icon(Icons.clear_rounded, color: Colors.grey[400]),
                  onPressed: () {
                    searchController.clear();
                    setState(() {
                      searchQuery = '';
                    });
                    _applyFilters();
                  },
                )
                    : null,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
          ),
          SizedBox(height: 16),
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildDateFilterChip('All', Icons.view_list_rounded),
                SizedBox(width: 8),
                _buildDateFilterChip('Today', Icons.today_rounded),
                SizedBox(width: 8),
                _buildDateFilterChip('Weekly', Icons.view_week_rounded),
                SizedBox(width: 8),
                _buildDateFilterChip('Monthly', Icons.calendar_month_rounded),
                SizedBox(width: 8),
                _buildDateFilterChip('Custom', Icons.calendar_today_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilterChip(String label, IconData icon) {
    final isSelected = selectedDateFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedDateFilter = label;
        });
        if (label == 'Custom') {
          _showCustomDatePicker();
        } else {
          _applyFilters();
        }
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.maincolor : Colors.transparent,
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
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    final statusCounts = _getStatusCounts();

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 25,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Overview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 16),
          // Status Filter Buttons
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatusFilterButton('All', -1, statusCounts.values.fold(0, (a, b) => a + b), Colors.grey[600]!),
                SizedBox(width: 12),
                _buildStatusFilterButton('Planned', 0, statusCounts['planned'] ?? 0, Colors.blue),
                SizedBox(width: 12),
                _buildStatusFilterButton('In Progress', 1, statusCounts['start'] ?? 0, Colors.orange),
                SizedBox(width: 12),
                _buildStatusFilterButton('Completed', 2, statusCounts['stop'] ?? 0, Colors.green),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPieChart() {
    final counts = _getStatusCounts();
    final entries = [
      {'label': 'Planned', 'count': counts['planned'] ?? 0, 'color': Colors.blue},
      {'label': 'In Progress', 'count': counts['start'] ?? 0, 'color': Colors.orange},
      {'label': 'Completed', 'count': counts['stop'] ?? 0, 'color': Colors.green},
    ].where((e) => (e['count'] as int) > 0).toList();

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 25,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Status Distribution',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 16),
          if (entries.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No data to display', style: TextStyle(color: Colors.grey[600])),
              ),
            )
          else ...[
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 4,
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
                  .map((e) => Row(
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
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepBarChart() {
    final grouped = _groupStepsByName();
    final stepNames = stepOrder.where((s) => grouped.containsKey(s)).toList();
    if (stepNames.isEmpty) {
      return Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 25,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Text('No step data to display', style: TextStyle(color: Colors.grey[600])),
        ),
      );
    }

    final bars = <BarChartGroupData>[];
    for (int i = 0; i < stepNames.length; i++) {
      final name = stepNames[i];
      final steps = grouped[name]!;
      final planned = steps.where((s) => s['status'] == 'planned').length.toDouble();
      final started = steps.where((s) => s['status'] == 'start').length.toDouble();
      final stopped = steps.where((s) => s['status'] == 'stop').length.toDouble();

      bars.add(
        BarChartGroupData(
          x: i,
          barsSpace: 4,
          barRods: [
            BarChartRodData(toY: planned, color: Colors.blue, width: 8),
            BarChartRodData(toY: started, color: Colors.orange, width: 8),
            BarChartRodData(toY: stopped, color: Colors.green, width: 8),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 25,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Steps by Status',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                barGroups: bars,
                gridData: FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= stepNames.length) return SizedBox.shrink();
                        final label = _getStepDisplayName(stepNames[idx]);
                        return Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(
                            label,
                            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                          ),
                        );
                      },
                      reservedSize: 44,
                    ),
                  ),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
              ),
            ),
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _legendDot('Planned', Colors.blue),
              _legendDot('In Progress', Colors.orange),
              _legendDot('Completed', Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendDot(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        SizedBox(width: 6),
        Text(label, style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildStatusFilterButton(String title, int index, int count, Color color) {
    final isSelected = (index == -1 && selectedStatusIndex == 0) || (selectedStatusIndex == index + 1);

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedStatusIndex = index == -1 ? 0 : index + 1;
        });
        _applyFilters();
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.grey[200]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isSelected ? color : Colors.grey[600],
              ),
            ),
            SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isSelected ? color : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewModeSelector() {
    return Container(
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _buildViewModeButton('Flow', 'flow', Icons.trending_flat_rounded),
          _buildViewModeButton('Kanban', 'kanban', Icons.view_column_rounded),
          _buildViewModeButton('Grid', 'grid', Icons.grid_view_rounded),
          _buildViewModeButton('List', 'list', Icons.view_list_rounded),
        ],
      ),
    );
  }

  Widget _buildViewModeButton(String title, String mode, IconData icon) {
    final isSelected = selectedViewMode == mode;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedViewMode = mode;
          });
        },
        child: AnimatedContainer(
          duration: Duration(milliseconds: 300),
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ] : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? AppColors.maincolor : Colors.grey[600],
              ),
              SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: isSelected ? AppColors.maincolor : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContentBasedOnMode() {
    if (filteredJobSteps.isEmpty) {
      return _buildEmptyState();
    }

    switch (selectedViewMode) {
      case 'flow':
        return _buildFlowView();
      case 'kanban':
        return _buildKanbanView();
      case 'grid':
        return _buildGridView();
      case 'list':
        return _buildListView();
      default:
        return _buildFlowView();
    }
  }

  Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 25,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 40,
              color: Colors.grey[400],
            ),
          ),
          SizedBox(height: 20),
          Text(
            'No Results Found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Try adjusting your filters or search terms',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  // NEW: Enhanced Flow View - Shows manufacturing flow for each job
  Widget _buildFlowView() {
    final jobGroups = _groupJobsByNumber();

    return Column(
      children: jobGroups.entries.map((entry) {
        return _buildJobFlowCard(entry.key, entry.value);
      }).toList(),
    );
  }

  Widget _buildJobFlowCard(String jobNo, List<Map<String, dynamic>> steps) {
    // Get job info from first step
    final jobInfo = steps.first;
    final completedSteps = steps.where((s) => s['status'] == 'stop').length;
    final totalSteps = steps.length;
    final progress = totalSteps > 0 ? completedSteps / totalSteps : 0.0;

    return Container(
      margin: EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 25,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Job Header
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.maincolor.withOpacity(0.1),
                  AppColors.maincolor.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.maincolor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.work_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            jobNo,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          Text(
                            'Priority: ${jobInfo['jobDemand']} • ${completedSteps}/${totalSteps} Steps Completed',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    CircularProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progress == 1.0 ? Colors.green : AppColors.maincolor,
                      ),
                      strokeWidth: 3,
                    ),
                  ],
                ),
                SizedBox(height: 16),
                // Progress Bar
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress,
                    child: Container(
                      decoration: BoxDecoration(
                        color: progress == 1.0 ? Colors.green : AppColors.maincolor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Manufacturing Flow
          Padding(
            padding: EdgeInsets.all(20),
            child: _buildManufacturingFlow(steps),
          ),
        ],
      ),
    );
  }

  Widget _buildManufacturingFlow(List<Map<String, dynamic>> steps) {
    // Create a map of available steps
    Map<String, Map<String, dynamic>> stepMap = {};
    for (var step in steps) {
      stepMap[step['stepName']] = step;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: stepOrder.asMap().entries.map<Widget>((entry) {
          final index = entry.key;
          final stepName = entry.value;
          final step = stepMap[stepName];
          final isLast = index == stepOrder.length - 1;

          return Row(
            children: [
              _buildFlowStepCard(stepName, step),
              if (!isLast) _buildFlowConnector(step != null),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFlowStepCard(String stepName, Map<String, dynamic>? step) {
    final isActive = step != null;
    final status = step?['status'] ?? 'not_started';
    final statusColor = isActive ? _getStatusColor(status) : Colors.grey[300]!;

    return Container(
      width: 140,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive ? statusColor.withOpacity(0.1) : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? statusColor : Colors.grey[300]!,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _getStepIcon(stepName),
              Spacer(),
              if (isActive)
                Icon(
                  _getStatusIcon(status),
                  color: statusColor,
                  size: 18,
                ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            _getStepDisplayName(stepName),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isActive ? Colors.grey[800] : Colors.grey[500],
            ),
          ),
          SizedBox(height: 4),
          Text(
            isActive ? _getStatusDisplayName(status) : 'Not Started',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isActive ? statusColor : Colors.grey[400],
            ),
          ),
          if (isActive && step!['startDate'] != null) ...[
            SizedBox(height: 8),
            Text(
              'Started: ${_formatDateTime(step['startDate'])}',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[500],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFlowConnector(bool isActive) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 2,
            color: isActive ? AppColors.maincolor : Colors.grey[300],
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 12,
            color: isActive ? AppColors.maincolor : Colors.grey[300],
          ),
          Container(
            width: 20,
            height: 2,
            color: isActive ? AppColors.maincolor : Colors.grey[300],
          ),
        ],
      ),
    );
  }

  // NEW: Kanban View - Shows steps in columns like a Kanban board
  Widget _buildKanbanView() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: stepOrder.map((stepName) {
          final stepSteps = filteredJobSteps.where((s) => s['stepName'] == stepName).toList();
          return _buildKanbanColumn(stepName, stepSteps);
        }).toList(),
      ),
    );
  }

  Widget _buildKanbanColumn(String stepName, List<Map<String, dynamic>> steps) {
    final statusCounts = <String, int>{};
    for (var step in steps) {
      final status = step['status'] as String;
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }

    return Container(
      width: 280,
      margin: EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column Header
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getStepColor(stepName).withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _getStepIcon(stepName),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _getStepDisplayName(stepName),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStepColor(stepName),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${steps.length}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    _buildMiniStatusBadge('${statusCounts['stop'] ?? 0} done', Colors.green),
                    SizedBox(width: 8),
                    _buildMiniStatusBadge('${statusCounts['start'] ?? 0} active', Colors.orange),
                  ],
                ),
              ],
            ),
          ),
          // Cards
          Container(
            constraints: BoxConstraints(maxHeight: 600),
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              shrinkWrap: true,
              itemCount: steps.length,
              itemBuilder: (context, index) => _buildKanbanCard(steps[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKanbanCard(Map<String, dynamic> step) {
    final status = step['status'] as String;
    final statusColor = _getStatusColor(status);

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  step['nrcJobNo'] ?? 'Unknown Job',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getStatusDisplayName(status),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.flag_rounded, size: 12, color: Colors.orange),
              SizedBox(width: 4),
              Text(
                'Priority: ${step['jobDemand']}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          if (step['startDate'] != null) ...[
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 12, color: Colors.blue),
                SizedBox(width: 4),
                Text(
                  _formatDateTime(step['startDate']),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGridView() {
    final groupedSteps = _groupStepsByName();

    return Column(
      children: groupedSteps.entries.map((entry) {
        return _buildStepGroupCard(entry.key, entry.value);
      }).toList(),
    );
  }

  Widget _buildListView() {
    return Column(
      children: filteredJobSteps.map((step) {
        return _buildCompactStepCard(step);
      }).toList(),
    );
  }

  Widget _buildStepGroupCard(String stepName, List<Map<String, dynamic>> steps) {
    final statusCounts = <String, int>{};
    for (var step in steps) {
      final status = step['status'] as String;
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 25,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _getStepColor(stepName).withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                _getStepIcon(stepName),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getStepDisplayName(stepName),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          _buildMiniStatusBadge('${steps.length} jobs', Colors.grey[600]!),
                          SizedBox(width: 8),
                          _buildMiniStatusBadge('${statusCounts['stop'] ?? 0} done', Colors.green),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
          // Jobs List
          Container(
            constraints: BoxConstraints(maxHeight: 300),
            child: ListView.builder(
              shrinkWrap: true,
              physics: BouncingScrollPhysics(),
              itemCount: steps.length,
              itemBuilder: (context, index) => _buildJobCard(steps[index], index == steps.length - 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatusBadge(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> step, bool isLast) {
    final status = step['status'] as String;
    final statusColor = _getStatusColor(status);

    return Container(
      margin: EdgeInsets.fromLTRB(20, 0, 20, isLast ? 20 : 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  step['nrcJobNo'] ?? 'Unknown Job',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getStatusDisplayName(status),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _buildInfoChip('Priority: ${step['jobDemand']}', Icons.flag_rounded, Colors.orange),
              if (step['startDate'] != null)
                _buildInfoChip('Started: ${_formatDateTime(step['startDate'])}', Icons.play_arrow_rounded, Colors.blue),
              if (step['endDate'] != null)
                _buildInfoChip('Ended: ${_formatDateTime(step['endDate'])}', Icons.check_rounded, Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String text, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStepCard(Map<String, dynamic> step) {
    final status = step['status'] as String;
    final statusColor = _getStatusColor(status);

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _getStepIcon(step['stepName']),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _getStepDisplayName(step['stepName']),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _getStatusDisplayName(status),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  'Job: ${step['nrcJobNo']} • Priority: ${step['jobDemand']}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (step['startDate'] != null) ...[
                  SizedBox(height: 4),
                  Text(
                    'Started: ${_formatDateTime(step['startDate'])}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActions() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton(
          heroTag: "refresh",
          onPressed: () {
            _mainAnimationController.reset();
            _fetchAllJobData();
          },
          backgroundColor: AppColors.maincolor,
          child: RotationTransition(
            turns: _refreshAnimation,
            child: Icon(Icons.refresh_rounded, color: Colors.white),
          ),
        ),
        SizedBox(height: 16),
        FloatingActionButton.extended(
          heroTag: "filter",
          onPressed: _showFilterBottomSheet,
          backgroundColor: Colors.white,
          foregroundColor: AppColors.maincolor,
          icon: Icon(Icons.tune_rounded),
          label: Text('Filters'),
        ),
      ],
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    'Advanced Filters',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Divider(),
            // Filter Options
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFilterSection(
                      'Date Range',
                      Icons.calendar_today_rounded,
                      _buildDateRangeOptions(),
                    ),
                    SizedBox(height: 24),
                    _buildFilterSection(
                      'Status',
                      Icons.check_circle_rounded,
                      _buildStatusOptions(),
                    ),
                    SizedBox(height: 24),
                    _buildFilterSection(
                      'Manufacturing Steps',
                      Icons.factory_rounded,
                      _buildStepOptions(),
                    ),
                  ],
                ),
              ),
            ),
            // Apply Button
            Container(
              padding: EdgeInsets.all(20),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _applyFilters();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.maincolor,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Apply Filters',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection(String title, IconData icon, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: AppColors.maincolor),
            SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        content,
      ],
    );
  }

  Widget _buildDateRangeOptions() {
    return Column(
      children: [
        'All,Today,Weekly,Monthly,Custom'.split(',').map((option) {
          return CheckboxListTile(
            title: Text(option),
            value: selectedDateFilter == option,
            onChanged: (value) {
              if (value == true) {
                setState(() {
                  selectedDateFilter = option;
                });
              }
            },
            activeColor: AppColors.maincolor,
          );
        }).toList().first,
        // Add other options similarly
      ],
    );
  }

  Widget _buildStatusOptions() {
    return Column(
      children: [
        'All,Planned,In Progress,Completed'.split(',').asMap().entries.map((entry) {
          final index = entry.key;
          final option = entry.value;
          return CheckboxListTile(
            title: Text(option),
            value: selectedStatusIndex == index,
            onChanged: (value) {
              if (value == true) {
                setState(() {
                  selectedStatusIndex = index;
                });
              }
            },
            activeColor: AppColors.maincolor,
          );
        }).toList().first,
        // Add other options
      ],
    );
  }

  Widget _buildStepOptions() {
    return Text('Step filtering options would go here');
  }

  void _showCustomDatePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(Duration(days: 365)),
      currentDate: DateTime.now(),
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
        customStartDate = picked.start;
        customEndDate = picked.end;
      });
      _applyFilters();
    }
  }

  // Helper methods
  Widget _getStepIcon(String stepName) {
    IconData iconData;
    Color color = _getStepColor(stepName);

    switch (stepName) {
      case 'Corrugation':
        iconData = Icons.waves_rounded;
        break;
      case 'FluteLaminateBoardConversion':
        iconData = Icons.transform_rounded;
        break;
      case 'Punching':
        iconData = Icons.circle;
        break;
      case 'SideFlapPasting':
        iconData = Icons.content_paste_rounded;
        break;
      default:
        iconData = Icons.build_rounded;
    }

    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(iconData, color: color, size: 20),
    );
  }

  Color _getStepColor(String stepName) {
    switch (stepName) {
      case 'Corrugation':
        return Colors.blue;
      case 'FluteLaminateBoardConversion':
        return Colors.green;
      case 'Punching':
        return Colors.orange;
      case 'SideFlapPasting':
        return Colors.purple;
      default:
        return Colors.grey;
    }
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

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'planned':
        return Icons.schedule_rounded;
      case 'start':
        return Icons.play_circle_filled_rounded;
      case 'stop':
        return Icons.check_circle_rounded;
      default:
        return Icons.help_rounded;
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
}