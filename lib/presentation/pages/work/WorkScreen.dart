import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nrc/constants/colors.dart';
import '../../../data/models/Job.dart';
import '../../../data/models/purchase_order.dart';
import '../../../data/models/WorkStepAssignment.dart';
import '../job/JobStep.dart';
import 'WorkDetailsScreen.dart';
import '../../../data/datasources/job_api.dart';
import '../../routes/UserRoleManager.dart';
import '../../../core/services/dio_service.dart';
import '../process/JobApiService.dart';

class WorkScreen extends StatefulWidget {
  final String? filterByMachineId;
  final String? filterByMachineName;
  
  const WorkScreen({
    Key? key,
    this.filterByMachineId,
    this.filterByMachineName,
  }) : super(key: key);

  @override
  State<WorkScreen> createState() => _WorkScreenState();
}

class _WorkScreenState extends State<WorkScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  List<Map<String, dynamic>> jobPlannings = [];
  List<Map<String, dynamic>> filteredJobPlannings = [];
  bool _isLoading = true;
  String? _error;
  Map<String, String> jobStatuses = {}; // key: "nrcJobNo|jobPlanId" -> status
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;
  final Set<String> _expandedJobNos = {};
  String? _userRole;

  bool _doesRoleHandleMachineStep(List<String> userRoles, String stepNameLower) {
    if (userRoles.isEmpty || stepNameLower.isEmpty) return false;
    final normalizedRoles = userRoles.map((role) => role.toLowerCase()).toList();

    bool matchesRole(List<String> keywords) =>
        normalizedRoles.any((role) => keywords.any((keyword) => role.contains(keyword)));

    if (stepNameLower.contains('printing')) {
      return matchesRole(['print', 'printing']);
    }
    if (stepNameLower.contains('corrug')) {
      return matchesRole(['corrug', 'corrugation']);
    }
    if (stepNameLower.contains('flute')) {
      return matchesRole(['flute', 'lamination', 'laminator']);
    }
    if (stepNameLower.contains('punch')) {
      return matchesRole(['punch', 'diecut', 'die-cut', 'die cutting']);
    }
    if (stepNameLower.contains('die cutting') || stepNameLower.contains('diecutting')) {
      return matchesRole(['die', 'diecut', 'die-cut']);
    }
    if (stepNameLower.contains('flap') || stepNameLower.contains('pasting')) {
      return matchesRole(['flap', 'pasting']);
    }
    return false;
  }

  bool _hasMachineAssignment(List<dynamic>? machineDetails) {
    if (machineDetails == null) return false;
    for (final detail in machineDetails) {
      if (detail is Map<String, dynamic>) {
        final machineId = detail['machineId']?.toString();
        final machineCode = detail['machineCode']?.toString();
        final nestedMachine = detail['machine'];
        final nestedId = nestedMachine is Map<String, dynamic> ? nestedMachine['id']?.toString() : null;
        final nestedCode = nestedMachine is Map<String, dynamic> ? nestedMachine['machineCode']?.toString() : null;
        if ((machineId != null && machineId.trim().isNotEmpty) ||
            (machineCode != null && machineCode.trim().isNotEmpty) ||
            (nestedId != null && nestedId.trim().isNotEmpty) ||
            (nestedCode != null && nestedCode.trim().isNotEmpty)) {
          return true;
        }
      }
    }
    return false;
  }


  bool _isMachineStepActive(String? status) {
    final normalized = status?.toLowerCase() ?? '';
    return normalized == 'in_progress' ||
        normalized == 'start' ||
        normalized == 'started' ||
        normalized == 'hold' ||
        normalized == 'major_hold' ||
        normalized == 'resume';
  }

  bool _isPreviousStepReady(
    Map<String, dynamic>? step, {
    Set<String>? allowedStatuses,
  }) {
    if (step == null) return false;
    final status = step['status']?.toString().toLowerCase() ?? '';
    final allowed = allowedStatuses ??
        const {
          'start',
          'started',
          'in_progress',
          'stop',
          'stopped',
          'completed',
          'accept'
        };
    return allowed.contains(status);
  }

  bool _isStepCompletedForFiltering(Map<String, dynamic> step) {
    final status = step['status']?.toString().toLowerCase() ?? '';
    final nameLower = step['stepName']?.toString().toLowerCase() ?? '';

    if (nameLower.contains('paperstore')) {
      return status == 'accept';
    }
    if (nameLower.contains('dispatch')) {
      return status == 'stop' || status == 'stopped' || status == 'completed';
    }

    return status == 'stop' ||
        status == 'stopped' ||
        status == 'completed' ||
        status == 'accept';
  }

  bool _isPreviousStepReadyForMachine(List<dynamic> steps, int currentStepNo) {
    if (currentStepNo <= 1) {
      return true; // First step has no dependency
    }

    Map<String, dynamic>? previousStep;
    for (final step in steps) {
      if (step is Map<String, dynamic>) {
        final stepNoRaw = step['stepNo'];
        final stepNo = stepNoRaw is int ? stepNoRaw : int.tryParse(stepNoRaw?.toString() ?? '');
        if (stepNo != null && stepNo == currentStepNo - 1) {
          previousStep = step;
          break;
        }
      }
    }

    if (previousStep == null) {
      return true;
    }

    return _isStepCompletedForFiltering(previousStep);
  }

  bool get _isAdminOrPlanner {
    final role = _userRole?.toLowerCase() ?? UserRoleManager().userRole?.toLowerCase();
    return role == 'admin' || role == 'planner';
  }

  String _formatJobDemand(String demand) {
    switch (demand.toLowerCase()) {
      case 'high':
        return 'Urgent';
      case 'medium':
        return 'Regular';
      default:
        return demand;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _blinkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );
    _blinkController.repeat(reverse: true);
    _searchController.addListener(_filterJobs);
    _initializePage();
  }

  Future<void> _initializePage() async {
    await UserRoleManager().loadUserRole();
    
    // Clear all caches to prevent cross-user contamination
    await _clearAllCaches();
    
    // Check if widget is still mounted before setting state
    if (!mounted) return;
    setState(() {
      _userRole = UserRoleManager().userRole;
    });
    await _fetchAllJobPlannings();
  }

  DateTime? _lastResumeRefresh;
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Only refresh if it's been more than 30 seconds since last refresh
      final now = DateTime.now();
      if (_lastResumeRefresh == null || 
          now.difference(_lastResumeRefresh!) > const Duration(seconds: 30)) {
        _lastResumeRefresh = now;
        // Refresh data when app becomes active again (throttled)
        _fetchAllJobPlannings(); // Don't clear cache on resume, just refresh data
      }
    }
  }

  @override
  void dispose() {
    // Cancel any ongoing operations to prevent setState calls after dispose
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  String _statusKey(String nrcJobNo, dynamic jobPlanId) {
    final planId = jobPlanId != null ? jobPlanId.toString() : 'null';
    return '$nrcJobNo|$planId';
  }

  void _filterJobs() {
    final query = _searchController.text.toLowerCase();
    print('Search query: "$query"');
    print('Total jobs: ${jobPlannings.length}');
    
    // Check if widget is still mounted before setting state
    if (!mounted) return;
    setState(() {
      if (query.isEmpty) {
        filteredJobPlannings = jobPlannings;
        print('No query - showing all jobs: ${filteredJobPlannings.length}');
      } else {
        filteredJobPlannings = jobPlannings
            .where((job) {
              // Search across multiple fields
              final nrcJobNo = job['nrcJobNo']?.toString().toLowerCase() ?? '';
              final jobPlanId = job['jobPlanId']?.toString().toLowerCase() ?? '';
              final jobDemand = job['jobDemand']?.toString().toLowerCase() ?? '';
              final createdAt = job['createdAt']?.toString().toLowerCase() ?? '';
              
              final matches = nrcJobNo.contains(query) ||
                             jobPlanId.contains(query) ||
                             jobDemand.contains(query) ||
                             createdAt.contains(query);
              
              print('Job ${job['nrcJobNo']}: nrcJobNo="$nrcJobNo", jobPlanId="$jobPlanId", jobDemand="$jobDemand" - contains "$query" = $matches');
              return matches;
            })
            .toList();
        print('Filtered jobs: ${filteredJobPlannings.length}');
      }
    });
  }

  Future<void> _clearAllCaches() async {
    print('DEBUG: Manual cache clear triggered...');
    
    // Clear JobApi cache (data cache only)
    JobApi.clearCache();
    print('DEBUG: Cleared JobApi cache');
    
    // Clear JobApiService cache
    try {
      final dio = DioService.instance;
      final jobApi = JobApi(dio);
      final jobApiService = JobApiService(jobApi);
      jobApiService.invalidateJobCaches('ALL_JOBS');
      print('DEBUG: Cleared JobApiService cache');
    } catch (e) {
      print('DEBUG: Error clearing JobApiService cache: $e');
    }
    
    // Clear only data-related SharedPreferences, keep auth data
    final prefs = await SharedPreferences.getInstance();
    // Remove only data cache keys, keep authentication
    await prefs.remove('cached_jobs');
    await prefs.remove('cached_job_plannings');
    await prefs.remove('cached_machines');
    await prefs.remove('cached_users');
    await prefs.remove('cached_dashboard');
    await prefs.remove('cached_purchase_orders');
    print('DEBUG: Cleared data cache, kept authentication');
    
    // Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jobs reloaded successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
    
    // Refresh the data immediately
    await _fetchAllJobPlannings();
    
    print('DEBUG: Data cache cleared and refreshed.');
  }

  Future<void> _fetchAllJobPlannings() async {
    // Check if widget is still mounted before setting state
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final dio = DioService.instance;
      final jobApi = JobApi(dio);
      // Force clear all caches to ensure fresh data
      JobApi.clearCache();
      
      // DEBUG: Clear all SharedPreferences cache
      final prefs = await SharedPreferences.getInstance();
      print('🔍 [Frontend] Clearing all cached data...');
      print('🔍 [Frontend] Current user ID: ${await prefs.getString('userId')}');
      print('🔍 [Frontend] Current access token: ${await prefs.getString('accessToken')}');
      print('🔍 [Frontend] Current user role: ${await prefs.getString('userRole')}');
      print('🔍 [Frontend] Current user roles: ${await prefs.getString('userRoles')}');
      
      // Clear ALL data caches, keep only authentication
      await prefs.remove('cached_jobs');
      await prefs.remove('cached_job_plannings');
      await prefs.remove('cached_machines');
      await prefs.remove('cached_users');
      await prefs.remove('cached_dashboard');
      await prefs.remove('cached_purchase_orders');
      await prefs.remove('cached_activity_logs');
      await prefs.remove('cached_status_overview');
      print('🔍 [Frontend] Cleared all data cache, kept authentication');
      
      // Clear JobApiService cache as well
      try {
        final jobApiService = JobApiService(jobApi);
        // Clear all caches in JobApiService
        jobApiService.invalidateJobCaches('ALL_JOBS');
        print('DEBUG: Cleared JobApiService cache');
      } catch (e) {
        print('DEBUG: Error clearing JobApiService cache: $e');
      }
      
      // Show debug info
      print('🔍 [Frontend] Data cache cleared, proceeding with fresh data fetch...');
      final plannings = await jobApi.getAllJobPlanningsFresh();
      if (plannings.isEmpty) {
        print('❌ [Frontend] No job plannings returned from API');
      }

      // Fetch statuses in small batches to avoid server overload
      Future<Map<String, String>> fetchStatusesInChunks(
          List<Map<String, dynamic>> items, int chunkSize) async {
        final Map<String, String> statuses = {};
        for (int i = 0; i < items.length; i += chunkSize) {
          final chunk = items.sublist(i, i + chunkSize > items.length ? items.length : i + chunkSize);
          final results = await Future.wait(chunk.map((planning) async {
            final nrcJobNo = planning['nrcJobNo']?.toString() ?? '';
            final jobPlanId = planning['jobPlanId'];
            final key = _statusKey(nrcJobNo, jobPlanId);
            String status = 'UNKNOWN';
            try {
              final jobs = await jobApi.getJobsByNo(nrcJobNo);
              if (jobs.isNotEmpty) {
                status = jobs[0].status.toString().toUpperCase();
              }
            } catch (_) {
              // Ignore errors, default to UNKNOWN
            }
            return MapEntry(key, status);
          }));
          for (final entry in results) {
            statuses[entry.key] = entry.value;
          }
        }
        return statuses;
      }

      print('🔍 [Frontend] Raw plannings count: ${plannings.length}');
      for (final planning in plannings) {
        print('   • Raw planning -> Job: ${planning['nrcJobNo']} | Plan: ${planning['jobPlanId']} | StepCount: ${(planning['steps'] as List?)?.length ?? 0}');
      }

      final statuses = await fetchStatusesInChunks(plannings, 5);

      // For specific operator roles, show all jobs assigned to them (backend already filters correctly)
      // The backend filtering is sufficient - no need for additional frontend filtering
      Future<List<Map<String, dynamic>>> _filterPlanningsForOperatorRoles(
          List<Map<String, dynamic>> allPlannings) async {
        // Return all plannings as backend already handles proper filtering based on user role and machine access
        return allPlannings;
      }

      final roleFilteredPlannings = await _filterPlanningsForOperatorRoles(plannings);

      // Apply machine filtering if specified
      List<Map<String, dynamic>> machineFilteredPlannings = roleFilteredPlannings;
      if (widget.filterByMachineId != null) {
        print('🔍 [Frontend] Filtering by machine ID: ${widget.filterByMachineId}');
        print('🔍 [Frontend] Total plannings before machine filter: ${roleFilteredPlannings.length}');
        
        // Get user roles for role-based step filtering
        final userRoles = UserRoleManager().userRoles;
        
        machineFilteredPlannings = roleFilteredPlannings.where((planning) {
          final nrcJobNo = planning['nrcJobNo']?.toString();
          final jobPlanId = planning['jobPlanId']?.toString();
          final jobDemand = planning['jobDemand']?.toString().toLowerCase() ?? '';
          final isUrgentJob = jobDemand == 'high';
          final userRoles = UserRoleManager().userRoles;
          bool usesMachine = false;
          bool hasCompletedStep = false;
          bool previousStepReadyForMachine = false;
          
          // Check if this planning uses the specified machine in any step
          if (planning['steps'] is List) {
            final steps = planning['steps'] as List;
            for (int stepIndex = 0; stepIndex < steps.length; stepIndex++) {
              final step = steps[stepIndex];
              final stepName = step['stepName']?.toString() ?? '';
              final stepNameLower = stepName.toLowerCase();
              final stepStatus = step['status']?.toString().toLowerCase();
              
              // Only consider steps that this role actually handles (e.g. printer -> PrintingDetails)
              final bool userHandlesThisMachineStep = _doesRoleHandleMachineStep(userRoles, stepNameLower);
              if (!userHandlesThisMachineStep) {
                continue;
              }
              
              // If no machineDetails are provided AND step is still planned,
              // treat the step as available on all machines (before any machine starts it)
              if (stepStatus == 'planned' && step['machineDetails'] is List && (step['machineDetails'] as List).isEmpty) {
                usesMachine = true;
                final stepStatus = step['status']?.toString().toLowerCase();
                final isCompleted = stepStatus == 'stop' || stepStatus == 'stopped' || stepStatus == 'completed';
                Map<String, dynamic>? previousStep;
                if (stepIndex > 0) {
                  final candidate = steps[stepIndex - 1];
                  if (candidate is Map<String, dynamic>) {
                    previousStep = candidate;
                  }
                }

                if (isUrgentJob) {
                  previousStepReadyForMachine = true;
                  print('   - ✅ Urgent job (no machineDetails): bypassing previous step check for step ${step['stepName']}');
                } else {
                  bool previousReady = true;
                  if (previousStep != null) {
                    final prevStatus = previousStep['status']?.toString().toLowerCase() ?? '';
                    final prevNameLower = previousStep['stepName']?.toString().toLowerCase() ?? '';
                    if (prevNameLower.contains('paperstore')) {
                      previousReady = prevStatus == 'accept';
                    } else {
                      final allowedStatuses = {'start', 'stop', 'stopped', 'completed', 'accept'};
                      previousReady = allowedStatuses.contains(prevStatus);
                    }
                  }
                  final isActive = _isMachineStepActive(stepStatus);
                  if (previousReady || isActive) {
                    previousStepReadyForMachine = true;
                  } else {
                    print('   - ⚠️ Previous step not ready (no machineDetails) for job $nrcJobNo (plan $jobPlanId); keeping hidden for machine ${step['stepName']}. Previous step status: ${previousStep?['status']}');
                  }
                }

                if (isCompleted) {
                  hasCompletedStep = true;
                  print('   - ⚠️ Step ${step['stepName']} for job $nrcJobNo (plan $jobPlanId) is completed (no machineDetails)');
                }
              }

              if (step['machineDetails'] is List) {
                final machineDetails = step['machineDetails'] as List;

                // Treat empty or "Not Assigned" machineDetails as ALL machines
                if (machineDetails.isEmpty && stepStatus == 'planned') {
                  usesMachine = true;

                  Map<String, dynamic>? previousStep;
                  if (stepIndex > 0 && steps[stepIndex - 1] is Map<String, dynamic>) {
                    previousStep = steps[stepIndex - 1] as Map<String, dynamic>;
                  }
                  print('   - Previous step for ${step['stepName']}: ${previousStep?['stepName']}, status: ${previousStep?['status']}');

                  bool previousReady = true;
                  if (previousStep != null) {
                    final prevStatus = previousStep['status']?.toString().toLowerCase() ?? '';
                    final prevNameLower = previousStep['stepName']?.toString().toLowerCase() ?? '';

                    if (prevNameLower.contains('paperstore')) {
                      const paperStoreAllowed = {
                        'start',
                        'started',
                        'in_progress',
                        'stop',
                        'stopped',
                        'completed',
                        'accept',
                      };
                      previousReady = paperStoreAllowed.contains(prevStatus);
                    } else {
                      const allowedStatuses = {
                        'start',
                        'started',
                        'in_progress',
                        'stop',
                        'stopped',
                        'completed',
                        'accept',
                      };
                      previousReady = allowedStatuses.contains(prevStatus);
                    }
                  }

                  final isActive = _isMachineStepActive(stepStatus);
                  if (previousReady || isActive) {
                    previousStepReadyForMachine = true;
                  } else {
                    print('   - ⚠️ Previous step not ready for job $nrcJobNo (plan $jobPlanId); keeping hidden for machine ${step['stepName']}. Previous step status: ${previousStep?['status']}');
                  }

                  // For the "all machines" case, treat step as completed if its status is a completed status
                  final isCompletedForAllMachines = stepStatus == 'stop' ||
                      stepStatus == 'stopped' ||
                      stepStatus == 'completed';
                  if (isCompletedForAllMachines) {
                    hasCompletedStep = true;
                    print('   - ⚠️ Step ${step['stepName']} for job $nrcJobNo (plan $jobPlanId) is completed');
                  }
                } else {
                  for (final machineDetail in machineDetails) {
                    if (machineDetail is Map<String, dynamic>) {
                      final machineIdInDetail = machineDetail['id']?.toString();
                      final machineIdField = machineDetail['machineId']?.toString();
                      final nestedMachineId = (machineDetail['machine'] as Map<String, dynamic>?)?['id']?.toString();
                      final nestedMachineCode = (machineDetail['machine'] as Map<String, dynamic>?)?['machineCode']?.toString();
                      final machineCode = machineDetail['machineCode']?.toString();
                      final machineType = machineDetail['machineType']?.toString();

                      // For PLANNED steps we treat them as available on ALL machines,
                      // regardless of any machineCode/type saved in planning.
                      // After the step is started, exclusivity is driven by updated machineDetails.
                      final isNotAssigned = stepStatus == 'planned';

                      bool matches = false;
                      if (isNotAssigned) {
                        matches = true;
                      } else if (machineIdInDetail == widget.filterByMachineId ||
                          machineIdField == widget.filterByMachineId ||
                          nestedMachineId == widget.filterByMachineId ||
                          nestedMachineCode == widget.filterByMachineId ||
                          machineCode == widget.filterByMachineId) {
                        matches = true;
                      }

                      if (matches) {
                        usesMachine = true;
                        print('🔍 [Frontend] ✅ Job $nrcJobNo (plan $jobPlanId) uses machine ${widget.filterByMachineId} in step ${step['stepName']}');

                        // Check if this specific step is completed
                        final stepStatus = step['status']?.toString().toLowerCase();
                        final isCompleted = stepStatus == 'stop' || stepStatus == 'stopped' || stepStatus == 'completed';
                        Map<String, dynamic>? previousStep;
                        if (stepIndex > 0) {
                          final candidate = steps[stepIndex - 1];
                          if (candidate is Map<String, dynamic>) {
                            previousStep = candidate;
                          }
                        }

                        bool previousReady = true; // Default to true if no previous step
                        if (previousStep != null) {
                          final prevStatus = previousStep['status']?.toString().toLowerCase() ?? '';
                          final prevNameLower = previousStep['stepName']?.toString().toLowerCase() ?? '';

                          if (prevNameLower.contains('paperstore')) {
                            const paperStoreAllowed = {
                              'start',
                              'started',
                              'in_progress',
                              'stop',
                              'stopped',
                              'completed',
                              'accept',
                            };
                            previousReady = paperStoreAllowed.contains(prevStatus);
                          } else {
                            const allowedStatuses = {
                              'start',
                              'started',
                              'in_progress',
                              'stop',
                              'stopped',
                              'completed',
                              'accept',
                            };
                            previousReady = allowedStatuses.contains(prevStatus);
                          }
                        }

                        final isActive = _isMachineStepActive(stepStatus);
                        if (previousReady || isActive) {
                          previousStepReadyForMachine = true;
                        } else {
                          print('   - ⚠️ Previous step not ready for job $nrcJobNo (plan $jobPlanId); keeping hidden for machine ${step['stepName']}. Previous step status: ${previousStep?['status']}');
                        }

                        if (isCompleted) {
                          hasCompletedStep = true;
                          print('   - ⚠️ Step ${step['stepName']} for job $nrcJobNo (plan $jobPlanId) is completed');
                        }
                      }
                    }
                  }
                }
              }
            }
          }
          
          // Show the job if it uses the machine, regardless of completion status
          // (Completion filtering happens later)
          if (usesMachine) {
            // For urgent jobs: bypass previous step check
            if (!isUrgentJob && !previousStepReadyForMachine) {
              print('🔍 [Frontend] Job $nrcJobNo (plan $jobPlanId) uses machine but previous step not ready; hiding for now');
              return false;
            }
            if (isUrgentJob) {
              print('🔍 [Frontend] ✅ Urgent job $nrcJobNo (plan $jobPlanId) MATCHES machine filter - bypassing previous step check');
            } else {
            print('🔍 [Frontend] Job $nrcJobNo (plan $jobPlanId) MATCHES machine filter, hasCompletedStep: $hasCompletedStep, prevReady: $previousStepReadyForMachine');
            }
            return true;
          } else {
            print('🔍 [Frontend] Job $nrcJobNo (plan $jobPlanId) does NOT use machine ${widget.filterByMachineId}');
            return false;
          }
        }).toList();
        print('🔍 [Frontend] After machine filtering: ${machineFilteredPlannings.length} jobs');
      }

      // Filter out completed steps
      // When filtering by machine: Only hide if the specific machine step is completed
      // When NOT filtering by machine: Hide if PaperStore or user's role step is completed
      final completedNonMachineFilteredPlannings = machineFilteredPlannings.where((planning) {
        if (widget.filterByMachineId != null) {
          // When filtering by machine, only check if the machine step itself is completed
          if (planning['steps'] is List) {
            final steps = planning['steps'] as List;
            for (final step in steps) {
              // Check if this step uses the filtered machine
              if (step['machineDetails'] is List) {
                final machineDetails = step['machineDetails'] as List;
                for (final machineDetail in machineDetails) {
                  if (machineDetail is Map<String, dynamic>) {
                    final machineIdInDetail = machineDetail['id']?.toString();
                    final machineIdField = machineDetail['machineId']?.toString();
                    final nestedMachineId = (machineDetail['machine'] as Map<String, dynamic>?)?['id']?.toString();
                    
                    if (machineIdInDetail == widget.filterByMachineId ||
                        machineIdField == widget.filterByMachineId ||
                        nestedMachineId == widget.filterByMachineId) {
                      // This step uses the filtered machine - check if it's completed
                      final stepStatus = step['status']?.toString().toLowerCase();
                      final isCompleted = stepStatus == 'stop' || stepStatus == 'stopped' || stepStatus == 'completed';
                      
                      if (isCompleted) {
                        print('🔍 [Frontend] Machine-filtered step ${step['stepName']} completed for job ${planning['nrcJobNo']}, hiding from UI');
                        return false; // Hide this job - the user's machine step is completed
                      }
                    }
                  }
                }
              }
            }
          }
          return true; // Keep job - machine step is not completed (ignore PaperStore completion)
        }
        
        // For non-machine filtering, check if user should bypass completion filtering
        // QC Manager, Dispatch Executive, Flying Squad, Admin, Planner should see all jobs
        final userRoles = UserRoleManager().userRoles;
        final bool isQualityRole = userRoles.any((role) => 
          role.toLowerCase().contains('quality') || 
          role.toLowerCase().contains('qc_manager') ||
          role.toLowerCase() == 'qc_manager'
        );
        final bool isDispatchRole = userRoles.any((role) => role.toLowerCase().contains('dispatch'));
        final isBypassRole = userRoles.any((role) => 
          role.toLowerCase().contains('qc_manager') ||
          role.toLowerCase().contains('dispatch_executive') ||
          role.toLowerCase().contains('dispatch executive') ||
          role.toLowerCase().contains('flyingsquad') ||
          role.toLowerCase().contains('flying squad') ||
          role.toLowerCase().contains('admin') ||
          role.toLowerCase().contains('planner')
        );
        
        // Check if this is an urgent job (high demand)
        final jobDemand = planning['jobDemand']?.toString().toLowerCase();
        final isUrgentJob = jobDemand == 'high';
        
        print('🔍 [Frontend] Role check for job ${planning['nrcJobNo']}: userRoles=$userRoles, isQualityRole=$isQualityRole, isDispatchRole=$isDispatchRole, isBypassRole=$isBypassRole, isUrgentJob=$isUrgentJob');
        
        // For other users, apply the original logic (check PaperStore completion)
        if (planning['steps'] is List) {
          final steps = planning['steps'] as List;
          
          // Individual step filtering logic (for partially completed jobs)
          for (int stepIndex = 0; stepIndex < steps.length; stepIndex++) {
            final step = steps[stepIndex];
            final stepName = step['stepName']?.toString();
            final stepStatus = step['status']?.toString().toLowerCase();
            
            // Check if this is a PaperStore step with 'accept' status (completed)
            if (stepName?.toLowerCase() == 'paperstore' || stepName?.toLowerCase() == 'paper store') {
              // ✅ PaperStore filtering - only hide if status is 'accept' (fully completed)
              // Do NOT hide if status is 'in_progress' or 'stop' (waiting for completion form)
              // Check both step.status and paperStore.status as fallback
              final paperStoreRecord = step['paperStore'];
              final paperStoreStatus = paperStoreRecord is Map 
                ? paperStoreRecord['status']?.toString().toLowerCase() 
                : null;
              
              final isPaperStoreCompleted = stepStatus == 'accept' || paperStoreStatus == 'accept';
              
              if (isPaperStoreCompleted) {
                final hasPaperStoreRole = userRoles.any((role) => role.toLowerCase().contains('paperstore'));
                // Only hide for PaperStore operators (or when not bypassing)
                if (!isBypassRole && hasPaperStoreRole) {
                  print('🔍 [Frontend] PaperStore completed (accept) for job ${planning['nrcJobNo']}, stepStatus=$stepStatus, paperStoreStatus=$paperStoreStatus, hiding from UI');
                  return false; // Hide this job
                } else {
                  print('🔍 [Frontend] PaperStore completed for job ${planning['nrcJobNo']} but role allows viewing; keeping in UI');
                }
              } else {
                print('🔍 [Frontend] PaperStore status is $stepStatus (paperStore: $paperStoreStatus) for job ${planning['nrcJobNo']}, NOT hiding (keep in UI)');
              }

              // Skip further checks for PaperStore after handling its logic
              continue;
            }
            
            // For other non-machine steps, check if they're completed
            // If step has no machines but status is stop/accept/completed, hide it
            final hasMachines = _hasMachineAssignment(step['machineDetails'] as List<dynamic>?);
            if (!hasMachines) {
              final stepNameLower = stepName?.toLowerCase() ?? '';
              
              // Special handling for Dispatch - only hide if dispatchProcess.status is 'accept' (fully dispatched)
              if (stepNameLower == 'dispatchprocess' || stepNameLower == 'dispatch') {
                if (!isDispatchRole && !isBypassRole) {
                  continue;
                }
                // If user is Quality role but not Dispatch role, skip Dispatch checks (let Quality view work)
                if (isQualityRole && !isDispatchRole) {
                  print('   - ℹ️ User is Quality role, skipping Dispatch checks for Quality view');
                  continue;
                }
                
                // Check dispatchProcess.status instead of stepStatus for Dispatch
                // DispatchProcess.status = 'accept' means fully dispatched, 'in_progress' means partial dispatch
                final dispatchProcess = step['dispatchProcess'];
                final dispatchProcessStatus = dispatchProcess is Map<String, dynamic>
                    ? dispatchProcess['status']?.toString().toLowerCase()
                    : null;
                
                print('🔍 [Frontend] Dispatch step for job ${planning['nrcJobNo']} (plan ${planning['jobPlanId']}): stepStatus=$stepStatus, dispatchProcessStatus=$dispatchProcessStatus');
                print('   - dispatchProcess data: $dispatchProcess');
                
                // For Dispatch, hide ONLY if dispatchProcess.status is EXACTLY 'accept' (fully dispatched)
                // Keep visible if status is 'in_progress' or null (partial dispatch or not started)
                // NEVER use stepStatus as fallback for dispatch - it's not reliable
                if (dispatchProcessStatus == 'accept') {
                  print('🔍 [Frontend] Dispatch fully completed (accept) for job ${planning['nrcJobNo']}, hiding from UI');
                  return false; // Hide this job - fully dispatched
                }
                
                // If dispatchProcessStatus is 'in_progress' or null, keep it visible (don't hide)
                print('🔍 [Frontend] Dispatch in progress or not started (status=$dispatchProcessStatus) for job ${planning['nrcJobNo']}, keeping visible');

                // Only show if previous step is ready (at 'start' or beyond) - applies to both urgent and regular jobs
                final previousStep = stepIndex > 0 && steps[stepIndex - 1] is Map<String, dynamic>
                    ? steps[stepIndex - 1] as Map<String, dynamic>
                    : null;
                if (!_isPreviousStepReady(previousStep)) {
                  print('🔍 [Frontend] Dispatch previous step not ready for job ${planning['nrcJobNo']} (plan ${planning['jobPlanId']}) - previous status: ${previousStep?['status']}, hiding from UI (urgent: $isUrgentJob)');
                  return false;
                }

                // Previous step ready and Dispatch not fully completed (in_progress) - keep visible
                continue;
              } else if (stepNameLower == 'qualitydept' || stepNameLower == 'quality') {
                print('🔍 [Frontend] Found Quality step for job ${planning['nrcJobNo']} (plan ${planning['jobPlanId']}): stepStatus=$stepStatus, stepIndex=$stepIndex');
                print('   - isQualityRole=$isQualityRole, isDispatchRole=$isDispatchRole, isBypassRole=$isBypassRole');
                
                if (!isQualityRole && !isBypassRole) {
                  print('   - ⚠️ Skipping Quality check: user does not have Quality role and is not bypass role');
                  continue;
                }
                if (isDispatchRole && !isQualityRole) {
                  // Dispatch view should ignore Quality completion gates
                  print('   - ⚠️ Skipping Quality check: user has Dispatch role but not Quality role');
                  continue;
                }
                
                print('   - ✅ Proceeding with Quality checks');
                final isQualityCompleted = stepStatus == 'accept' || stepStatus == 'stop' || stepStatus == 'stopped' || stepStatus == 'completed';
                if (isQualityCompleted) {
                  print('🔍 [Frontend] Quality completed ($stepStatus) for job ${planning['nrcJobNo']}, hiding from UI');
                  return false;
                }

                // Only show if previous step is ready (at 'start' or beyond) - applies to both urgent and regular jobs
                final previousStep = stepIndex > 0 && steps[stepIndex - 1] is Map<String, dynamic>
                    ? steps[stepIndex - 1] as Map<String, dynamic>
                    : null;
                print('   - Previous step: ${previousStep?['stepName']}, status: ${previousStep?['status']}');
                if (!_isPreviousStepReady(previousStep)) {
                  print('🔍 [Frontend] Quality previous step not ready for job ${planning['nrcJobNo']} (plan ${planning['jobPlanId']}) - previous status: ${previousStep?['status']}, hiding from UI (urgent: $isUrgentJob)');
                  return false;
                }

                // Previous step ready but Quality still pending - keep visible
                print('   - ✅ Quality checks passed: previous step ready and Quality not completed - keeping visible');
                continue;
              } else {
                // For other non-machine steps
                final isCompleted = stepStatus == 'stop' || stepStatus == 'stopped' || stepStatus == 'completed' || stepStatus == 'accept';
                if (isCompleted) {
                  print('🔍 [Frontend] Completed non-machine step ${stepName} for job ${planning['nrcJobNo']}, hiding from UI');
                  return false; // Hide this job
                }
              }
            } else {
              final stepNameLower = step['stepName']?.toString().toLowerCase() ?? '';
              final isMachineStepCompleted = stepStatus == 'stop' || stepStatus == 'stopped' || stepStatus == 'completed' || stepStatus == 'accept';
              final bool userHandlesThisMachineStep = _doesRoleHandleMachineStep(userRoles, stepNameLower);
              final bool machineFilterActive = widget.filterByMachineId != null;

              if (isMachineStepCompleted && (userHandlesThisMachineStep || machineFilterActive) && !isBypassRole) {
                print('🔍 [Frontend] Completed machine step ${step['stepName']} for job ${planning['nrcJobNo']}, hiding from UI');
                return false;
              }
            }
          }
        }
        return true; // Keep this job
      }).toList();
      
      // Keep every planning (including multiple jobPlanIds) for consistency across all roles
      final List<Map<String, dynamic>> deduplicatedPlannings = List<Map<String, dynamic>>.from(completedNonMachineFilteredPlannings);
      print('🔍 [Frontend] Keeping ${deduplicatedPlannings.length} plannings after filtering (no deduplication)');
      
      // Job plannings are already filtered by backend based on user role
      
      // Use job plannings directly (already filtered by backend)
      List<Map<String, dynamic>> finalJobList = [];
      List<Map<String, dynamic>> highDemandJobs = [];
      List<Map<String, dynamic>> regularJobs = [];
      
      for (var planning in deduplicatedPlannings) {
        final nrcJobNo = planning['nrcJobNo'] as String;
        final jobDemand = planning['jobDemand'] as String?;
        final jobPlanId = planning['jobPlanId'];
        print('🔍 [Frontend] Final list candidate -> Job: $nrcJobNo | Plan: $jobPlanId | Status: ${planning['status']}');
        print('🔍 [Frontend] Processing planning: $nrcJobNo, demand: $jobDemand');
        
        final statusKey = _statusKey(nrcJobNo, planning['jobPlanId']);
        // Add job status
        planning['status'] = statuses[statusKey] ?? 'UNKNOWN';
        
        // Separate high-demand jobs from regular jobs
        if (jobDemand?.toLowerCase() == 'high') {
          highDemandJobs.add(planning);
          print('🔍 [Frontend] High-demand job found: $nrcJobNo');
        } else {
          regularJobs.add(planning);
        }
      }
      
      // Prioritize high-demand jobs at the top
      finalJobList = [...highDemandJobs, ...regularJobs];
      print('🔍 [Frontend] Total jobs: ${finalJobList.length}, High-demand: ${highDemandJobs.length}');

      // Check if widget is still mounted before setting state
      if (!mounted) return;
      setState(() {
        jobPlannings = finalJobList;
        filteredJobPlannings = finalJobList; // Initialize filtered list
        jobStatuses = statuses;
        _isLoading = false;
      });
    } catch (e) {
      // Check if widget is still mounted before setting state
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load job plannings';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          widget.filterByMachineName != null 
            ? 'Jobs for ${widget.filterByMachineName}' 
            : 'Work Assignment'
        ),
        backgroundColor: AppColors.maincolor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          // Debug clear cache button
          IconButton(
            icon: const Icon(Icons.clear_all, color: Colors.white),
            onPressed: _isLoading ? null : _clearAllCaches,
            tooltip: 'Clear All Caches',
          ),
          IconButton(
            icon: _isLoading
                ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            )
                : const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _clearAllCaches,
            tooltip: 'Reload',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    offset: const Offset(0, 2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  _filterJobs();
                },
                decoration: InputDecoration(
                  hintText: 'Search by Job Number, Plan ID, Demand...',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  prefixIcon: Icon(Icons.search, color: Colors.blue),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.grey[600]),
                    onPressed: () {
                      _searchController.clear();
                      _filterJobs(); // Also trigger filter when clearing
                    },
                  )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : filteredJobPlannings.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchController.text.isNotEmpty
                  ? Icons.search_off
                  : Icons.work_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isNotEmpty
                  ? 'No jobs found matching "${_searchController.text}"'
                  : 'No job plannings found.',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredJobPlannings.length,
        itemBuilder: (context, index) {
          final planning = filteredJobPlannings[index];
          return _buildSummaryCard(context, planning);
        },
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, Map<String, dynamic> jobPlanning) {
    final nrcJobNo = jobPlanning['nrcJobNo']?.toString() ?? '';
    final status = jobStatuses[_statusKey(nrcJobNo, jobPlanning['jobPlanId'])] ?? '';
    final isHold = status == 'HOLD';
    final jobDemand = jobPlanning['jobDemand']?.toString() ?? '';
    
    // Debug logging for high-demand jobs
    if (jobDemand.toLowerCase() == 'high') {
      print('🔍 [Frontend] High-demand job card: $nrcJobNo, demand: $jobDemand');
    }

    return Card
      (
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.grey[50]!,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  if (isHold) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: const Text('Work on Hold'),
                        content: const Text('This Work is in hold, Contact to admin'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                    return;
                  }
                  // Navigate to JobTimelinePage
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const Center(child: CircularProgressIndicator()),
                  );
                  final dio = Dio();
                  final jobApi = JobApi(dio);
                  final dynamic rawJobPlanId = jobPlanning['jobPlanId'];
                  final int? jobPlanId = rawJobPlanId is int
                      ? rawJobPlanId
                      : int.tryParse(rawJobPlanId?.toString() ?? '');
                  final planning = await jobApi.getJobPlanningStepsByNrcJobNo(
                    nrcJobNo,
                    jobPlanId: jobPlanId,
                  );
                  if (mounted) Navigator.of(context).pop();
                  final steps = planning?['steps'] ?? [];
                  if (!mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => JobTimelinePage(
                        jobNumber: nrcJobNo,
                        assignedSteps: steps,
                        jobPlanId: jobPlanId,
                        filterByMachineId: widget.filterByMachineId, // Pass machine context
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'WORK ASSIGNMENT',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.maincolor,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Tooltip(
                              message: 'NRC Job No: $nrcJobNo',
                              child: Text(
                                'NRC Job No: $nrcJobNo',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[800],
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Tooltip(
                              message: 'Job Plan: ${jobPlanning['jobPlanCode'] ?? jobPlanning['jobPlanId']}',
                              child: Text(
                                'Job Plan: ${jobPlanning['jobPlanCode'] ?? jobPlanning['jobPlanId']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isHold)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'HOLD',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      if (_formatJobDemand(jobPlanning['jobDemand'] ?? '').toLowerCase() == 'urgent')
                        AnimatedBuilder(
                          animation: _blinkAnimation,
                          builder: (context, child) {
                            return Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(_blinkAnimation.value * 0.6),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: const Text(
                                'U',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            );
                          },
                        ),
                      IconButton(
                        tooltip: _expandedJobNos.contains(nrcJobNo) ? 'Collapse' : 'Expand',
                        icon: Icon(
                          _expandedJobNos.contains(nrcJobNo)
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: Colors.grey[700],
                        ),
                        onPressed: () {
                          setState(() {
                            if (_expandedJobNos.contains(nrcJobNo)) {
                              _expandedJobNos.remove(nrcJobNo);
                            } else {
                              _expandedJobNos.add(nrcJobNo);
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              if (_expandedJobNos.contains(nrcJobNo))
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      _buildSummaryItem(
                        icon: Icons.trending_up,
                        title: 'Job Demand',
                        value: _formatJobDemand(jobPlanning['jobDemand'] ?? ''),
                        color: Colors.purple,
                      ),
                      const SizedBox(height: 10),
                      if (_isAdminOrPlanner)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              final dynamic rawJobPlanId = jobPlanning['jobPlanId'];
                              final int? planId = rawJobPlanId is int
                                  ? rawJobPlanId
                                  : int.tryParse(rawJobPlanId?.toString() ?? '');

                              final dynamic rawPoId = jobPlanning['purchaseOrderId'];
                              final int? poId = rawPoId is int
                                  ? rawPoId
                                  : int.tryParse(rawPoId?.toString() ?? '');

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => WorkDetailsScreen(
                                    nrcJobNo: nrcJobNo,
                                    jobPlanId: planId,
                                    purchaseOrderId: poId,
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.maincolor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 2,
                            ),
                            child: const Text(
                              'View Complete Details',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
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

  Widget _buildSummaryItem({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Tooltip(
                  message: value,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}