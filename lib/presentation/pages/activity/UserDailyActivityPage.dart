import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../../../constants/colors.dart';
import '../../../constants/strings.dart';
import '../../../data/datasources/job_api.dart';

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
      
      // Filter logs for the selected date and relevant actions
      final selectedDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final nextDay = selectedDate.add(const Duration(days: 1));
      
      print('📅 [ACTIVITY DEBUG] Selected date normalized: $selectedDate');
      
      final filteredLogs = logs.where((log) {
        try {
          // Try createdAt first, then updatedAt as fallback (for synthetic logs from JobStepMachine)
          String? dateString = log['createdAt']?.toString();
          if (dateString == null || dateString.isEmpty) {
            dateString = log['updatedAt']?.toString();
          }
          
          if (dateString == null || dateString.isEmpty) {
            return false;
          }
          
          final logDate = DateTime.parse(dateString).toLocal();
          final logDay = DateTime(logDate.year, logDate.month, logDate.day);
          
          // Check if log is from selected date
          if (logDay.isAtSameMomentAs(selectedDate)) {
            final action = (log['action'] ?? '').toString().toLowerCase();
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
              print('❌ [ACTIVITY DEBUG] Completed log but wrong date: action=${log['action']}, logDate=$logDay, selectedDate=$selectedDate, dateString=$dateString');
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
      
      for (final log in filteredLogs) {
        final nrcJobNo = (log['nrcJobNo'] ?? '').toString();
        final action = (log['action'] ?? '').toString();
        final details = (log['details'] ?? '').toString();
        final createdAt = (log['createdAt'] ?? '').toString();
        
        if (nrcJobNo.isNotEmpty) {
          if (!jobActivities.containsKey(nrcJobNo)) {
            jobActivities[nrcJobNo] = {
              'jobNumber': nrcJobNo,
              'actions': <Map<String, dynamic>>[],
              'quantities': <String>[],
              'status': 'Unknown',
            };
            uniqueQuantities[nrcJobNo] = {}; // Initialize quantities map
          }
          
          jobActivities[nrcJobNo]!['actions'].add({
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
                if (!uniqueQuantities[nrcJobNo]!.containsKey('OK')) {
                  uniqueQuantities[nrcJobNo]!['OK'] = okKey;
                }
              }
              if (jsonData['totalWastage'] != null && jsonData['totalWastage'] > 0) {
                final wastageKey = 'Wastage: ${jsonData['totalWastage']}';
                if (!uniqueQuantities[nrcJobNo]!.containsKey('Wastage')) {
                  uniqueQuantities[nrcJobNo]!['Wastage'] = wastageKey;
                }
              }
            }
          } catch (e) {
            // If JSON parsing fails, try regex extraction
            if (details.toLowerCase().contains('quantity')) {
              final quantityMatch = RegExp(r'(\d+)').firstMatch(details);
              if (quantityMatch != null) {
                final qtyKey = quantityMatch.group(1)!;
                if (!uniqueQuantities[nrcJobNo]!.containsKey('qty')) {
                  uniqueQuantities[nrcJobNo]!['qty'] = qtyKey;
                }
              }
            }
          }
          
          // Determine overall status - check both action and details
          final actionLower = action.toLowerCase();
          final detailsLower = details.toLowerCase();
          if (actionLower.contains('completed') || detailsLower.contains('completed')) {
            jobActivities[nrcJobNo]!['status'] = 'Completed';
          } else if (actionLower.contains('hold')) {
            jobActivities[nrcJobNo]!['status'] = 'On Hold';
          } else if (actionLower.contains('started')) {
            jobActivities[nrcJobNo]!['status'] = 'In Progress';
          }
        }
      }
      
      // Convert unique quantities map to list, maintaining order (OK first, then Wastage)
      for (final jobNumber in uniqueQuantities.keys) {
        final quantitiesMap = uniqueQuantities[jobNumber]!;
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
        jobActivities[jobNumber]!['quantities'] = quantitiesList;
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
                        'Job: $jobNumber',
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
              'Actions Today:',
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
                  Text(
                    _formatTime(action['time'] ?? ''),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
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
              'No Activity Today',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[800]),
            ),
            const SizedBox(height: 8),
            Text(
              'No job activities recorded for ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
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
          : _dailyActivities.isEmpty
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
    );
  }
}
