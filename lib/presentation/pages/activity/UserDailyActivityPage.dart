import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../../../constants/colors.dart';
import '../../../constants/strings.dart';
import '../../../data/datasources/job_api.dart';

enum FilterType { daily, weekly, monthly }

class UserDailyActivityPage extends StatefulWidget {
  const UserDailyActivityPage({super.key});

  @override
  State<UserDailyActivityPage> createState() => _UserDailyActivityPageState();
}

class _UserDailyActivityPageState extends State<UserDailyActivityPage> {
  late JobApi _jobApi;
  bool _isLoading = true;
  String? _error;
  String _userId = '';
  List<Map<String, dynamic>> _dailyActivities = [];
  DateTime _selectedDate = DateTime.now();
  FilterType _selectedFilter = FilterType.daily;

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

    // Fetch daily activities
    await _fetchDailyActivities();
  }

  Future<void> _fetchDailyActivities() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      // Fetch user's activity logs for the selected date
      final logs = await _jobApi.getActivityLogsByUser(_userId);
      
      print('📊 [ACTIVITY DEBUG] Total logs fetched: ${logs.length}');
      print('📅 [ACTIVITY DEBUG] Selected date: $_selectedDate');
      
      // Filter logs based on selected filter type
      DateTime startDate;
      DateTime endDate;
      final now = DateTime.now();
      
      switch (_selectedFilter) {
        case FilterType.daily:
          // Use selected date for daily filter (allows calendar picker to work)
          startDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
          endDate = startDate.add(const Duration(days: 1));
          break;
        case FilterType.weekly:
          // Always use current week (week containing today), not selected date
          final weekStart = now.subtract(Duration(days: now.weekday - 1));
          startDate = DateTime(weekStart.year, weekStart.month, weekStart.day);
          // End date is 7 days later (exclusive, so it includes all of the 7th day)
          endDate = startDate.add(const Duration(days: 7));
          break;
        case FilterType.monthly:
          // Always use current month (month containing today), not selected date
          startDate = DateTime(now.year, now.month, 1);
          endDate = DateTime(now.year, now.month + 1, 1);
          break;
      }
      
      print('📅 [ACTIVITY DEBUG] Filter: $_selectedFilter, Start: $startDate, End: $endDate');
      
      final filteredLogs = logs.where((log) {
        try {
          // For completed actions, try to get the completion date from details JSON or root level
          String? dateString;
          final action = (log['action'] ?? '').toString().toLowerCase();
          final isCompletedAction = action.contains('completed');
          
          // For completed actions, try to get the completion date
          if (isCompletedAction) {
            // First check root level for completedAt (for completed jobs and step completions)
            dateString = log['completedAt']?.toString();
            
            // If not found, try to extract endDate or completedAt from details JSON
            if (dateString == null || dateString.isEmpty) {
              try {
                final detailsStr = log['details']?.toString();
                if (detailsStr != null && detailsStr.isNotEmpty) {
                  final detailsJson = jsonDecode(detailsStr);
                  if (detailsJson is Map) {
                    dateString = detailsJson['completedAt']?.toString() ??
                                detailsJson['endDate']?.toString() ??
                                detailsJson['completionDate']?.toString();
                  }
                }
              } catch (e) {
                // If parsing fails, fall back to createdAt
              }
            }
          }
          
          // Fallback to createdAt or updatedAt if no completion date found
          if (dateString == null || dateString.isEmpty) {
            dateString = log['createdAt']?.toString();
          }
          if (dateString == null || dateString.isEmpty) {
            dateString = log['updatedAt']?.toString();
          }
          
          if (dateString == null || dateString.isEmpty) {
            return false;
          }
          
          final logDate = DateTime.parse(dateString).toLocal();
          // Normalize to start of day for accurate comparison
          final logDateNormalized = DateTime(logDate.year, logDate.month, logDate.day);
          final startDateNormalized = DateTime(startDate.year, startDate.month, startDate.day);
          final endDateNormalized = DateTime(endDate.year, endDate.month, endDate.day);
          
          // Check if log is within the date range (inclusive start, exclusive end)
          if (logDateNormalized.isAtSameMomentAs(startDateNormalized) || 
              (logDateNormalized.isAfter(startDateNormalized) && logDateNormalized.isBefore(endDateNormalized))) {
            final details = (log['details'] ?? '').toString().toLowerCase();
            final nrcJobNo = (log['nrcJobNo'] ?? '').toString();
            
            print('✅ [ACTIVITY DEBUG] Log matches date: action=$action, date=$dateString, nrcJobNo=$nrcJobNo, userId=${log['userId']}');
            
            // Only include relevant job actions - check both action and details fields
            final isRelevant = action.contains('started') || 
                   action.contains('completed') || 
                   action.contains('hold') ||
                   action.contains('stopped') ||
                   action.contains('quantity') ||
                   details.contains('completed') ||
                   (details.contains('step') && (details.contains('completed') || details.contains('quantity')));
            
            if (isRelevant) {
              print('✅ [ACTIVITY DEBUG] Log is relevant and will be included');
            } else {
              print('⚠️ [ACTIVITY DEBUG] Log matches date but action/details are not relevant');
            }
            
            return isRelevant;
          } else {
            // Debug: show why log doesn't match
            if ((log['action'] ?? '').toString().toLowerCase().contains('completed')) {
              print('❌ [ACTIVITY DEBUG] Completed log but wrong date: action=${log['action']}, logDate=$logDate, logDateNormalized=$logDateNormalized, startDate=$startDate, startDateNormalized=$startDateNormalized, endDate=$endDate, endDateNormalized=$endDateNormalized, dateString=$dateString');
              print('   - isAtSameMomentAs: ${logDateNormalized.isAtSameMomentAs(startDateNormalized)}');
              print('   - isAfter: ${logDateNormalized.isAfter(startDateNormalized)}');
              print('   - isBefore: ${logDateNormalized.isBefore(endDateNormalized)}');
            }
          }
          return false;
        } catch (e) {
          print('❌ [ACTIVITY DEBUG] Error filtering log: $e, log: ${log.toString().substring(0, 100)}');
          return false;
        }
      }).toList();
      
      print('📊 [ACTIVITY DEBUG] Filtered logs count: ${filteredLogs.length}');

      // Process and group activities by job
      final Map<String, Map<String, dynamic>> jobActivities = {};
      final Map<String, Map<String, String>> uniqueQuantities = {}; // Track unique quantities per job
      const statusPriority = {
        'Unknown': 0,
        'In Progress': 1,
        'On Hold': 2,
        'Completed': 3,
      };

      void updateStatus(String activityKey, String newStatus) {
        final currentStatus =
            (jobActivities[activityKey]!['status'] ?? 'Unknown') as String;
        final currentPriority = statusPriority[currentStatus] ?? 0;
        final newPriority = statusPriority[newStatus] ?? 0;
        if (newPriority >= currentPriority) {
          jobActivities[activityKey]!['status'] = newStatus;
        }
      }
      
      for (final log in filteredLogs) {
        final nrcJobNo = (log['nrcJobNo'] ?? '').toString();
        final action = (log['action'] ?? '').toString();
        final details = (log['details'] ?? '').toString();
        final createdAt = (log['createdAt'] ?? '').toString();
        
        // Extract jobPlanId from log (try root level first, then from details JSON)
        // IMPORTANT: Always extract jobPlanId to ensure completed jobs are separated
        String? jobPlanId;
        if (log['jobPlanId'] != null) {
          jobPlanId = log['jobPlanId'].toString();
        } else {
          // Try to extract from details JSON
          try {
            if (details.contains('{') && details.contains('}')) {
              final jsonPart = details.split(' | Resource:')[0].trim();
              final jsonData = jsonDecode(jsonPart);
              
              // First priority: jobPlanId from JSON
              if (jsonData['jobPlanId'] != null) {
                jobPlanId = jsonData['jobPlanId'].toString();
              }
              
              // Second priority: jobPlanId from nested structures
              if ((jobPlanId == null || jobPlanId.isEmpty) && jsonData['jobPlanning'] != null) {
                final jobPlanning = jsonData['jobPlanning'];
                if (jobPlanning is Map && jobPlanning['jobPlanId'] != null) {
                  jobPlanId = jobPlanning['jobPlanId'].toString();
                }
              }
              
              // Third priority: stepNo or resourceId as fallback to make key unique
              if (jobPlanId == null || jobPlanId.isEmpty) {
                if (jsonData['stepNo'] != null) {
                  jobPlanId = 'step_${jsonData['stepNo']}';
                } else if (jsonData['resourceId'] != null) {
                  jobPlanId = 'res_${jsonData['resourceId']}';
                } else if (jsonData['id'] != null) {
                  // Use id as last resort to ensure uniqueness
                  jobPlanId = 'id_${jsonData['id']}';
                }
              }
            }
          } catch (e) {
            // If JSON parsing fails, try to extract from resource part
            try {
              if (details.contains('Resource:')) {
                final resourcePart = details.split('Resource:')[1].trim();
                final resourceMatch = RegExp(r'(\d+)').firstMatch(resourcePart);
                if (resourceMatch != null) {
                  jobPlanId = 'res_${resourceMatch.group(1)}';
                }
              }
            } catch (e2) {
              // If all parsing fails, use a combination of timestamp and action to ensure uniqueness
              // This ensures completed jobs are still separated even without jobPlanId
              jobPlanId = '${createdAt}_${action.hashCode}';
            }
          }
        }
        
        // Create composite key using nrcJobNo + jobPlanId to separate different plannings
        // ALWAYS use composite key to prevent merging jobs with same nrcJobNo
        // This ensures completed jobs with different jobPlanId are shown separately
        final activityKey = jobPlanId != null && jobPlanId.isNotEmpty 
            ? '${nrcJobNo}_$jobPlanId'
            : '${nrcJobNo}_${createdAt}_${action.hashCode}'; // Use timestamp + action hash as fallback to ensure uniqueness
        
        if (nrcJobNo.isNotEmpty) {
          if (!jobActivities.containsKey(activityKey)) {
            jobActivities[activityKey] = {
              'jobNumber': nrcJobNo,
              'jobPlanId': jobPlanId, // Store jobPlanId for display
              'actions': <Map<String, dynamic>>[],
              'quantities': <String>[],
              'status': 'Unknown',
            };
            uniqueQuantities[activityKey] = {}; // Initialize quantities map
          }
          
          jobActivities[activityKey]!['actions'].add({
            'action': action,
            'details': details,
            'time': createdAt,
          });
          
          // Extract quantity information from details (try parsing JSON first, then regex)
          try {
            // Try to parse details as JSON if it contains JSON structure
            if (details.contains('{') && details.contains('}')) {
              final jsonPart = details.split(' | Resource:')[0].trim();
              final jsonData = jsonDecode(jsonPart);
              
              // Extract totalOK and totalWastage from JSON - store unique values
              if (jsonData['totalOK'] != null) {
                final okKey = 'OK: ${jsonData['totalOK']}';
                if (!uniqueQuantities[activityKey]!.containsKey('OK')) {
                  uniqueQuantities[activityKey]!['OK'] = okKey;
                }
              }
              if (jsonData['totalWastage'] != null && jsonData['totalWastage'] > 0) {
                final wastageKey = 'Wastage: ${jsonData['totalWastage']}';
                if (!uniqueQuantities[activityKey]!.containsKey('Wastage')) {
                  uniqueQuantities[activityKey]!['Wastage'] = wastageKey;
                }
              }
            }
          } catch (e) {
            // If JSON parsing fails, try regex extraction
            if (details.toLowerCase().contains('quantity')) {
              final quantityMatch = RegExp(r'(\d+)').firstMatch(details);
              if (quantityMatch != null) {
                final qtyKey = quantityMatch.group(1)!;
                if (!uniqueQuantities[activityKey]!.containsKey('qty')) {
                  uniqueQuantities[activityKey]!['qty'] = qtyKey;
                }
              }
            }
          }
          
          // Determine overall status - check both action and details
          final actionLower = action.toLowerCase();
          final detailsLower = details.toLowerCase();
          if (actionLower.contains('completed') || detailsLower.contains('completed')) {
            updateStatus(activityKey, 'Completed');
          } else if (actionLower.contains('hold')) {
            updateStatus(activityKey, 'On Hold');
          } else if (actionLower.contains('started')) {
            updateStatus(activityKey, 'In Progress');
          }
        }
      }
      
      // Convert unique quantities map to list, maintaining order (OK first, then Wastage)
      for (final activityKey in uniqueQuantities.keys) {
        final quantitiesMap = uniqueQuantities[activityKey]!;
        final quantitiesList = <String>[];
        if (quantitiesMap.containsKey('OK')) {
          quantitiesList.add(quantitiesMap['OK']!);
        }
        if (quantitiesMap.containsKey('Wastage')) {
          quantitiesList.add(quantitiesMap['Wastage']!);
        }
        if (quantitiesMap.containsKey('qty')) {
          quantitiesList.add(quantitiesMap['qty']!);
        }
        jobActivities[activityKey]!['quantities'] = quantitiesList;
      }
      
      setState(() {
        _dailyActivities = jobActivities.values.toList();
        _isLoading = false;
      });
      
    } catch (e) {
      setState(() {
        _error = 'Failed to load daily activities.';
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
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

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      await _fetchDailyActivities();
    }
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('Today', FilterType.daily),
            const SizedBox(width: 12),
            _buildFilterChip('This Week', FilterType.weekly),
            const SizedBox(width: 12),
            _buildFilterChip('This Month', FilterType.monthly),
          ],
        ),
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
        _fetchDailyActivities();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.maincolor : Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? AppColors.maincolor : AppColors.maincolor.withOpacity(0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected 
                  ? AppColors.maincolor.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.maincolor,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'on hold':
        return Colors.orange;
      case 'in progress':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Icons.check_circle;
      case 'on hold':
        return Icons.pause_circle;
      case 'in progress':
        return Icons.play_circle;
      default:
        return Icons.info;
    }
  }

  Widget _buildActivityCard(Map<String, dynamic> jobActivity) {
    final jobNumber = jobActivity['jobNumber'] ?? '';
    final jobPlanId = jobActivity['jobPlanId'];
    final status = jobActivity['status'] ?? 'Unknown';
    final actions = jobActivity['actions'] as List<Map<String, dynamic>>;
    final quantities = jobActivity['quantities'] as List<String>;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Job header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getStatusIcon(status),
                    color: _getStatusColor(status),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        jobPlanId != null && jobPlanId.toString().isNotEmpty
                            ? 'Job: $jobNumber (Plan: $jobPlanId)'
                            : 'Job: $jobNumber',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Status: $status',
                        style: TextStyle(
                          color: _getStatusColor(status),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Quantities section
            if (quantities.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.inventory, color: Colors.blue[600], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Quantities: ${quantities.join(', ')}',
                      style: TextStyle(
                        color: Colors.blue[800],
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            // Actions list
            Text(
              _selectedFilter == FilterType.daily
                  ? 'Actions Today:'
                  : _selectedFilter == FilterType.weekly
                  ? 'Actions This Week:'
                  : 'Actions This Month:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            ...actions.map((action) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      action['action'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            )).toList(),
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
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text('Error', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchDailyActivities,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.maincolor,
                foregroundColor: Colors.white,
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
            Icon(Icons.work_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _selectedFilter == FilterType.daily
                  ? 'No Activity Today'
                  : _selectedFilter == FilterType.weekly
                  ? 'No Activity This Week'
                  : 'No Activity This Month',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[800]),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedFilter == FilterType.daily
                  ? 'No job activities recorded for ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'
                  : _selectedFilter == FilterType.weekly
                  ? 'No job activities recorded for this week'
                  : 'No job activities recorded for this month',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
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
          'Your Daily Activity',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        backgroundColor: AppColors.maincolor,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDate,
            tooltip: 'Select Date',
          ),
          IconButton(
            icon: _isLoading ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ) : const Icon(Icons.refresh_rounded),
            onPressed: _isLoading ? null : _fetchDailyActivities,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildErrorState()
          : Column(
              children: [
                _buildFilterChips(),
                Expanded(
                  child: _dailyActivities.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _fetchDailyActivities,
              color: AppColors.maincolor,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _dailyActivities.length,
                itemBuilder: (context, index) {
                  return _buildActivityCard(_dailyActivities[index]);
                },
              ),
                        ),
                ),
              ],
            ),
    );
  }
}
