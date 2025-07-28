import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../constants/colors.dart';
import '../../../data/datasources/job_api.dart';
import '../../../core/services/dio_service.dart';
import '../../routes/UserRoleManager.dart';
import '../process/JobApiService.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> bundledNotifications = [];
  bool isLoading = false;
  String? currentUserRole;
  late JobApiService _apiService;

  @override
  void initState() {
    super.initState();
    _apiService = JobApiService(JobApi(DioService.instance));
    _loadUserRoleAndNotifications();
  }

  Future<void> _loadUserRoleAndNotifications() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Load user role
      final userRoleManager = UserRoleManager();
      await userRoleManager.loadUserRole();
      currentUserRole = userRoleManager.userRole;

      // Load notifications
      await _loadNotifications();
    } catch (e) {
      print('Error loading notifications: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadNotifications() async {
    try {
      // Get all job plannings
      final allJobs = await _apiService.getAllJobPlannings();
      
      List<Map<String, dynamic>> allNotifications = [];

      for (var job in allJobs) {
        final jobNumber = job['nrcJobNo'];
        if (jobNumber != null) {
          // Get detailed job planning with steps
          final jobPlanning = await _apiService.getJobPlanningStepsByNrcJobNo(jobNumber);
          
          if (jobPlanning != null && jobPlanning['steps'] != null) {
            final steps = jobPlanning['steps'] as List;
            
            // Check for completed steps and next steps
            for (int i = 0; i < steps.length; i++) {
              final step = steps[i];
              
              // If current step is completed (stop)
              if (step['status'] == 'stop') {
                // Add completed notification
                allNotifications.add({
                  'type': 'completed',
                  'jobNumber': jobNumber,
                  'stepName': step['stepName'],
                  'stepNo': step['stepNo'],
                  'completedAt': step['endDate'],
                  'message': '${_formatStepName(step['stepName'])} completed for Job $jobNumber',
                  'completedStep': step['stepName'],
                });
                
                // Check if there's a next step that should be notified
                if (i + 1 < steps.length) {
                  final nextStep = steps[i + 1];
                  if (nextStep['status'] == 'planned') {
                    // Add next step notification
                    allNotifications.add({
                      'type': 'next_step',
                      'jobNumber': jobNumber,
                      'stepName': nextStep['stepName'],
                      'stepNo': nextStep['stepNo'],
                      'message': '${_formatStepName(step['stepName'])} completed → Time to start ${_formatStepName(nextStep['stepName'])} for Job $jobNumber',
                      'priority': 'high',
                      'completedStep': step['stepName'],
                      'nextStep': nextStep['stepName'],
                    });
                  }
                }
              }
            }
          }
        }
      }

      // Filter notifications based on user role
      List<Map<String, dynamic>> filteredNotifications = [];
      for (var notification in allNotifications) {
        if (_shouldShowNotification(notification)) {
          filteredNotifications.add(notification);
        }
      }

      // Bundle notifications by job number
      Map<String, List<Map<String, dynamic>>> jobBundles = {};
      
      for (var notification in filteredNotifications) {
        final jobNumber = notification['jobNumber'];
        if (!jobBundles.containsKey(jobNumber)) {
          jobBundles[jobNumber] = [];
        }
        jobBundles[jobNumber]!.add(notification);
      }
      
      // Convert bundles to list
      List<Map<String, dynamic>> bundles = [];
      jobBundles.forEach((jobNumber, notifications) {
        bundles.add({
          'jobNumber': jobNumber,
          'notifications': notifications,
          'totalNotifications': notifications.length,
          'hasUrgent': notifications.any((n) => n['priority'] == 'high'),
          'latestNotification': notifications.first, // Most recent notification
        });
      });
      
      // Sort bundles by urgency (urgent first) then by job number
      bundles.sort((a, b) {
        if (a['hasUrgent'] && !b['hasUrgent']) return -1;
        if (!a['hasUrgent'] && b['hasUrgent']) return 1;
        return a['jobNumber'].compareTo(b['jobNumber']);
      });

      setState(() {
        bundledNotifications = bundles;
      });
    } catch (e) {
      print('Error loading notifications: $e');
    }
  }

  bool _shouldShowNotification(Map<String, dynamic> notification) {
    // Admin can see all notifications
    if (currentUserRole == 'admin') return true;
    
    // For next_step notifications, check if it's relevant to current user
    if (notification['type'] == 'next_step') {
      return _shouldNotifyUser(notification['nextStep']);
    }
    
    // For completed notifications, show if user was involved in the completed step
    if (notification['type'] == 'completed') {
      return _shouldNotifyUser(notification['completedStep']);
    }
    
    return false;
  }

  bool _shouldNotifyUser(String stepName) {
    if (currentUserRole == null) return false;
    
    // Map step names to roles
    switch (stepName) {
      case 'PrintingDetails':
        return currentUserRole == 'Planner' || currentUserRole == 'admin';
      case 'Corrugation':
        return currentUserRole == 'Production Head' || currentUserRole == 'admin';
      case 'FluteLaminateBoardConversion':
        return currentUserRole == 'Production Head' || currentUserRole == 'admin';
      case 'Punching':
        return currentUserRole == 'Production Head' || currentUserRole == 'admin';
      case 'SideFlapPasting':
        return currentUserRole == 'Production Head' || currentUserRole == 'admin';
      case 'QualityDept':
        return currentUserRole == 'QC Manager' || currentUserRole == 'admin';
      case 'DispatchProcess':
        return currentUserRole == 'Dispatch Executive' || currentUserRole == 'admin';
      default:
        return currentUserRole == 'admin';
    }
  }

  String _formatStepName(String stepName) {
    switch (stepName) {
      case 'PaperStore':
        return 'Paper Store';
      case 'PrintingDetails':
        return 'Printing';
      case 'Corrugation':
        return 'Corrugation';
      case 'FluteLaminateBoardConversion':
        return 'Flute Lamination';
      case 'Punching':
        return 'Punching';
      case 'SideFlapPasting':
        return 'Flap Pasting';
      case 'QualityDept':
        return 'Quality Control';
      case 'DispatchProcess':
        return 'Dispatch';
      default:
        return stepName;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'completed':
        return Colors.green;
      case 'next_step':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'completed':
        return Icons.check_circle;
      case 'next_step':
        return Icons.notification_important;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.notifications, color: AppColors.maincolor),
            const SizedBox(width: 8),
            const Text('Notifications'),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotifications,
          ),
        ],
      ),
             body: isLoading
           ? const Center(child: CircularProgressIndicator())
           : bundledNotifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No notifications',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You\'ll see notifications here when work is completed or when it\'s your turn to start work.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                                     child: ListView.builder(
                     padding: const EdgeInsets.all(16),
                     itemCount: bundledNotifications.length,
                     itemBuilder: (context, index) {
                       final bundle = bundledNotifications[index];
                       final notifications = bundle['notifications'] as List<Map<String, dynamic>>;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              onTap: () => _showNotificationDetails(bundle),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: bundle['hasUrgent'] 
                                      ? Colors.red.withOpacity(0.1)
                                      : Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  bundle['hasUrgent'] ? Icons.notification_important : Icons.work,
                                  color: bundle['hasUrgent'] ? Colors.red : Colors.blue,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                'Job ${bundle['jobNumber']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    '${bundle['totalNotifications']} notification${bundle['totalNotifications'] > 1 ? 's' : ''}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // Show latest notification message
                                  Text(
                                    notifications.first['message'],
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (bundle['hasUrgent'])
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        'URGENT',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                    color: Colors.grey[400],
                                  ),
                                ],
                              ),
                            ),
                            // Show additional notifications if more than 1
                            if (notifications.length > 1)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Column(
                                  children: notifications.skip(1).take(2).map((notification) => 
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      child: Row(
                                        children: [
                                          Icon(
                                            _getNotificationIcon(notification['type']),
                                            size: 14,
                                            color: _getNotificationColor(notification['type']),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              notification['message'],
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ).toList(),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}';
    } catch (e) {
      return 'Invalid date';
    }
  }

  void _showNotificationDetails(Map<String, dynamic> bundle) {
    final notifications = (bundle['notifications'] as List<Map<String, dynamic>>)
      ..sort((a, b) => (a['stepNo'] as int).compareTo(b['stepNo'] as int));
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
            minWidth: 300,
            maxWidth: 400,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    Icon(Icons.notifications, color: AppColors.maincolor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Job ${bundle['jobNumber']} - Notifications',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${notifications.length} notification${notifications.length > 1 ? 's' : ''}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: notifications.length,
                  separatorBuilder: (context, idx) => const SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final notification = notifications[idx];
                    final isNextStep = notification['type'] == 'next_step';
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isNextStep
                                ? Colors.orange.withOpacity(0.13)
                                : _getNotificationColor(notification['type']).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isNextStep
                                  ? Colors.orange.withOpacity(0.35)
                                  : _getNotificationColor(notification['type']).withOpacity(0.18),
                              width: isNextStep ? 2 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.04),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _getNotificationIcon(notification['type']),
                                    color: _getNotificationColor(notification['type']),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      notification['message'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  if (notification['priority'] == 'high')
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'URGENT',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              if (notification['completedAt'] != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Completed: ${_formatDate(notification['completedAt'])}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                              if (isNextStep) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    children: const [
                                      Icon(Icons.arrow_forward, color: Colors.orange, size: 18),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Next step for this work. Please proceed.',
                                          style: TextStyle(
                                            color: Colors.orange,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _navigateToWorkScreen(bundle['jobNumber']);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.maincolor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Go to Work Screen'),
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
    // Navigate to WorkScreen page
    context.push('/work-screen');
  }
}
