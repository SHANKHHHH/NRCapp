import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../constants/colors.dart';
import '../../../constants/strings.dart';
import '../../../data/datasources/job_api.dart';
import 'dart:convert';

class UserActivityPage extends StatefulWidget {
  const UserActivityPage({super.key});

  @override
  State<UserActivityPage> createState() => _UserActivityPageState();
}

class _UserActivityPageState extends State<UserActivityPage> with TickerProviderStateMixin {
  List<Map<String, dynamic>> activityLogs = [];
  List<Map<String, dynamic>> filteredLogs = [];
  bool isLoading = false;
  String? error;
  JobApi? _jobApi;
  late TabController _tabController;

  // Filter states
  String _selectedUser = 'All Users';
  String _selectedAction = 'All Actions';
  String _searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;

  // Available filters
  List<String> availableUsers = ['All Users'];
  List<String> availableActions = ['All Actions'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeApi();
    _fetchActivityLogs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _initializeApi() {
    final dio = Dio();
    dio.options.baseUrl = '${AppStrings.baseUrl}/api';
    _jobApi = JobApi(dio);
  }

  Future<void> _fetchActivityLogs() async {
    if (_jobApi == null) {
      setState(() {
        error = 'Connection problem. Please try again.';
      });
      return;
    }

    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final response = await _jobApi!.getActivityLogs();

      List<Map<String, dynamic>> allLogs = [];
      if (response is List) {
        allLogs = response;
      }

      // Filter out "User Login" actions
      final filteredLogs = allLogs.where((log) =>
      log['action'] != null &&
          log['action'] != 'User Login'
      ).toList();

      // Extract unique users and actions for filters
      final users = <String>{};
      final actions = <String>{};

      for (var log in filteredLogs) {
        final user = log['user'];
        if (user != null && user['id'] != null) {
          final userName = user['name'] ?? user['id'];
          users.add(userName);
        }
        if (log['action'] != null) {
          actions.add(log['action']);
        }
      }

      setState(() {
        activityLogs = filteredLogs;
        availableUsers = ['All Users', ...users.toList()
          ..sort()
        ];
        availableActions = ['All Actions', ...actions.toList()
          ..sort()
        ];
        _applyFilters();
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Cannot load activities. Check your internet connection.';
        isLoading = false;
      });
    }
  }

  void _applyFilters() {
    filteredLogs = activityLogs.where((log) {
      // User filter
      if (_selectedUser != 'All Users') {
        final user = log['user'];
        if (user != null) {
          final userName = user['name'] ?? user['id'];
          if (userName != _selectedUser) {
            return false;
          }
        } else {
          return false;
        }
      }

      // Action filter
      if (_selectedAction != 'All Actions' &&
          log['action'] != _selectedAction) {
        return false;
      }

      // Search query filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final details = (log['details'] ?? '').toString().toLowerCase();
        final action = (log['action'] ?? '').toString().toLowerCase();
        final user = log['user'];
        final userId = user != null ? (user['name'] ?? user['id'] ?? '')
            .toString()
            .toLowerCase() : '';
        final jobNo = (log['nrcJobNo'] ?? '').toString().toLowerCase();

        if (!details.contains(query) &&
            !action.contains(query) &&
            !userId.contains(query) &&
            !jobNo.contains(query)) {
          return false;
        }
      }

      // Date range filter
      if (_startDate != null || _endDate != null) {
        final createdAt = log['createdAt'];
        if (createdAt != null) {
          try {
            final logDate = DateTime.parse(createdAt);
            if (_startDate != null && logDate.isBefore(_startDate!)) {
              return false;
            }
            if (_endDate != null &&
                logDate.isAfter(_endDate!.add(const Duration(days: 1)))) {
              return false;
            }
          } catch (e) {
            // If date parsing fails, include the log
          }
        }
      }

      return true;
    }).toList();
  }

  // Dashboard Statistics
  Map<String, int> _getActionStats() {
    Map<String, int> stats = {};
    for (var log in filteredLogs) {
      String action = log['action']?.toString() ?? 'Unknown';
      stats[action] = (stats[action] ?? 0) + 1;
    }
    return stats;
  }

  Map<String, int> _getUserStats() {
    Map<String, int> stats = {};
    for (var log in filteredLogs) {
      final user = log['user'];
      String userName = 'Unknown User';
      if (user != null && user is Map<String, dynamic>) {
        userName = user['name']?.toString() ?? user['id']?.toString() ?? 'Unknown User';
      }
      stats[userName] = (stats[userName] ?? 0) + 1;
    }
    return stats;
  }

  List<Map<String, dynamic>> _getDailyActivity() {
    Map<String, int> dailyStats = {};
    final now = DateTime.now();

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateKey = '${date.day}/${date.month}';
      dailyStats[dateKey] = 0;
    }

    for (var log in filteredLogs) {
      try {
        final createdAt = log['createdAt']?.toString();
        if (createdAt != null) {
          final logDate = DateTime.parse(createdAt);
          final dateKey = '${logDate.day}/${logDate.month}';
          if (dailyStats.containsKey(dateKey)) {
            dailyStats[dateKey] = (dailyStats[dateKey] ?? 0) + 1;
          }
        }
      } catch (e) {
        // Skip invalid dates
      }
    }

    return dailyStats.entries.map((e) =>
    {
      'date': e.key,
      'count': e.value,
    }).toList();
  }

  String _getTimeAgo(String createdAt) {
    try {
      final dateTime = DateTime.parse(createdAt);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else {
        return '${difference.inDays}d ago';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  Color _getActionColor(String action) {
    if (action.contains('Created')) {
      return const Color(0xFF22C55E);
    } else if (action.contains('Updated')) {
      return const Color(0xFFF59E0B);
    } else if (action.contains('Completed')) {
      return const Color(0xFF3B82F6);
    } else if (action.contains('Started')) {
      return const Color(0xFF8B5CF6);
    } else if (action.contains('JobStep')) {
      return const Color(0xFF06B6D4);
    } else if (action.contains('Job')) {
      return const Color(0xFF10B981);
    } else {
      return const Color(0xFF64748B);
    }
  }

  String _formatActivityDetails(String details) {
    if (details.isEmpty) return 'No details available';
    
    try {
      if (details.contains('{') && details.contains('}')) {
        final parts = details.split(' | Resource:');
        final jsonPart = parts[0].trim();
        final jsonData = jsonDecode(jsonPart);

        if (jsonData['message'] != null) {
          final message = jsonData['message'];
          final jobNo = jsonData['nrcJobNo'] ?? jsonData['jobNo'];
          final updatedFields = jsonData['updatedFields'] as List?;
          final status = jsonData['status'];
          final stepNo = jsonData['stepNo'];

          String formatted = message;

          if (jobNo != null) {
            formatted += '\nJob Number: $jobNo';
          }

          if (stepNo != null) {
            formatted += '\nStep: $stepNo';
          }

          if (status != null) {
            formatted += '\nNew Status: $status';
          }

          if (updatedFields != null && updatedFields.isNotEmpty) {
            formatted += '\nChanged: ${updatedFields.join(', ')}';
          }

          return formatted;
        }
      }

      String cleaned = details;
      cleaned = cleaned.replaceAll(RegExp(r'for jobStepId: \d+'), '');
      cleaned = cleaned.replaceAll(RegExp(r'jobStepId: \d+'), '');
      cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

      if (cleaned.contains(' | Resource:')) {
        cleaned = cleaned.split(' | Resource:')[0].trim();
      }

      return cleaned;
    } catch (e) {
      String cleaned = details;
      cleaned = cleaned.replaceAll(RegExp(r'for jobStepId: \d+'), '');
      cleaned = cleaned.replaceAll(RegExp(r'jobStepId: \d+'), '');
      cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (cleaned.contains(' | Resource:')) {
        cleaned = cleaned.split(' | Resource:')[0].trim();
      }
      return cleaned;
    }
  }

  String _getUserDisplayName(dynamic user) {
    if (user == null) return 'Unknown User';

    if (user is Map<String, dynamic>) {
      final name = user['name'];
      final id = user['id'];

      if (name != null && name.toString().isNotEmpty) {
        return name.toString();
      } else if (id != null) {
        return id.toString();
      }
    }
    return 'Unknown User';
  }

  String _getUserRole(dynamic user) {
    if (user == null) return 'Unknown';
    
    if (user is Map<String, dynamic>) {
      return user['role']?.toString() ?? 'Unknown';
    }
    return 'Unknown';
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.maincolor,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _applyFilters();
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedUser = 'All Users';
      _selectedAction = 'All Actions';
      _searchQuery = '';
      _startDate = null;
      _endDate = null;
      _applyFilters();
    });
  }

  Widget _buildDashboardTab() {
    final actionStats = _getActionStats();
    final userStats = _getUserStats();
    final dailyActivity = _getDailyActivity();

    return Container(
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Activity Overview',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Monitor user activities and system interactions',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Summary Cards
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Total Activities',
                    '${filteredLogs.length}',
                    Icons.timeline_rounded,
                    const Color(0xFF3B82F6),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryCard(
                    'Active Users',
                    '${userStats.length}',
                    Icons.people_rounded,
                    const Color(0xFF10B981),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Activity Types Chart (Full Width)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Activity Types',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 220,
                      child: actionStats.isNotEmpty
                          ? PieChart(
                        PieChartData(
                          sections: actionStats.entries.take(6).map((entry) {
                            return PieChartSectionData(
                              color: _getActionColor(entry.key),
                              value: entry.value.toDouble(),
                              title: '${entry.value}',
                              radius: 60,
                              titleStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            );
                          }).toList(),
                          centerSpaceRadius: 50,
                          sectionsSpace: 3,
                        ),
                      )
                          : const Center(
                        child: Text(
                          'No data available',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Legend
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      children: actionStats.entries.take(6).map((entry) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _getActionColor(entry.key),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              entry.key,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),


            const SizedBox(height: 24),

            // Weekly Activity Chart
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Last 7 Days Activity',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 250,
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (value) {
                              return FlLine(
                                color: Colors.grey[200] ?? Colors.grey,
                                strokeWidth: 1,
                              );
                            },
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 50,
                                getTitlesWidget: (value, meta) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Text(
                                      value.toInt().toString(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                getTitlesWidget: (value, meta) {
                                  final index = value.toInt();
                                  if (index >= 0 &&
                                      index < dailyActivity.length) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        dailyActivity[index]['date'],
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    );
                                  }
                                  return const Text('');
                                },
                              ),
                            ),
                            rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          borderData: FlBorderData(
                            show: true,
                            border: Border(
                              bottom: BorderSide(color: Colors.grey[200] ?? Colors.grey),
                              left: BorderSide(color: Colors.grey[200] ?? Colors.grey),
                            ),
                          ),
                          lineBarsData: [
                            LineChartBarData(
                              spots: dailyActivity
                                  .asMap()
                                  .entries
                                  .map((entry) {
                                return FlSpot(
                                  entry.key.toDouble(),
                                  entry.value['count'].toDouble(),
                                );
                              }).toList(),
                              isCurved: true,
                              color: AppColors.maincolor,
                              barWidth: 3,
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.maincolor.withOpacity(0.1),
                                    AppColors.maincolor.withOpacity(0.0),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, barData, index) {
                                  return FlDotCirclePainter(
                                    radius: 5,
                                    color: AppColors.maincolor,
                                    strokeWidth: 3,
                                    strokeColor: Colors.white,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon,
      Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 28,
                    color: color,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.trending_up_rounded,
                  size: 20,
                  color: Colors.grey[400],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivitiesTab() {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          // Enhanced Search and Filters Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Color(0x0F000000),
                  blurRadius: 20,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    color: const Color(0xFFF8FAFC),
                  ),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search activities, jobs, or users...',
                      hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                      prefixIcon: Icon(
                          Icons.search_rounded, color: Color(0xFF94A3B8)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                        _applyFilters();
                      });
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // Filter Dropdowns
                Row(
                  children: [
                    Expanded(
                      child: _buildFilterDropdown(
                        value: _selectedUser,
                        items: availableUsers,
                        hint: 'All Users',
                        onChanged: (value) {
                          setState(() {
                            _selectedUser = value!;
                            _applyFilters();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildFilterDropdown(
                        value: _selectedAction,
                        items: availableActions,
                        hint: 'All Actions',
                        onChanged: (value) {
                          setState(() {
                            _selectedAction = value!;
                            _applyFilters();
                          });
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        onPressed: _selectDateRange,
                        icon: Icons.calendar_month_rounded,
                        label: _startDate != null && _endDate != null
                            ? '${_startDate!.day}/${_startDate!
                            .month} - ${_endDate!.day}/${_endDate!.month}'
                            : 'Select Date Range',
                        isPrimary: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildActionButton(
                      onPressed: _clearFilters,
                      icon: Icons.clear_rounded,
                      label: 'Clear Filters',
                      isPrimary: false,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Results Summary
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.list_alt_rounded, size: 20, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  '${filteredLogs.length} activities found',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                if (isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF3B82F6)),
                    ),
                  ),
              ],
            ),
          ),

          // Activity List
          Expanded(
            child: isLoading
                ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF3B82F6)),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading activities...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            )
                : error != null
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.error_outline_rounded,
                        size: 48,
                        color: Colors.red[400],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      error!,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF64748B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _fetchActivityLogs,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try Again'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.maincolor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
            )
                : filteredLogs.isEmpty
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.inbox_outlined,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No activities found',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Try adjusting your search or filters',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: filteredLogs.length,
              itemBuilder: (context, index) {
                final log = filteredLogs[index];
                final user = log['user'];
                final jobNo = log['nrcJobNo'];

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Row
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _getActionColor(log['action']?.toString() ?? ''),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    log['action']?.toString() ?? 'Unknown Action',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 18,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius: BorderRadius.circular(
                                              8),
                                        ),
                                        child: Icon(
                                          Icons.person_outline_rounded,
                                          size: 16,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _getUserDisplayName(user),
                                        style: const TextStyle(
                                          color: Color(0xFF475569),
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius: BorderRadius.circular(
                                              12),
                                        ),
                                        child: Text(
                                          _getUserRole(user),
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[200] ?? Colors.grey),
                              ),
                              child: Text(
                                _getTimeAgo(log['createdAt']?.toString() ?? ''),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Job Number Badge
                        if (jobNo != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white,
                                  Colors.grey[50] ?? Colors.grey,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey[300] ?? Colors.grey,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.work_outline_rounded,
                                  size: 16,
                                  color: Colors.grey[700] ?? Colors.grey,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Job: $jobNo',
                                  style: TextStyle(
                                    color: Colors.grey[700] ?? Colors.grey,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Activity Details
                        if (log['details'] != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[100] ?? Colors.blue,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(
                                        Icons.info_outline_rounded,
                                        size: 16,
                                        color: Colors.blue[700] ?? Colors.blue,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Details',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _formatActivityDetails(log['details']?.toString() ?? ''),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.5,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String value,
    required List<String> items,
    required String hint,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          hint: Text(
            hint,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 14,
            ),
          ),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(
                item,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF475569),
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required bool isPrimary,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? AppColors.maincolor : Colors.grey[100],
        foregroundColor: isPrimary ? Colors.white : Colors.grey[700],
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'User Activity',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppColors.maincolor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchActivityLogs,
            tooltip: 'Refresh Data',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(
              icon: Icon(Icons.dashboard_rounded),
              text: 'Dashboard',
            ),
            Tab(
              icon: Icon(Icons.list_rounded),
              text: 'Activities',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDashboardTab(),
          _buildActivitiesTab(),
        ],
      ),
    );
  }
}