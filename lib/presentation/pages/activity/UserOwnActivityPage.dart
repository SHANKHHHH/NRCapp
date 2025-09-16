import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../../../constants/colors.dart';
import '../../../constants/strings.dart';
import '../../../data/datasources/job_api.dart';

enum FilterType { daily, weekly, custom }

class UserOwnActivityPage extends StatefulWidget {
  const UserOwnActivityPage({super.key});

  @override
  State<UserOwnActivityPage> createState() => _UserOwnActivityPageState();
}

class _UserOwnActivityPageState extends State<UserOwnActivityPage> {
  late JobApi _jobApi;
  bool _isLoading = true;
  String? _error;
  String _userId = '';
  List<Map<String, dynamic>> _logs = [];
  List<Map<String, dynamic>> _filteredLogs = [];

  // Filter variables
  FilterType _selectedFilter = FilterType.weekly;
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Setup API
    final dio = Dio();
    dio.options.baseUrl = '${AppStrings.baseUrl}/api';
    _jobApi = JobApi(dio);

    // Read userId from prefs
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    if (userId == null || userId.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'No user session found.';
      });
      return;
    }
    setState(() {
      _userId = userId;
    });

    // Fetch logs
    await _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final logs = await _jobApi.getActivityLogsByUser(_userId);
      // Filter out login events
      final filtered = logs.where((log) => (log['action'] ?? '') != 'User Login').toList();
      setState(() {
        _logs = filtered;
        _isLoading = false;
      });
      _applyFilter();
    } catch (e) {
      setState(() {
        _error = 'Failed to load activity.';
        _isLoading = false;
      });
    }
  }

  void _applyFilter() {
    final now = DateTime.now();
    List<Map<String, dynamic>> filtered = [];

    switch (_selectedFilter) {
      case FilterType.daily:
        final today = DateTime(now.year, now.month, now.day);
        filtered = _logs.where((log) {
          try {
            final logDate = DateTime.parse(log['createdAt'] ?? '').toLocal();
            final logDay = DateTime(logDate.year, logDate.month, logDate.day);
            return logDay.isAtSameMomentAs(today);
          } catch (e) {
            return false;
          }
        }).toList();
        break;

      case FilterType.weekly:
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        final weekStartDay = DateTime(weekStart.year, weekStart.month, weekStart.day);
        filtered = _logs.where((log) {
          try {
            final logDate = DateTime.parse(log['createdAt'] ?? '').toLocal();
            return logDate.isAfter(weekStartDay.subtract(const Duration(seconds: 1)));
          } catch (e) {
            return false;
          }
        }).toList();
        break;

      case FilterType.custom:
        if (_customStartDate != null && _customEndDate != null) {
          final startDay = DateTime(_customStartDate!.year, _customStartDate!.month, _customStartDate!.day);
          final endDay = DateTime(_customEndDate!.year, _customEndDate!.month, _customEndDate!.day, 23, 59, 59);

          filtered = _logs.where((log) {
            try {
              final logDate = DateTime.parse(log['createdAt'] ?? '').toLocal();
              return logDate.isAfter(startDay.subtract(const Duration(seconds: 1))) &&
                  logDate.isBefore(endDay.add(const Duration(seconds: 1)));
            } catch (e) {
              return false;
            }
          }).toList();
        } else {
          filtered = _logs;
        }
        break;
    }

    setState(() {
      _filteredLogs = filtered;
    });
  }

  Future<void> _selectCustomDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _customStartDate != null && _customEndDate != null
          ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.maincolor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = picked.end;
        _selectedFilter = FilterType.custom;
      });
      _applyFilter();
    }
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Today', FilterType.daily),
                  const SizedBox(width: 8),
                  _buildFilterChip('This Week', FilterType.weekly),
                  const SizedBox(width: 8),
                  _buildCustomFilterChip(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, FilterType filterType) {
    final isSelected = _selectedFilter == filterType;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filterType;
        });
        _applyFilter();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.maincolor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.maincolor : AppColors.maincolor.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: AppColors.maincolor.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.maincolor,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomFilterChip() {
    final isSelected = _selectedFilter == FilterType.custom;
    final hasCustomRange = _customStartDate != null && _customEndDate != null;

    String label = 'Custom';
    if (isSelected && hasCustomRange) {
      label = 'Custom (${_customStartDate!.month}/${_customStartDate!.day} - ${_customEndDate!.month}/${_customEndDate!.day})';
    }

    return GestureDetector(
      onTap: () async {
        await _selectCustomDateRange();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.maincolor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.maincolor : AppColors.maincolor.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: AppColors.maincolor.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.maincolor,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  String _getFilterResultText() {
    final count = _filteredLogs.length;
    switch (_selectedFilter) {
      case FilterType.daily:
        return '$count activities today';
      case FilterType.weekly:
        return '$count activities this week';
      case FilterType.custom:
        if (_customStartDate != null && _customEndDate != null) {
          return '$count activities in selected range';
        }
        return '$count activities';
    }
  }

  String _timeAgo(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
      if (diff.inHours < 24) return '${diff.inHours} hours ago';
      return '${diff.inDays} days ago';
    } catch (_) {
      return iso;
    }
  }

  IconData _getActionIcon(String action) {
    if (action.contains('Created')) return Icons.add_circle_outline;
    if (action.contains('Updated')) return Icons.edit_outlined;
    if (action.contains('Deleted')) return Icons.delete_outline;
    if (action.contains('Login')) return Icons.login;
    if (action.contains('Submitted')) return Icons.send_outlined;
    if (action.contains('Approved')) return Icons.check_circle_outline;
    if (action.contains('Rejected')) return Icons.cancel_outlined;
    return Icons.info_outline;
  }

  Color _getActionColor(String action) {
    if (action.contains('Created')) return Colors.green;
    if (action.contains('Updated')) return Colors.orange;
    if (action.contains('Deleted')) return Colors.red;
    if (action.contains('Login')) return Colors.blue;
    if (action.contains('Submitted')) return Colors.indigo;
    if (action.contains('Approved')) return Colors.teal;
    if (action.contains('Rejected')) return Colors.redAccent;
    return Colors.grey;
  }

  Widget _buildLogTile(Map<String, dynamic> log) {
    final action = (log['action'] ?? '').toString();
    final details = (log['details'] ?? '').toString();
    final createdAt = (log['createdAt'] ?? '').toString();
    final nrcJobNo = (log['nrcJobNo'] ?? '').toString();

    final actionColor = _getActionColor(action);
    final actionIcon = _getActionIcon(action);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: actionColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    actionIcon,
                    color: actionColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        action,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _timeAgo(createdAt),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Text(
                details,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.4,
                ),
              ),
            ),
            if (nrcJobNo.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.maincolor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Job ID: $nrcJobNo',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
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

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchLogs,
              icon: const Icon(Icons.refresh),
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
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _selectedFilter == FilterType.daily
                  ? 'No Activity Today'
                  : _selectedFilter == FilterType.weekly
                  ? 'No Activity This Week'
                  : 'No Activity Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedFilter == FilterType.daily
                  ? 'No activities recorded for today'
                  : _selectedFilter == FilterType.weekly
                  ? 'No activities recorded for this week'
                  : 'No activities found for the selected period',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Loading your activity...',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Your Activity',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppColors.maincolor,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Icon(Icons.refresh_rounded),
            onPressed: _isLoading ? null : _fetchLogs,
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _error != null
          ? _buildErrorState()
          : Column(
        children: [
          _buildFilterChips(),
          if (!_isLoading && _filteredLogs.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    _getFilterResultText(),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _filteredLogs.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              onRefresh: _fetchLogs,
              color: AppColors.maincolor,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _filteredLogs.length,
                itemBuilder: (context, index) {
                  return _buildLogTile(_filteredLogs[index]);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}