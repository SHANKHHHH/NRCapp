import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../constants/colors.dart';
import '../../../data/datasources/job_api.dart';
import '../../../core/services/dio_service.dart';
import '../../routes/UserRoleManager.dart';
import '../process/JobApiService.dart';

// Shared helpers so other parts of the app (e.g., bottom nav) can reuse the
// same role logic and notification computation without duplicating code.
String _normalizeRole(String? role) {
  return (role ?? '').trim().toLowerCase();
}

bool shouldNotifyUserForStep(String? currentUserRole, String stepName) {
  final role = _normalizeRole(currentUserRole);

  // Admin can see everything
  if (role == 'admin') return true;

  switch (stepName) {
    case 'PaperStore':
      return role == 'planner';
    case 'PrintingDetails':
      return role == 'printer' || role == 'printing manager' || role == 'printing_manager';
    case 'Corrugation':
    case 'FluteLaminateBoardConversion':
    case 'Punching':
    case 'SideFlapPasting':
      return role == 'production head';
    case 'QualityDept':
      return role == 'qc manager' || role == 'quality dept' || role == 'qualitydept' || role == 'quality';
    case 'DispatchProcess':
      return role == 'dispatch executive' || role == 'dispatch';
    default:
      return false;
  }
}

bool shouldNotifyUserForStepWithRoles(List<String> currentUserRoles, String stepName) {
  // Admin can see everything
  if (currentUserRoles.contains('admin')) return true;

  switch (stepName) {
    case 'PaperStore':
      return currentUserRoles.contains('planner');
    case 'PrintingDetails':
      return currentUserRoles.contains('printer') || 
             currentUserRoles.contains('printing manager') || 
             currentUserRoles.contains('printing_manager');
    case 'Corrugation':
    case 'FluteLaminateBoardConversion':
    case 'Punching':
    case 'SideFlapPasting':
      return currentUserRoles.contains('production head');
    case 'QualityDept':
      return currentUserRoles.contains('qc manager') || 
             currentUserRoles.contains('quality dept') || 
             currentUserRoles.contains('qualitydept') || 
             currentUserRoles.contains('quality');
    case 'DispatchProcess':
      return currentUserRoles.contains('dispatch executive') || 
             currentUserRoles.contains('dispatch');
    default:
      return false;
  }
}

bool shouldShowNotificationForRole(Map<String, dynamic> notification, String? currentUserRole) {
  if (_normalizeRole(currentUserRole) == 'admin') return true;

  if (notification['type'] == 'next_step') {
    return shouldNotifyUserForStep(currentUserRole, notification['nextStep']);
  }
  if (notification['type'] == 'completed') {
    return shouldNotifyUserForStep(currentUserRole, notification['completedStep']);
  }
  return false;
}

bool shouldShowNotificationForRoles(Map<String, dynamic> notification, List<String> currentUserRoles) {
  if (currentUserRoles.contains('admin')) return true;

  if (notification['type'] == 'next_step') {
    return shouldNotifyUserForStepWithRoles(currentUserRoles, notification['nextStep']);
  }
  if (notification['type'] == 'completed') {
    return shouldNotifyUserForStepWithRoles(currentUserRoles, notification['completedStep']);
  }
  return false;
}

// Backoff helper to avoid hammering the steps endpoint; retries 429s with delay
Future<Map<String, dynamic>?> _safeGetPlanningWithBackoff(
    JobApiService api,
    String jobNumber,
    ) async {
  int attempt = 0;
  while (attempt < 3) {
    try {
      // Use fresh fetch on manual refresh to ensure next-step alerts don't get stuck behind cache
      return await api.getJobPlanningStepsByNrcJobNoFresh(jobNumber);
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 429) {
        attempt += 1;
        // Respect Retry-After header if present
        final retryAfter = e.response?.headers.value('retry-after');
        Duration delay = Duration(milliseconds: 500 * attempt * attempt);
        if (retryAfter != null) {
          final sec = int.tryParse(retryAfter);
          if (sec != null) delay = Duration(seconds: sec);
        }
        await Future.delayed(delay);
        continue;
      }
      // For other errors, stop retrying
      return null;
    } catch (_) {
      return null;
    }
  }
  return null;
}

DateTime? _lastBadgeAt;
int _lastBadgeCount = 0;

Future<int> fetchNotificationCountForBadge() async {
  try {
    final now = DateTime.now();
    if (_lastBadgeAt != null && now.difference(_lastBadgeAt!) < const Duration(seconds: 15)) {
      return _lastBadgeCount;
    }
    final roleManager = UserRoleManager();
    await roleManager.loadUserRole();
    final roles = roleManager.userRoles;
    final role = roleManager.userRole;

    final api = JobApiService(JobApi(DioService.instance));
    final allJobs = await api.getAllJobPlannings();

    int count = 0;
    // Cap how many jobs we inspect for the badge to avoid bursts
    const int maxJobsPerBadge = 30;
    int processed = 0;
    for (var job in allJobs) {
      if (processed >= maxJobsPerBadge) break;
      final jobNumber = job['nrcJobNo'];
      if (jobNumber == null) continue;

      final jobPlanning = await _safeGetPlanningWithBackoff(api, jobNumber);
      if (jobPlanning == null || jobPlanning['steps'] == null) continue;

      final steps = jobPlanning['steps'] as List;

      final bool dispatchCompleted = steps.any((s) =>
      s != null && s['stepName'] == 'DispatchProcess' && s['status'] == 'stop');
      if (dispatchCompleted) continue;

      if (steps.isNotEmpty) {
        final firstStep = steps.first;
        final firstStatus = (firstStep['status'] ?? '').toString().toLowerCase();
        if (firstStep['stepName'] == 'PaperStore' && (firstStatus == 'planned' || firstStatus == 'start')) {
          final notif = {'type': 'next_step', 'nextStep': firstStep['stepName']};
          if (shouldShowNotificationForRoles(notif, roles)) count += 1;
        }
      }

      for (int i = 0; i < steps.length; i++) {
        final step = steps[i];
        final stepStatus = (step['status'] ?? '').toString().toLowerCase();
        if (stepStatus == 'stop' || stepStatus == 'completed' || stepStatus == 'accept') {
          final completedNotif = {'type': 'completed', 'completedStep': step['stepName']};
          if (shouldShowNotificationForRoles(completedNotif, roles)) count += 1;

          if (i + 1 < steps.length) {
            final nextStep = steps[i + 1];
            final nextStatus = (nextStep['status'] ?? '').toString().toLowerCase();
            if (nextStatus == 'planned' || nextStatus == 'start' || nextStatus == 'in_progress') {
              final nextStepNotif = {'type': 'next_step', 'nextStep': nextStep['stepName']};
              if (shouldShowNotificationForRoles(nextStepNotif, roles)) count += 1;
            }
          }
        }
      }
      processed += 1;
    }
    _lastBadgeAt = DateTime.now();
    _lastBadgeCount = count;
    return _lastBadgeCount;
  } catch (e) {
    return 0;
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> bundledNotifications = [];
  bool isLoading = false;
  List<String> currentUserRoles = [];
  String? currentUserRole;
  late JobApiService _apiService;

  @override
  void initState() {
    super.initState();
    _apiService = JobApiService(JobApi(DioService.instance));
    _loadUserRoleAndNotifications();
  }

  Future<void> _loadUserRoleAndNotifications() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final userRoleManager = UserRoleManager();
      await userRoleManager.loadUserRole();
      currentUserRoles = userRoleManager.userRoles;
      currentUserRole = userRoleManager.userRole;
      await _loadNotifications();
    } catch (e) {
      print('Error loading notifications: $e');
    } finally {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  DateTime? _lastRefreshAt;
  bool _refreshDisabled = false;

  Future<void> _loadNotifications() async {
    try {
      // Throttle: avoid refreshes more often than every 10 seconds
      final now = DateTime.now();
      if (_lastRefreshAt != null && now.difference(_lastRefreshAt!) < const Duration(seconds: 10)) {
        return;
      }
      _lastRefreshAt = now;
      if (!mounted) return;
      setState(() => _refreshDisabled = true);

      final allJobs = await _apiService.getAllJobPlannings();
      List<Map<String, dynamic>> allNotifications = [];

      // Limit per-refresh workload: only process first N jobs (pagination-lite)
      // Adjust the cap to tune server load vs freshness
      const int maxJobsPerRefresh = 30;
      int processed = 0;
      for (var job in allJobs) {
        if (processed >= maxJobsPerRefresh) break;
        final jobNumber = job['nrcJobNo'];
        if (jobNumber == null) continue;

        final jobPlanning = await _safeGetPlanningWithBackoff(_apiService, jobNumber);

        if (jobPlanning != null && jobPlanning['steps'] != null) {
          final steps = jobPlanning['steps'] as List;

          final bool dispatchCompleted = steps.any((s) =>
          s != null && s['stepName'] == 'DispatchProcess' && s['status'] == 'stop');
          if (dispatchCompleted) continue;

          if (steps.isNotEmpty) {
            final firstStep = steps.first;
            if (firstStep['stepName'] == 'PaperStore' && firstStep['status'] == 'planned') {
              allNotifications.add({
                'type': 'next_step',
                'jobNumber': jobNumber,
                'stepName': firstStep['stepName'],
                'stepNo': firstStep['stepNo'],
                'message': 'New Job $jobNumber',
                'subtitle': 'Start ${_formatStepName(firstStep['stepName'])}',
                'priority': 'high',
                'nextStep': firstStep['stepName'],
              });
            }
          }

          for (int i = 0; i < steps.length; i++) {
            final step = steps[i];
            final stepStatus = (step['status'] ?? '').toString().toLowerCase();

            if (stepStatus == 'stop' || stepStatus == 'completed' || stepStatus == 'accept') {
              allNotifications.add({
                'type': 'completed',
                'jobNumber': jobNumber,
                'stepName': step['stepName'],
                'stepNo': step['stepNo'],
                'completedAt': step['endDate'],
                'message': 'Job $jobNumber',
                'subtitle': '${_formatStepName(step['stepName'])} Done ✓',
                'completedStep': step['stepName'],
              });

              if (i + 1 < steps.length) {
                final nextStep = steps[i + 1];
                final nextStatus = (nextStep['status'] ?? '').toString().toLowerCase();
                if (nextStatus == 'planned' || nextStatus == 'start' || nextStatus == 'in_progress') {
                  allNotifications.add({
                    'type': 'next_step',
                    'jobNumber': jobNumber,
                    'stepName': nextStep['stepName'],
                    'stepNo': nextStep['stepNo'],
                    'message': 'Job $jobNumber',
                    'subtitle': 'Next: ${_formatStepName(nextStep['stepName'])}',
                    'priority': 'high',
                    'completedStep': step['stepName'],
                    'nextStep': nextStep['stepName'],
                  });
                }
              }
            }
          }
        }
        processed += 1;
      }

      List<Map<String, dynamic>> filteredNotifications = allNotifications
          .where((notification) => _shouldShowNotification(notification))
          .toList();

      Map<String, List<Map<String, dynamic>>> jobBundles = {};

      for (var notification in filteredNotifications) {
        final jobNumber = notification['jobNumber'];
        if (!jobBundles.containsKey(jobNumber)) {
          jobBundles[jobNumber] = [];
        }
        jobBundles[jobNumber]!.add(notification);
      }

      List<Map<String, dynamic>> bundles = [];
      jobBundles.forEach((jobNumber, notifications) {
        bundles.add({
          'jobNumber': jobNumber,
          'notifications': notifications,
          'totalNotifications': notifications.length,
          'hasUrgent': notifications.any((n) => n['priority'] == 'high'),
          'latestNotification': notifications.first,
        });
      });

      bundles.sort((a, b) {
        if (a['hasUrgent'] && !b['hasUrgent']) return -1;
        if (!a['hasUrgent'] && b['hasUrgent']) return 1;
        return a['jobNumber'].compareTo(b['jobNumber']);
      });

      if (!mounted) return;
      setState(() => bundledNotifications = bundles);
    } catch (e) {
      print('Error loading notifications: $e');
    }
    finally {
      if (mounted) setState(() => _refreshDisabled = false);
    }
  }

  bool _shouldShowNotification(Map<String, dynamic> notification) {
    return shouldShowNotificationForRoles(notification, currentUserRoles);
  }

  String _formatStepName(String stepName) {
    switch (stepName) {
      case 'PaperStore': return 'Paper Store';
      case 'PrintingDetails': return 'Printing';
      case 'Corrugation': return 'Corrugation';
      case 'FluteLaminateBoardConversion': return 'Flute Lamination';
      case 'Punching': return 'Punching';
      case 'SideFlapPasting': return 'Flap Pasting';
      case 'QualityDept': return 'Quality Check';
      case 'DispatchProcess': return 'Dispatch';
      default: return stepName;
    }
  }

  IconData _getStepIcon(String stepName) {
    switch (stepName) {
      case 'PaperStore': return Icons.inventory_2_rounded;
      case 'PrintingDetails': return Icons.print_rounded;
      case 'Corrugation': return Icons.waves_rounded;
      case 'FluteLaminateBoardConversion': return Icons.layers_rounded;
      case 'Punching': return Icons.radio_button_unchecked_rounded;
      case 'SideFlapPasting': return Icons.content_paste_rounded;
      case 'QualityDept': return Icons.verified_rounded;
      case 'DispatchProcess': return Icons.local_shipping_rounded;
      default: return Icons.work_rounded;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'completed': return const Color(0xFF4CAF50);
      case 'next_step': return const Color(0xFFFF9800);
      default: return const Color(0xFF2196F3);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.maincolor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.notifications_rounded,
                color: AppColors.maincolor,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            const Text('My Work'),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: _refreshDisabled
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.refresh_rounded, size: 18),
            ),
            onPressed: _refreshDisabled ? null : _loadNotifications,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : bundledNotifications.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
        onRefresh: _loadNotifications,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: bundledNotifications.length,
          itemBuilder: (context, index) => _buildNotificationCard(bundledNotifications[index]),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              size: 64,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Work Today',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'All caught up! 🎉\nNew work will appear here',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> bundle) {
    final notifications = bundle['notifications'] as List<Map<String, dynamic>>;
    // Prefer showing the next step (what's ready to start) as the primary item
    final Map<String, dynamic>? nextStepNotification = notifications.firstWhere(
          (n) => (n['type'] ?? '') == 'next_step',
      orElse: () => {},
    );
    final Map<String, dynamic> primaryNotification =
    (nextStepNotification != null && nextStepNotification.isNotEmpty)
        ? nextStepNotification
        : notifications.first;
    final isUrgent = bundle['hasUrgent'] as bool;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isUrgent
            ? Border.all(color: const Color(0xFFFF9800), width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showNotificationDetails(bundle),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Job Icon
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _getNotificationColor(primaryNotification['type']).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _getStepIcon(primaryNotification['stepName']),
                    color: _getNotificationColor(primaryNotification['type']),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Show first which step is ready to start
                          Text(
                            primaryNotification['type'] == 'next_step'
                                ? 'Start ${_formatStepName(primaryNotification['stepName'])}'
                                : (primaryNotification['subtitle'] ?? 'Job ${bundle['jobNumber']}'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const Spacer(),
                          if (isUrgent)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF9800),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'NOW',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        primaryNotification['type'] == 'next_step'
                            ? 'Job ${bundle['jobNumber']}'
                            : (primaryNotification['subtitle'] ?? ''),
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (notifications.length > 1) ...[
                        const SizedBox(height: 8),
                        Text(
                          '+${notifications.length - 1} more',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Arrow
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showNotificationDetails(Map<String, dynamic> bundle) {
    final notifications = (bundle['notifications'] as List<Map<String, dynamic>>)
      ..sort((a, b) => (a['stepNo'] as int).compareTo(b['stepNo'] as int));

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
            maxWidth: 400,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.maincolor.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.maincolor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.work_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Job ${bundle['jobNumber']}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${notifications.length} task${notifications.length > 1 ? 's' : ''}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Notifications List
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: notifications.length,
                  separatorBuilder: (context, idx) => const SizedBox(height: 12),
                  itemBuilder: (context, idx) {
                    final notification = notifications[idx];
                    final isNextStep = notification['type'] == 'next_step';

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isNextStep
                            ? const Color(0xFFFF9800).withOpacity(0.1)
                            : const Color(0xFF4CAF50).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: isNextStep
                            ? Border.all(color: const Color(0xFFFF9800), width: 2)
                            : Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _getNotificationColor(notification['type']),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _getStepIcon(notification['stepName']),
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  notification['subtitle'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                if (isNextStep)
                                  const Text(
                                    'Ready to start',
                                    style: TextStyle(
                                      color: Color(0xFFFF9800),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (isNextStep)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF9800),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'START',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          else
                            const Icon(
                              Icons.check_circle,
                              color: Color(0xFF4CAF50),
                              size: 24,
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              // Actions
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Close',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _navigateToWorkScreen(bundle['jobNumber']);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.maincolor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Start Work',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToWorkScreen(String jobNumber) {
    context.push('/work-screen');
  }
}