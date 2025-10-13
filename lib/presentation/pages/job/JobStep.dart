import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nrc/constants/colors.dart';
import 'package:nrc/core/services/dio_service.dart';
import 'package:nrc/presentation/pages/job/work_action_form.dart';
import 'package:nrc/presentation/pages/job/work_form.dart';
import 'package:nrc/presentation/pages/process/DialogManager.dart';
import '../../../data/datasources/job_api.dart';
import '../../../data/models/Job.dart';
import '../../../data/models/WorkStepAssignment.dart';
import '../../../data/models/job_step_models.dart';
import '../../../utils/field_editability.dart';
import '../../routes/UserRoleManager.dart';
import '../process/JobApiService.dart';
import '../process/JobTimelineUI.dart';
import '../process/StepDataManager.dart';
import '../process/StepItemWidget.dart';
import '../process/ExpandableStepCardWidget.dart';
import '../process/StepProgressManager.dart';
import '../process/RevolutionaryStepStatusManager.dart';
import '../process/RevolutionaryStepTapHandler.dart';
import '../process/RevolutionaryStepItemWidget.dart';

class JobTimelinePage extends StatefulWidget {
  final String? jobNumber;
  final List<dynamic>? assignedSteps;

  const JobTimelinePage({super.key, this.jobNumber, this.assignedSteps});

  @override
  State<JobTimelinePage> createState() => _JobTimelinePageState();
}

class _JobTimelinePageState extends State<JobTimelinePage> {
  List<StepData> steps = [];
  List<int> currentActiveSteps = [];
  dynamic jobDetails;
  Map<String, dynamic>? _jobData;
  bool _jobLoading = false;
  String? _jobError;
  late final JobApiService _apiService;
  List<String> _userRoles = [];
  String _primaryRole = '';
  bool _isInitializing = true;
  String _loadingMessage = 'Initializing...';
  List<String> _missingStepTitles = [];
  
  Map<int, Map<String, dynamic>?> _stepDetailsCache = {};
  Map<String, Map<String, dynamic>?> _individualStepDetailsCache = {};
  // Freeze progression when a step is actively started
  int? _startedStepIndex;
  int? _startedStepNoFromPlanning;
  StepType? _startedStepType;
  bool _freezeAtStarted = false;
  Map<String, dynamic>? _paperStoreCache;
  
  // User machine access for smart filtering
  List<String> _userMachineIds = [];
  
  // State synchronization tracking
  bool _isValidatingState = false;
  DateTime? _lastStateValidation;
  Map<String, dynamic>? _lastKnownBackendState;
  bool _isDataLoaded = false;

  @override
  void initState() {
    super.initState();
    _apiService = JobApiService(JobApi(DioService.instance));
    _loadUserRoleAndInitializeSteps();
    
    // Removed auto-refresh to prevent constant UI updates
    // Users can use pull-to-refresh or manual refresh button instead
  }

  Future<void> _loadUserRoleAndInitializeSteps() async {
    if (!mounted) return;
    setState(() {
      _isInitializing = true;
      _loadingMessage = 'Loading user role...';
    });

    // Load user roles from UserRoleManager
    final userRoleManager = UserRoleManager();
    await userRoleManager.loadUserRole();
    _userRoles = userRoleManager.userRoles;
    _primaryRole = userRoleManager.userRole ?? '';

    // Load user machine access
    await _loadUserMachineAccess();

    print('User Roles in JobTimelinePage: $_userRoles');
    print('Primary Role: $_primaryRole');
    print('User Machine IDs: $_userMachineIds');

    if (!mounted) return;
    setState(() {
      _loadingMessage = 'Initializing steps...';
    });

    _initializeSteps();
    await _initializeStepsWithBackendSync();
    
    // 🚀 REVOLUTIONARY: Update PaperStore, Quality, Dispatch statuses from backend
    await _updateAllStepStatusesFromBackend();

    if (!mounted) return;
    setState(() {
      _isInitializing = false;
    });
  }

  /// Load user machine access for smart filtering
  Future<void> _loadUserMachineAccess() async {
    print('🚀 START: Loading user machine access...');
    
    try {
      print('🚀 STEP 1: Getting raw machines...');
      final machines = await _apiService.getMachinesRaw();
      print('🚀 STEP 1 COMPLETE: Got ${machines.length} raw machines');
      
      print('🚀 STEP 2: Getting user machines...');
      final userMachines = await _apiService.getUserMachines();
      print('🚀 STEP 2 COMPLETE: Got ${userMachines.length} user machines');
      
      print('🔍 DEBUG getUserMachines raw data: $userMachines');
      
      _userMachineIds = userMachines
          .where((um) => um['isActive'] == true)
          .map((um) => um['machineId']?.toString())
          .whereType<String>()
          .toList();
          
      print('✅ FINAL: Loaded ${_userMachineIds.length} user machine IDs: $_userMachineIds');
    } catch (e, stackTrace) {
      print('❌ CATCH BLOCK: Error loading user machine access');
      print('❌ Error: $e');
      print('❌ Stack trace: $stackTrace');
      _userMachineIds = [];
    }
    
    print('🚀 END: User machine access loading complete. Final list: $_userMachineIds');
  }

  /// Get real-time machine statuses from JobStepMachine table for this specific job and step
  Future<Map<String, String>> _getMachineStatuses(StepData step, List<String> machineIds) async {
    try {
      final statuses = <String, String>{};
      final stepNo = StepDataManager.getStepNumber(step.type);
      
      // Fetch machine statuses from the backend's getAvailableMachines API
      // This returns the JobStepMachine statuses for this specific job and step
      try {
        final response = await _apiService.getAvailableMachines(widget.jobNumber!, stepNo);
        
        if (response != null && response['machines'] is List) {
          final machines = response['machines'] as List;
          for (final machine in machines) {
            final machineId = machine['machineId']?.toString();
            final status = machine['status']?.toString() ?? 'available';
            if (machineId != null) {
              statuses[machineId] = status;
              print('🔍 Machine $machineId status for ${step.title}: $status');
            }
          }
        }
      } catch (e) {
        print('❌ Error fetching JobStepMachine statuses: $e');
        // Default all to available if error
        for (final machineId in machineIds) {
          statuses[machineId] = 'available';
        }
      }
      
      return statuses;
    } catch (e) {
      print('❌ Error getting machine statuses: $e');
      return {};
    }
  }

  /// Get machine status from status map
  String _getMachineStatusFromMap(String? machineId, Map<String, String> statuses) {
    if (machineId == null) return 'available';
    return statuses[machineId] ?? 'available';
  }

  /// Check if a step type requires machine selection
  bool _isMachineRequiredStep(StepType stepType) {
    switch (stepType) {
      case StepType.printing:
      case StepType.corrugation:
      case StepType.fluteLamination:
      case StepType.punching:
      case StepType.flapPasting:
        return true; // These steps require machines
      case StepType.paperStore:
      case StepType.qc:
      case StepType.dispatch:
        return false; // These steps do NOT require machines
      default:
        return false; // Default to no machine required
    }
  }

  /// Check machine assignment and start work
  void _checkMachineAssignmentAndStart(StepData step) {
    print('DEBUG: Checking machine assignment for ${step.title}');
    
    if (_isMachineRequiredStep(step.type)) {
      // For machine-required steps, check if machines are assigned
      final stepNo = StepDataManager.getStepNumber(step.type);
      final stepDetails = _stepDetailsCache[stepNo];
      
      if (stepDetails != null && stepDetails['machineDetails'] != null) {
        final machineDetails = stepDetails['machineDetails'];
        if (machineDetails is List && machineDetails.isNotEmpty) {
          // Machines are assigned, show smart machine selection
          _showSmartMachineSelection(step);
        } else {
          // No machines assigned
          DialogManager.showErrorMessage(
            context,
            'No machines assigned for ${step.title}. Please contact your administrator.'
          );
        }
      } else {
        // No step details available
        DialogManager.showErrorMessage(
          context,
          'Step details not available for ${step.title}. Please try again.'
        );
      }
    } else {
      // For non-machine steps, start work directly
      print('DEBUG: ${step.title} does not require machines, starting work directly');
      _startWorkDirectly(step);
    }
  }

  /// Start work directly for non-machine steps
  void _startWorkDirectly(StepData step) {
    print('DEBUG: Starting work directly for ${step.title}');
    _showNonMachineWorkDialog(step);
  }

  /// 🎨 STUNNING: Show work form for non-machine steps (PaperStore, Quality, Dispatch)
  Future<void> _showNonMachineWorkDialog(StepData step) async {
    print('🎨 Showing stunning work form for ${step.title}');
    
    try {
      // Fetch step details to check current status
      final stepNo = StepDataManager.getStepNumber(step.type);
      final stepDetails = await _apiService.getStepDetailsWithEditability(widget.jobNumber!, step.type);
      
      String currentStatus = 'pending';
      Map<String, dynamic>? stepData;
      
      if (stepDetails != null && stepDetails.isNotEmpty) {
        stepData = stepDetails[0].data;
        currentStatus = stepData['status'] ?? 'pending';
      }
      
      print('🎨 Current status for ${step.title}: $currentStatus');
      
      // Show the stunning dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            return Container(
              color: Colors.black.withOpacity(0.6),
              child: Center(
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                  constraints: BoxConstraints(
                    maxWidth: 500,
                    maxHeight: MediaQuery.of(context).size.height * 0.85,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 40,
                        offset: Offset(0, 20),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header with gradient
                      Container(
                        padding: EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.maincolor,
                              AppColors.maincolor.withOpacity(0.8),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(24),
                            topRight: Radius.circular(24),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _getStepIcon(step.type),
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    step.title,
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    widget.jobNumber ?? 'Job',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: Icon(Icons.close, color: Colors.white),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.2),
                                shape: CircleBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Content
                      Flexible(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Status Card
                              Container(
                                padding: EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(currentStatus).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _getStatusColor(currentStatus).withOpacity(0.3),
                                    width: 2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(currentStatus),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: _getStatusColor(currentStatus).withOpacity(0.4),
                                            blurRadius: 8,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: 16),
                                    Icon(
                                      _getStatusIcon(currentStatus),
                                      color: _getStatusColor(currentStatus),
                                      size: 24,
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Current Status',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            _getStatusText(currentStatus),
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: _getStatusColor(currentStatus),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              SizedBox(height: 24),
                              
                              // Info Card
                              Container(
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.blue[200]!),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline, color: Colors.blue[700], size: 24),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _getStepDescription(step.type),
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.blue[900],
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              SizedBox(height: 24),
                              
                              // Action Buttons
                              _buildActionButtons(
                                context,
                                dialogContext,
                                step,
                                currentStatus,
                                setDialogState,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    } catch (e) {
      print('❌ Error showing work form: $e');
      DialogManager.showErrorMessage(context, 'Failed to load step details. Please try again.');
    }
  }

  /// Get icon for step type
  IconData _getStepIcon(StepType stepType) {
    switch (stepType) {
      case StepType.paperStore:
        return Icons.inventory_2;
      case StepType.qc:
        return Icons.verified_user;
      case StepType.dispatch:
        return Icons.local_shipping;
      default:
        return Icons.work;
    }
  }

  /// Get step description
  String _getStepDescription(StepType stepType) {
    switch (stepType) {
      case StepType.paperStore:
        return 'Manage paper inventory and prepare materials for the job';
      case StepType.qc:
        return 'Perform quality control checks and ensure product meets standards';
      case StepType.dispatch:
        return 'Prepare and dispatch the finished product to the customer';
      default:
        return 'Complete this step to proceed';
    }
  }

  /// Get status color
  Color _getStatusColor(String status) {
    switch (status) {
      case 'in_progress':
        return Colors.blue;
      case 'hold':
        return Colors.orange;
      case 'stop':
        return Colors.grey;
      case 'accept':
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  /// Get status icon
  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'in_progress':
        return Icons.play_circle_filled;
      case 'hold':
        return Icons.pause_circle_filled;
      case 'stop':
        return Icons.stop_circle;
      case 'accept':
      case 'completed':
        return Icons.check_circle;
      default:
        return Icons.circle_outlined;
    }
  }

  /// Get status text
  String _getStatusText(String status) {
    switch (status) {
      case 'in_progress':
        return 'In Progress';
      case 'hold':
        return 'On Hold';
      case 'stop':
        return 'Stopped';
      case 'accept':
        return 'Accepted';
      case 'completed':
        return 'Completed';
      default:
        return 'Pending';
    }
  }

  /// Build action buttons based on current status
  Widget _buildActionButtons(
    BuildContext context,
    BuildContext dialogContext,
    StepData step,
    String currentStatus,
    StateSetter setDialogState,
  ) {
    return Column(
      children: [
        // Start Button
        if (currentStatus == 'pending' || currentStatus == 'stop')
          _buildStunningButton(
            context: context,
            label: 'Start Work',
            icon: Icons.play_arrow,
            color: Colors.green,
            onPressed: () async {
              await _startNonMachineStep(step, dialogContext, setDialogState);
            },
          ),
        
        // Resume Button
        if (currentStatus == 'hold')
          _buildStunningButton(
            context: context,
            label: 'Resume Work',
            icon: Icons.play_arrow,
            color: Colors.green,
            onPressed: () async {
              await _resumeNonMachineStep(step, dialogContext, setDialogState);
            },
          ),
        
        SizedBox(height: 12),
        
        // Hold Button
        if (currentStatus == 'in_progress')
          _buildStunningButton(
            context: context,
            label: 'Hold Work',
            icon: Icons.pause,
            color: Colors.orange,
            onPressed: () async {
              await _holdNonMachineStep(step, dialogContext, setDialogState);
            },
          ),
        
        SizedBox(height: 12),
        
        // Complete Button
        if (currentStatus == 'in_progress')
          _buildStunningButton(
            context: context,
            label: 'Complete Work',
            icon: Icons.check_circle,
            color: AppColors.maincolor,
            onPressed: () async {
              Navigator.pop(dialogContext);
              // Navigate to work form for completion
              await _openWorkActionForm(step);
            },
          ),
        
        SizedBox(height: 12),
        
        // View Details Button (always visible)
        _buildStunningButton(
          context: context,
          label: 'View Details',
          icon: Icons.description,
          color: Colors.blue,
          isOutlined: true,
          onPressed: () async {
            Navigator.pop(dialogContext);
            await _openWorkActionForm(step);
          },
        ),
      ],
    );
  }

  /// Build stunning button
  Widget _buildStunningButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    bool isOutlined = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          decoration: BoxDecoration(
            color: isOutlined ? Colors.white : color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color,
              width: 2,
            ),
            boxShadow: isOutlined ? [] : [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isOutlined ? color : Colors.white,
                size: 24,
              ),
              SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isOutlined ? color : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Start non-machine step
  Future<void> _startNonMachineStep(StepData step, BuildContext dialogContext, StateSetter setDialogState) async {
    try {
      print('🚀 Starting ${step.title}...');
      
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.maincolor),
                ),
                SizedBox(height: 16),
                Text('Starting work...', style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ),
      );
      
      String endpoint = '';
      switch (step.type) {
        case StepType.paperStore:
          endpoint = '/paper-store/${widget.jobNumber}/start';
          break;
        case StepType.qc:
          endpoint = '/quality-dept/${widget.jobNumber}/start';
          break;
        case StepType.dispatch:
          endpoint = '/dispatch-process/${widget.jobNumber}/start';
          break;
        default:
          throw Exception('Invalid step type');
      }
      
      final response = await _apiService.startWorkWithoutMachine(endpoint);
      
      if (mounted) Navigator.pop(context); // Close loading
      
      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Work started successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        
        // Refresh and update dialog
        await _initializeAndLoadData();
        Navigator.pop(dialogContext); // Close dialog
        
      } else {
        DialogManager.showErrorMessage(context, response['message'] ?? 'Failed to start work');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading
      print('❌ Error starting work: $e');
      DialogManager.showErrorMessage(context, 'Failed to start work. Please try again.');
    }
  }

  /// Hold non-machine step
  Future<void> _holdNonMachineStep(StepData step, BuildContext dialogContext, StateSetter setDialogState) async {
    try {
      print('⏸️ Holding ${step.title}...');
      
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                ),
                SizedBox(height: 16),
                Text('Putting work on hold...', style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ),
      );
      
      String endpoint = '';
      switch (step.type) {
        case StepType.paperStore:
          endpoint = '/paper-store/${widget.jobNumber}/hold';
          break;
        case StepType.qc:
          endpoint = '/quality-dept/${widget.jobNumber}/hold';
          break;
        case StepType.dispatch:
          endpoint = '/dispatch-process/${widget.jobNumber}/hold';
          break;
        default:
          throw Exception('Invalid step type');
      }
      
      final response = await _apiService.holdWork(endpoint, {'holdRemark': 'Work paused by user'});
      
      if (mounted) Navigator.pop(context); // Close loading
      
      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.pause_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Work put on hold successfully!'),
              ],
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        
        // Refresh and update dialog
        await _initializeAndLoadData();
        Navigator.pop(dialogContext); // Close dialog
        
      } else {
        DialogManager.showErrorMessage(context, response['message'] ?? 'Failed to hold work');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading
      print('❌ Error holding work: $e');
      DialogManager.showErrorMessage(context, 'Failed to hold work. Please try again.');
    }
  }

  /// Resume non-machine step
  Future<void> _resumeNonMachineStep(StepData step, BuildContext dialogContext, StateSetter setDialogState) async {
    try {
      print('▶️ Resuming ${step.title}...');
      
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                ),
                SizedBox(height: 16),
                Text('Resuming work...', style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ),
      );
      
      String endpoint = '';
      switch (step.type) {
        case StepType.paperStore:
          endpoint = '/paper-store/${widget.jobNumber}/resume';
          break;
        case StepType.qc:
          endpoint = '/quality-dept/${widget.jobNumber}/resume';
          break;
        case StepType.dispatch:
          endpoint = '/dispatch-process/${widget.jobNumber}/resume';
          break;
        default:
          throw Exception('Invalid step type');
      }
      
      final response = await _apiService.resumeWork(endpoint);
      
      if (mounted) Navigator.pop(context); // Close loading
      
      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.play_arrow, color: Colors.white),
                SizedBox(width: 12),
                Text('Work resumed successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        
        // Refresh and update dialog
        await _initializeAndLoadData();
        Navigator.pop(dialogContext); // Close dialog
        
      } else {
        DialogManager.showErrorMessage(context, response['message'] ?? 'Failed to resume work');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading
      print('❌ Error resuming work: $e');
      DialogManager.showErrorMessage(context, 'Failed to resume work. Please try again.');
    }
  }

  /// Open work action form (alias for existing _showWorkForm method)
  Future<void> _openWorkActionForm(StepData step) async {
    // Call the existing _showWorkForm method that handles all the form logic
    _showWorkForm(step);
  }

  /// 🚀 REVOLUTIONARY: Initialize and load all data with bulletproof status management
  Future<void> _initializeAndLoadData() async {
    print('🚀 REVOLUTIONARY: Refreshing with bulletproof status management');
    
    // 🎯 Clear ALL caches to force fresh data from backend
    RevolutionaryStepStatusManager.clearCache(widget.jobNumber!);
    _stepDetailsCache.clear();
    _individualStepDetailsCache.clear();
    _paperStoreCache = null;
    print('🚀 Cleared all caches for job: ${widget.jobNumber}');
    
    // Reload the job details and refresh the timeline
    await _initializeStepsWithBackendSync();
    
    // 🎯 REVOLUTIONARY: Update all step statuses with REAL backend data
    await _updateAllStepStatusesFromBackend();
    
    // Force UI update
    if (mounted) {
      setState(() {
        _isDataLoaded = true;
      });
      print('✅ UI refreshed successfully');
    }
  }
  
  /// 🚀 REVOLUTIONARY: Update step statuses from backend (ONLY PaperStore, Quality, Dispatch!)
  Future<void> _updateAllStepStatusesFromBackend() async {
    print('🚀 REVOLUTIONARY: Updating PaperStore, Quality, and Dispatch statuses ONLY');
    
    for (int i = 0; i < steps.length; i++) {
      final step = steps[i];
      
      // 🎯 ONLY update PaperStore, Quality, and Dispatch steps - DON'T TOUCH OTHERS!
      if (step.type == StepType.paperStore || 
          step.type == StepType.qc || 
          step.type == StepType.dispatch) {
        try {
          print('🚀 Fetching real status for ${step.title}...');
          
          // Fetch step details from backend
          List<StepDataWithEditability> stepDetailsList;
          switch (step.type) {
            case StepType.paperStore:
              stepDetailsList = await _apiService.getPaperStoreStepByJobWithEditability(widget.jobNumber!);
              break;
            case StepType.qc:
              stepDetailsList = await _apiService.getStepDetailsWithEditability(widget.jobNumber!, StepType.qc);
              break;
            case StepType.dispatch:
              stepDetailsList = await _apiService.getStepDetailsWithEditability(widget.jobNumber!, StepType.dispatch);
              break;
            default:
              continue;
          }
          
          if (stepDetailsList.isNotEmpty) {
            final stepData = stepDetailsList.first.data;
            final statusString = stepData['status']?.toString().toLowerCase() ?? 'pending';
            
            print('🚀 Backend status for ${step.title}: $statusString');
            
            // Convert string to StepStatus
            StepStatus realStatus;
            switch (statusString) {
              case 'start':
              case 'started':
                realStatus = StepStatus.started;
                break;
              case 'in_progress':
              case 'inprogress':
                realStatus = StepStatus.inProgress;
                break;
              case 'hold':
              case 'paused':
                realStatus = StepStatus.hold;
                break;
              case 'stop':
              case 'completed':
              case 'complete':
              case 'accept':  // ✅ Paper Store uses "accept" for completed status
                realStatus = StepStatus.completed;
                break;
              default:
                realStatus = StepStatus.pending;
            }
            
            print('🚀 REAL STATUS for ${step.title}: $realStatus');
            
            // Update the step status
            if (mounted) {
              setState(() {
                step.status = realStatus;
              });
            }
          } else {
            print('❌ No data found for ${step.title}');
          }
        } catch (e) {
          print('❌ Error updating status for ${step.title}: $e');
        }
      } else {
        print('🎯 Skipping ${step.title} - keeping existing flow');
      }
    }
  }

  void _initializeSteps() {
    setState(() {
      steps = StepDataManager.initializeSteps(widget.assignedSteps, userRole: _primaryRole, userRoles: _userRoles);
      if (steps.length > 1) {
        currentActiveSteps = [1]; // Initialize with first step
      }
    });
    print('Initialized ${steps.length} steps for user roles: $_userRoles');

    // Debug: Print all steps with their types
    for (int i = 0; i < steps.length; i++) {
      print('DEBUG: Step $i: ${steps[i].title} (${steps[i].type})');
    }

    // Compute and report missing standard steps for visibility
    _computeMissingSteps();
  }

  void _computeMissingSteps() {
    final presentTypes = steps.map((s) => s.type).toSet();
    final expectedTypes = <StepType>{
      StepType.paperStore,
      StepType.printing,
      StepType.corrugation,
      StepType.fluteLamination,
      StepType.punching,
      StepType.flapPasting,
      StepType.qc,
      StepType.dispatch,
    };
    final missing = expectedTypes.difference(presentTypes);
    final displayFor = (StepType t) {
      switch (t) {
        case StepType.paperStore:
          return 'Paper Store';
        case StepType.printing:
          return 'Printing';
        case StepType.corrugation:
          return 'Corrugation';
        case StepType.fluteLamination:
          return 'Flute Lamination';
        case StepType.punching:
          return 'Punching';
        case StepType.flapPasting:
          return 'Flap Pasting';
        case StepType.qc:
          return 'Quality Control';
        case StepType.dispatch:
          return 'Dispatch';
        default:
          return '';
      }
    };
    setState(() {
      _missingStepTitles = missing.map(displayFor).where((e) => e.isNotEmpty).toList();
    });

    if (_missingStepTitles.isNotEmpty) {
      print('WARNING: Missing steps for job ${widget.jobNumber}: ${_missingStepTitles.join(', ')}');
    }
    
    // Check if user has no steps available for their role
    if (steps.length <= 1) { // Only "Job Assigned" step
      print('No steps available for user roles: $_userRoles');
    }
  }

  /// Optimized backend sync that batches API calls and uses caching
  Future<void> _initializeStepsWithBackendSync() async {
    if (widget.jobNumber == null) return;

    print('Starting optimized backend sync for ${steps.length} steps...');

    // Check if user has any steps available for their roles
    if (steps.isEmpty || steps.length <= 1) {
      print('No steps available for user roles: $_userRoles');
      return;
    }

    setState(() {
      _loadingMessage = 'Loading step data...';
    });

    try {
      // Batch load all step details in parallel
      await _batchLoadStepDetails();
      
      setState(() {
        _loadingMessage = 'Processing step statuses...';
      });

      await _processAllStepsWithCachedData();
      
      setState(() {
        _loadingMessage = 'Finalizing...';
      });

      // Determine current active steps
      _determineCurrentActiveSteps();

      // Check for parallel steps
      _activateParallelSteps();

      setState(() {
        _isDataLoaded = true;
      });

      print('Optimized backend sync completed. Current active steps: $currentActiveSteps');
    } catch (e) {
      print('Error during optimized backend sync: $e');
      // Fallback to individual sync if batch loading fails
      await _fallbackIndividualSync();
    }
  }

  Future<void> _batchLoadStepDetails() async {
    if (widget.jobNumber == null) return;

    // Try batch fetch of all planning steps first
    try {
      final planning = await _apiService.getJobPlanningStepsByNrcJobNo(widget.jobNumber!);
      if (planning != null && planning is Map && planning['steps'] is List) {
        final List stepsList = planning['steps'];
        for (final s in stepsList) {
          if (s is Map && s.containsKey('stepNo')) {
            final int? stepNo = s['stepNo'] is int
                ? s['stepNo']
                : int.tryParse(s['stepNo']?.toString() ?? '');
            if (stepNo != null) {
              _stepDetailsCache[stepNo] = Map<String, dynamic>.from(s);
              print('Loaded planning step details (batched) for step $stepNo: ${s['stepName']} = ${s['status']}');
              
              // Special debug for Flute Lamination
              if (s['stepName'] == 'FluteLaminateBoardConversion') {
                print('🔍 FLUTE LAMINATION CACHING DEBUG:');
                print('  - stepNo: $stepNo');
                print('  - stepName: ${s['stepName']}');
                print('  - status: ${s['status']}');
                print('  - cached data: ${_stepDetailsCache[stepNo]}');
              }
              
              if (_startedStepNoFromPlanning == null &&
                  (s['status']?.toString() == 'start')) {
                _startedStepNoFromPlanning = stepNo;
                print('DEBUG: Found started step from planning: $stepNo (${s['stepName']})');
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error fetching batched planning steps: $e');
    }

    List<Future<void>> batchFutures = [];

    // Load remaining step details in parallel, but skip future steps once a started step exists
    for (int i = 1; i < steps.length; i++) {
      final step = steps[i];
      final stepNo = StepDataManager.getStepNumber(step.type);

      if (_startedStepNoFromPlanning != null && stepNo > _startedStepNoFromPlanning!) {
        continue;
      }
      if (!_stepDetailsCache.containsKey(stepNo)) {
        batchFutures.add(_loadStepDetailsWithCache(stepNo, step.type));
      }
      
      // Only load individual step details for steps that are in "start" status (for hold/resume functionality)
      // We'll check the status after loading planning details
    }

    if (steps.any((step) => step.type == StepType.paperStore)) {
      batchFutures.add(_loadPaperStoreWithCache());
      // Also load planning step details for PaperStore
      final paperStoreStep = steps.firstWhere((step) => step.type == StepType.paperStore);
      final paperStoreStepNo = StepDataManager.getStepNumber(paperStoreStep.type);
      if (!_stepDetailsCache.containsKey(paperStoreStepNo)) {
        batchFutures.add(_loadStepDetailsWithCache(paperStoreStepNo, paperStoreStep.type));
      }
    }

    await Future.wait(batchFutures);
    
    // Load individual step details for all steps BEFORE processing (for hold/resume functionality)
    await _loadIndividualStepDetailsForActiveSteps();
  }
  
  /// Load individual step details for all steps (for hold/resume functionality)
  Future<void> _loadIndividualStepDetailsForActiveSteps() async {
    List<Future<void>> individualFutures = [];
    
    for (int i = 1; i < steps.length; i++) {
      final step = steps[i];
      final stepNo = StepDataManager.getStepNumber(step.type);
      
      // Load individual step details for all steps to ensure hold/resume status is properly loaded
      print('Loading individual step details for ${step.title}');
      individualFutures.add(_loadIndividualStepDetailsWithCache(stepNo, step.type));
    }
    
    // Load individual step details immediately in parallel
    await Future.wait(individualFutures);
    print('Loaded individual step details for ${individualFutures.length} steps');
  }

  /// Load step details with caching
  Future<void> _loadStepDetailsWithCache(int stepNo, StepType stepType) async {
    try {
      // Check cache first
      if (_stepDetailsCache.containsKey(stepNo)) {
        print('Using cached step details for step $stepNo');
        return;
      }

      // Load from API
      final stepDetails = await _apiService.getJobPlanningStepDetails(widget.jobNumber!, stepNo);
      _stepDetailsCache[stepNo] = stepDetails;
      
      print('Loaded and cached step details for step $stepNo');
    } catch (e) {
      print('Error loading step details for step $stepNo: $e');
      _stepDetailsCache[stepNo] = null;
    }
  }

  /// Load individual step details with caching (for hold/resume functionality)
  Future<void> _loadIndividualStepDetailsWithCache(int stepNo, StepType stepType) async {
    try {
      final cacheKey = '${widget.jobNumber}_${stepType.name}_individual';
      
      // Check cache first
      if (_individualStepDetailsCache.containsKey(cacheKey)) {
        print('Using cached individual step details for $stepType');
        return;
      }

      print('Loading individual step details for $stepType (stepNo: $stepNo)');

      // Load individual step details based on step type
      List<StepDataWithEditability> stepDetailsList;
      switch (stepType) {
        case StepType.paperStore:
          stepDetailsList = await _apiService.getPaperStoreStepByJobWithEditability(widget.jobNumber!);
          break;
        case StepType.printing:
          stepDetailsList = await _apiService.getStepDetailsWithEditability(widget.jobNumber!, StepType.printing);
          break;
        case StepType.corrugation:
          stepDetailsList = await _apiService.getStepDetailsWithEditability(widget.jobNumber!, StepType.corrugation);
          break;
        case StepType.fluteLamination:
          stepDetailsList = await _apiService.getStepDetailsWithEditability(widget.jobNumber!, StepType.fluteLamination);
          break;
        case StepType.punching:
          stepDetailsList = await _apiService.getStepDetailsWithEditability(widget.jobNumber!, StepType.punching);
          break;
        case StepType.flapPasting:
          stepDetailsList = await _apiService.getStepDetailsWithEditability(widget.jobNumber!, StepType.flapPasting);
          break;
        case StepType.qc:
          stepDetailsList = await _apiService.getStepDetailsWithEditability(widget.jobNumber!, StepType.qc);
          break;
        case StepType.dispatch:
          stepDetailsList = await _apiService.getStepDetailsWithEditability(widget.jobNumber!, StepType.dispatch);
          break;
        default:
          print('Unknown step type for individual details: $stepType');
          return;
      }

      print('Individual step details API response for $stepType: ${stepDetailsList.length} items');

      // Get the first step details if available
      Map<String, dynamic>? stepDetails;
      if (stepDetailsList.isNotEmpty) {
        stepDetails = stepDetailsList.first.data;
        print('Individual step details data: $stepDetails');
      } else {
        print('No individual step details found for $stepType');
      }

      if (stepDetails != null) {
        _individualStepDetailsCache[cacheKey] = stepDetails;
        print('Loaded and cached individual step details for $stepType: ${stepDetails['status']}');
      } else {
        print('No step details to cache for $stepType');
        _individualStepDetailsCache[cacheKey] = null;
      }
    } catch (e) {
      print('Error loading individual step details for $stepType: $e');
      _individualStepDetailsCache['${widget.jobNumber}_${stepType.name}_individual'] = null;
    }
  }

  /// Load paper store data with caching
  Future<void> _loadPaperStoreWithCache() async {
    try {
      if (_paperStoreCache != null) {
        print('Using cached paper store data');
        return;
      }

      _paperStoreCache = await _apiService.getPaperStoreStepByJob(widget.jobNumber!);
      print('Loaded and cached paper store data');
    } catch (e) {
      print('Error loading paper store data: $e');
      _paperStoreCache = null;
    }
  }

  /// Process all steps using cached data
  Future<void> _processAllStepsWithCachedData() async {
    for (int i = 1; i < steps.length; i++) {
      final step = steps[i];
      final stepNo = StepDataManager.getStepNumber(step.type);
      
      // Skip if step has form data (already completed)
      if (step.formData.isNotEmpty && step.status == StepStatus.completed) {
        print('Step ${step.title} has form data, preserving completed status');
        continue;
      }

      // Get cached data
      final stepDetails = _stepDetailsCache[stepNo];
      
    // Special debug for Flute Lamination
    if (step.type == StepType.fluteLamination) {
      print('🔍 FLUTE LAMINATION: Processing step ${step.title} (status: ${step.status})');
    }

      // Process step status derived from planning details first (basic start/stop functionality)
      _processStepStatus(step, i, stepDetails);
      
      // Then process individual step status (for hold/resume functionality)
      _processIndividualStepStatus(step, i, stepDetails);
      
      // Debug logging after processing
      if (step.type == StepType.fluteLamination) {
        print('🔍 FLUTE LAMINATION AFTER PROCESSING:');
        print('  - step.status = ${step.status}');
        print('  - stepIndex = $i');
        print('  - currentActiveSteps = $currentActiveSteps');
        print('  - _startedStepIndex = $_startedStepIndex');
        print('  - _freezeAtStarted = $_freezeAtStarted');
      }

      // Don't break here - we need to process all steps to ensure UI is updated
      // The _freezeAtStarted flag is used later in _activateParallelSteps()

      // Special handling for individual step statuses
      if (step.type == StepType.paperStore && _paperStoreCache != null) {
        _processPaperStoreStep(step, i);
      }
    }
  }

  /// Process individual step status from step details (for hold/resume functionality)
  void _processIndividualStepStatus(StepData step, int stepIndex, Map<String, dynamic>? stepDetails) {
    // Get individual step details from cache
    final cacheKey = '${widget.jobNumber}_${step.type.name}_individual';
    final individualStepDetails = _individualStepDetailsCache[cacheKey];
    
    if (individualStepDetails == null || !individualStepDetails.containsKey('status')) {
      return;
    }
    
    final individualStatus = individualStepDetails['status'];
    print('Processing individual step status for ${step.title}: $individualStatus (individual details)');
    
    // Auto-populate missing fields
    _autoPopulateStepFields(individualStepDetails, step.type);
    
    setState(() {
      // Only set internal status for hold/resume, don't change the main step status
      if (individualStatus == 'in_progress') {
        step.internalStatus = 'in_progress'; // Internal status for button logic
        print('Step ${step.title} internal status set to in_progress');
      } else if (individualStatus == 'hold') {
        step.internalStatus = 'hold'; // Internal status for button logic
        print('Step ${step.title} internal status set to hold');
      } else if (individualStatus == 'accept') {
        step.status = StepStatus.completed;
        print('Step ${step.title} marked as COMPLETED (individual status)');
      }
    });
  }

  /// Auto-populate missing fields in step details
  void _autoPopulateStepFields(Map<String, dynamic> stepDetails, StepType stepType) {
    final now = DateTime.now();
    
    // Auto-populate date if null
    if (stepDetails['date'] == null) {
      stepDetails['date'] = now.toIso8601String().split('T')[0]; // YYYY-MM-DD format
      print('Auto-populated date: ${stepDetails['date']}');
    }
    
    // Auto-populate shift if null
    if (stepDetails['shift'] == null) {
      final hour = now.hour;
      if (hour >= 6 && hour < 14) {
        stepDetails['shift'] = 'Morning';
      } else if (hour >= 14 && hour < 22) {
        stepDetails['shift'] = 'Afternoon';
      } else {
        stepDetails['shift'] = 'Night';
      }
      print('Auto-populated shift: ${stepDetails['shift']}');
    }
    
    // Auto-populate operator name if null
    if (stepDetails['oprName'] == null) {
      // Try to get from user context, fallback to a default
      stepDetails['oprName'] = 'NRC005'; // This should come from user context
      print('Auto-populated operator: ${stepDetails['oprName']}');
    }
    
    // Auto-populate machine if null - get from step assignment
    if (stepDetails['machine'] == null) {
      // Get machine from machineDetails in stepDetails
      final machineDetails = stepDetails['machineDetails'];
      if (machineDetails != null && machineDetails is List && machineDetails.isNotEmpty) {
        final machineInfo = machineDetails[0];
        if (machineInfo is Map) {
          stepDetails['machine'] = machineInfo['machineCode'] ?? machineInfo['machineType'] ?? 'Not assigned';
          print('Auto-populated machine: ${stepDetails['machine']}');
        }
      }
    }
  }

  void _processStepStatus(StepData step, int stepIndex, Map<String, dynamic>? stepDetails) {
    dynamic planningStatus;
    
    // Only use planning status from the main job planning API, not from individual step details
    if (stepDetails is Map && stepDetails!.containsKey('status') && stepDetails!['stepName'] != null) {
      // This is from the main planning API (has stepName), use its status
      planningStatus = stepDetails['status'];
    } else {
      // This is from individual step details API, ignore its status
      planningStatus = null;
    }
    
    // Get planning status from main job planning data for all steps if not available from stepDetails
    if (planningStatus == null) {
      if (jobDetails != null) {
        final jobData = jobDetails as List;
        if (jobData.isNotEmpty) {
          final allSteps = jobData[0].allSteps as List;
          final stepName = _getStepNameFromType(step.type);
          final jobStep = allSteps.firstWhere(
            (s) => s['stepName'] == stepName,
            orElse: () => null,
          );
          if (jobStep != null) {
            planningStatus = jobStep['status'];
            print('${step.title} planning status from job data: $planningStatus');
          }
        }
      }
    }
    
    // Debug logging for step status processing
    print('DEBUG: Processing step ${step.title} (${step.type})');
    print('DEBUG: stepDetails = $stepDetails');
    print('DEBUG: planningStatus = $planningStatus');
    print('DEBUG: Current step status = ${step.status}');
    
    // Special debug for Flute Lamination
    if (step.type == StepType.fluteLamination) {
      print('🔍 FLUTE LAMINATION: planningStatus=$planningStatus, currentStatus=${step.status}');
    }

    setState(() {
      // 1. Work Complete: If planning/status is 'stop', mark as completed
      if (planningStatus == 'stop') {
        step.status = StepStatus.completed;
        print('Step ${step.title} marked as WORK COMPLETE (stop detected)');
      }
      // 2. Work Started: If planning/status is 'start'
      else if (planningStatus == 'start') {
        step.status = StepStatus.started;
        if (!currentActiveSteps.contains(stepIndex)) {
          currentActiveSteps.add(stepIndex);
        }
        _startedStepIndex = stepIndex;
        _startedStepType = step.type;
        // If started step is printing or corrugation, allow the other to be active too
        if (step.type == StepType.printing || step.type == StepType.corrugation) {
          final otherType = step.type == StepType.printing ? StepType.corrugation : StepType.printing;
          final otherIndex = steps.indexWhere((s) => s.type == otherType);
          if (otherIndex != -1 && !currentActiveSteps.contains(otherIndex)) {
            currentActiveSteps.add(otherIndex);
          }
          _freezeAtStarted = false; // allow parallel pair
        } else {
          _freezeAtStarted = true;
        }
        print('Step ${step.title} marked as WORK STARTED');
        print('DEBUG: After setState - step.status = ${step.status}');
        print('DEBUG: Set _startedStepIndex = $_startedStepIndex, _startedStepType = $_startedStepType');
      }
      // 3. In Progress: If planning status is 'in_progress'
      else if (planningStatus == 'in_progress') {
        step.status = StepStatus.inProgress;
        if (!currentActiveSteps.contains(stepIndex)) {
          currentActiveSteps.add(stepIndex);
        }
        print('Step ${step.title} marked as IN PROGRESS');
      }
      // 4. Hold: If planning status is 'hold'
      else if (planningStatus == 'hold') {
        step.status = StepStatus.hold;
        if (!currentActiveSteps.contains(stepIndex)) {
          currentActiveSteps.add(stepIndex);
        }
        print('Step ${step.title} marked as HOLD');
      }
      // 5. Pending: If planning status is 'planned'
      else if (planningStatus == 'planned') {
        step.status = StepStatus.pending;
        print('Step ${step.title} marked as PENDING (planned)');
        
        // For new jobs where all steps are planned, allow multiple steps to be active
        // Check if this is a new job (no steps are started or completed)
        bool isNewJob = !steps.any((s) => s.status == StepStatus.started || s.status == StepStatus.completed);
        
        if (isNewJob) {
          // For new jobs, activate all steps that the user has access to
          if (!currentActiveSteps.contains(stepIndex)) {
            currentActiveSteps.add(stepIndex);
          }
          print('Forcing step ${step.title} to be active (new job - all steps planned)');
        } else {
          // For existing jobs, check if all previous steps are completed
          bool allPreviousCompleted = true;
          for (int j = 1; j < stepIndex; j++) {
            if (steps[j].status != StepStatus.completed) {
              allPreviousCompleted = false;
              break;
            }
          }
          if (allPreviousCompleted) {
            if (!currentActiveSteps.contains(stepIndex)) {
              currentActiveSteps.add(stepIndex);
            }
            print('Forcing step ${step.title} to be active due to planned status');
          }
        }
      }
      // 4. Fallback: Pending (but preserve completed status if step has form data)
      else {
        if (step.formData.isEmpty) {
          step.status = StepStatus.pending;
          print('Step ${step.title} marked as PENDING (fallback)');
        } else {
          step.status = StepStatus.completed;
          print('Step ${step.title} preserved as COMPLETED (has form data)');
        }
      }
    });
  }

  /// Process Paper Store step using cached data
  void _processPaperStoreStep(StepData step, int stepIndex) {
    // Don't override the status - let the main planning status take precedence
    // The paper store cache is only used for form data, not status
    if (_paperStoreCache != null) {
      // Only update form data if needed, but don't change status
      print('Paper store cache available, but not overriding status. Current status: ${step.status}');
    }
  }

  /// Activate parallel steps if needed
  void _activateParallelSteps() {
    if (_freezeAtStarted) {
      // Do not activate further/parallel steps while a step is actively started
      return;
    }
    // If started step is printing/corrugation, we already added the pair; no other parallel activation
    if (_startedStepType == StepType.printing || _startedStepType == StepType.corrugation) {
      return;
    }
    for (int i = 0; i < currentActiveSteps.length; i++) {
      final activeStepIndex = currentActiveSteps[i];
      if (activeStepIndex < steps.length) {
        final activeStep = steps[activeStepIndex];
        if (StepProgressManager.canRunInParallel(activeStep.type)) {
          final parallelStepTypes = StepProgressManager.getParallelSteps(activeStep.type);
          for (final parallelStepType in parallelStepTypes) {
            final parallelStepIndex = steps.indexWhere((s) => s.type == parallelStepType);
            if (parallelStepIndex != -1 && StepProgressManager.shouldActivateStep(steps, parallelStepIndex)) {
              if (!currentActiveSteps.contains(parallelStepIndex)) {
                currentActiveSteps.add(parallelStepIndex);
                print('Activated parallel step: ${steps[parallelStepIndex].title}');
              }
              }
            }
          }
        }
      }
    }

  /// Fallback to individual sync if batch loading fails
  Future<void> _fallbackIndividualSync() async {
    print('Falling back to individual sync...');
    
    List<Future<void>> syncFutures = [];
    for (int i = 1; i < steps.length; i++) {
      syncFutures.add(_syncStepWithBackend(steps[i], i));
    }
    await Future.wait(syncFutures);
  }

  void _determineCurrentActiveSteps() {
    setState(() {
      // Check if user has any steps available for their roles
      if (steps.isEmpty || steps.length <= 1) {
        print('No steps available for user roles: $_userRoles');
        return;
      }

      List<int> activeSteps = [];

      // Debug logging for Flute Lamination
      if (_startedStepIndex != null && _startedStepType == StepType.fluteLamination) {
        print('🔍 DETERMINE ACTIVE STEPS: Flute Lamination started at index $_startedStepIndex');
      }

      // If we have a started step, keep it active and, for printing/corrugation,
      // also activate its parallel pair so both can run independently
      if (_startedStepIndex != null) {
        activeSteps = [_startedStepIndex!];
        print('🔍 DETERMINE ACTIVE STEPS: Found started step at index $_startedStepIndex (${_startedStepType})');

        if (_startedStepType == StepType.printing || _startedStepType == StepType.corrugation) {
          final parallelTypes = StepProgressManager.getParallelSteps(_startedStepType!);
          for (final parallelType in parallelTypes) {
            final parallelIndex = steps.indexWhere((s) => s.type == parallelType);
            if (parallelIndex != -1 && StepProgressManager.shouldActivateStep(steps, parallelIndex)) {
              activeSteps.add(parallelIndex);
            }
          }
        }

        // For other step types (like Flute Lamination), also check if previous steps should remain active
        if (_startedStepType != StepType.printing && _startedStepType != StepType.corrugation) {
          // Keep previous completed steps active for user interaction
          for (int i = 1; i < _startedStepIndex!; i++) {
            if (steps[i].status == StepStatus.completed) {
              activeSteps.add(i);
              print('Keeping completed step active at index $i (${steps[i].title})');
            }
          }
        }

        currentActiveSteps = activeSteps;
        print('Active steps with started step: $currentActiveSteps');
        return;
      }

      // Find all steps that should be active
      print('🔍 DETERMINE ACTIVE STEPS: No started step, checking all steps for activation');
      for (int i = 1; i < steps.length; i++) {
        final step = steps[i];
        print('  Step $i: ${step.title} - Status: ${step.status}');

        // Check if step is started or in progress
        if (step.status == StepStatus.started || step.status == StepStatus.inProgress) {
          activeSteps.add(i);
          print('Found active step at index: $i (${step.title}) - status: ${step.status}');
        }
        // Check if step is pending and should be activated
        else if (step.status == StepStatus.pending) {
          final shouldActivate = StepProgressManager.shouldActivateStep(steps, i);
          print('  Step $i (${step.title}) pending - shouldActivate: $shouldActivate');
          if (shouldActivate) {
            activeSteps.add(i);
            print('Found pending step that should be active at index: $i (${step.title})');
          }
        }
      }

      // If no active steps found, find the first step that should be activated
      if (activeSteps.isEmpty) {
        for (int i = 1; i < steps.length; i++) {
          if (StepProgressManager.shouldActivateStep(steps, i)) {
            activeSteps.add(i);
            print('Found first available step at index: $i (${steps[i].title})');
            break;
          }
        }
      }

      currentActiveSteps = activeSteps;
      print('Current active steps: $currentActiveSteps');
    });
  }

  /// Legacy method for fallback - kept for backward compatibility
  Future<void> _syncStepWithBackend(StepData step, int stepIndex) async {
    try {
      // If step has form data, it was completed, so preserve completed status
      if (step.formData.isNotEmpty && step.status == StepStatus.completed) {
        print('Step ${step.title} has form data, preserving completed status');
        return;
      }

      final stepNo = StepDataManager.getStepNumber(step.type);
      final stepDetails = await _apiService.getJobPlanningStepDetails(widget.jobNumber!, stepNo);

      // If planning doesn't include this step, do not query step-specific endpoints
      if (stepDetails == null) {
        setState(() {
          step.status = StepStatus.pending;
        });
        print('Planning has no details for ${step.title} (stepNo $stepNo); skipping step-specific queries.');
        return;
      }

      final stepStatus = await _apiService.getStepStatusByType(step.type, widget.jobNumber!);

      dynamic planningStatus;
      if (stepDetails is List && stepDetails!.isEmpty) {
        planningStatus = null;
      } else if (stepDetails is Map && stepDetails!.containsKey('status')) {
        planningStatus = stepDetails['status'];
      } else if (stepDetails is Map && stepDetails!.isEmpty) {
        planningStatus = null;
      } else {
        planningStatus = null;
      }

      // 1. Work Complete: If either status is 'stop', mark as completed and move to next step
      if (stepStatus == 'stop' || planningStatus == 'stop') {
        setState(() {
          step.status = StepStatus.completed;
        });
        print('Step ${step.title} marked as WORK COMPLETE (stop detected)');
        // Check if all parallel steps are completed before moving to next step
        bool shouldMoveToNext = true;
        if (StepProgressManager.canRunInParallel(step.type)) {
          shouldMoveToNext = StepProgressManager.areAllParallelStepsCompleted(steps, step.type);
          print('Step ${step.title} can run in parallel. All parallel steps completed: $shouldMoveToNext');
        }

        if (shouldMoveToNext) {
          // Move to the next available step(s)
          StepProgressManager.moveToNextStep(
            steps,
            stepIndex,
                (newActiveStep) => setState(() {
              if (!currentActiveSteps.contains(newActiveStep)) {
                currentActiveSteps.add(newActiveStep);
              }
            }),
                (message) => DialogManager.showSuccessMessage(context, message),
          );
        } else {
          print('Not moving to next step yet - waiting for parallel steps to complete');
        }
        return;
      }

      // 2. Work Started: If either status is 'start'
      if (stepStatus == 'start' || planningStatus == 'start') {
        setState(() {
          step.status = StepStatus.started;
          if (!currentActiveSteps.contains(stepIndex)) {
            currentActiveSteps.add(stepIndex);
          }
        });
        print('Step ${step.title} marked as WORK STARTED (from either API)');
        return;
      }

      // 3. Pending: If planning status is 'planned'
      if (planningStatus == 'planned') {
        setState(() {
          step.status = StepStatus.pending;
        });
        print('Step ${step.title} marked as PENDING (planned)');
        
        // For new jobs where all steps are planned, allow multiple steps to be active
        // Check if this is a new job (no steps are started or completed)
        bool isNewJob = !steps.any((s) => s.status == StepStatus.started || s.status == StepStatus.completed);
        
        if (isNewJob) {
          // For new jobs, activate all steps that the user has access to
          setState(() {
            if (!currentActiveSteps.contains(stepIndex)) {
              currentActiveSteps.add(stepIndex);
            }
          });
          print('Forcing step ${step.title} to be active (new job - all steps planned)');
        } else {
          // For existing jobs, check if all previous steps are completed
          bool allPreviousCompleted = true;
          for (int j = 1; j < stepIndex; j++) {
            if (steps[j].status != StepStatus.completed) {
              allPreviousCompleted = false;
              break;
            }
          }
          if (allPreviousCompleted) {
            setState(() {
              if (!currentActiveSteps.contains(stepIndex)) {
                currentActiveSteps.add(stepIndex);
              }
            });
            print('Forcing step ${step.title} to be active due to planned status');
          }
        }
        return;
      }

      // 4. Fallback: Pending (but preserve completed status if step has form data)
      setState(() {
        // Only set to pending if the step doesn't have form data (indicating it wasn't actually completed)
        if (step.formData.isEmpty) {
          step.status = StepStatus.pending;
          print('Step ${step.title} marked as PENDING (fallback)');
        } else {
          // If step has form data, it was completed, so keep it completed
          step.status = StepStatus.completed;
          print('Step ${step.title} preserved as COMPLETED (has form data)');
        }
      });

      // For Paper Store, also sync with paper store API
      if (step.type == StepType.paperStore) {
        await _syncPaperStoreStepWithBackend();
      }
    } catch (e) {
      print('Error syncing step ${step.title}: $e');
      setState(() {
        step.status = StepStatus.pending;
      });
    }
  }

  Future<void> _syncPaperStoreStepWithBackend() async {
    if (widget.jobNumber == null) return;

    try {
      final paperStore = await _apiService.getPaperStoreStepByJob(widget.jobNumber!);
      if (paperStore != null) {
        final status = paperStore['status'];
        final paperStoreStepIndex = steps.indexWhere((step) => step.type == StepType.paperStore);

        if (paperStoreStepIndex != -1) {
          setState(() {
            if (status == 'in_progress') {
              steps[paperStoreStepIndex].status = StepStatus.inProgress;
              if (!currentActiveSteps.contains(paperStoreStepIndex)) {
                currentActiveSteps.add(paperStoreStepIndex);
              }
            } else if (status == 'hold') {
              steps[paperStoreStepIndex].status = StepStatus.hold;
              if (!currentActiveSteps.contains(paperStoreStepIndex)) {
                currentActiveSteps.add(paperStoreStepIndex);
              }
            } else if (status == 'accept') {
              steps[paperStoreStepIndex].status = StepStatus.completed;
            }
          });
        }
      }
    } catch (e) {
      print('Error syncing Paper Store step: $e');
    }
  }

  Future<void> _fetchJobDetails() async {
    // Don't reload if already loaded
    if (jobDetails != null && !_jobLoading) {
      return;
    }

    setState(() {
      _jobLoading = true;
      _jobError = null;
    });

    try {
      final details = await _apiService.fetchJobDetails(widget.jobNumber ?? '');
      print("This is the details I want");
      print(details);
      setState(() {
        jobDetails = details;
        // Initialize _jobData from job details
        if (details != null && details.isNotEmpty) {
          // details is List<Job>, so get the first Job and convert to Map
          final firstJob = details[0];
          _jobData = {
            'id': firstJob.id,
            'nrcJobNo': firstJob.nrcJobNo,
            'styleItemSKU': firstJob.styleItemSKU,
            'customerName': firstJob.customerName,
            'fluteType': firstJob.fluteType,
            'status': firstJob.status,
            'latestRate': firstJob.latestRate,
            'preRate': firstJob.preRate,
            'length': firstJob.length,
            'width': firstJob.width,
            'height': firstJob.height,
            'boxDimensions': firstJob.boxDimensions,
            'diePunchCode': firstJob.diePunchCode,
            'boardCategory': firstJob.boardCategory,
            'noOfColor': firstJob.noOfColor,
            'processColors': firstJob.processColors,
            'specialColor1': firstJob.specialColor1,
            'specialColor2': firstJob.specialColor2,
            'specialColor3': firstJob.specialColor3,
            'specialColor4': firstJob.specialColor4,
            'overPrintFinishing': firstJob.overPrintFinishing,
            'topFaceGSM': firstJob.topFaceGSM,
            'flutingGSM': firstJob.flutingGSM,
            'bottomLinerGSM': firstJob.bottomLinerGSM,
            'decalBoardX': firstJob.decalBoardX,
            'lengthBoardY': firstJob.lengthBoardY,
            'boardSize': firstJob.boardSize,
            'noUps': firstJob.noUps,
            'artworkReceivedDate': firstJob.artworkReceivedDate,
            'artworkApprovalDate': firstJob.artworkApprovalDate,
            'shadeCardApprovalDate': firstJob.shadeCardApprovalDate,
            'srNo': firstJob.srNo,
            'jobDemand': firstJob.jobDemand,
            'imageURL': firstJob.imageURL,
            'createdAt': firstJob.createdAt,
            'updatedAt': firstJob.updatedAt,
            'userId': firstJob.userId,
            'machineId': firstJob.machineId,
            'isMachineDetailsFilled': firstJob.isMachineDetailsFilled,
            'hasPurchaseOrders': firstJob.hasPurchaseOrders,
            // Add purchase order data if available
            if (firstJob.purchaseOrders != null && firstJob.purchaseOrders!.isNotEmpty)
              'totalPOQuantity': firstJob.purchaseOrders![0].totalPOQuantity,
          };
          print('🔍 [JobStep] _jobData populated: ${_jobData?.keys.toList()}');
          print('🔍 [JobStep] _jobData values: ${_jobData?.values.toList()}');
        } else {
          print('🔍 [JobStep] No job details found or empty');
        }
        _jobLoading = false;
      });
    } catch (e) {
      setState(() {
        _jobError = 'Failed to load job details';
        _jobLoading = false;
      });
    }
  }

  Future<void> _fetchStepDetails(StepType stepType) async {
    final stepNo = StepDataManager.getStepNumber(stepType);
    if (stepNo == null || widget.jobNumber == null) return;

    try {
      print('DEBUG: Fetching step details for step $stepNo');
      final stepDetails = await _apiService.getStepDetailsWithEditability(widget.jobNumber!, stepType);
      if (stepDetails != null && stepDetails.isNotEmpty) {
        // Extract data from StepDataWithEditability
        final stepData = stepDetails[0];
        _stepDetailsCache[stepNo] = stepData.data;
        print('DEBUG: Step details cached for step $stepNo');
      }
    } catch (e) {
      print('DEBUG: Error fetching step details for $stepType: $e');
    }
  }

  void _handleStepTap(StepData step) {
    print('DEBUG: Step tapped: ${step.title}, Type: ${step.type}, Status: ${step.status}');

    if (step.type == StepType.jobAssigned) {
      _showCompleteJobDetails();
      return;
    }

    final isActive = _isStepActive(step);
    print('DEBUG: Step ${step.title} - isActive: $isActive, status: ${step.status}');

    if (step.status == StepStatus.pending && isActive) {
      print('DEBUG: Step ${step.title} is pending and active - checking machine assignment');
      // Check machine assignment before allowing start
      _checkMachineAssignmentAndStart(step);
    } else if (step.status == StepStatus.started || step.status == StepStatus.inProgress) {
      print('DEBUG: Step ${step.title} is already started - checking for machine selection');
      // Check if this step requires machines
      if (_isMachineRequiredStep(step.type)) {
        // For machine-required steps, check ALL accessible plannings for this step
        _showSmartMachineSelection(step);
      } else {
        // For non-machine steps (PaperStore, Quality, Dispatch), show work form directly
        print('DEBUG: Step ${step.title} does not require machines, showing work form directly');
        _showWorkForm(step);
      }
    } else if (step.status == StepStatus.hold) {
      print('DEBUG: Step ${step.title} is on hold - showing work form to resume');
      // For hold status, show work form to allow resume
      if (_isMachineRequiredStep(step.type)) {
        // For machine-required steps, show machine selection
        _showSmartMachineSelection(step);
      } else {
        // For non-machine steps (PaperStore, Quality, Dispatch), show work form directly
        print('DEBUG: Step ${step.title} is on hold, showing work form to resume');
        _showWorkForm(step);
      }
    } else if (step.status == StepStatus.completed) {
      print('DEBUG: Showing completed step details for ${step.title}');
      _showCompletedStepDetails(step);
    } else {
      print('DEBUG: Step ${step.title} is not available. Status: ${step.status}, Active: $isActive');
      DialogManager.showErrorMessage(
          context,
          '${step.title} is not available yet. Complete previous steps first.'
      );
    }
  }

  /// 🚀 REVOLUTIONARY: Smart Machine Selection with ALL Accessible Plannings
  Future<void> _showSmartMachineSelection(StepData step) async {
    try {
      print('🚀 SMART MACHINE SELECTION: Analyzing all accessible plannings for ${step.title}');
      
      // Show beautiful loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Container(
          color: Colors.black54,
          child: Center(
            child: Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.maincolor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Center(
                      child: SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.maincolor),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Analyzing Machines',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Finding all available machines for ${step.title}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Get ALL job plannings for this job
      final allPlannings = await _apiService.getAllJobPlannings();
      final jobPlannings = allPlannings
          .where((p) => p['nrcJobNo'] == widget.jobNumber)
          .toList();

      print('📊 Found ${jobPlannings.length} plannings for job ${widget.jobNumber}');

      // Collect all machines from all plannings - backend handles access control
      final stepNo = StepDataManager.getStepNumber(step.type);
      final allAccessibleMachines = <Map<String, dynamic>>[];
      final planningMachineMap = <String, List<Map<String, dynamic>>>{};

      for (final planning in jobPlannings) {
        final steps = planning['steps'] as List<dynamic>? ?? [];
        final matchingStep = steps.firstWhere(
          (s) => s['stepNo'] == stepNo,
          orElse: () => null,
        );

        if (matchingStep != null && matchingStep['machineDetails'] != null) {
          final machineDetails = matchingStep['machineDetails'] as List<dynamic>? ?? [];
          final planningId = planning['jobPlanId'].toString();
          
          print('🔍 DEBUG: Planning $planningId has ${machineDetails.length} machines');
          
          // Show ALL machines from planning - backend will handle access control when user tries to start
          // Filter out machines with no id (not assigned)
          final accessibleMachines = machineDetails.where((md) {
            if (md is Map<String, dynamic>) {
              // Check for 'id' field (the actual machine ID)
              final machineId = md['id']?.toString();
              // Only show machines that actually have an id assigned
              return machineId != null && machineId.isNotEmpty && machineId != 'null';
            }
            return false;
          }).cast<Map<String, dynamic>>().toList();
          
          print('🔍 DEBUG: Planning $planningId - showing ${accessibleMachines.length} assigned machines (filtered out unassigned)');

          if (accessibleMachines.isNotEmpty) {
            planningMachineMap[planningId] = accessibleMachines;
            allAccessibleMachines.addAll(accessibleMachines);
          }
        }
      }

      if (mounted) Navigator.pop(context); // Close loading dialog

      print('🎯 Found ${allAccessibleMachines.length} accessible machines across ${planningMachineMap.length} plannings');

      if (allAccessibleMachines.isEmpty) {
        _showNoMachinesAvailableDialog(step);
        return;
      }

      // Remove duplicates while preserving order
      final uniqueMachines = <String, Map<String, dynamic>>{};
      for (final machine in allAccessibleMachines) {
        final machineId = machine['id']?.toString();
        if (machineId != null && !uniqueMachines.containsKey(machineId)) {
          uniqueMachines[machineId] = machine;
        }
      }

      final machines = uniqueMachines.values.toList();
      print('🔧 Unique accessible machines: ${machines.length}');

      if (machines.length == 1) {
        // Single machine - show form directly
        final machineId = machines.first['id']?.toString();
        print('✅ Single machine available: $machineId');
        _showWorkFormWithMachine(step, machineId!);
      } else {
        // Multiple machines - show revolutionary selection dialog
        print('🎨 Showing multi-machine selection dialog with ${machines.length} machines');
        _showRevolutionaryMachineSelectionDialog(step, machines, planningMachineMap);
      }

    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading dialog
      print('❌ Error in smart machine selection: $e');
      DialogManager.showErrorMessage(context, 'Failed to load machine information. Please try again.');
    }
  }

  /// 🎨 REVOLUTIONARY: Beautiful Machine Selection Dialog with Real-time Status
  Future<void> _showRevolutionaryMachineSelectionDialog(
    StepData step, 
    List<Map<String, dynamic>> machines,
    Map<String, List<Map<String, dynamic>>> planningMachineMap,
  ) async {
    try {
      // Get real-time machine statuses from JobStepMachine table
      final machineStatuses = await _getMachineStatuses(step, machines.map((m) => m['id']?.toString()).whereType<String>().toList());
      
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => Container(
            color: Colors.black54,
            child: Center(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 20),
                constraints: BoxConstraints(maxWidth: 400, maxHeight: 600),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 30,
                      offset: Offset(0, 15),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with gradient
                    Container(
                      padding: EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.maincolor, AppColors.maincolor.withOpacity(0.8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.precision_manufacturing, color: Colors.white, size: 28),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Select Machine',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '${step.title} • ${machines.length} machines available',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(Icons.close, color: Colors.white),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.2),
                              shape: CircleBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Content
                    Flexible(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          children: [
                            // Info card
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue[200]!),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.blue[700], size: 24),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Select a machine to continue working on ${step.title}. Real-time status shown below.',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.blue[900],
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            SizedBox(height: 20),
                            
                            // Machine cards
                            ...machines.asMap().entries.map((entry) {
                              final index = entry.key;
                              final machine = entry.value;
                              final machineId = machine['id']?.toString();
                              final machineCode = machine['machineCode']?.toString() ?? 'Unknown';
                              final machineType = machine['machineType']?.toString() ?? 'Unknown';
                              final unit = machine['unit']?.toString() ?? 'Unknown';
                              
                              final machineStatus = _getMachineStatusFromMap(machineId, machineStatuses);
                              final isWorking = machineStatus == 'in_progress' || machineStatus == 'hold';
                              final statusColor = machineStatus == 'in_progress' ? Colors.blue : 
                                                 machineStatus == 'hold' ? Colors.orange :
                                                 machineStatus == 'stop' ? Colors.grey :
                                                 Colors.green;
                              final statusText = machineStatus == 'in_progress' ? 'Working' :
                                                machineStatus == 'hold' ? 'On Hold' :
                                                machineStatus == 'stop' ? 'Stopped' :
                                                'Available';
                              final statusIcon = machineStatus == 'in_progress' ? Icons.play_circle_filled : 
                                                machineStatus == 'hold' ? Icons.pause_circle_filled :
                                                machineStatus == 'stop' ? Icons.stop_circle :
                                                Icons.check_circle;
                              
                              return Container(
                                margin: EdgeInsets.only(bottom: 16),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.pop(context);
                                      _showWorkFormWithMachine(step, machineId!);
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      padding: EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: statusColor.withOpacity(0.3), 
                                          width: 2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: statusColor.withOpacity(0.1),
                                            blurRadius: 12,
                                            offset: Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          // Status indicator
                                          Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: statusColor,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: statusColor.withOpacity(0.3),
                                                  blurRadius: 8,
                                                  spreadRadius: 2,
                                                ),
                                              ],
                                            ),
                                          ),
                                          SizedBox(width: 16),
                                          
                                          // Machine icon
                                          Container(
                                            padding: EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Icon(
                                              Icons.precision_manufacturing,
                                              color: statusColor,
                                              size: 24,
                                            ),
                                          ),
                                          SizedBox(width: 16),
                                          
                                          // Machine details
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  machineCode,
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.grey[800],
                                                  ),
                                                ),
                                                SizedBox(height: 4),
                                                Text(
                                                  '$unit • $machineType',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                                SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    Icon(statusIcon, color: statusColor, size: 16),
                                                    SizedBox(width: 6),
                                                    Text(
                                                      statusText,
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w600,
                                                        color: statusColor,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          
                                          // Arrow
                                          Container(
                                            padding: EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.arrow_forward_ios,
                                              color: statusColor,
                                              size: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      print('❌ Error showing machine selection dialog: $e');
      DialogManager.showErrorMessage(context, 'Failed to load machine selection. Please try again.');
    }
  }

  /// Show dialog when no machines are available
  void _showNoMachinesAvailableDialog(StepData step) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.warning, color: Colors.orange[700], size: 24),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'No Machines Available',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          'You don\'t have access to any machines for ${step.title}. Please contact your administrator.',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: AppColors.maincolor)),
          ),
        ],
      ),
    );
  }

  void _handleStepTapWithMachine(StepData step, String machineId) {
    print('DEBUG: Step tapped with machine: ${step.title}, Machine: $machineId, Type: ${step.type}, Status: ${step.status}');

    if (step.type == StepType.jobAssigned) {
      _showCompleteJobDetails();
      return;
    }

    final isActive = _isStepActive(step);
    print('DEBUG: Step ${step.title} with machine $machineId - isActive: $isActive, status: ${step.status}');

    if (step.status == StepStatus.pending && isActive) {
      // Start work with specific machine
      _startWorkWithMachine(step, machineId);
    } else if (step.status == StepStatus.started || step.status == StepStatus.inProgress) {
      print('DEBUG: Step ${step.title} is already started - showing work form with machine $machineId');
      // For already started steps, show work form directly with machine info
      _showWorkFormWithMachine(step, machineId);
    } else if (step.status == StepStatus.completed) {
      print('DEBUG: Showing completed step details for ${step.title} with machine $machineId');
      _showCompletedStepDetails(step);
    } else {
      print('DEBUG: Step ${step.title} with machine $machineId is not available. Status: ${step.status}, Active: $isActive');
      DialogManager.showErrorMessage(
          context,
          '${step.title} is not available yet. Complete previous steps first.'
      );
    }
  }


  Future<void> _showMachineSelectionDialog(StepData step) async {
      final stepNo = StepDataManager.getStepNumber(step.type);
    print('DEBUG: _showMachineSelectionDialog called for step: ${step.title}, stepNo: $stepNo, jobNumber: ${widget.jobNumber}');
    
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => JobTimelineUI.buildLoadingDialog('Loading machines...'),
      );

      print('DEBUG: Fetching machine details from step data...');
      // Get machine details from the step's existing data
      final machineDetails = await _getMachineDetailsForStep(step);
      print('DEBUG: Machine details: $machineDetails');
      
      // Fetch machine statuses from backend
      final machineStatuses = await _fetchMachineStatuses(widget.jobNumber!, stepNo);
      print('DEBUG: Machine statuses from backend: $machineStatuses');
      
      if (mounted) Navigator.pop(context); // Close loading dialog

      if (machineDetails == null || machineDetails.isEmpty) {
        print('DEBUG: No machine details found');
        DialogManager.showErrorMessage(context, 'No machines available for this step');
            return;
          }

      final machines = machineDetails;
      print('DEBUG: Machines list: $machines');

      // Show enhanced machine selection dialog with better UX
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.maincolor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.precision_manufacturing, color: AppColors.maincolor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select Machine', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('${step.title}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (machines.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${machines.length} machines available. Select one to continue.',
                              style: TextStyle(fontSize: 13, color: Colors.blue[900]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ...machines.map((machine) {
                  final machineId = machine['machineId'] ?? machine['id'];
                  final machineStatus = _getMachineStatus(machineId, machineStatuses);
                  final isWorking = machineStatus == 'in_progress' || machineStatus == 'hold';
                  final statusColor = machineStatus == 'in_progress' ? Colors.blue : 
                                     machineStatus == 'hold' ? Colors.orange :
                                     machineStatus == 'stop' ? Colors.grey :
                                     Colors.green;
                  final statusText = machineStatus == 'in_progress' ? 'Working' :
                                    machineStatus == 'hold' ? 'On Hold' :
                                    machineStatus == 'stop' ? 'Stopped' :
                                    'Available';
                  final statusIcon = machineStatus == 'in_progress' ? Icons.play_circle : 
                                    machineStatus == 'hold' ? Icons.pause_circle :
                                    machineStatus == 'stop' ? Icons.stop_circle :
                                    Icons.check_circle;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withOpacity(0.3), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withOpacity(0.1),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        splashColor: statusColor.withOpacity(0.2),
                        highlightColor: statusColor.withOpacity(0.1),
                        onTap: () {
                          print('DEBUG: Machine selected: $machineId (status: $machineStatus)');
                          Navigator.of(context).pop();
                          if (isWorking) {
                            _showWorkFormWithMachine(step, machineId);
                          } else {
                            _startWorkWithMachine(step, machineId);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.precision_manufacturing, color: statusColor, size: 28),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      machine['machineCode'] ?? machineId ?? 'Unknown',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      '${machine['unit'] ?? 'Unknown'} • ${machine['machineType'] ?? 'Unknown'}',
                                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                    ),
                                    SizedBox(height: 8),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(statusIcon, color: statusColor, size: 14),
                                          SizedBox(width: 6),
                                          Text(
                                            statusText,
                                            style: TextStyle(
                                              color: statusColor,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                isWorking ? Icons.open_in_new : Icons.play_arrow,
                                color: statusColor,
                                size: 28,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.close, size: 18),
              label: Text('Cancel'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[700],
              ),
            ),
          ],
        ),
      );

    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading dialog
      print('DEBUG: Error loading machines: $e');
      print('DEBUG: Error type: ${e.runtimeType}');
      print('DEBUG: Error details: ${e.toString()}');
      DialogManager.showErrorMessage(context, 'Failed to load machines: ${e.toString()}');
    }
  }

  Future<void> _startUrgentJobWork(StepData step) async {
    final stepNo = StepDataManager.getStepNumber(step.type);
    
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => JobTimelineUI.buildLoadingDialog('Starting urgent job work...'),
      );

      // Call the urgent job auto-assignment API
      final result = await _apiService.startUrgentJobWork(widget.jobNumber!, stepNo);
      
      if (mounted) Navigator.pop(context); // Close loading dialog

      if (result == null) {
        DialogManager.showErrorMessage(context, 'Failed to start urgent job work');
        return;
      }

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Urgent job work started successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Start the work form with the auto-assigned machine
      final machineId = result['machineId'];
      _showWorkFormWithMachine(step, machineId);

    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading dialog
      print('Error starting urgent job work: $e');
      DialogManager.showErrorMessage(context, 'Failed to start urgent job work: ${e.toString()}');
    }
  }

  void _showMachineNotAssignedDialog(StepData step) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.white,
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 8),
            Text('Machine Not Assigned'),
          ],
        ),
        content: Text(
          'Contact To Admin',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }


  Future<void> _showJobDetailsDialog() async {
    // Fetch job details if not already loaded
    if (jobDetails == null) {
      await _fetchJobDetails();
    }

    // Get PO details
    String poQuantity = 'N/A';
    String customerName = 'N/A';

    if (jobDetails != null) {
      // Check if jobDetails is a list and get the first item
      final jobData = jobDetails is List ? (jobDetails as List)[0] : jobDetails;
      print(jobData.toString());
      if (jobData != null && jobData.purchaseOrders != null) {
        final purchaseOrders = jobData.purchaseOrders as List;
        if (purchaseOrders.isNotEmpty) {
          final po = purchaseOrders[0];
          poQuantity = '${po.totalPOQuantity ?? 'N/A'}';
          customerName =  jobData.customerName ?? 'N/A';
        }
      }
    }

    // Get artwork image
    String? imageUrl;
    if (jobDetails != null) {
      final jobData = jobDetails is List ? (jobDetails as List)[0] : jobDetails;
      imageUrl = jobData?.imageURL;
    }

    // Get machine information for current active steps
    Map<String, dynamic>? currentStepMachineInfo;

    try {
      if (currentActiveSteps.isNotEmpty) {
        // Use the first active step for machine info display
        final currentStepIndex = currentActiveSteps.first;
        if (currentStepIndex > 0 && currentStepIndex < steps.length) {
          final currentStep = steps[currentStepIndex];
          final stepNo = StepDataManager.getStepNumber(currentStep.type);
          final stepDetails = await _apiService.getJobPlanningStepDetails(widget.jobNumber!, stepNo);

          if (stepDetails != null && stepDetails is Map) {
            final machineDetails = stepDetails['machineDetails'];

            if (machineDetails != null && machineDetails is List && machineDetails.isNotEmpty) {
              final machineInfo = machineDetails[0];
              if (machineInfo is Map) {
                currentStepMachineInfo = {
                  'stepTitle': currentStep.title,
                  'machineCode': machineInfo['machineCode'] ?? 'Not assigned',
                  'machineId': machineInfo['machineId'] ?? 'Not assigned',
                  'unit': machineInfo['unit'] ?? 'Not assigned',
                };
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error fetching current step machine information: $e');
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            const SizedBox(width: 8),
            Text('Job Details'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Job Information
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.assignment, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Job Information',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Job Number: ${widget.jobNumber}'),
                    Text('Customer: $customerName'),
                    Text('Quantity: $poQuantity'),
                    if (jobDetails != null) ...[
                      Builder(
                        builder: (context) {
                          final jobData = jobDetails is List ? (jobDetails as List)[0] : jobDetails;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (jobData?.noUps != null)
                                Text('No. of Ups: ${jobData.noUps}'),
                              if (jobData?.styleItemSKU != null)
                                Text('Style: ${jobData.styleItemSKU}'),
                              if (jobData?.boxDimensions != null)
                                Text('Dimensions: ${jobData.boxDimensions}'),
                              if (jobData?.boardSize != null)
                                Text('Board Size: ${jobData.boardSize}'),
                              if (jobData?.fluteType != null)
                                Text('Flute Type: ${jobData.fluteType}'),
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Current Step Machine Information
              if (currentStepMachineInfo != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.build, color: Colors.green[700], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Current Step Machine',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${currentStepMachineInfo['stepTitle']}:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Machine: ${currentStepMachineInfo['machineCode']}'),
                            Text('ID: ${currentStepMachineInfo['machineId']}'),
                            Text('Unit: ${currentStepMachineInfo['unit']}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              if (currentStepMachineInfo != null) const SizedBox(height: 16),

              // Artwork Image (if available)
              if (imageUrl != null && imageUrl.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.image, color: Colors.purple[700], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Artwork Reference',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: GestureDetector(
                            onTap: () => _showFullScreenImage(imageUrl),
                            child: Builder(
                              builder: (context) {
                                final imageData = _safeBase64Decode(imageUrl);
                                if (imageData != null) {
                                  return Image.memory(
                                    imageData,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey[200],
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.broken_image, color: Colors.grey[400]),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Image not available',
                                                style: TextStyle(color: Colors.grey[600]),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                } else {
                                  return Container(
                                    color: Colors.grey[200],
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.broken_image, color: Colors.grey[400]),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Image not available',
                                            style: TextStyle(color: Colors.grey[600]),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }
                              },
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
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  bool _isStepActive(StepData step) {
    int stepIndex = steps.indexOf(step);
    bool isActive = currentActiveSteps.contains(stepIndex);
    print('DEBUG: Checking if step ${step.title} (index: $stepIndex) is active. Current active steps: $currentActiveSteps, Result: $isActive');
    print('DEBUG: Step status: ${step.status}, Step type: ${step.type}');
    return isActive;
  }

  Future<void> _startWork(StepData step) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (context) => JobTimelineUI.buildLoadingDialog('Starting work...'),
    );

    try {
      // First update the backend
      await _performStartWork(step);

      if (mounted) Navigator.pop(context);

      setState(() {
        step.status = StepStatus.started;
        final stepIndex = steps.indexOf(step);
        if (stepIndex != -1 && !currentActiveSteps.contains(stepIndex)) {
          currentActiveSteps.add(stepIndex);
        }
      });

      DialogManager.showSuccessMessage(context, '${step.title} work started!');

      // Clear relevant caches to force fresh data
      final stepNo = StepDataManager.getStepNumber(step.type);
      _stepDetailsCache.remove(stepNo);
      _completedStepDetailsCache.remove(step.type);

      // Immediately update the UI state
      if (mounted) {
        setState(() {
          // Force UI refresh to show updated status
        });
      }

      // Trigger immediate comprehensive refresh
      Future.delayed(Duration(milliseconds: 200), () {
        if (mounted) {
          print('Auto-refreshing after work start...');
          _refreshAllStepData();
        }
      });
      
      // Additional refresh after a longer delay to ensure backend sync
      Future.delayed(Duration(milliseconds: 1000), () {
        if (mounted) {
          print('Secondary auto-refresh after work start...');
          _refreshAllStepData();
        }
      });

    } catch (e) {
      if (mounted) Navigator.pop(context);
      print('Start work error: $e');
      
      // Check if it's an access denied error (403)
      if (e.toString().contains('403') || e.toString().contains('Access Denied')) {
        DialogManager.showAccessDeniedMessage(context);
      } else {
        print('Start work validation warning or server error (operation may have succeeded): $e');
      }
    }
  }

  /// Start work on steps that don't require machines (PaperStore, Quality, Dispatch)
  Future<void> _startWorkOnStep(StepData step) async {
    print('DEBUG: _startWorkOnStep called for step: ${step.title}');
    
    // Check if this step requires machines
    final stepNo = StepDataManager.getStepNumber(step.type);
    final stepDetails = _stepDetailsCache[stepNo];
    
    if (stepDetails != null && stepDetails['machineDetails'] != null) {
      final machineDetails = stepDetails['machineDetails'];
      if (machineDetails is List && machineDetails.isNotEmpty) {
        // This step has machines, show machine selection dialog
        print('DEBUG: Step ${step.title} has machines, showing machine selection dialog');
        await _showMachineSelectionDialog(step);
        return;
      }
    }
    
    // For steps without machines, just show the work form directly
    // The original flow handles the step status updates
    print('DEBUG: Step ${step.title} has no machines, showing work form directly');
    _showWorkForm(step);
  }

  Future<void> _startWorkWithMachine(StepData step, String machineId) async {
    print('DEBUG: Starting work with machine $machineId for step ${step.title}');
    
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => JobTimelineUI.buildLoadingDialog('Starting work...'),
    );
    
    try {
      // Always call the API to start work
      await _performStartWorkWithMachine(step, machineId);
      
      if (mounted) Navigator.pop(context); // Close loading dialog
      
      // After successful API call, show the work form
      _showWorkFormWithMachine(step, machineId);
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading dialog
      
      print('DEBUG: Error starting work with machine: $e');
      
      // Check for specific error types
      if (e.toString().contains('403') || 
          e.toString().contains('Access Denied') || 
          e.toString().contains('do not have access')) {
        // Show beautiful access denied dialog
        _showAccessDeniedDialog(step, machineId);
      } else if (e.toString().contains('not available') || 
                 e.toString().contains('already') ||
                 e.toString().contains('in_progress')) {
        print('DEBUG: Machine already in use, opening form anyway');
        _showWorkFormWithMachine(step, machineId);
      } else {
        DialogManager.showErrorMessage(context, 'Failed to start work: ${e.toString()}');
      }
    }
  }
  
  void _showAccessDeniedDialog(StepData step, String machineId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.block, color: Colors.red, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Access Denied',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red[700]),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Column(
                children: [
                  Icon(Icons.lock_outline, size: 48, color: Colors.red[400]),
                  SizedBox(height: 12),
                  Text(
                    'You don\'t have permission to access this machine',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.red[900],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Machine ID: $machineId',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.red[700],
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Please contact your administrator to get access to this machine.',
                      style: TextStyle(fontSize: 13, color: Colors.blue[900]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.arrow_back, size: 18),
            label: Text('Go Back'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[700],
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performStartWorkWithMachine(StepData step, String machineId) async {
    final stepNo = StepDataManager.getStepNumber(step.type);

    if (jobDetails == null) {
      await _fetchJobDetails();
    }

    // Use new machine-specific API
    final result = await _apiService.startWorkOnMachine(
      widget.jobNumber!, 
      stepNo, 
      machineId,
      formData: null
    );

    if (result == null) {
      throw Exception('Failed to start work on machine');
    }

    // Also start paper store work if needed
    if (step.type == StepType.paperStore) {
      await _apiService.startPaperStoreWork(widget.jobNumber!, _convertJobDetailsToMap());
    }
  }

  void _showWorkFormWithMachine(StepData step, String machineId) async {
    if (step.type == StepType.paperStore) {
      await _showPaperStoreFormWithMachine(step, machineId);
      return;
    }

    final stepNo = StepDataManager.getStepNumber(step.type);

    int? expectedQuantity;
    if (jobDetails != null) {
      final jobData = jobDetails is List ? (jobDetails as List)[0] : jobDetails;
      if (jobData != null && jobData.purchaseOrders != null) {
        final purchaseOrders = jobData.purchaseOrders as List;
        if (purchaseOrders.isNotEmpty) {
          expectedQuantity = purchaseOrders[0].totalPOQuantity;
        }
      }
    }
    
    // Fallback quantity when no PO exists - use reasonable defaults based on step type
    if (expectedQuantity == null || expectedQuantity <= 0) {
      switch (step.type) {
        case StepType.paperStore:
          expectedQuantity = 1000; // Default for paper store
          break;
        case StepType.printing:
          expectedQuantity = 500; // Default for printing
          break;
        case StepType.corrugation:
          expectedQuantity = 800; // Default for corrugation
          break;
        case StepType.fluteLamination:
          expectedQuantity = 600; // Default for flute lamination
          break;
        case StepType.punching:
        case StepType.dieCutting:
          expectedQuantity = 400; // Default for punching/die cutting
          break;
        case StepType.flapPasting:
          expectedQuantity = 300; // Default for flap pasting
          break;
        case StepType.qc:
          expectedQuantity = 200; // Default for quality control
          break;
        case StepType.dispatch:
          expectedQuantity = 100; // Default for dispatch
          break;
        default:
          expectedQuantity = 1000; // General default
      }
    }

    // Show work form with machine info - using the same dialog approach as original
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WorkActionForm(
        title: step.title,
        description: step.description,
        initialQty: step.formData['Qty Sheet'] ?? '',
        hasData: step.formData.isNotEmpty,
        initialStatus: step.internalStatus ?? _getStepStatusString(step.status),
        jobNumber: widget.jobNumber,
        stepNo: stepNo,
        apiService: _apiService,
        expectedQuantity: expectedQuantity,
        stepType: step.type,
        jobData: _jobData,
        machineId: machineId, // Pass machine ID to form
        nrcJobNo: widget.jobNumber!,
        onComplete: (formData) async {
          String formatUtcDateToFixedIso(dynamic value) {
            if (value is DateTime) {
              final year = value.year.toString().padLeft(4, '0');
              final month = value.month.toString().padLeft(2, '0');
              final day = value.day.toString().padLeft(2, '0');
              final hour = value.hour.toString().padLeft(2, '0');
              final minute = value.minute.toString().padLeft(2, '0');
              final second = value.second.toString().padLeft(2, '0');
              final millisecond = value.millisecond.toString().padLeft(3, '0');

              return '${year}-${month}-${day}T${hour}:${minute}:${second}.${millisecond}Z';
            } else if (value is String) {
              final parsed = DateTime.parse(value);
              final year = parsed.year.toString().padLeft(4, '0');
              final month = parsed.month.toString().padLeft(2, '0');
              final day = parsed.day.toString().padLeft(2, '0');
              final hour = parsed.hour.toString().padLeft(2, '0');
              final minute = parsed.minute.toString().padLeft(2, '0');
              final second = parsed.second.toString().padLeft(2, '0');
              final millisecond = parsed.millisecond.toString().padLeft(3, '0');

              return '${year}-${month}-${day}T${hour}:${minute}:${second}.${millisecond}Z';
            }
            final now = DateTime.now();
            final year = now.year.toString().padLeft(4, '0');
            final month = now.month.toString().padLeft(2, '0');
            final day = now.day.toString().padLeft(2, '0');
            final hour = now.hour.toString().padLeft(2, '0');
            final minute = now.minute.toString().padLeft(2, '0');
            final second = now.second.toString().padLeft(2, '0');
            final millisecond = now.millisecond.toString().padLeft(3, '0');

            return '${year}-${month}-${day}T${hour}:${minute}:${second}.${millisecond}Z';
          }

          formData['Date'] = formatUtcDateToFixedIso(formData['Date']);

          await _handleWorkFormComplete(step, formData);
        },
        onStart: () async {
          setState(() {
            step.status = StepStatus.started;
            final stepIndex = steps.indexOf(step);
            if (stepIndex != -1 && !currentActiveSteps.contains(stepIndex)) {
              currentActiveSteps.add(stepIndex);
            }
          });
          print('Work started for ${step.title} on machine $machineId');
          
          // Clear all caches immediately and refresh
          _apiService.clearAllJobCaches(widget.jobNumber!);
          _clearAllCaches();
          await _refreshAllStepData();
        },
        onPause: () {
          print('Work paused for ${step.title} on machine $machineId');
        },
        onStop: () async {
          print('Work stopped for ${step.title} on machine $machineId');
          
          // Clear started step index when step is stopped
          final stepIndex = steps.indexOf(step);
          if (_startedStepIndex == stepIndex) {
            setState(() {
              _startedStepIndex = null;
              _startedStepType = null;
              _freezeAtStarted = false;
              print('Cleared started step index after stopping ${step.title}');
            });
          }
          
          // Clear all caches immediately and refresh
          _apiService.clearAllJobCaches(widget.jobNumber!);
          _clearAllCaches();
          await _refreshAllStepData();
        },
        onHold: (String remarks) async {
          print('${step.title} work held with remarks: $remarks on machine $machineId');
          
          // Machine-specific hold is handled by the WorkActionForm
          // No need to call old updateStepStatusGeneric API
          
          // Update status to hold
          setState(() {
            step.status = StepStatus.hold;
          });
          
          // Clear all caches immediately and refresh
          _apiService.clearAllJobCaches(widget.jobNumber!);
          _clearAllCaches();
          await _refreshAllStepData();
        },
        onResume: (String remarks) async {
          print('${step.title} work resumed with remarks: $remarks on machine $machineId');
          
          // Machine-specific resume is handled by the WorkActionForm
          // No need to call old updateStepStatusGeneric API
          
          // Update status back to started
          setState(() {
            step.status = StepStatus.started;
          });
          
          // Clear all caches immediately and refresh
          _apiService.clearAllJobCaches(widget.jobNumber!);
          _clearAllCaches();
          await _refreshAllStepData();
        },
      ),
    );
  }

  Future<void> _showPaperStoreFormWithMachine(StepData step, String machineId) async {
    // Similar to _showPaperStoreForm but with machine info
    // For now, just call the regular paper store form
    await _showPaperStoreForm(step);
  }

  Future<void> _performStartWork(StepData step) async {
    final stepNo = StepDataManager.getStepNumber(step.type);

    if (jobDetails == null) {
      await _fetchJobDetails();
    }

    // Defensive check for jobStepId
    final stepDetails = await _apiService.getJobPlanningStepDetails(widget.jobNumber!, stepNo);
    if (stepDetails == null || !(stepDetails is Map) || !stepDetails.containsKey('id')) {
      DialogManager.showErrorMessage(context, 'Job step ID not found in planning details. Please contact admin.');
      throw Exception('Job step ID not found in planning details.');
    }

    await _apiService.updateJobPlanningStepComplete(widget.jobNumber!, stepNo, "start");

    if (step.type == StepType.paperStore) {
      await _apiService.startPaperStoreWork(widget.jobNumber!, _convertJobDetailsToMap());
    }
  }

  void _showWorkForm(StepData step) async {
    if (step.type == StepType.paperStore) {
      await _showPaperStoreForm(step);
      return;
    }

    final stepNo = StepDataManager.getStepNumber(step.type);

    int? expectedQuantity;
    if (jobDetails != null) {
      final jobData = jobDetails is List ? (jobDetails as List)[0] : jobDetails;
      if (jobData != null && jobData.purchaseOrders != null) {
        final purchaseOrders = jobData.purchaseOrders as List;
        if (purchaseOrders.isNotEmpty) {
          final po = purchaseOrders[0];
          expectedQuantity = po.totalPOQuantity;
          print('JobStep - Expected Quantity: $expectedQuantity');
        }
      }
    }

    // Extract machine ID from step data for machine-specific steps
    String? machineId;
    String? nrcJobNo;
    
    // Get machine details from step details cache
    final stepDetails = _stepDetailsCache[stepNo];
    if (stepDetails != null && stepDetails['machineDetails'] != null) {
      final machineDetails = stepDetails['machineDetails'];
      if (machineDetails is List && machineDetails.isNotEmpty) {
        final machineDetail = machineDetails[0];
        machineId = machineDetail['machineId']?.toString();
        nrcJobNo = widget.jobNumber;
        print('🔍 [JobStep] Machine ID: $machineId, NRC Job No: $nrcJobNo');
      }
    }

    // 🚀 REVOLUTIONARY: Fetch REAL status from backend for Quality and Dispatch
    String realStatus = step.internalStatus ?? _getStepStatusString(step.status);
    if (step.type == StepType.qc || step.type == StepType.dispatch) {
      try {
        print('🚀 Fetching real ${step.title} status from backend...');
        final stepDetailsList = await _apiService.getStepDetailsWithEditability(widget.jobNumber!, step.type);
        if (stepDetailsList.isNotEmpty) {
          final stepData = stepDetailsList.first.data;
          realStatus = stepData['status']?.toString().toLowerCase() ?? realStatus;
          print('🚀 Real ${step.title} status from backend: $realStatus');
          print('🚀 Passing realStatus to WorkActionForm: $realStatus');
        }
      } catch (e) {
        print('❌ Error fetching real ${step.title} status: $e');
      }
    }

    // For other steps, use WorkActionForm
    print('🔍 [JobStep] Creating WorkActionForm for step: ${step.title}');
    print('🔍 [JobStep] Passing jobData: ${_jobData?.keys.toList()}');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WorkActionForm(
        title: step.title,
        description: step.description,
        initialQty: step.formData['Qty Sheet'] ?? '',
        hasData: step.formData.isNotEmpty,
        initialStatus: realStatus,
        jobNumber: widget.jobNumber,
        stepNo: stepNo,
        apiService: _apiService,
        expectedQuantity: expectedQuantity,
        stepType: step.type,
        jobData: _jobData,
        machineId: machineId,
        nrcJobNo: nrcJobNo,
        onComplete: (formData) async {


          String formatUtcDateToFixedIso(dynamic value) {
            if (value is DateTime) {
              final year = value.year.toString().padLeft(4, '0');
              final month = value.month.toString().padLeft(2, '0');
              final day = value.day.toString().padLeft(2, '0');
              final hour = value.hour.toString().padLeft(2, '0');
              final minute = value.minute.toString().padLeft(2, '0');
              final second = value.second.toString().padLeft(2, '0');
              final millisecond = value.millisecond.toString().padLeft(3, '0');

              return '${year}-${month}-${day}T${hour}:${minute}:${second}.${millisecond}Z';
            } else if (value is String) {
              final parsed = DateTime.parse(value);
              final year = parsed.year.toString().padLeft(4, '0');
              final month = parsed.month.toString().padLeft(2, '0');
              final day = parsed.day.toString().padLeft(2, '0');
              final hour = parsed.hour.toString().padLeft(2, '0');
              final minute = parsed.minute.toString().padLeft(2, '0');
              final second = parsed.second.toString().padLeft(2, '0');
              final millisecond = parsed.millisecond.toString().padLeft(3, '0');

              return '${year}-${month}-${day}T${hour}:${minute}:${second}.${millisecond}Z';
            }
            final now = DateTime.now();
            final year = now.year.toString().padLeft(4, '0');
            final month = now.month.toString().padLeft(2, '0');
            final day = now.day.toString().padLeft(2, '0');
            final hour = now.hour.toString().padLeft(2, '0');
            final minute = now.minute.toString().padLeft(2, '0');
            final second = now.second.toString().padLeft(2, '0');
            final millisecond = now.millisecond.toString().padLeft(3, '0');

            return '${year}-${month}-${day}T${hour}:${minute}:${second}.${millisecond}Z';
          }

          formData['Date'] = formatUtcDateToFixedIso(formData['Date']);

          await _handleWorkFormComplete(step, formData);
        },
        onStart: () async {
          setState(() {
            step.status = StepStatus.started;
            final stepIndex = steps.indexOf(step);
            if (stepIndex != -1 && !currentActiveSteps.contains(stepIndex)) {
              currentActiveSteps.add(stepIndex);
            }
          });
          print('Work started for ${step.title}');
          
          // Clear all caches immediately and refresh
          _apiService.clearAllJobCaches(widget.jobNumber!);
          _clearAllCaches();
          await _refreshAllStepData();
        },
        onPause: () {
          print('Work paused for ${step.title}');
        },
        onStop: () async {
          print('Work stopped for ${step.title}');
          
          // Clear started step index when step is stopped
          final stepIndex = steps.indexOf(step);
          if (_startedStepIndex == stepIndex) {
            setState(() {
              _startedStepIndex = null;
              _startedStepType = null;
              _freezeAtStarted = false;
              print('Cleared started step index after stopping ${step.title}');
            });
          }
          
          // Clear all caches immediately and refresh
          _apiService.clearAllJobCaches(widget.jobNumber!);
          _clearAllCaches();
          await _refreshAllStepData();
        },
        onHold: (String remarks) async {
          print('${step.title} work held with remarks: $remarks');
          
          // Machine-specific hold is handled by the WorkActionForm
          // No need to call old updateStepStatusGeneric API
          
          // Update status to hold
          setState(() {
            step.status = StepStatus.hold;
          });
          
          // Clear all caches immediately and refresh
          _apiService.clearAllJobCaches(widget.jobNumber!);
          _clearAllCaches();
          await _refreshAllStepData();
        },
        onResume: (String remarks) async {
          print('${step.title} work resumed with remarks: $remarks');
          
          // Machine-specific resume is handled by the WorkActionForm
          // No need to call old updateStepStatusGeneric API
          
          // Update status back to started
          setState(() {
            step.status = StepStatus.started;
          });
          
          // Clear all caches immediately and refresh
          _apiService.clearAllJobCaches(widget.jobNumber!);
          _clearAllCaches();
          await _refreshAllStepData();
        },
      ),
    );
  }

  Future<void> _showPaperStoreForm(StepData step) async {
    // Use the same generic WorkActionForm as other steps
    final stepNo = StepDataManager.getStepNumber(step.type);
    int? expectedQuantity;
    
    // Get expected quantity from job details
    if (jobDetails != null) {
      final jobData = jobDetails as List;
      if (jobData.isNotEmpty) {
        final purchaseOrders = jobData[0].purchaseOrders as List;
        if (purchaseOrders.isNotEmpty) {
          final po = purchaseOrders[0];
          expectedQuantity = po.totalPOQuantity;
          print('JobStep - Expected Quantity: $expectedQuantity');
        }
      }
    }

    // 🚀 REVOLUTIONARY: Fetch REAL status from backend for PaperStore
    String realStatus = 'started'; // Default fallback
    try {
      print('🚀 Fetching real PaperStore status from backend...');
      final stepDetailsList = await _apiService.getPaperStoreStepByJobWithEditability(widget.jobNumber!);
      if (stepDetailsList.isNotEmpty) {
        final stepData = stepDetailsList.first.data;
        realStatus = stepData['status']?.toString().toLowerCase() ?? 'started';
        print('🚀 Real PaperStore status from backend: $realStatus');
        print('🚀 Passing realStatus to WorkActionForm: $realStatus');
      }
    } catch (e) {
      print('❌ Error fetching real PaperStore status: $e');
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WorkActionForm(
        title: step.title,
        description: step.description,
        initialQty: step.formData['Qty Sheet'] ?? '',
        hasData: step.formData.isNotEmpty,
        initialStatus: realStatus,
        jobNumber: widget.jobNumber,
        stepNo: stepNo,
        apiService: _apiService,
        expectedQuantity: expectedQuantity,
        stepType: step.type,
        jobData: _jobData,
        onComplete: (formData) async {
          // Handle PaperStore completion
          await _completePaperStoreWork(step, formData);
        },
        onHold: (String remarks) async {
          print('Paper Store work held with remarks: $remarks');
          
          // Call generic API to hold Paper Store work
          await _apiService.holdStep('PaperStore', widget.jobNumber!, remarks);
          
          // Update status to hold
        setState(() {
            step.status = StepStatus.hold;
          });
        
        // Clear all caches immediately and refresh
        _apiService.clearAllJobCaches(widget.jobNumber!);
        _clearAllCaches();
        await _refreshAllStepData();
      },
        onResume: (String remarks) async {
          print('Paper Store work resumed with remarks: $remarks');
        
          // Call generic API to resume Paper Store work
          await _apiService.resumeStep('PaperStore', widget.jobNumber!, remarks);
        
          // Update status back to started
        setState(() {
            step.status = StepStatus.started;
          });
          
        // Clear all caches immediately and refresh
        _apiService.clearAllJobCaches(widget.jobNumber!);
        _clearAllCaches();
        await _refreshAllStepData();
      },
      ),
    );
  }

  Future<void> _completePaperStoreWork(StepData step, Map<String, String> formData) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (context) => JobTimelineUI.buildLoadingDialog('Submitting Paper Store data...'),
      );

      final stepNo = StepDataManager.getStepNumber(StepType.paperStore);

      // Only submit form data - don't change status (it's already 'stop' from Stop Work)
      await _apiService.putStepDetails(StepType.paperStore, widget.jobNumber!, formData, stepNo);

      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (!mounted) return;

      // Update form data but keep status as completed (which represents 'stop' status)
      setState(() {
        step.formData = formData;
        // Status remains StepStatus.completed (representing backend 'stop' status)
      });

      // Move to next step after completion
      final paperStoreStepIndex = steps.indexWhere((s) => s.type == StepType.paperStore);
      if (paperStoreStepIndex != -1) {
        StepProgressManager.moveToNextStep(
          steps,
          paperStoreStepIndex,
              (newActiveStep) => setState(() {
            if (!currentActiveSteps.contains(newActiveStep)) {
              currentActiveSteps.add(newActiveStep);
            }
          }),
              (message) => DialogManager.showSuccessMessage(context, message),
        );
      }

      // Show success message and refresh
      DialogManager.showSuccessMessage(context, 'Paper Store work completed successfully!');
      
      // Clear all caches and refresh
      _apiService.clearAllJobCaches(widget.jobNumber!);
      _clearAllCaches();
      await _refreshAllStepData();
    } catch (e) {
      if (mounted) Navigator.pop(context);
      DialogManager.showErrorMessage(context, 'Failed to complete Paper Store work: ${e.toString()}');
    }
  }

  Future<void> _handleWorkFormComplete(StepData step, Map<String, String> formData) async {
    try {
      print('JobStep - Received formData:');
      print('Qty Sheet: ${formData['Qty Sheet']}');
      print('Full formData: $formData');

      showDialog(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (context) => JobTimelineUI.buildLoadingDialog('Completing work...'),
      );

      final stepNo = StepDataManager.getStepNumber(step.type);

      await _apiService.putStepDetails(step.type, widget.jobNumber!, formData, stepNo);

        // Try to update step status to stop, but don't fail if it's already completed
        try {
          await _apiService.updateJobPlanningStepComplete(widget.jobNumber!, stepNo, "stop", additionalFields: formData);
        print('Successfully updated step status to stop');
      } catch (e) {
        print('Failed to update step status to stop: $e');
        // If it's a validation error, just log and continue
        if (e.toString().contains('400') || e.toString().contains('Invalid transition')) {
          print('Step status update failed due to validation, but continuing with completion...');
        } else {
          // Re-throw other errors
          throw e;
        }
      }

      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      final stepIndex = steps.indexOf(step);
      setState(() {
        step.formData = formData;
        step.status = StepStatus.completed;
        // Clear started step index when step is completed
        if (_startedStepIndex == stepIndex) {
          _startedStepIndex = null;
          _startedStepType = null;
          _freezeAtStarted = false;
          print('Cleared started step index after completing ${step.title}');
        }
      });

      // reflect completed status in cached planning details
      if (_stepDetailsCache.containsKey(stepNo)) {
        final cachedDetails = _stepDetailsCache[stepNo];
        if (cachedDetails != null && cachedDetails is Map) {
          cachedDetails['status'] = 'stop';
        }
      }

      await _optimizedStepProgressionCheck(step, stepIndex);

      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context); // Close WorkActionForm dialog
      }

      DialogManager.showSuccessMessage(context, '${step.title} completed successfully!');

      // Clear all caches immediately to force fresh data
      _apiService.clearAllJobCaches(widget.jobNumber!);
      _clearAllCaches();

      // Immediately update the UI state
      if (mounted) {
        setState(() {
          // Force UI refresh to show updated status
        });
      }

      // Trigger immediate comprehensive refresh
      Future.delayed(Duration(milliseconds: 100), () {
        if (mounted) {
          print('Auto-refreshing after work completion...');
          _refreshAllStepData();
        }
      });
      
      // Additional refresh after a longer delay to ensure backend sync
      Future.delayed(Duration(milliseconds: 1000), () {
        if (mounted) {
          print('Secondary auto-refresh after work completion...');
          _refreshAllStepData();
        }
      });

    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      // Check if it's an access denied error (403)
      if (e.toString().contains('403') || e.toString().contains('Access Denied')) {
        DialogManager.showAccessDeniedMessage(context);
      } else if (!e.toString().contains('400') && !e.toString().contains('validation')) {
        // Only show error for actual failures, not validation errors
        DialogManager.showErrorMessage(context, 'Failed to complete work: ${e.toString()}');
      }
    }
  }

  /// Optimized step progression check using cached data
  Future<void> _optimizedStepProgressionCheck(StepData step, int stepIndex) async {
      // Check if all parallel steps are completed before moving to next step
      bool shouldMoveToNext = true;
      if (StepProgressManager.canRunInParallel(step.type)) {
        shouldMoveToNext = StepProgressManager.areAllParallelStepsCompleted(steps, step.type);
        print('Step ${step.title} can run in parallel. All parallel steps completed: $shouldMoveToNext');
      }

      if (shouldMoveToNext) {
      // Check for any planned steps that should become active using cached data
        bool hasPlannedStep = false;
        for (int i = 1; i < steps.length; i++) {
          if (steps[i].status == StepStatus.pending) {
            final checkStepNo = StepDataManager.getStepNumber(steps[i].type);
          final stepDetails = _stepDetailsCache[checkStepNo];
          
          // If not in cache, load it
          if (stepDetails == null) {
            try {
              final loadedDetails = await _apiService.getJobPlanningStepDetails(widget.jobNumber!, checkStepNo);
              _stepDetailsCache[checkStepNo] = loadedDetails;
              if (loadedDetails != null && loadedDetails['status'] == 'planned') {
              hasPlannedStep = true;
              setState(() {
                if (!currentActiveSteps.contains(i)) {
                  currentActiveSteps.add(i);
                }
              });
              print('Found planned step ${steps[i].title}, adding to active steps');
              break;
            }
            } catch (e) {
              print('Error checking planned step: $e');
            }
          } else if (stepDetails['status'] == 'planned') {
            hasPlannedStep = true;
            setState(() {
              if (!currentActiveSteps.contains(i)) {
                currentActiveSteps.add(i);
              }
            });
            print('Found planned step ${steps[i].title}, adding to active steps');
            break;
          }
          }
        }

        if (!hasPlannedStep) {
          StepProgressManager.moveToNextStep(
            steps,
            stepIndex,
                (newActiveStep) => setState(() {
              if (!currentActiveSteps.contains(newActiveStep)) {
                currentActiveSteps.add(newActiveStep);
              }
            }),
                (message) => DialogManager.showSuccessMessage(context, message),
          );
        }
      } else {
        print('Not moving to next step yet - waiting for parallel steps to complete');
      }
  }

  /// Clear all caches to force fresh data
  void _clearAllCaches() {
    _stepDetailsCache.clear();
    _individualStepDetailsCache.clear();
    _paperStoreCache = null;
    _completedStepDetailsCache.clear();
    jobDetails = null; // Clear job details cache too
  }

  /// Refresh all step data and trigger UI update
  Future<void> _refreshAllStepData() async {
    try {
      print('🔄 [RefreshAllStepData] Starting comprehensive refresh...');
      
      // Clear all caches first
      _clearAllCaches();
      
      // Reset started step tracking
      _startedStepIndex = null;
      _startedStepType = null;
      _freezeAtStarted = false;
      
      // Fetch fresh job details
      await _fetchJobDetails();
      
      // Fetch fresh planning steps
      final planningData = await _apiService.getJobPlanningStepsByNrcJobNo(widget.jobNumber!);
      print('🔄 [RefreshAllStepData] Fetched planning data: ${planningData != null ? 'success' : 'failed'}');
      
      // Process all steps with fresh data
      await _processAllStepsWithCachedData();
      
      // Determine active steps
      _determineCurrentActiveSteps();
      
      // Force UI update
      if (mounted) {
        setState(() {
          print('🔄 [RefreshAllStepData] UI updated with fresh data - Active steps: $currentActiveSteps');
        });
      }
      
      print('✅ [RefreshAllStepData] Comprehensive refresh completed successfully');
    } catch (e) {
      print('❌ [RefreshAllStepData] Error during refresh: $e');
      // Even if there's an error, try to update the UI with whatever data we have
      if (mounted) {
        setState(() {
          print('🔄 [RefreshAllStepData] UI updated despite error');
        });
      }
    }
  }

  /// Optimized refresh method that uses cached data when possible
  Future<void> _refreshStepStatuses() async {
    if (widget.jobNumber == null) return;

    if (steps.isEmpty || steps.length <= 1) {
      print('No steps available for user role: $_userRoles');
      return;
    }

    _clearAllCaches();

    await _batchLoadStepDetails();
    await _processAllStepsWithCachedData();

    _determineCurrentActiveSteps();
  }


  void _showCompleteJobDetails() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (context) => JobTimelineUI.buildLoadingDialog('Details are loading, please wait...'),
    );

    await _fetchJobDetails();
    Navigator.of(context).pop();

    // Convert jobDetails (List<Job>) to Map<String, dynamic> for DialogManager
    Map<String, dynamic>? jobDetailsMap;
    if (jobDetails != null) {
      final jobData = jobDetails is List ? (jobDetails as List)[0] : jobDetails;
      if (jobData != null) {
        // Convert to Map if it's not already a Map
        Map<String, dynamic> jobMap;
        if (jobData is Map) {
          jobMap = Map<String, dynamic>.from(jobData);
        } else {
          // If it's a Job object, convert to Map
          jobMap = {
            'id': jobData.id,
            'nrcJobNo': jobData.nrcJobNo,
            'styleItemSKU': jobData.styleItemSKU,
            'customerName': jobData.customerName,
            'status': jobData.status,
            'fluteType': jobData.fluteType,
            'jobDemand': jobData.jobDemand,
            'srNo': jobData.srNo,
            'length': jobData.length,
            'width': jobData.width,
            'height': jobData.height,
            'boxDimensions': jobData.boxDimensions,
            'boardSize': jobData.boardSize,
            'noUps': jobData.noUps,
            'boardCategory': jobData.boardCategory,
            'diePunchCode': jobData.diePunchCode,
            'topFaceGSM': jobData.topFaceGSM,
            'flutingGSM': jobData.flutingGSM,
            'bottomLinerGSM': jobData.bottomLinerGSM,
            'decalBoardX': jobData.decalBoardX,
            'lengthBoardY': jobData.lengthBoardY,
            'noOfColor': jobData.noOfColor,
            'overPrintFinishing': jobData.overPrintFinishing,
            'purchaseOrders': jobData.purchaseOrders,
            'purchaseOrder': jobData.purchaseOrder,
          };
        }

        jobDetailsMap = {
          'Job ID': jobMap['id']?.toString() ?? 'N/A',
          'Job Number': jobMap['nrcJobNo']?.toString() ?? 'N/A',
          'Style Item SKU': jobMap['styleItemSKU']?.toString() ?? 'N/A',
          'Customer Name': jobMap['customerName']?.toString() ?? 'N/A',
          'Status': jobMap['status']?.toString() ?? 'N/A',
          'Flute Type': jobMap['fluteType']?.toString() ?? 'N/A',
          'Job Demand': jobMap['jobDemand']?.toString() ?? 'N/A',
          'SR Number': jobMap['srNo']?.toString() ?? 'N/A',

          'Length': jobMap['length']?.toString() ?? 'N/A',
          'Width': jobMap['width']?.toString() ?? 'N/A',
          'Height': jobMap['height']?.toString() ?? 'N/A',
          'Box Dimensions': jobMap['boxDimensions']?.toString() ?? 'N/A',
          'Board Size': jobMap['boardSize']?.toString() ?? 'N/A',
          'No Ups': jobMap['noUps']?.toString() ?? 'N/A',

          'Board Category': jobMap['boardCategory']?.toString() ?? 'N/A',
          'Die Punch Code': jobMap['diePunchCode']?.toString() ?? 'N/A',
          'Top Face GSM': jobMap['topFaceGSM']?.toString() ?? 'N/A',
          'Fluting GSM': jobMap['flutingGSM']?.toString() ?? 'N/A',
          'Bottom Liner GSM': jobMap['bottomLinerGSM']?.toString() ?? 'N/A',
          'Decal Board X': jobMap['decalBoardX']?.toString() ?? 'N/A',
          'Length Board Y': jobMap['lengthBoardY']?.toString() ?? 'N/A',

          'No Of Color': jobMap['noOfColor']?.toString() ?? 'N/A',
          'Process Colors': jobMap['processColors']?.toString() ?? 'N/A',
          'Special Color 1': jobMap['specialColor1']?.toString() ?? 'N/A',
          'Special Color 2': jobMap['specialColor2']?.toString() ?? 'N/A',
          'Special Color 3': jobMap['specialColor3']?.toString() ?? 'N/A',
          'Special Color 4': jobMap['specialColor4']?.toString() ?? 'N/A',
          'Over Print Finishing': jobMap['overPrintFinishing']?.toString() ?? 'N/A',

          'Latest Rate': jobMap['latestRate']?.toString() ?? 'N/A',
          'Pre Rate': jobMap['preRate']?.toString() ?? 'N/A',

          'Artwork Received Date': jobMap['artworkReceivedDate']?.toString() ?? 'N/A',
          'Artwork Approval Date': jobMap['artworkApprovalDate']?.toString() ?? 'N/A',
          'Shade Card Approval Date': jobMap['shadeCardApprovalDate']?.toString() ?? 'N/A',
          'Image URL': jobMap['imageURL']?.toString() ?? 'N/A',

          'User ID': jobMap['userId']?.toString() ?? 'N/A',
          'Machine ID': jobMap['machineId']?.toString() ?? 'N/A',
          'Created At': jobMap['createdAt']?.toString() ?? 'N/A',
          'Updated At': jobMap['updatedAt']?.toString() ?? 'N/A',
          'Has Purchase Orders': jobMap['hasPurchaseOrders']?.toString() ?? 'N/A',
        };

        final purchaseOrders = jobMap['purchaseOrders'];
        if (purchaseOrders != null && purchaseOrders is List && purchaseOrders.isNotEmpty) {
          final po = purchaseOrders[0];
          if (po is Map) {
            jobDetailsMap['PO ID'] = po['id']?.toString() ?? 'N/A';
            jobDetailsMap['PO Number'] = po['poNumber']?.toString() ?? 'N/A';
            jobDetailsMap['Total PO Quantity'] = po['totalPOQuantity']?.toString() ?? 'N/A';
            jobDetailsMap['Unit'] = po['unit']?.toString() ?? 'N/A';
            jobDetailsMap['PO Status'] = po['status']?.toString() ?? 'N/A';
            jobDetailsMap['PO Created At'] = po['createdAt']?.toString() ?? 'N/A';
            jobDetailsMap['PO Updated At'] = po['updatedAt']?.toString() ?? 'N/A';
          }
        }

        final purchaseOrder = jobMap['purchaseOrder'];
        if (purchaseOrder != null && purchaseOrder is Map) {
          jobDetailsMap['Single PO ID'] = purchaseOrder['id']?.toString() ?? 'N/A';
          jobDetailsMap['Single PO Number'] = purchaseOrder['poNumber']?.toString() ?? 'N/A';
          jobDetailsMap['Single PO Quantity'] = purchaseOrder['totalPOQuantity']?.toString() ?? 'N/A';
          jobDetailsMap['Single PO Unit'] = purchaseOrder['unit']?.toString() ?? 'N/A';
          jobDetailsMap['Single PO Status'] = purchaseOrder['status']?.toString() ?? 'N/A';
        }
      }
    }

    DialogManager.showJobDetailsDialog(context, widget.jobNumber, jobDetailsMap);
  }

  // Cache for completed step details
  Map<StepType, Map<String, dynamic>?> _completedStepDetailsCache = {};

  void _showCompletedStepDetails(StepData step) async {
    print('DEBUG: _showCompletedStepDetails called for step: ${step.title} (${step.type})');
    
    // Check cache first
    if (_completedStepDetailsCache.containsKey(step.type)) {
      final cachedDetails = _completedStepDetailsCache[step.type];
      if (cachedDetails != null) {
        _showStepDetailsDialog(step, cachedDetails);
        return;
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (context) => JobTimelineUI.buildLoadingDialog('Loading step details...'),
    );

    try {
      Map<String, dynamic>? stepDetails;

      switch (step.type) {
        case StepType.printing:
          print('DEBUG: Fetching printing details for job: ${widget.jobNumber}');
          stepDetails = await _apiService.getPrintingDetails(widget.jobNumber!);
          print('DEBUG: Printing details response: $stepDetails');
          break;
        case StepType.corrugation:
          print('DEBUG: Fetching corrugation details for job: ${widget.jobNumber}');
          stepDetails = await _apiService.getCorrugationDetails(widget.jobNumber!);
          print('DEBUG: Corrugation details response: $stepDetails');
          break;
        case StepType.fluteLamination:
          print('DEBUG: Fetching flute lamination details for job: ${widget.jobNumber}');
          stepDetails = await _apiService.getFluteLaminationDetails(widget.jobNumber!);
          print('DEBUG: Flute lamination details response: $stepDetails');
          break;
        case StepType.punching:
          print('DEBUG: Fetching punching details for job: ${widget.jobNumber}');
          stepDetails = await _apiService.getPunchingDetails(widget.jobNumber!);
          print('DEBUG: Punching details response: $stepDetails');
          break;
        case StepType.flapPasting:
          print('DEBUG: Fetching flap pasting details for job: ${widget.jobNumber}');
          stepDetails = await _apiService.getFlapPastingDetails(widget.jobNumber!);
          print('DEBUG: Flap pasting details response: $stepDetails');
          break;
        case StepType.qc:
          print('DEBUG: Fetching QC details for job: ${widget.jobNumber}');
          stepDetails = await _apiService.getQCDetails(widget.jobNumber!);
          print('DEBUG: QC details response: $stepDetails');
          break;
        case StepType.dispatch:
          print('DEBUG: Fetching dispatch details for job: ${widget.jobNumber}');
          stepDetails = await _apiService.getDispatchDetails(widget.jobNumber!);
          print('DEBUG: Dispatch details response: $stepDetails');
          break;
        case StepType.paperStore:
          print('DEBUG: Fetching paper store details for job: ${widget.jobNumber}');
          stepDetails = await _apiService.getPaperStoreStepByJob(widget.jobNumber!);
          print('DEBUG: Paper store details response: $stepDetails');
          break;
        default:
          print('DEBUG: Unknown step type: ${step.type}');
          stepDetails = null;
      }

      if (mounted) Navigator.pop(context); // Close loading dialog

      if (stepDetails != null) {
        // Handle different response structures
        Map<String, dynamic> details;
        if (stepDetails['data'] != null && stepDetails['data'] is List && stepDetails['data'].isNotEmpty) {
          // Standard response structure with data array
          details = stepDetails['data'][0];
        } else if (stepDetails['data'] != null && stepDetails['data'] is Map) {
          // Direct data object
          details = stepDetails['data'];
        } else if (step.type == StepType.paperStore && stepDetails is Map) {
          // Paper Store specific - data is directly in the response
          details = stepDetails;
        } else {
          details = {};
        }

        if (details.isNotEmpty) {
          // Cache the details for future use
          _completedStepDetailsCache[step.type] = details;
          _showStepDetailsDialog(step, details);
        } else {
          // Handle case where step is assigned but has no details yet
          // Show a message indicating the step is ready to start
          _showStepReadyToStartDialog(step);
        }
      } else {
        // Handle case where step is assigned but has no details yet
        _showStepReadyToStartDialog(step);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading dialog
      DialogManager.showErrorMessage(context, 'Failed to load ${step.title} details: ${e.toString()}');
    }
  }

  void _showStepDetailsDialog(StepData step, Map<String, dynamic> details) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.white,
        title: Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.maincolor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${step.title} Details',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Job Number: ${widget.jobNumber}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              // Show only Status and Quantity
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        'Status:',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${details['status'] ?? 'N/A'}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        'Quantity:',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${details['quantity'] ?? 'N/A'}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showStepReadyToStartDialog(StepData step) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.white,
        title: Row(
          children: [
            Icon(Icons.play_circle_outline, color: Colors.green[600]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${step.title} - Ready to Start',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Job Number: ${widget.jobNumber}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.green[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This step is assigned to you but has no work details yet. You can start working on it when it becomes active.',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Status: Ready to Start',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'This step will become available when previous steps are completed.',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatFieldName(String fieldName) {
    // Convert camelCase or snake_case to Title Case
    return fieldName
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}' : '')
        .join(' ');
  }

  /// Convert jobDetails (List<Job>) to Map<String, dynamic> for Paper Store APIs
  Map<String, dynamic> _convertJobDetailsToMap() {
    Map<String, dynamic> jobDetailsMap = {};
    if (jobDetails != null) {
      final jobData = jobDetails is List ? (jobDetails as List)[0] : jobDetails;
      if (jobData != null) {
        // Convert Job object to Map
        jobDetailsMap = {
          'boardSize': jobData.boxDimensions,
          'noUps': jobData.purchaseOrders?.isNotEmpty == true
              ? jobData.purchaseOrders![0].totalPOQuantity
              : 0,
          'fluteType': jobData.fluteType,
        };
      }
    }
    return jobDetailsMap;
  }

  /// Safely decode base64 image data, handling various formats
  Uint8List? _safeBase64Decode(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return null;

    try {
      String base64Data = imageUrl;

      // Handle data URLs (e.g., "data:image/jpeg;base64,/9j/4AAQ...")
      if (imageUrl.startsWith('data:')) {
        final parts = imageUrl.split(',');
        if (parts.length > 1) {
          base64Data = parts[1];
        }
      }

      // Handle URLs with metadata (e.g., "image/jpeg; base64,/9j/4AAQ...")
      if (base64Data.contains('; base64,')) {
        final parts = base64Data.split('; base64,');
        if (parts.length > 1) {
          base64Data = parts[1];
        }
      }

      // Clean up any remaining whitespace or newlines
      base64Data = base64Data.trim();

      return base64Decode(base64Data);
    } catch (e) {
      print('Error decoding base64 image: $e');
      return null;
    }
  }

  /// Show full screen image viewer
  void _showFullScreenImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return;

    final imageData = _safeBase64Decode(imageUrl);
    if (imageData == null) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            // Full screen image
            InteractiveViewer(
              child: Center(
                child: Image.memory(
                  imageData,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[900],
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image, color: Colors.grey[400], size: 64),
                            const SizedBox(height: 16),
                            Text(
                              'Image not available',
                              style: TextStyle(color: Colors.grey[400], fontSize: 18),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            // Close button
            Positioned(
              top: 40,
              right: 20,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 24,
                  ),
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.assignment, color: AppColors.maincolor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Job ${widget.jobNumber ?? ''}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blue),
            tooltip: 'Reload Job Data',
            onPressed: () async {
              // Show loading indicator
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => JobTimelineUI.buildLoadingDialog('Refreshing...'),
              );

              try {
                // Use comprehensive refresh method
                await _refreshAllStepData();

                // Close loading dialog
                if (mounted) {
                  Navigator.pop(context);
                }

                // Show success message
                if (mounted) {
                  DialogManager.showSuccessMessage(context, 'Jobs reloaded successfully!');
                }
              } catch (e) {
                // Close loading dialog
                if (mounted) {
                  Navigator.pop(context);
                }

                // Show error message
                if (mounted) {
                  DialogManager.showErrorMessage(context, 'Failed to reload job data: ${e.toString()}');
                }
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshStepStatuses,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Show loading indicator while initializing
              if (_isInitializing)
                Container(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.all(16),
                  child: Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(_loadingMessage),
                      ],
                    ),
                  ),
                )
              // Show message if no steps available for user role
              else if (steps.length <= 1)
                Container(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.orange[700],
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No Steps Available',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No steps are available for your roles: ${_userRoles.join(', ')}\n\nThis job may not have the steps you can work on, or the steps may not be assigned yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.orange[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              // Navigate to job list to find other jobs
                              Navigator.of(context).pushNamedAndRemoveUntil(
                                '/jobs',
                                (route) => false,
                              );
                            },
                            icon: Icon(Icons.list, size: 18),
                            label: Text('View All Jobs'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[600],
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              else
                JobTimelineUI.buildProgressIndicator(steps),
              if (steps.length > 1)
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: steps.length,
                  itemBuilder: (context, index) {
                    final step = steps[index];
                    return Column(
                      children: [
                        StepItemWidget(
                          step: step,
                          index: index,
                          isActive: _isStepActive(step),
                          jobNumber: widget.jobNumber,
                          onTap: () => _handleStepTap(step),
                        ),
                        // Show Step Details button right after any active step
                        if (currentActiveSteps.contains(index) && index > 0)
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showJobDetailsDialog(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.blue[700],
                                elevation: 2,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.blue[200]!),
                                ),
                              ),
                              icon: Icon(Icons.info_outline, size: 20),
                              label: Text(
                                'Step Details',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  /// ========================================
  /// PERMANENT STATE SYNCHRONIZATION SYSTEM
  /// ========================================
  
  /// Start periodic state validation to prevent frontend-backend sync issues
  void _startPeriodicStateValidation() {
    // Validate state every 30 seconds
    Future.delayed(Duration(seconds: 30), () {
      if (mounted) {
        _validateAndSyncState();
        _startPeriodicStateValidation(); // Schedule next validation
      }
    });
  }
  
  /// Comprehensive state validation and synchronization
  Future<void> _validateAndSyncState() async {
    if (_isValidatingState || widget.jobNumber == null) return;
    
    _isValidatingState = true;
    print('🔄 [StateSync] Starting comprehensive state validation...');
    
    try {
      // 1. Fetch fresh data from backend
      final freshPlanningData = await _apiService.getJobPlanningStepsByNrcJobNo(widget.jobNumber!);
      if (freshPlanningData == null) {
        print('❌ [StateSync] Failed to fetch fresh planning data');
        return;
      }
      
      // 2. Compare with current frontend state
      final backendState = _extractBackendState(freshPlanningData);
      final frontendState = _extractFrontendState();
      
      // 3. Check for inconsistencies
      final inconsistencies = _detectStateInconsistencies(frontendState, backendState);
      
      if (inconsistencies.isNotEmpty) {
        print('⚠️ [StateSync] Found ${inconsistencies.length} inconsistencies:');
        for (final inconsistency in inconsistencies) {
          print('   - $inconsistency');
        }
        
        // 4. Auto-correct inconsistencies
        await _autoCorrectStateInconsistencies(inconsistencies, backendState);
        
        // 5. Refresh UI
        if (mounted) {
          setState(() {
            _lastStateValidation = DateTime.now();
            _lastKnownBackendState = backendState;
          });
        }
        
        print('✅ [StateSync] State inconsistencies corrected');
      } else {
        print('✅ [StateSync] No inconsistencies found - state is synchronized');
      }
      
    } catch (e) {
      print('❌ [StateSync] Error during state validation: $e');
    } finally {
      _isValidatingState = false;
    }
  }
  
  /// Extract current backend state from planning data
  Map<String, dynamic> _extractBackendState(Map<String, dynamic> planningData) {
    final Map<String, dynamic> backendState = {};
    
    if (planningData['steps'] is List) {
      final steps = planningData['steps'] as List;
      for (final step in steps) {
        if (step is Map && step['stepName'] != null && step['status'] != null) {
          final stepName = step['stepName'].toString();
          final status = step['status'].toString();
          final stepNo = step['stepNo'];
          
          backendState[stepName] = {
            'status': status,
            'stepNo': stepNo,
            'startDate': step['startDate'],
            'endDate': step['endDate'],
            'user': step['user'],
          };
        }
      }
    }
    
    return backendState;
  }
  
  /// Extract current frontend state
  Map<String, dynamic> _extractFrontendState() {
    final Map<String, dynamic> frontendState = {};
    
    for (int i = 0; i < steps.length; i++) {
      final step = steps[i];
      final stepName = _getStepNameFromType(step.type);
      
      frontendState[stepName] = {
        'status': _getStepStatusString(step.status),
        'stepNo': StepDataManager.getStepNumber(step.type),
        'isActive': currentActiveSteps.contains(i),
        'hasFormData': step.formData.isNotEmpty,
      };
    }
    
    return frontendState;
  }
  
  /// Detect inconsistencies between frontend and backend states
  List<String> _detectStateInconsistencies(
    Map<String, dynamic> frontendState, 
    Map<String, dynamic> backendState
  ) {
    final List<String> inconsistencies = [];
    
    // Check each step for inconsistencies
    for (final stepName in backendState.keys) {
      if (!frontendState.containsKey(stepName)) {
        inconsistencies.add('Missing step in frontend: $stepName');
        continue;
      }
      
      final frontendStep = frontendState[stepName];
      final backendStep = backendState[stepName];
      
      // Check status mismatch
      final frontendStatus = frontendStep['status'];
      final backendStatus = backendStep['status'];
      
      if (frontendStatus != backendStatus) {
        inconsistencies.add('Status mismatch for $stepName: Frontend=$frontendStatus, Backend=$backendStatus');
      }
      
      // Check if step should be active based on backend status
      final shouldBeActive = _shouldStepBeActive(backendStep);
      final isActive = frontendStep['isActive'];
      
      if (shouldBeActive != isActive) {
        inconsistencies.add('Active state mismatch for $stepName: Should be $shouldBeActive, Is $isActive');
      }
    }
    
    return inconsistencies;
  }
  
  /// Auto-correct state inconsistencies
  Future<void> _autoCorrectStateInconsistencies(
    List<String> inconsistencies, 
    Map<String, dynamic> backendState
  ) async {
    print('🔧 [StateSync] Auto-correcting ${inconsistencies.length} inconsistencies...');
    
    // Clear caches to force fresh data fetch
    _stepDetailsCache.clear();
    _paperStoreCache = null;
    
    // Re-process all steps with fresh backend data
    await _processAllStepsWithCachedData();
    
    // Force UI refresh
    if (mounted) {
      setState(() {
        // Trigger rebuild with corrected state
      });
    }
  }
  
  /// Check if a step should be active based on backend status
  bool _shouldStepBeActive(Map<String, dynamic> backendStep) {
    final status = backendStep['status']?.toString();
    
    switch (status) {
      case 'start':
        return true;
      case 'planned':
        // For new jobs, allow multiple steps to be active
        return true;
      case 'stop':
        return false;
      default:
        return false;
    }
  }
  
  /// Get step name from step type
  String _getStepNameFromType(StepType stepType) {
    switch (stepType) {
      case StepType.paperStore:
        return 'PaperStore';
      case StepType.printing:
        return 'PrintingDetails';
      case StepType.corrugation:
        return 'Corrugation';
      case StepType.fluteLamination:
        return 'FluteLaminateBoardConversion';
      case StepType.punching:
        return 'Punching';
      case StepType.flapPasting:
        return 'SideFlapPasting';
      case StepType.qc:
        return 'QualityDept';
      case StepType.dispatch:
        return 'DispatchProcess';
      default:
        return 'Unknown';
    }
  }


  /// Get step type string for API calls
  String? _getStepTypeString(StepType stepType) {
    switch (stepType) {
      case StepType.paperStore:
        return 'paper-store';
      case StepType.printing:
        return 'printing-details';
      case StepType.corrugation:
        return 'corrugation';
      case StepType.fluteLamination:
        return 'flute-laminate-board-conversion';
      case StepType.punching:
        return 'punching';
      case StepType.flapPasting:
        return 'side-flap-pasting';
      case StepType.qc:
        return 'quality-dept';
      case StepType.dispatch:
        return 'dispatch-process';
      default:
        return null;
    }
  }
  
  /// Get step status string from step status enum
  String _getStepStatusString(StepStatus status) {
    switch (status) {
      case StepStatus.pending:
        return 'planned';
      case StepStatus.started:
        return 'start';
      case StepStatus.inProgress:
        return 'in_progress';
      case StepStatus.hold:
        return 'hold';
      case StepStatus.completed:
        return 'stop';
      default:
        return 'planned';
    }
  }

  /// Fetch machine statuses from backend
  Future<List<Map<String, dynamic>>> _fetchMachineStatuses(String jobNumber, int stepNo) async {
    try {
      // Call the getAvailableMachines API to get machine statuses
      final response = await _apiService.getAvailableMachines(jobNumber, stepNo);
      
      if (response != null && response['machines'] != null) {
        final machines = response['machines'] as List;
        print('DEBUG: Fetched ${machines.length} machine statuses');
        return machines.cast<Map<String, dynamic>>();
      }
      
      return [];
    } catch (e) {
      print('DEBUG: Error fetching machine statuses: $e');
      return [];
    }
  }

  /// Get machine status from the fetched machine statuses
  String _getMachineStatus(String? machineId, List<Map<String, dynamic>> machineStatuses) {
    if (machineId == null || machineStatuses.isEmpty) return 'available';
    
    // Find the machine in the statuses list
    final machine = machineStatuses.firstWhere(
      (m) => m['machineId'] == machineId,
      orElse: () => <String, dynamic>{},
    );
    
    if (machine.isEmpty) return 'available';
    
    return machine['status'] ?? 'available';
  }

  /// Get machine details for a specific step (original method)
  Future<List<Map<String, dynamic>>?> _getMachineDetailsForStep(StepData step) async {
    final stepNo = _getStepNumber(step);
    if (stepNo == null || widget.jobNumber == null) return null;

    print('DEBUG: Getting machine details for step $stepNo');
    
    // Use the original method - get from step data
    final stepDetails = _stepDetailsCache[stepNo];
    if (stepDetails == null) {
      print('DEBUG: No step details in cache, fetching...');
      try {
        await _fetchStepDetails(step.type);
        final updatedStepDetails = _stepDetailsCache[stepNo];
        if (updatedStepDetails == null) return null;
        
        final machineDetails = updatedStepDetails['machineDetails'];
        if (machineDetails == null || machineDetails is! List) return null;
        
        print('DEBUG: Found machine details: $machineDetails');
        return machineDetails
            .where((machine) => machine is Map<String, dynamic>)
            .cast<Map<String, dynamic>>()
            .toList();
      } catch (e) {
        print('DEBUG: Error fetching step details: $e');
        return null;
      }
    }

    final machineDetails = stepDetails['machineDetails'];
    if (machineDetails == null || machineDetails is! List) {
      print('DEBUG: No machine details in step details');
      return null;
    }

    print('DEBUG: Found machine details in cache: $machineDetails');
    return machineDetails
        .where((machine) => machine is Map<String, dynamic>)
        .cast<Map<String, dynamic>>()
        .toList();
  }

  /// Get step number for a step
  int? _getStepNumber(StepData step) {
    // Use the StepDataManager to get the correct step number
    return StepDataManager.getStepNumber(step.type);
  }
  
  /// Manual state refresh - can be called by user (pull-to-refresh)
  Future<void> _manualStateRefresh() async {
    print('🔄 [ManualRefresh] User triggered state refresh...');
    
    // Clear all caches and reload fresh data
    await _initializeAndLoadData();
  }
  

  @override
  void dispose() {
    // Cancel any ongoing operations to prevent setState calls after dispose
    super.dispose();
  }
}