import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../constants/colors.dart';
import '../../routes/UserRoleManager.dart';
import 'package:dio/dio.dart';
import '../../../constants/strings.dart';
import '../../../data/datasources/job_api.dart';
import 'dart:convert'; // Added for jsonDecode
import '../activity/UserDailyActivityPage.dart';
import 'package:fl_chart/fl_chart.dart';
import '../process/JobApiService.dart';
import '../../../core/services/dio_service.dart';
import '../work/WorkScreen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<String> _userRoles = [];
  String _primaryRole = '';
  bool _dashboardExpanded = false;

  // Status Overview state
  int totalOrders = 0;
  int activeJobs = 0;
  int inProgress = 0;
  int completedOrders = 0;
  bool isLoadingStatus = false;
  JobApi? _jobApi;


  // Machine state
  List<Map<String, dynamic>> _userMachines = [];
  List<Map<String, dynamic>> _allMachines = [];
  Map<String, int> _machineJobCounts = {};
  int _totalJobPlanningsCount = 0; // Total number of job plannings accessible to user
  List<Map<String, dynamic>>? _jobPlannings; // Store job plannings for counter calculations
  bool isLoadingMachines = false;
  JobApiService? _apiService;

  // Derived for insights
  int get _notStarted => (totalOrders - completedOrders - inProgress).clamp(0, totalOrders);

  // Check if user has any dashboard cards to show
  bool _hasDashboardCards() {
    // Admin can see all department cards
    if (_userRoles.contains('admin')) {
      return true;
    }

    // Define valid roles that have dashboard cards
    final validDashboardRoles = {
      'planner',
      'printer',
      'production_head',
      'dispatch_executive',
      'qc_manager',
      'qc_manager_flying',
      'flyingsquad',
    };

    // Check if user has any of the valid dashboard roles
    return _userRoles.any((role) => validDashboardRoles.contains(role));
  }

  // Check if user has roles that can see all jobs (excluding roles without machine access like paperstore, dispatch, quality)
  bool _canUserSeeAllJobs() {
    final allJobsRoles = {
      'flyingsquad',
      'planner', // Planner can see all jobs
      'admin', // Admin can see everything
    };
    
    return _userRoles.any((role) => allJobsRoles.contains(role.toLowerCase()));
  }

  // Check if user has roles that don't have machine access (paperstore, dispatch, quality)
  bool _hasNoMachineAccess() {
    final noMachineAccessRoles = {
      'paperstore',
      'qc_manager', 
      'qc_manager_flying',
      'dispatch_executive',
    };
    
    return _userRoles.any((role) => noMachineAccessRoles.contains(role.toLowerCase()));
  }

  // Check if user is specifically a paperstore user
  bool _isPaperstoreUser() {
    return _userRoles.any((role) => role.toLowerCase() == 'paperstore');
  }

  // Helper method to check if step has machine assignment (matching WorkScreen logic)
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

  // Check if user is specifically a quality control user
  bool _isQualityUser() {
    return _userRoles.any((role) => 
      role.toLowerCase() == 'qc_manager' || 
      role.toLowerCase() == 'qc_manager_flying'
    );
  }

  // Check if user is specifically a dispatch user
  bool _isDispatchUser() {
    return _userRoles.any((role) => role.toLowerCase() == 'dispatch_executive');
  }

  // Get appropriate section title based on user role
  String _getSectionTitle() {
    if (_isPaperstoreUser() || _isQualityUser() || _isDispatchUser()) {
      return 'Work Access';
    }
    return _canUserSeeAllJobs() ? 'All Machines' : 'My Machines';
  }

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _initializeApiAndFetch();
  }

  void _loadUserRole() async {
    print('HomeScreen: Loading user role...');
    await UserRoleManager().loadUserRole();
    final roles = UserRoleManager().userRoles;
    print('HomeScreen: Loaded roles: $roles');
    print('HomeScreen: Roles length: ${roles.length}');
    
    if (roles.isEmpty) {
      print('HomeScreen: No roles found, redirecting to login');
      if (mounted) {
        // No role should mean not logged in; redirect to login
        context.pushReplacement('/');
      }
      return;
    }
    
    // Check if widget is still mounted before setting state
    if (!mounted) return;
    setState(() {
      _userRoles = roles;
      _primaryRole = roles.isNotEmpty ? roles.first : '';
    });
    print('User Roles in HomeScreen: $_userRoles');
    print('Primary Role: $_primaryRole');
  }

  void _initializeApiAndFetch() {
    print('Initializing JobApi...');
    final dio = Dio();
    dio.options.baseUrl = AppStrings.baseUrl;
    _jobApi = JobApi(dio);
    _apiService = JobApiService(_jobApi!);
    print('JobApi initialized, calling _fetchMachinesAndJobs...');
    _fetchMachinesAndJobs();
  }


  Future<void> _fetchMachinesAndJobs() async {
    print('_fetchMachinesAndJobs called, _apiService is: ${_apiService == null ? "null" : "initialized"}');
    if (_apiService == null) {
      print('ApiService not initialized!');
      return;
    }
    
    // Check if widget is still mounted before setting state
    if (!mounted) return;
    setState(() { isLoadingMachines = true; });
    
    try {
      print('Fetching user machines (role-filtered)...');
      
      // Check user role types for machine and job access
      final canSeeAllJobs = _canUserSeeAllJobs(); // admin, planner, flyingsquad
      final hasNoMachineAccess = _hasNoMachineAccess(); // paperstore, dispatch, quality
      print('User can see all jobs: $canSeeAllJobs');
      print('User has no machine access: $hasNoMachineAccess');
      
      // Fetch job plannings first (backend already filters correctly based on user role)
      final jobPlannings = await _jobApi!.getAllJobPlanningsFresh();
      print('Job Plannings: ${jobPlannings.length} items');
      
      List<Map<String, dynamic>> accessibleMachines = [];
      
      if (canSeeAllJobs) {
        // For admin, planner, flyingsquad - show ALL machines
        print('User can see all jobs - fetching all machines');
        accessibleMachines = await _apiService!.getMachinesRaw();
        print('All Machines: ${accessibleMachines.length} items');
      } else if (hasNoMachineAccess) {
        // For roles without machine access (paperstore, dispatch, quality) - show all machines for job counting
        print('User has no machine access - fetching all machines for job counting');
        accessibleMachines = await _apiService!.getMachinesRaw();
        print('All Machines: ${accessibleMachines.length} items');
      } else {
        // For machine access roles (printer, corrugator, etc.) - get user's assigned machines
        print('Getting user assigned machines...');
        
        // Step 1: Try to get user's assigned machines from backend
        Set<String> userMachineIds = {};
        
        try {
          final userMachines = await _apiService!.getUserMachines();
          print('User Machines API: ${userMachines.length} items');
          print('User Machines sample: ${userMachines.take(2).toList()}');
          
          // Extract machine IDs from user machines (handle different field names and isActive)
          for (final userMachine in userMachines) {
            final isActive = userMachine['isActive'];
            final isActiveBool = isActive == true || isActive == null || isActive == 1 || isActive == 'true';
            
            if (isActiveBool) {
              final machineId = userMachine['machineId']?.toString();
              if (machineId != null) {
                userMachineIds.add(machineId);
              }
            }
          }
          
          // Fallback: if no active machines found, use all user machines
          if (userMachineIds.isEmpty && userMachines.isNotEmpty) {
            print('No active machines found, using all user machines');
            for (final userMachine in userMachines) {
              final machineId = userMachine['machineId']?.toString();
              if (machineId != null) {
                userMachineIds.add(machineId);
              }
            }
          }
      } catch (e) {
          print('Error getting user machines from API: $e');
        }
        
        // Step 2: Fallback - if getUserMachines() failed, extract from job plannings for user's role
        if (userMachineIds.isEmpty) {
          print('User Machines API failed, extracting from job plannings based on role');
          
          // Get current user ID to match with job steps
          final prefs = await SharedPreferences.getInstance();
          final currentUserId = prefs.getString('userId');
          print('Current User ID: $currentUserId');
          
          for (final planning in jobPlannings) {
            if (planning['steps'] is List) {
              final steps = planning['steps'] as List;
              for (final step in steps) {
                final stepName = step['stepName']?.toString();
                final stepUser = step['user']?.toString();
                
                // Check if this step matches user's role and is assigned to this user
                bool shouldIncludeStep = false;
                if (_userRoles.any((role) => role.toLowerCase() == 'printer') && stepName == 'PrintingDetails') {
                  shouldIncludeStep = true;
                } else if (_userRoles.any((role) => role.toLowerCase() == 'corrugator') && stepName == 'Corrugation') {
                  shouldIncludeStep = true;
                } else if (_userRoles.any((role) => role.toLowerCase() == 'flutelaminator') && stepName == 'FluteLaminateBoardConversion') {
                  shouldIncludeStep = true;
                } else if (_userRoles.any((role) => role.toLowerCase() == 'puncher') && stepName == 'Punching') {
                  shouldIncludeStep = true;
                } else if (_userRoles.any((role) => role.toLowerCase() == 'flap') && stepName == 'SideFlapPasting') {
                  shouldIncludeStep = true;
                }
                
                // If step matches role and user assignment, add machines
                if (shouldIncludeStep && step['machineDetails'] is List) {
                  final machineDetails = step['machineDetails'] as List;
                  for (final machineDetail in machineDetails) {
                    if (machineDetail is Map<String, dynamic>) {
                      final machineId = machineDetail['id']?.toString();
                      if (machineId != null) {
                        userMachineIds.add(machineId);
                        print('Added machine from job planning: $machineId (step: $stepName)');
                      }
                    }
                  }
                }
              }
            }
          }
        }
        
        print('User Machine IDs: ${userMachineIds.toList()}');
        
        // Step 3: Get all machines and filter to only show assigned ones
        final allMachines = await _apiService!.getMachinesRaw();
        print('All Machines: ${allMachines.length} items');
        
        accessibleMachines = allMachines
            .where((machine) {
              final machineId = machine['id']?.toString();
              final isMatch = userMachineIds.contains(machineId);
              if (isMatch) {
                print('Found assigned machine: ${machine['machineCode']} (id: $machineId)');
              }
              return isMatch;
            })
            .toList();
      }
      
      print('Accessible Machines: ${accessibleMachines.length} items');
      
      // Count jobs per machine
      final machineJobCounts = <String, int>{};
      for (final machine in accessibleMachines) {
        final machineId = machine['id']?.toString();
        if (machineId != null) {
          machineJobCounts[machineId] = 0;
        }
      }
      
      // Count each job planning (card) separately - don't group by nrcJobNo
      int totalActiveJobs = 0; // Track active jobs for non-machine roles
      
      // Process each planning individually - count each card separately
      for (final planning in jobPlannings) {
        final nrcJobNo = planning['nrcJobNo']?.toString() ?? 'unknown';
        final planningId = planning['jobPlanId'] ?? planning['id'] ?? 'unknown';
        
        // Track which machines are used in this planning (card)
        final Set<String> machinesUsedInThisPlanning = {};
        bool hasActiveNonMachineStep = false; // Track if planning has active non-machine step
        
        print('🔍 [HomeScreen] Processing planning $planningId (job $nrcJobNo)');
        
        if (planning['steps'] is List) {
          final steps = planning['steps'] as List;
          for (final step in steps) {
            final stepName = step['stepName']?.toString();
            
            // Determine which steps to include based on user role type
            bool shouldIncludeStep = false;
            
            if (canSeeAllJobs) {
              // For admin, planner, flyingsquad - count all steps
              shouldIncludeStep = true;
            } else if (hasNoMachineAccess) {
              // For dispatch, quality - count all steps (existing behavior)
              // For paperstore - only count paperstore step
              if (_userRoles.any((role) => role.toLowerCase() == 'paperstore')) {
                shouldIncludeStep = (stepName == 'PaperStore');
                print('🔍 [HomeScreen] PaperStore user - stepName: $stepName, shouldIncludeStep: $shouldIncludeStep');
              } else {
                shouldIncludeStep = true;
              }
            } else {
              // For machine access roles (printer, corrugator, etc.) - ONLY count steps that match their role
              if (_userRoles.any((role) => role.toLowerCase() == 'printer') && stepName == 'PrintingDetails') {
                shouldIncludeStep = true;
              } else if (_userRoles.any((role) => role.toLowerCase() == 'corrugator') && stepName == 'Corrugation') {
                shouldIncludeStep = true;
              } else if (_userRoles.any((role) => role.toLowerCase() == 'flutelaminator') && stepName == 'FluteLaminateBoardConversion') {
                shouldIncludeStep = true;
              } else if (_userRoles.any((role) => role.toLowerCase() == 'punching_operator') && stepName == 'Punching') {
                shouldIncludeStep = true;
              } else if (_userRoles.any((role) => role.toLowerCase() == 'pasting_operator') && stepName == 'SideFlapPasting') {
                shouldIncludeStep = true;
              }
            }
            
            // If this step should be included, check if it has machines
            if (shouldIncludeStep) {
              final stepStatus = step['status']?.toString().toLowerCase();
              final hasMachines = step['machineDetails'] is List && (step['machineDetails'] as List).isNotEmpty;
              
              // Special handling for PaperStore step (check if it's completed)
              if (stepName?.toLowerCase() == 'paperstore' || stepName?.toLowerCase() == 'paper store') {
                // For PaperStore, only hide if status is 'accept' (fully completed)
                if (stepStatus == 'accept') {
                  print('🔍 [HomeScreen] PaperStore completed (accept) for planning $planningId');
                } else {
                  hasActiveNonMachineStep = true;
                  print('🔍 [HomeScreen] Active PaperStore step for planning $planningId');
                }
              } else {
                // For other non-machine steps, use general completion logic
                final isCompleted = stepStatus == 'stop' || stepStatus == 'stopped' || stepStatus == 'completed' || stepStatus == 'accept';
                
                if (!hasMachines) {
                  if (!isCompleted) {
                    hasActiveNonMachineStep = true;
                    print('🔍 [HomeScreen] Active non-machine step ${stepName} for planning $planningId');
                  } else {
                    print('🔍 [HomeScreen] Completed non-machine step ${stepName} for planning $planningId');
                  }
                } else if (hasMachines) {
                  // Machine-based step - apply same filtering as WorkScreen
                  // Hide if step is completed
                  if (isCompleted) {
                    print('🔍 [HomeScreen] Completed step ${stepName} for planning $planningId, skipping');
                    continue;
                  }
                  
                  // Check if previous step is ready (for machine steps)
                  bool previousStepReady = true;
                  final stepIndex = steps.indexOf(step);
                  if (stepIndex > 0) {
                    final previousStep = steps[stepIndex - 1];
                    if (previousStep is Map<String, dynamic>) {
                      final prevStatus = previousStep['status']?.toString().toLowerCase() ?? '';
                      final prevNameLower = previousStep['stepName']?.toString().toLowerCase() ?? '';
                      
                      // Check if previous step is completed
                      if (prevNameLower.contains('paperstore')) {
                        previousStepReady = prevStatus == 'accept';
                      } else if (prevStatus == 'stop' || prevStatus == 'stopped' || prevStatus == 'completed' || prevStatus == 'accept') {
                        previousStepReady = true;
                      } else {
                        previousStepReady = false;
                      }
                      
                      // Also check if current step is active (start/in_progress) - if yes, allow even if previous not ready
                      final currentStepActive = stepStatus == 'start' || stepStatus == 'in_progress';
                      if (currentStepActive) {
                        previousStepReady = true;
                      }
                    }
                  }
                  
                  // Only count machines if previous step is ready OR current step is active
                  if (previousStepReady) {
                    final machineDetails = step['machineDetails'] as List;
                    for (final machineDetail in machineDetails) {
                      if (machineDetail is Map<String, dynamic>) {
                        final stepMachineId = machineDetail['id']?.toString();
                        if (stepMachineId != null) {
                          machinesUsedInThisPlanning.add(stepMachineId);
                          print('🔍 [HomeScreen] Added machine $stepMachineId for planning $planningId (step $stepName)');
                        }
                      }
                    }
                  } else {
                    print('🔍 [HomeScreen] Previous step not ready for planning $planningId (step $stepName), skipping machine count');
                  }
                }
              }
            }
          }
        }
        
        // For non-machine roles, count jobs with active steps
        if (hasNoMachineAccess && hasActiveNonMachineStep) {
          totalActiveJobs++;
          print('🔍 [HomeScreen] Counting active planning $planningId for non-machine role');
        }
        
        // Count each planning (card) separately for each machine it uses
        // IMPORTANT: Count each planning card separately, even if same nrcJobNo
        // Each card (jobPlanId) should be counted separately
        for (final machineId in machinesUsedInThisPlanning) {
          bool shouldCountThisMachine = true;
          
          // For machine access roles (printer, corrugator, etc.), verify they have access to this machine
          // This ensures: Job counts only for machines the user actually has access to
          if (!canSeeAllJobs && !hasNoMachineAccess) {
            final isAccessibleMachine = accessibleMachines.any((machine) => 
                machine['id']?.toString() == machineId);
            shouldCountThisMachine = isAccessibleMachine;
          }
          
          // Count this planning (card) for this specific machine
          // Each planning card is counted separately - don't group by nrcJobNo
          if (shouldCountThisMachine) {
            machineJobCounts[machineId] = (machineJobCounts[machineId] ?? 0) + 1;
            print('🔍 [HomeScreen Counter] Counting planning $planningId (job $nrcJobNo) for machine $machineId - count now: ${machineJobCounts[machineId]}');
          }
        }
      }
      
      // Ensure all accessible machines have job counts (even if 0)
      // This applies to all role types
      for (final machine in accessibleMachines) {
        final machineId = machine['id']?.toString();
        if (machineId != null && !machineJobCounts.containsKey(machineId)) {
          machineJobCounts[machineId] = 0;
        }
      }
      
      // Check if widget is still mounted before updating state
      if (!mounted) return;
      
      setState(() {
        _userMachines = accessibleMachines; // Use accessible machines as user machines for role-based display
        _allMachines = accessibleMachines;
        _machineJobCounts = machineJobCounts;
        _jobPlannings = jobPlannings; // Store job plannings for counter calculations
        // For non-machine roles (PaperStore, QC, Dispatch), use totalActiveJobs
        // For machine roles, count jobs that have at least one machine assigned
        if (hasNoMachineAccess) {
          _totalJobPlanningsCount = totalActiveJobs;
          print('Set _totalJobPlanningsCount to $totalActiveJobs (active jobs for non-machine role)');
        } else {
          // For machine roles, count unique plannings that have accessible machines
          // Count each planning card separately (not grouped by nrcJobNo)
          final uniquePlanningsWithMachines = <String>{};
          for (final planning in jobPlannings) {
            final planningId = planning['jobPlanId']?.toString() ?? planning['id']?.toString();
            if (planningId == null) continue;
            
            final steps = planning['steps'];
            if (steps is! List) continue;
            
            bool hasAccessibleMachine = false;
            for (int i = 0; i < steps.length; i++) {
              final step = steps[i];
              if (step is! Map<String, dynamic>) continue;
              
              final machineDetails = step['machineDetails'];
              if (machineDetails is! List || machineDetails.isEmpty) {
                continue;
              }

              final stepStatus = step['status']?.toString().toLowerCase();
              final isCompleted = stepStatus == 'stop' ||
                  stepStatus == 'stopped' ||
                  stepStatus == 'completed' ||
                  stepStatus == 'accept';

              if (isCompleted) {
                continue;
              }

              // Check if previous step is ready
              bool previousReady = true;
              if (i > 0) {
                final previousStep = steps[i - 1];
                if (previousStep is Map<String, dynamic>) {
                  final prevStatus = previousStep['status']?.toString().toLowerCase();
                  final prevNameLower = previousStep['stepName']?.toString().toLowerCase() ?? '';
                  if (prevNameLower.contains('paperstore')) {
                    previousReady = prevStatus == 'accept';
                  } else {
                    previousReady = prevStatus == 'stop' ||
                        prevStatus == 'stopped' ||
                        prevStatus == 'completed' ||
                        prevStatus == 'accept';
                  }
                }
              }

              if (!previousReady) {
                continue;
              }

              // Check machine assignment matches accessible machines
              for (final machineDetail in machineDetails) {
                if (machineDetail is! Map<String, dynamic>) continue;
                final machineIdInDetail = machineDetail['id']?.toString();
                final matchesAccessibleMachine = accessibleMachines.any((machine) {
                  final accessibleId = machine['id']?.toString();
                  return accessibleId != null && accessibleId == machineIdInDetail;
                });

                if (matchesAccessibleMachine) {
                  hasAccessibleMachine = true;
                  break;
                }
              }
              
              if (hasAccessibleMachine) break;
            }
            
            if (hasAccessibleMachine) {
              uniquePlanningsWithMachines.add(planningId);
            }
          }

          _totalJobPlanningsCount = uniquePlanningsWithMachines.length;
          print(
              'Set _totalJobPlanningsCount to ${_totalJobPlanningsCount} based on active machine steps after role filtering and machine access');
        }
      });
      
      print('Machine setup complete - ${accessibleMachines.length} accessible machines');
      
    } catch (e) {
      print('Error fetching machines and jobs: ' + e.toString());
      
      // Check if widget is still mounted before updating state
      if (!mounted) return;
      setState(() {
        _userMachines = [];
        _allMachines = [];
        _machineJobCounts = {};
        _totalJobPlanningsCount = 0;
      });
    }
    
    // Check if widget is still mounted before setting state
    if (!mounted) return;
    setState(() { isLoadingMachines = false; });
  }

  void _navigateToMachineJobs(Map<String, dynamic> machine) {
    final machineId = machine['id']?.toString();
    final machineName = machine['machineCode'] ?? machine['description'] ?? 'Unknown Machine';
    
    if (machineId != null) {
      // Navigate to WorkScreen with machine-specific filtering
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WorkScreen(
            filterByMachineId: machineId,
            filterByMachineName: machineName,
          ),
        ),
      );
    }
  }

  void _navigateToPaperstoreWork() async {
    // Navigate to WorkScreen - shows the same UI that was previously on work tab for paperstore
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const WorkScreen(),
      ),
    );
    // Refresh data when returning from WorkScreen
    if (mounted) {
      _fetchMachinesAndJobs();
    }
  }

  void _navigateToQualityWork() async {
    // Navigate to WorkScreen - shows the same UI that was previously on work tab for quality control
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const WorkScreen(),
      ),
    );
    // Refresh data when returning from WorkScreen
    if (mounted) {
      _fetchMachinesAndJobs();
    }
  }

  void _navigateToDispatchWork() async {
    // Navigate to WorkScreen - shows the same UI that was previously on work tab for dispatch
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const WorkScreen(),
      ),
    );
    // Refresh data when returning from WorkScreen
    if (mounted) {
      _fetchMachinesAndJobs();
    }
  }

  void _logout() async {
    print('🔒 [Logout] Starting logout process...');
    
    // 🔒 CRITICAL: Call backend logout API to clear session token from database
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      
      if (token != null) {
        print('🔒 [Logout] Calling backend logout API...');
        final dio = Dio();
        await dio.post(
          '${AppStrings.baseUrl}/auth/logout',
          options: Options(
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          ),
        );
        print('✅ [Logout] Backend session cleared successfully');
      }
    } catch (e) {
      print('⚠️ [Logout] Backend logout failed (continuing with local logout): $e');
      // Continue with local logout even if backend call fails
    }
    
    // Clear in-memory and persisted roles to avoid stale roles on next login
    await UserRoleManager().clearUserRole();

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('accessToken');
    await prefs.remove('userId');
    await prefs.remove('userRole');
    await prefs.remove('userRoles');

    print('✅ [Logout] All authentication data cleared');
    if (mounted) context.pushReplacement('/'); // Navigate back to the login screen
  }




  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: AppColors.white,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Menu',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.maincolor),
            ),
            const SizedBox(height: 24),
            if (_userRoles.contains('admin'))...[
              ElevatedButton(
                onPressed: () => context.push('/create-id'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.maincolor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text(
                  'Add New Account',
                  style: TextStyle(color: AppColors.white),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  context.push('/user-activity');
                },
                icon: const Icon(Icons.people,color: AppColors.white),
                label: const Text('User Activity',style: TextStyle(color: AppColors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.maincolor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],

            if (_userRoles.contains('planner') || _userRoles.contains('admin')) ...[
              ElevatedButton.icon(
                onPressed: () {
                  context.push('/job-input');
                },
                icon: const Icon(Icons.add,color: AppColors.white),
                label: const Text('Add New Customer',style: TextStyle(color: AppColors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.maincolor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  context.push('/completed-jobs');
                },
                icon: const Icon(Icons.check_circle,color: AppColors.white),
                label: const Text('Completed Jobs',style: TextStyle(color: AppColors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.maincolor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  context.push('/edit-machines');
                },
                icon: const Icon(Icons.build,color: AppColors.white),
                label: const Text('Edit Machines',style: TextStyle(color: AppColors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.maincolor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  print('Edit Working Details button clicked');
                  context.push('/edit-working-details');
                },
                icon: const Icon(Icons.edit_note,color: AppColors.white),
                label: const Text('Edit Working Details',style: TextStyle(color: AppColors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.maincolor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  context.push('/user-activity');
                },
                icon: const Icon(Icons.people,color: AppColors.white),
                label: const Text('User Activity',style: TextStyle(color: AppColors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.maincolor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
            ElevatedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: AppColors.white,),
              label: const Text('Logout',style: TextStyle(color: AppColors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.maincolor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const UserDailyActivityPage(),
                  ),
                );
              },
              icon: const Icon(Icons.history, color: AppColors.white),
              label: const Text('Your Activity', style: TextStyle(color: AppColors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.maincolor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: _buildDrawer(),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.menu, color: Colors.black87, size: 28),
            onPressed: () {
              _scaffoldKey.currentState!.openDrawer();
            },
          ),
          title: const Text(
            'Factory Portal',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_userRoles.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          'Logged in as: ${UserRoleManager().rolesDisplayString}',
                          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blue[800]),
                        ),
                      ],
                    ),
                    if (UserRoleManager().hasMultipleRoles) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Primary role: $_primaryRole',
                        style: TextStyle(fontSize: 12, color: Colors.blue[600]),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (_userRoles.contains('planner') || _userRoles.contains('admin')) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => context.push('/all-Jobs'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: const Text(
                        'All Jobs',
                        style: TextStyle(color: AppColors.maincolor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8), // Space between the buttons
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => context.push('/job-list'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: const Text(
                        'Plan Jobs',
                        style: TextStyle(color: AppColors.maincolor),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (_userRoles.isNotEmpty && _hasDashboardCards()) ...[
              _buildDashboardDropdown(),
              const SizedBox(height: 28),
            ],
            _buildMachineCards(),
          ],
        ),
      ),
    );
  }

  Widget _buildDepartmentCards({bool showHeader = true}) {
    // Admin can see all department cards. Other roles see cards based on their roles.
    if (_userRoles.contains('admin')) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader) ...[
            const Text(
              'Department Overview',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => context.push('/planning-dashboard'),
                  child: _buildDepartmentCard(
                    'Planning',
                    'Get comprehensive overview of planning activities',
                    Icons.analytics_outlined,
                    Colors.blue,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => context.push('/printing-dashboard'),
                  child: _buildDepartmentCard(
                    'Printing Manager',
                    'Manage printing operations and schedules',
                    Icons.print_outlined,
                    Colors.indigo,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => context.push('/production-dashboard'),
                  child: _buildDepartmentCard(
                    'Production Head',
                    'Monitor production metrics and performance',
                    Icons.factory_outlined,
                    Colors.cyan,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => context.push('/dispatch-dashboard'),
                  child: _buildDepartmentCard(
                    'Dispatch Executive',
                    'Manage dispatch operations and logistics',
                    Icons.local_shipping_outlined,
                    Colors.blue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => context.push('/qc-dashboard'),
                  child: _buildDepartmentCard(
                    'QC Manager',
                    'Quality control and assurance management',
                    Icons.verified_outlined,
                    Colors.cyan,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => context.push('/flying-squad-dashboard'),
                  child: _buildDepartmentCard(
                    'Flying Squad',
                    'Monitor all job steps and perform QC checks',
                    Icons.flight_takeoff,
                    Colors.purple,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // Non-admin roles: show cards for all user roles
    List<Widget> departmentCards = [];
    
    // Define role to card mapping
    final roleCardMap = {
      'planner': {
        'title': 'Planning',
        'description': 'Get comprehensive overview of planning activities',
        'icon': Icons.analytics_outlined,
        'color': Colors.blue,
        'onTap': () => context.push('/planning-dashboard'),
      },
      'printer': {
        'title': 'Printing Manager',
        'description': 'Manage printing operations and schedules',
        'icon': Icons.print_outlined,
        'color': Colors.indigo,
        'onTap': () => context.push('/printing-dashboard'),
      },
      'production_head': {
        'title': 'Production Head',
        'description': 'Monitor production metrics and performance',
        'icon': Icons.factory_outlined,
        'color': Colors.cyan,
        'onTap': () => context.push('/production-dashboard'),
      },
      'dispatch_executive': {
        'title': 'Dispatch Executive',
        'description': 'Manage dispatch operations and logistics',
        'icon': Icons.local_shipping_outlined,
        'color': Colors.blue,
        'onTap': () => context.push('/dispatch-dashboard'),
      },
      'qc_manager': {
        'title': 'QC Manager',
        'description': 'Quality control and assurance management',
        'icon': Icons.verified_outlined,
        'color': Colors.cyan,
        'onTap': () => context.push('/qc-dashboard'),
      },
      'qc_manager_flying': {
        'title': 'QC Checks',
        'description': 'Perform QC checks on all job steps',
        'icon': Icons.flight_takeoff,
        'color': Colors.purple,
        'onTap': () => context.push('/flying-squad-dashboard'),
      },
      'flyingsquad': {
        'title': 'Flying Squad',
        'description': 'Monitor all job steps and perform QC checks',
        'icon': Icons.flight_takeoff,
        'color': Colors.purple,
        'onTap': () => context.push('/flying-squad-dashboard'),
      },
    };

    // Create cards for each user role
    for (String role in _userRoles) {
      if (roleCardMap.containsKey(role)) {
        final cardData = roleCardMap[role]!;
        departmentCards.add(
          GestureDetector(
            onTap: cardData['onTap'] as VoidCallback,
            child: _buildDepartmentCard(
              cardData['title'] as String,
              cardData['description'] as String,
              cardData['icon'] as IconData,
              cardData['color'] as Color,
            ),
          ),
        );
      }
    }

    // If no valid roles found, return empty
    if (departmentCards.isEmpty) {
      return const SizedBox.shrink();
    }

    // Arrange cards in rows of 2
    List<Widget> cardRows = [];
    for (int i = 0; i < departmentCards.length; i += 2) {
      if (i + 1 < departmentCards.length) {
        // Two cards in a row
        cardRows.add(
          Row(
            children: [
              Expanded(child: departmentCards[i]),
              const SizedBox(width: 12),
              Expanded(child: departmentCards[i + 1]),
            ],
          ),
        );
        if (i + 2 < departmentCards.length) {
          cardRows.add(const SizedBox(height: 12));
        }
      } else {
        // Single card in a row
        cardRows.add(departmentCards[i]);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader) ...[
          const Text(
            'Department Overview',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
        ],
        ...cardRows,
      ],
    );
  }

  Widget _buildDashboardDropdown() {
    return Container(
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
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _dashboardExpanded,
          onExpansionChanged: (expanded) {
            if (mounted) {
              setState(() => _dashboardExpanded = expanded);
            }
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.maincolor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.dashboard_rounded, color: AppColors.maincolor, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Dashboard',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          children: [
            _buildDepartmentCards(showHeader: false),
          ],
        ),
      ),
    );
  }

  Widget _buildDepartmentCard(String title, String description, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }




  Widget _buildMachineCards() {
    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _getSectionTitle(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: isLoadingMachines
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh),
                onPressed: isLoadingMachines ? null : () {
                  if (_apiService == null) {
                    _initializeApiAndFetch();
                  } else {
                    _fetchMachinesAndJobs();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isLoadingMachines)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_allMachines.isEmpty && !(_isPaperstoreUser() || _isQualityUser() || _isDispatchUser()))
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    const Icon(
                      Icons.build_circle,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _canUserSeeAllJobs() 
                        ? 'No machines found in the system'
                        : 'No machines assigned to your role',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            _buildMachineGrid(),
        ],
      ),
    );
  }

  Widget _buildMachineGrid() {
    final List<Widget> rows = [];
    
    // Collect special cards based on user roles
    final List<Widget> specialCards = [];
    if (_isPaperstoreUser()) {
      specialCards.add(_buildPaperstoreCard());
    }
    if (_isQualityUser()) {
      specialCards.add(_buildQualityCard());
    }
    if (_isDispatchUser()) {
      specialCards.add(_buildDispatchCard());
    }
    
    // If user has special roles, show ONLY their department cards (no machines)
    if (specialCards.isNotEmpty) {
      // Add special cards in pairs (2x2 grid)
      for (int i = 0; i < specialCards.length; i += 2) {
        final firstCard = specialCards[i];
        final secondCard = i + 1 < specialCards.length ? specialCards[i + 1] : null;
        
        rows.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              children: [
                Expanded(
                  child: firstCard,
                ),
                if (secondCard != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: secondCard,
                  ),
                ] else ...[
                  const SizedBox(width: 12),
                  const Expanded(child: SizedBox()),
                ],
              ],
            ),
          ),
        );
      }
      
      return Column(children: rows);
    }
    
    // For regular users (no special roles), show machine cards only
    final machines = _allMachines;
    for (int i = 0; i < machines.length; i += 2) {
      final firstMachine = machines[i];
      final secondMachine = i + 1 < machines.length ? machines[i + 1] : null;
      
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Row(
            children: [
              Expanded(
                child: _buildMachineCard(firstMachine),
              ),
              if (secondMachine != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMachineCard(secondMachine),
                ),
              ],
            ],
          ),
        ),
      );
    }
    
    return Column(children: rows);
  }

  // Calculate machine job count using WorkScreen filtering logic (for counter only)
  int _calculateMachineJobCount(String? machineId) {
    if (machineId == null || _jobPlannings == null || _jobPlannings!.isEmpty) {
      return _machineJobCounts[machineId] ?? 0; // Fallback to original count
    }
    
    int count = 0;
    for (final planning in _jobPlannings!) {
      if (planning['steps'] is! List) continue;
      final steps = planning['steps'] as List;
      
      for (int stepIndex = 0; stepIndex < steps.length; stepIndex++) {
        final step = steps[stepIndex];
        if (step is! Map<String, dynamic>) continue;
        
        final stepStatus = step['status']?.toString().toLowerCase();
        final machineDetails = step['machineDetails'] as List<dynamic>?;
        final hasMachines = _hasMachineAssignment(machineDetails);
        
        if (hasMachines) {
          // Check if this step uses the specified machine
          bool usesThisMachine = false;
          if (machineDetails != null) {
            for (final md in machineDetails) {
              if (md is Map<String, dynamic>) {
                final stepMachineId = md['id']?.toString();
                if (stepMachineId == machineId) {
                  usesThisMachine = true;
                  break;
                }
              }
            }
          }
          
          if (usesThisMachine) {
            // Check if step is completed (matching WorkScreen logic)
            final isCompleted = stepStatus == 'stop' || stepStatus == 'stopped' || stepStatus == 'completed' || stepStatus == 'accept';
            if (isCompleted) continue;
            
            // Check if previous step is ready (matching WorkScreen logic)
            bool previousStepReady = true;
            if (stepIndex > 0 && steps[stepIndex - 1] is Map<String, dynamic>) {
              final previousStep = steps[stepIndex - 1] as Map<String, dynamic>;
              final prevStatus = previousStep['status']?.toString().toLowerCase() ?? '';
              if (prevStatus == 'planned') {
                previousStepReady = false;
              } else if (prevStatus == 'stop' || prevStatus == 'stopped' || prevStatus == 'completed' || prevStatus == 'accept') {
                previousStepReady = true;
              }
            }
            
            // Also allow if current step is active
            final isActive = stepStatus == 'start' || stepStatus == 'in_progress';
            if (isActive) previousStepReady = true;
            
            if (previousStepReady) {
              count++;
              break; // Count this job only once per machine
            }
          }
        }
      }
    }
    
    return count;
  }

  Widget _buildMachineCard(Map<String, dynamic> machine) {
    final machineId = machine['id']?.toString();
    final machineName = machine['machineCode'] ?? machine['description'] ?? 'Unknown Machine';
    final machineType = machine['machineType'] ?? machine['type'] ?? '';
    // Simply use the count from _machineJobCounts (already calculated in _fetchMachinesAndJobs)
    final jobCount = _machineJobCounts[machineId] ?? 0;
    
    // Determine card color based on job count
    Color cardColor;
    if (jobCount == 0) {
      cardColor = Colors.grey.shade50;
    } else if (jobCount <= 2) {
      cardColor = Colors.green.shade50;
    } else if (jobCount <= 5) {
      cardColor = Colors.orange.shade50;
    } else {
      cardColor = Colors.red.shade50;
    }
    
    return GestureDetector(
      onTap: () => _navigateToMachineJobs(machine),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cardColor == Colors.grey.shade50 ? Colors.grey.shade300 : Colors.transparent,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.maincolor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.build_circle,
                    color: AppColors.maincolor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
              Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        machineName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (machineType.isNotEmpty)
                        Text(
                          machineType,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '$jobCount',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: jobCount == 0 ? Colors.grey[600] : AppColors.maincolor,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    jobCount == 1 ? 'job' : 'jobs',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaperstoreCard() {
    // Get total job count for paperstore - apply same filtering as WorkScreen
    // Count only jobs where PaperStore is visible (not completed)
    int paperStoreJobCount = 0;
    final userRoles = UserRoleManager().userRoles;
    final hasPaperStoreRole = userRoles.any((role) => role.toLowerCase().contains('paperstore'));
    final isBypassRole = userRoles.any((role) => 
      role.toLowerCase().contains('qc_manager') ||
      role.toLowerCase().contains('dispatch_executive') ||
      role.toLowerCase().contains('dispatch executive') ||
      role.toLowerCase().contains('flyingsquad') ||
      role.toLowerCase().contains('flying squad') ||
      role.toLowerCase().contains('admin') ||
      role.toLowerCase().contains('planner')
    );
    
    if (_jobPlannings != null && _jobPlannings!.isNotEmpty) {
      if (hasPaperStoreRole || isBypassRole) {
        // Apply same filtering logic as WorkScreen
        for (final planning in _jobPlannings!) {
          if (planning['steps'] is! List) continue;
          final steps = planning['steps'] as List;
          bool shouldCount = false;
          
          for (final step in steps) {
            if (step is! Map<String, dynamic>) continue;
            
            final stepName = step['stepName']?.toString().toLowerCase() ?? '';
            final stepStatus = step['status']?.toString().toLowerCase();
            
            // Check for PaperStore step
            if (stepName == 'paperstore' || stepName == 'paper store') {
              final paperStoreRecord = step['paperStore'];
              final paperStoreStatus = paperStoreRecord is Map 
                ? paperStoreRecord['status']?.toString().toLowerCase() 
                : null;
              
              final isPaperStoreCompleted = stepStatus == 'accept' || paperStoreStatus == 'accept';
              
              // Only hide for PaperStore operators if completed
              if (isPaperStoreCompleted && !isBypassRole && hasPaperStoreRole) {
                shouldCount = false;
                break;
              } else {
                // PaperStore is visible (not completed or user has bypass role)
                shouldCount = true;
                break;
              }
            }
          }
          
          if (shouldCount) {
            paperStoreJobCount++;
          }
        }
      }
    }
    
    final totalJobs = (hasPaperStoreRole || isBypassRole) ? paperStoreJobCount : _totalJobPlanningsCount;
    
    return GestureDetector(
      onTap: () => _navigateToPaperstoreWork(),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.blue.shade100,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.inventory_2,
                    color: Colors.blue.shade700,
                    size: 20,
                  ),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Paperstore',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'All Jobs Access',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
                Text(
                  '$totalJobs',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: totalJobs == 0 ? Colors.grey[600] : Colors.blue.shade700,
                  ),
                ),
                const SizedBox(width: 4),
              Expanded(
                  child: Text(
                    totalJobs == 1 ? 'job' : 'jobs',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityCard() {
    // Get total job count for quality - apply same filtering as WorkScreen
    // Count only jobs where Quality is visible (not completed, and previous step is ready)
    int qualityJobCount = 0;
    final userRoles = UserRoleManager().userRoles;
    final isQualityRole = userRoles.any((role) => 
      role.toLowerCase().contains('quality') || 
      role.toLowerCase().contains('qc_manager') ||
      role.toLowerCase() == 'qc_manager'
    );
    final isBypassRole = userRoles.any((role) => 
      role.toLowerCase().contains('qc_manager') ||
      role.toLowerCase().contains('dispatch_executive') ||
      role.toLowerCase().contains('dispatch executive') ||
      role.toLowerCase().contains('flyingsquad') ||
      role.toLowerCase().contains('flying squad') ||
      role.toLowerCase().contains('admin') ||
      role.toLowerCase().contains('planner')
    );
    
    if (_jobPlannings != null && _jobPlannings!.isNotEmpty) {
      if (isQualityRole || isBypassRole) {
        // Apply same filtering logic as WorkScreen
        for (final planning in _jobPlannings!) {
          if (planning['steps'] is! List) continue;
          final steps = planning['steps'] as List;
          bool shouldCount = false;
          
          for (int stepIndex = 0; stepIndex < steps.length; stepIndex++) {
            final step = steps[stepIndex];
            if (step is! Map<String, dynamic>) continue;
            
            final stepName = step['stepName']?.toString().toLowerCase() ?? '';
            final stepStatus = step['status']?.toString().toLowerCase();
            
            // Check for Quality step
            if (stepName == 'qualitydept' || stepName == 'quality') {
              final machineDetails = step['machineDetails'] as List<dynamic>?;
              bool hasMachines = false;
              if (machineDetails != null && machineDetails.isNotEmpty) {
                for (final md in machineDetails) {
                  if (md is Map<String, dynamic>) {
                    final machineId = md['id']?.toString();
                    final machineCode = md['machineCode']?.toString();
                    if ((machineId != null && machineId.trim().isNotEmpty && machineId.toLowerCase() != 'not assigned') ||
                        (machineCode != null && machineCode.trim().isNotEmpty && machineCode.toLowerCase() != 'not assigned')) {
                      hasMachines = true;
                      break;
                    }
                  }
                }
              }
              
              // For non-machine steps (Quality has no machines)
              if (!hasMachines) {
                // Hide if Quality is completed
                if (stepStatus == 'accept' || stepStatus == 'stop' || stepStatus == 'stopped' || stepStatus == 'completed') {
                  shouldCount = false;
                  break;
                }
                
                // Only show if previous step is ready
                if (stepIndex > 0 && steps[stepIndex - 1] is Map<String, dynamic>) {
                  final previousStep = steps[stepIndex - 1] as Map<String, dynamic>;
                  final prevStatus = previousStep['status']?.toString().toLowerCase() ?? '';
                  // Previous step should be at least started (not 'planned')
                  if (prevStatus == 'planned') {
                    shouldCount = false;
                    break;
                  }
                }
                
                // Quality is visible
                shouldCount = true;
                break;
              }
            }
          }
          
          if (shouldCount) {
            qualityJobCount++;
          }
        }
      }
    }
    
    final totalJobs = (isQualityRole || isBypassRole) ? qualityJobCount : _totalJobPlanningsCount;
    
    return GestureDetector(
      onTap: () => _navigateToQualityWork(),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.green.shade100,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.verified_user,
                    color: Colors.green.shade700,
                    size: 20,
                  ),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Quality Control',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'All Jobs Access',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '$totalJobs',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: totalJobs == 0 ? Colors.grey[600] : Colors.green.shade700,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    totalJobs == 1 ? 'job' : 'jobs',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDispatchCard() {
    // Get total job count for dispatch - apply same filtering as WorkScreen
    // Count only jobs where Dispatch is visible (not completed, and previous step is ready)
    int dispatchJobCount = 0;
    final userRoles = UserRoleManager().userRoles;
    final isDispatchRole = userRoles.any((role) => role.toLowerCase().contains('dispatch'));
    final isBypassRole = userRoles.any((role) => 
      role.toLowerCase().contains('qc_manager') ||
      role.toLowerCase().contains('dispatch_executive') ||
      role.toLowerCase().contains('dispatch executive') ||
      role.toLowerCase().contains('flyingsquad') ||
      role.toLowerCase().contains('flying squad') ||
      role.toLowerCase().contains('admin') ||
      role.toLowerCase().contains('planner')
    );
    
    print('🔍 [Dispatch Counter] userRoles=$userRoles, isDispatchRole=$isDispatchRole, isBypassRole=$isBypassRole');
    print('🔍 [Dispatch Counter] _jobPlannings count: ${_jobPlannings?.length ?? 0}');
    
    if (_jobPlannings != null && _jobPlannings!.isNotEmpty) {
      if (isDispatchRole || isBypassRole) {
        // Apply same filtering logic as WorkScreen
        for (final planning in _jobPlannings!) {
          if (planning['steps'] is! List) continue;
          final steps = planning['steps'] as List;
          bool shouldCount = false;
          
          for (int stepIndex = 0; stepIndex < steps.length; stepIndex++) {
            final step = steps[stepIndex];
            if (step is! Map<String, dynamic>) continue;
            
            final stepName = step['stepName']?.toString().toLowerCase() ?? '';
            final stepStatus = step['status']?.toString().toLowerCase();
            
            // Check for Dispatch step
            if (stepName == 'dispatchprocess' || stepName == 'dispatch') {
              final machineDetails = step['machineDetails'] as List<dynamic>?;
              bool hasMachines = false;
              if (machineDetails != null && machineDetails.isNotEmpty) {
                for (final md in machineDetails) {
                  if (md is Map<String, dynamic>) {
                    final machineId = md['id']?.toString();
                    final machineCode = md['machineCode']?.toString();
                    if ((machineId != null && machineId.trim().isNotEmpty && machineId.toLowerCase() != 'not assigned') ||
                        (machineCode != null && machineCode.trim().isNotEmpty && machineCode.toLowerCase() != 'not assigned')) {
                      hasMachines = true;
                      break;
                    }
                  }
                }
              }
              
              // For non-machine steps (Dispatch has no machines)
              if (!hasMachines) {
                // Hide if Dispatch is completed
                if (stepStatus == 'stop' || stepStatus == 'stopped' || stepStatus == 'completed' || stepStatus == 'accept') {
                  shouldCount = false;
                  break;
                }
                
                // Only show if previous step (Quality) is ready
                if (stepIndex > 0 && steps[stepIndex - 1] is Map<String, dynamic>) {
                  final previousStep = steps[stepIndex - 1] as Map<String, dynamic>;
                  final prevStatus = previousStep['status']?.toString().toLowerCase() ?? '';
                  // Previous step should be at least started (not 'planned')
                  if (prevStatus == 'planned') {
                    shouldCount = false;
                    break;
                  }
                }
                
                // Dispatch is visible
                shouldCount = true;
                print('🔍 [Dispatch Counter] Job ${planning['nrcJobNo']} (plan ${planning['jobPlanId']}) - Dispatch visible, counting');
                break;
              }
            }
          }
          
          if (shouldCount) {
            dispatchJobCount++;
          } else {
            print('🔍 [Dispatch Counter] Job ${planning['nrcJobNo']} (plan ${planning['jobPlanId']}) - NOT counting (shouldCount=false)');
          }
        }
        print('🔍 [Dispatch Counter] Total dispatch jobs counted: $dispatchJobCount');
      } else {
        print('🔍 [Dispatch Counter] User is not Dispatch role and not bypass role, skipping count');
      }
    } else {
      print('🔍 [Dispatch Counter] No job plannings available');
    }
    
    final totalJobs = (isDispatchRole || isBypassRole) ? dispatchJobCount : _totalJobPlanningsCount;
    print('🔍 [Dispatch Counter] Final totalJobs: $totalJobs');
    
    return GestureDetector(
      onTap: () => _navigateToDispatchWork(),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.orange.shade100,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.local_shipping,
                    color: Colors.orange.shade700,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dispatch',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'All Jobs Access',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '$totalJobs',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: totalJobs == 0 ? Colors.grey[600] : Colors.orange.shade700,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    totalJobs == 1 ? 'job' : 'jobs',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkInsights() {
    final entries = [
      {'label': 'In Progress', 'count': inProgress, 'color': Colors.orange},
      {'label': 'Completed', 'count': completedOrders, 'color': Colors.green},
      {'label': 'Not Started', 'count': _notStarted, 'color': Colors.grey},
    ].where((e) => (e['count'] as int) > 0).toList();

    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Work Insights',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('No data to display', style: TextStyle(color: Colors.grey[600])),
              ),
            )
          else ...[
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 36,
                  sections: entries
                      .map(
                        (e) => PieChartSectionData(
                          color: e['color'] as Color,
                          value: (e['count'] as int).toDouble(),
                          title: (e['count'] as int).toString(),
                          titleStyle: const TextStyle(
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
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: entries
                  .map(
                    (e) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: e['color'] as Color, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text('${e['label']}: ${e['count']}', style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600)),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOverviewCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }




  @override
  void dispose() {
    // Cancel any ongoing operations to prevent setState calls after dispose
    _jobApi = null;
    super.dispose();
  }
}