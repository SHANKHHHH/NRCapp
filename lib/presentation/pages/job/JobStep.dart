import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:nrc/constants/colors.dart';
import 'package:nrc/core/services/dio_service.dart';
import 'package:nrc/presentation/pages/job/work_action_form.dart';
import 'package:nrc/presentation/pages/job/work_form.dart';
import 'package:nrc/presentation/pages/process/DialogManager.dart';
import '../../../data/datasources/job_api.dart';
import '../../../data/models/Job.dart';
import '../../../data/models/WorkStepAssignment.dart';
import '../../../data/models/job_step_models.dart';
import '../../routes/UserRoleManager.dart';
import '../process/JobApiService.dart';
import '../process/JobTimelineUI.dart';
import '../process/PaperStoreFormManager.dart';
import '../process/StepDataManager.dart';
import '../process/StepItemWidget.dart';
import '../process/StepProgressManager.dart';

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
  bool _jobLoading = false;
  String? _jobError;
  late final JobApiService _apiService;
  String? _userRole;
  bool _isInitializing = true;
  String _loadingMessage = 'Initializing...';
  List<String> _missingStepTitles = [];
  
  Map<int, Map<String, dynamic>?> _stepDetailsCache = {};
  // Freeze progression when a step is actively started
  int? _startedStepIndex;
  int? _startedStepNoFromPlanning;
  StepType? _startedStepType;
  bool _freezeAtStarted = false;
  Map<String, dynamic>? _paperStoreCache;
  bool _isDataLoaded = false;

  @override
  void initState() {
    super.initState();
    _apiService = JobApiService(JobApi(DioService.instance));
    _loadUserRoleAndInitializeSteps();
  }

  Future<void> _loadUserRoleAndInitializeSteps() async {
    setState(() {
      _isInitializing = true;
      _loadingMessage = 'Loading user role...';
    });

    // Load user role from UserRoleManager
    final userRoleManager = UserRoleManager();
    await userRoleManager.loadUserRole();
    _userRole = userRoleManager.userRole;

    print('User Role in JobTimelinePage: $_userRole');

    setState(() {
      _loadingMessage = 'Initializing steps...';
    });

    _initializeSteps();
    await _initializeStepsWithBackendSync();

    setState(() {
      _isInitializing = false;
    });
  }

  void _initializeSteps() {
    setState(() {
      steps = StepDataManager.initializeSteps(widget.assignedSteps, userRole: _userRole);
      if (steps.length > 1) {
        currentActiveSteps = [1]; // Initialize with first step
      }
    });
    print('Initialized ${steps.length} steps for user role: $_userRole');

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
  }

  /// Optimized backend sync that batches API calls and uses caching
  Future<void> _initializeStepsWithBackendSync() async {
    if (widget.jobNumber == null) return;

    print('Starting optimized backend sync for ${steps.length} steps...');

    // Check if user has any steps available for their role
    if (steps.isEmpty || steps.length <= 1) {
      print('No steps available for user role: $_userRole');
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
              print('Loaded planning step details (batched) for step $stepNo');
              if (_startedStepNoFromPlanning == null &&
                  (s['status']?.toString() == 'start')) {
                _startedStepNoFromPlanning = stepNo;
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
    }

    if (steps.any((step) => step.type == StepType.paperStore)) {
      batchFutures.add(_loadPaperStoreWithCache());
    }

    await Future.wait(batchFutures);
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

      // Process step status derived only from planning details
      _processStepStatus(step, i, stepDetails);

      if (_freezeAtStarted == true) {
        break;
      }

      // Special handling for Paper Store
      if (step.type == StepType.paperStore && _paperStoreCache != null) {
        _processPaperStoreStep(step, i);
      }
    }
  }

  void _processStepStatus(StepData step, int stepIndex, Map<String, dynamic>? stepDetails) {
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
      }
      // 3. Pending: If planning status is 'planned'
      else if (planningStatus == 'planned') {
        step.status = StepStatus.pending;
        print('Step ${step.title} marked as PENDING (planned)');
        
        // Check if all previous steps are completed
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
    if (_paperStoreCache != null) {
      final status = _paperStoreCache!['status'];
      
      setState(() {
        if (status == 'in_progress') {
          step.status = StepStatus.started;
          if (!currentActiveSteps.contains(stepIndex)) {
            currentActiveSteps.add(stepIndex);
          }
        } else if (status == 'accept') {
          step.status = StepStatus.completed;
        }
      });
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
      // Check if user has any steps available for their role
      if (steps.isEmpty || steps.length <= 1) {
        print('No steps available for user role: $_userRole');
        return;
      }

      List<int> activeSteps = [];

      // If we have a started step, keep it active and, for printing/corrugation,
      // also activate its parallel pair so both can run independently
      if (_startedStepIndex != null) {
        activeSteps = [_startedStepIndex!];

        if (_startedStepType == StepType.printing || _startedStepType == StepType.corrugation) {
          final parallelTypes = StepProgressManager.getParallelSteps(_startedStepType!);
          for (final parallelType in parallelTypes) {
            final parallelIndex = steps.indexWhere((s) => s.type == parallelType);
            if (parallelIndex != -1 && StepProgressManager.shouldActivateStep(steps, parallelIndex)) {
              activeSteps.add(parallelIndex);
            }
          }
        }

        currentActiveSteps = activeSteps;
        print('Freezing active steps at started index (with parallel if applicable): $currentActiveSteps');
        return;
      }

      // Find all steps that should be active
      for (int i = 1; i < steps.length; i++) {
        final step = steps[i];

        // Check if step is started or in progress
        if (step.status == StepStatus.started || step.status == StepStatus.inProgress) {
          activeSteps.add(i);
          print('Found active step at index: $i (${step.title})');
        }
        // Check if step is pending and should be activated
        else if (step.status == StepStatus.pending) {
          if (StepProgressManager.shouldActivateStep(steps, i)) {
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
              steps[paperStoreStepIndex].status = StepStatus.started;
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
      print(details?[0]);
      setState(() {
        jobDetails = details;
        _jobLoading = false;
      });
    } catch (e) {
      setState(() {
        _jobError = 'Failed to load job details';
        _jobLoading = false;
      });
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
      // Check machine assignment before allowing start
      _checkMachineAssignmentAndStart(step);
    } else if (step.status == StepStatus.started || step.status == StepStatus.inProgress) {
      print('DEBUG: Showing work form for ${step.title}');
      _showWorkForm(step);
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


  Future<void> _checkMachineAssignmentAndStart(StepData step) async {
    // Exclude these steps from machine assignment check
    final excludedSteps = [
      StepType.paperStore,
      StepType.qc,
      StepType.dispatch,
    ];

    if (excludedSteps.contains(step.type)) {
      print('Step ${step.title} is excluded from machine assignment check');
      // Show start work dialog directly for excluded steps
      DialogManager.showStartWorkDialog(context, step, () => _startWork(step));
      return;
    }

    try {
      // Use cached step details if available
      final stepNo = StepDataManager.getStepNumber(step.type);
      Map<String, dynamic>? stepDetails = _stepDetailsCache[stepNo];
      
      // If not in cache, load it
      if (stepDetails == null) {
        stepDetails = await _apiService.getJobPlanningStepDetails(widget.jobNumber!, stepNo);
        _stepDetailsCache[stepNo] = stepDetails;
      }

      if (stepDetails != null && stepDetails is Map) {
        final machineDetails = stepDetails['machineDetails'];

        if (machineDetails != null && machineDetails is List && machineDetails.isNotEmpty) {
          final machineInfo = machineDetails[0];

          if (machineInfo is Map && machineInfo['machineType'] == 'Not assigned') {
            _showMachineNotAssignedDialog(step);
            return;
          }

          // Machine is assigned - show start work dialog directly
          DialogManager.showStartWorkDialog(context, step, () => _startWork(step));
          return;
        }
      }

      print('No machine details found for ${step.title}');
      DialogManager.showStartWorkDialog(context, step, () => _startWork(step));

    } catch (e) {
      print('Error checking machine assignment for ${step.title}: $e');
      DialogManager.showStartWorkDialog(context, step, () => _startWork(step));
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
                  'machineId': machineInfo['id'] ?? 'Not assigned',
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
                              if (jobData?.styleItemSKU != null)
                                Text('Style: ${jobData.styleItemSKU}'),
                              if (jobData?.boxDimensions != null)
                                Text('Dimensions: ${jobData.boxDimensions}'),
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
    print('Checking if step ${step.title} (index: $stepIndex) is active. Current active steps: $currentActiveSteps, Result: $isActive');
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

      Future.delayed(Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() {
          });
        }
      });

    } catch (e) {
      if (mounted) Navigator.pop(context);
      print(e.toString());
      DialogManager.showErrorMessage(context, 'Failed to start work: ${e.toString()}');
    }
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

    // For other steps, use WorkActionForm
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WorkActionForm(
        title: step.title,
        description: step.description,
        initialQty: step.formData['Qty Sheet'] ?? '',
        hasData: step.formData.isNotEmpty,
        jobNumber: widget.jobNumber,
        stepNo: stepNo,
        apiService: _apiService,
        expectedQuantity: expectedQuantity,
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
        onStart: () {
          setState(() {
            step.status = StepStatus.started;
            final stepIndex = steps.indexOf(step);
            if (stepIndex != -1 && !currentActiveSteps.contains(stepIndex)) {
              currentActiveSteps.add(stepIndex);
            }
          });
          print('Work started for ${step.title}');
        },
        onPause: () {
          print('Work paused for ${step.title}');
        },
        onStop: () {
          print('Work stopped for ${step.title}');
        },
      ),
    );
  }

  Future<void> _showPaperStoreForm(StepData step) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (context) => JobTimelineUI.buildLoadingDialog('Loading...'),
    );

    if (jobDetails == null) {
      await _fetchJobDetails();
    }

    Navigator.of(context).pop();

    PaperStoreFormManager.showPaperStoreForm(
      context,
      step,
      widget.jobNumber,
      _convertJobDetailsToMap(),
          (formData) => _completePaperStoreWork(step, formData),
    );
  }

  Future<void> _completePaperStoreWork(StepData step, Map<String, String> formData) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (context) => JobTimelineUI.buildLoadingDialog('Completing Paper Store work...'),
      );

      // Complete paper store work (updates status to 'accept')
      await _apiService.completePaperStoreWork(widget.jobNumber!, _convertJobDetailsToMap(), formData);

      // Update job planning step status to 'stop' with end date
      await _apiService.updateJobPlanningStepComplete(widget.jobNumber!, 1, "stop");

      if (mounted) Navigator.pop(context);

      if (!mounted) return;

      final paperStoreStepIndex = steps.indexWhere((s) => s.type == StepType.paperStore);
      setState(() {
        step.status = StepStatus.completed;
        step.formData = formData;
      });

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

      DialogManager.showSuccessMessage(context, 'Paper Store work completed successfully!');
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

      await _apiService.updateJobPlanningStepComplete(widget.jobNumber!, stepNo, "stop");

      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      final stepIndex = steps.indexOf(step);
      setState(() {
        step.formData = formData;
        step.status = StepStatus.completed;
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

    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      DialogManager.showErrorMessage(context, 'Failed to complete work: ${e.toString()}');
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
    _paperStoreCache = null;
    _completedStepDetailsCache.clear();
    jobDetails = null; // Clear job details cache too
  }

  /// Optimized refresh method that uses cached data when possible
  Future<void> _refreshStepStatuses() async {
    if (widget.jobNumber == null) return;

    if (steps.isEmpty || steps.length <= 1) {
      print('No steps available for user role: $_userRole');
      return;
    }

    _clearAllCaches();

    List<int> completedStepIndices = [];
    for (int i = 1; i < steps.length; i++) {
      if (steps[i].status == StepStatus.completed) {
        completedStepIndices.add(i);
      }
    }

    await _batchLoadStepDetails();
    await _processAllStepsWithCachedData();

    for (int index in completedStepIndices) {
      if (index < steps.length) {
        steps[index].status = StepStatus.completed;
      }
    }

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
          DialogManager.showErrorMessage(context, 'No details found for ${step.title}');
        }
      } else {
        DialogManager.showErrorMessage(context, 'No details found for ${step.title}');
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
                builder: (context) => JobTimelineUI.buildLoadingDialog('Reloading...'),
              );

              try {
                // Clear all caches first
                _clearAllCaches();
                
                // Refresh job details
                await _fetchJobDetails();

                // Refresh step statuses using optimized method
                await _refreshStepStatuses();

                // Close loading dialog
                if (mounted) {
                  Navigator.pop(context);
                }

                // Show success message
                if (mounted) {
                  DialogManager.showSuccessMessage(context, 'Job data reloaded successfully!');
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
                        'No steps are available for your role: $_userRole\nPlease contact your administrator.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.orange[600],
                        ),
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
}