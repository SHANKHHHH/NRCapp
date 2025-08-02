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
  List<StepData> steps = []; // Initialize with empty list
  int currentActiveStep = 0;
  dynamic jobDetails;
  bool _jobLoading = false;
  String? _jobError;
  late final JobApiService _apiService;
  String? _userRole;
  bool _isInitializing = true; // New loading state
  String _loadingMessage = 'Initializing...'; // Loading message for user feedback

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
        currentActiveStep = 1;
      }
    });
    print('Initialized ${steps.length} steps for user role: $_userRole');
  }

  Future<void> _initializeStepsWithBackendSync() async {
    if (widget.jobNumber == null) return;

    print('Starting backend sync for ${steps.length} steps...');

    // Check if user has any steps available for their role
    if (steps.isEmpty || steps.length <= 1) {
      print('No steps available for user role: $_userRole');
      return;
    }

    setState(() {
      _loadingMessage = 'Syncing with backend...';
    });

    // Create a list of futures for parallel execution
    List<Future<void>> syncFutures = [];

    for (int i = 1; i < steps.length; i++) {
      syncFutures.add(_syncStepWithBackend(steps[i], i));
    }

    // Execute all sync operations in parallel
    await Future.wait(syncFutures);

    print('Backend sync completed. Determining current active step...');

    setState(() {
      _loadingMessage = 'Finalizing...';
    });

    // After syncing all steps, determine the current active step
    _determineCurrentActiveStep();

    print('Initialization complete. Current active step: $currentActiveStep');
  }

  void _determineCurrentActiveStep() {
    setState(() {
      // Check if user has any steps available for their role
      if (steps.isEmpty || steps.length <= 1) {
        print('No steps available for user role: $_userRole');
        return;
      }

      // First priority: Find any step that is currently 'started' (in progress)
      for (int i = 1; i < steps.length; i++) {
        if (steps[i].status == StepStatus.started) {
          currentActiveStep = i;
          print('Found started step at index: $i (${steps[i].title})');
          return;
        }
      }

      // Second priority: Find any step with 'planned' status - stay on that step
      for (int i = 1; i < steps.length; i++) {
        if (steps[i].status == StepStatus.pending) {
          bool allPreviousCompleted = true;
          for (int j = 1; j < i; j++) {
            if (steps[j].status != StepStatus.completed) {
              allPreviousCompleted = false;
              break;
            }
          }

          if (allPreviousCompleted) {
            currentActiveStep = i;
            print('Found available step at index: $i (${steps[i].title}) - staying here until status changes to stop');
            return;
          }
        }
      }

      // Fallback: If no started or available step found, keep current
      print('No active step found, keeping current: $currentActiveStep');
    });
  }

  Future<void> _syncStepWithBackend(StepData step, int stepIndex) async {
    try {
      final stepNo = StepDataManager.getStepNumber(step.type);
      final stepDetails = await _apiService.getJobPlanningStepDetails(widget.jobNumber!, stepNo);
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
        print('Step  [33m${step.title} [0m marked as WORK COMPLETE (stop detected)');
        // Move to the next available step
        for (int i = stepIndex + 1; i < steps.length; i++) {
          if (steps[i].status == StepStatus.pending || steps[i].status == StepStatus.inProgress || steps[i].status == StepStatus.started) {
            setState(() {
              currentActiveStep = i;
            });
            print('Moved to next step: ${steps[i].title}');
            break;
          }
        }
        StepProgressManager.moveToNextStep(
          steps,
          stepIndex,
              (newActiveStep) => setState(() => currentActiveStep = newActiveStep),
              (message) => DialogManager.showSuccessMessage(context, message),
        );
        return;
      }

      // 2. Work Started: If either status is 'start'
      if (stepStatus == 'start' || planningStatus == 'start') {
        setState(() {
          step.status = StepStatus.started;
          currentActiveStep = stepIndex;
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
            currentActiveStep = stepIndex;
          });
          print('Forcing step ${step.title} to be active due to planned status');
        }
        return;
      }

      // 4. Fallback: Pending
      setState(() {
        step.status = StepStatus.pending;
        print('Step ${step.title} marked as PENDING (fallback)');
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
              currentActiveStep = paperStoreStepIndex;
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
    setState(() {
      _jobLoading = true;
      _jobError = null;
    });

    try {
      final details = await _apiService.fetchJobDetails(widget.jobNumber ?? '');
      print("This is the details I want");
      print(details?[0]);
      setState(() {
        // Handle the case where details might be a List<Job> or a single Job
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
    print('Step tapped: ${step.title}, Status: ${step.status}');

    if (step.type == StepType.jobAssigned) {
      _showCompleteJobDetails();
      return;
    }

    final isActive = _isStepActive(step);
    print('Step ${step.title} - isActive: $isActive, status: ${step.status}');

    if (step.status == StepStatus.pending && isActive) {
      // Check machine assignment before allowing start
      _checkMachineAssignmentAndStart(step);
    } else if (step.status == StepStatus.started || step.status == StepStatus.inProgress) {
      print('Showing work form for ${step.title}');
      _showWorkForm(step);
    } else if (step.status == StepStatus.completed) {
      print('Showing completed step details for ${step.title}');
      _showCompletedStepDetails(step);
    } else {
      print('Step ${step.title} is not available. Status: ${step.status}, Active: $isActive');
      DialogManager.showErrorMessage(
          context,
          '${step.title} is not available yet. Complete previous steps first.'
      );
    }
  }

  Future<void> _checkMachineAssignmentForPendingStep(StepData step) async {
    // Exclude these steps from machine assignment check
    final excludedSteps = [
      StepType.paperStore,
      StepType.qc,
      StepType.dispatch,
    ];

    if (excludedSteps.contains(step.type)) {
      print('Step ${step.title} is excluded from machine assignment check');
      // Don't show work details dialog for pending active step
      return;
    }

    try {
      // Get step details to check machine assignment
      final stepNo = StepDataManager.getStepNumber(step.type);
      final stepDetails = await _apiService.getJobPlanningStepDetails(widget.jobNumber!, stepNo);

      if (stepDetails != null && stepDetails is Map) {
        final machineDetails = stepDetails['machineDetails'];

        if (machineDetails != null && machineDetails is List && machineDetails.isNotEmpty) {
          final machineInfo = machineDetails[0];

          if (machineInfo is Map && machineInfo['machineType'] == 'Not assigned') {
            // Machine not assigned - show dialog
            _showMachineNotAssignedDialog(step);
            return;
          }

          // Machine is assigned - don't show work details dialog for pending active step
          print('Machine is assigned for ${step.title}, but not showing work details dialog');
          return;
        }
      }

      // No machine details found - don't show work details dialog for pending active step
      print('No machine details found for ${step.title}, but not showing work details dialog');

    } catch (e) {
      print('Error checking machine assignment for ${step.title}: $e');
      // Don't show work details dialog for pending active step
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
      // Get step details to check machine assignment
      final stepNo = StepDataManager.getStepNumber(step.type);
      final stepDetails = await _apiService.getJobPlanningStepDetails(widget.jobNumber!, stepNo);

      if (stepDetails != null && stepDetails is Map) {
        final machineDetails = stepDetails['machineDetails'];

        if (machineDetails != null && machineDetails is List && machineDetails.isNotEmpty) {
          final machineInfo = machineDetails[0];

          if (machineInfo is Map && machineInfo['machineType'] == 'Not assigned') {
            // Machine not assigned - show dialog
            _showMachineNotAssignedDialog(step);
            return;
          }

          // Machine is assigned - show start work dialog directly
          DialogManager.showStartWorkDialog(context, step, () => _startWork(step));
          return;
        }
      }

      // No machine details found - show start work dialog directly
      print('No machine details found for ${step.title}');
      DialogManager.showStartWorkDialog(context, step, () => _startWork(step));

    } catch (e) {
      print('Error checking machine assignment for ${step.title}: $e');
      // If there's an error checking, show start work dialog directly
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

  Future<void> _showWorkDetailsDialog(StepData step, Map<String, dynamic>? machineInfo) async {
    // Fetch job details if not already loaded
    if (jobDetails == null) {
      await _fetchJobDetails();
    }

    // Get PO details
    String poQuantity = 'N/A';
    String customerName = 'N/A';
    print("This is The Job Details");
    print(jobDetails);

    if (jobDetails != null) {
      // Check if jobDetails is a list and get the first item
      final jobData = jobDetails is List ? (jobDetails as List)[0] : jobDetails;
      print("this is the JobData: $jobData");
      if (jobData != null && jobData.purchaseOrders != null) {
        final purchaseOrders = jobData.purchaseOrders as List;
        if (purchaseOrders.isNotEmpty) {
          final po = purchaseOrders[0];
          print('Purchase Order Data: $po');
          poQuantity = '${po.totalPOQuantity ?? 'N/A'} ${po.unit ?? ''}';
          customerName = jobData.customerName ?? 'N/A';
          print('Quantity: $poQuantity');
          print('Customer: $customerName');
        }
      }
    }

    // Get artwork image
    String? imageUrl;
    if (jobDetails != null) {
      final jobData = jobDetails is List ? (jobDetails as List)[0] : jobDetails;
      imageUrl = jobData?.imageURL;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Icon(Icons.work, color: Colors.blue),
            const SizedBox(width: 8),
            Text('Work Details - ${step.title}'),
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
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Machine Details (if available)
              if (machineInfo != null)
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
                            'Machine Details',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Machine Code: ${machineInfo['machineCode'] ?? 'N/A'}'),
                      Text('Machine Type: ${machineInfo['machineType'] ?? 'N/A'}'),
                      Text('Unit: ${machineInfo['unit'] ?? 'N/A'}'),
                    ],
                  ),
                ),

              if (machineInfo != null) const SizedBox(height: 16),

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
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              DialogManager.showStartWorkDialog(context, step, () => _startWork(step));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: Text('Start Work'),
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

    // Get machine information for current active step only
    Map<String, dynamic>? currentStepMachineInfo;

    try {
      if (currentActiveStep > 0 && currentActiveStep < steps.length) {
        final currentStep = steps[currentActiveStep];
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
    bool isActive = stepIndex == currentActiveStep;
    print('Checking if step ${step.title} (index: $stepIndex) is active. Current active: $currentActiveStep, Result: $isActive');
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

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Update local state immediately for UI responsiveness
      setState(() {
        step.status = StepStatus.started;
        // Ensure this step becomes the current active step
        final stepIndex = steps.indexOf(step);
        if (stepIndex != -1) {
          currentActiveStep = stepIndex;
        }
      });

      // Show success message
      DialogManager.showSuccessMessage(context, '${step.title} work started!');

      // Force UI rebuild to reflect changes
      Future.delayed(Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() {
            // Trigger rebuild
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

    // Update job planning step status to 'start' with start date
    await _apiService.updateJobPlanningStepComplete(widget.jobNumber!, stepNo, "start");

    // For Paper Store, also create/update paper store record
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

    // Get expected quantity from job details
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
            // For current time - preserve local time
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

          // Ensure your formData uses formatted date
          formData['Date'] = formatUtcDateToFixedIso(formData['Date']);

          await _handleWorkFormComplete(step, formData);
        },
        onStart: () {
          setState(() {
            step.status = StepStatus.started;
            final stepIndex = steps.indexOf(step);
            if (stepIndex != -1) {
              currentActiveStep = stepIndex;
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
              (newActiveStep) => setState(() => currentActiveStep = newActiveStep),
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
      // Debug print to see what's being received
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

      // Post step details to backend first
      await _apiService.putStepDetails(step.type, widget.jobNumber!, formData, stepNo);

      // Then update job planning step status to 'stop' with end date
      await _apiService.updateJobPlanningStepComplete(widget.jobNumber!, stepNo, "stop");

      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context); // Close loading dialog
      }

      final stepIndex = steps.indexOf(step);
      setState(() {
        step.formData = formData;
        step.status = StepStatus.completed;
      });

      // Re-sync all steps to check for any 'planned' status
      await _refreshStepStatuses();

      // Check for any planned steps that should become active
      bool hasPlannedStep = false;
      for (int i = 1; i < steps.length; i++) {
        if (steps[i].status == StepStatus.pending) {
          final checkStepNo = StepDataManager.getStepNumber(steps[i].type);
          final stepDetails = await _apiService.getJobPlanningStepDetails(widget.jobNumber!, checkStepNo);
          if (stepDetails != null && stepDetails['status'] == 'planned') {
            hasPlannedStep = true;
            setState(() {
              currentActiveStep = i;
            });
            print('Found planned step ${steps[i].title}, staying on it');
            break;
          }
        }
      }

      if (!hasPlannedStep) {
        StepProgressManager.moveToNextStep(
          steps,
          stepIndex,
              (newActiveStep) => setState(() => currentActiveStep = newActiveStep),
              (message) => DialogManager.showSuccessMessage(context, message),
        );
      }

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

  // New method to refresh step statuses
  Future<void> _refreshStepStatuses() async {
    if (widget.jobNumber == null) return;

    // Check if user has any steps available for their role
    if (steps.isEmpty || steps.length <= 1) {
      print('No steps available for user role: $_userRole');
      return;
    }

    for (int i = 1; i < steps.length; i++) {
      await _syncStepWithBackend(steps[i], i);
    }

    _determineCurrentActiveStep();
  }

  void _submitForm(StepData step, Map<String, String> formData) {
    setState(() {
      step.formData = formData;
      step.status = StepStatus.inProgress;
    });
    DialogManager.showSuccessMessage(context, '${step.title} details saved successfully!');
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
            'processColors': jobData.processColors,
            'specialColor1': jobData.specialColor1,
            'specialColor2': jobData.specialColor2,
            'specialColor3': jobData.specialColor3,
            'specialColor4': jobData.specialColor4,
            'overPrintFinishing': jobData.overPrintFinishing,
            'latestRate': jobData.latestRate,
            'preRate': jobData.preRate,
            'artworkReceivedDate': jobData.artworkReceivedDate,
            'artworkApprovalDate': jobData.artworkApprovalDate,
            'shadeCardApprovalDate': jobData.shadeCardApprovalDate,
            'imageURL': jobData.imageURL,
            'userId': jobData.userId,
            'machineId': jobData.machineId,
            'createdAt': jobData.createdAt,
            'updatedAt': jobData.updatedAt,
            'hasPurchaseOrders': jobData.hasPurchaseOrders,
            'purchaseOrders': jobData.purchaseOrders,
            'purchaseOrder': jobData.purchaseOrder,
          };
        }

        // Convert Job object to Map<String, dynamic> with all available fields
        jobDetailsMap = {
          // Basic Job Information
          'Job ID': jobMap['id']?.toString() ?? 'N/A',
          'Job Number': jobMap['nrcJobNo']?.toString() ?? 'N/A',
          'Style Item SKU': jobMap['styleItemSKU']?.toString() ?? 'N/A',
          'Customer Name': jobMap['customerName']?.toString() ?? 'N/A',
          'Status': jobMap['status']?.toString() ?? 'N/A',
          'Flute Type': jobMap['fluteType']?.toString() ?? 'N/A',
          'Job Demand': jobMap['jobDemand']?.toString() ?? 'N/A',
          'SR Number': jobMap['srNo']?.toString() ?? 'N/A',
          
          // Dimensions
          'Length': jobMap['length']?.toString() ?? 'N/A',
          'Width': jobMap['width']?.toString() ?? 'N/A',
          'Height': jobMap['height']?.toString() ?? 'N/A',
          'Box Dimensions': jobMap['boxDimensions']?.toString() ?? 'N/A',
          'Board Size': jobMap['boardSize']?.toString() ?? 'N/A',
          'No Ups': jobMap['noUps']?.toString() ?? 'N/A',
          
          // Board Specifications
          'Board Category': jobMap['boardCategory']?.toString() ?? 'N/A',
          'Die Punch Code': jobMap['diePunchCode']?.toString() ?? 'N/A',
          'Top Face GSM': jobMap['topFaceGSM']?.toString() ?? 'N/A',
          'Fluting GSM': jobMap['flutingGSM']?.toString() ?? 'N/A',
          'Bottom Liner GSM': jobMap['bottomLinerGSM']?.toString() ?? 'N/A',
          'Decal Board X': jobMap['decalBoardX']?.toString() ?? 'N/A',
          'Length Board Y': jobMap['lengthBoardY']?.toString() ?? 'N/A',
          
          // Printing Details
          'No Of Color': jobMap['noOfColor']?.toString() ?? 'N/A',
          'Process Colors': jobMap['processColors']?.toString() ?? 'N/A',
          'Special Color 1': jobMap['specialColor1']?.toString() ?? 'N/A',
          'Special Color 2': jobMap['specialColor2']?.toString() ?? 'N/A',
          'Special Color 3': jobMap['specialColor3']?.toString() ?? 'N/A',
          'Special Color 4': jobMap['specialColor4']?.toString() ?? 'N/A',
          'Over Print Finishing': jobMap['overPrintFinishing']?.toString() ?? 'N/A',
          
          // Financial Information
          'Latest Rate': jobMap['latestRate']?.toString() ?? 'N/A',
          'Pre Rate': jobMap['preRate']?.toString() ?? 'N/A',
          
          // Artwork Information
          'Artwork Received Date': jobMap['artworkReceivedDate']?.toString() ?? 'N/A',
          'Artwork Approval Date': jobMap['artworkApprovalDate']?.toString() ?? 'N/A',
          'Shade Card Approval Date': jobMap['shadeCardApprovalDate']?.toString() ?? 'N/A',
          'Image URL': jobMap['imageURL']?.toString() ?? 'N/A',
          
          // System Information
          'User ID': jobMap['userId']?.toString() ?? 'N/A',
          'Machine ID': jobMap['machineId']?.toString() ?? 'N/A',
          'Created At': jobMap['createdAt']?.toString() ?? 'N/A',
          'Updated At': jobMap['updatedAt']?.toString() ?? 'N/A',
          'Has Purchase Orders': jobMap['hasPurchaseOrders']?.toString() ?? 'N/A',
        };
        
        // Add purchase order details if available
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
        
        // Add single purchase order if available
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

  void _showCompletedStepDetails(StepData step) async {
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
          stepDetails = await _apiService.getPrintingDetails(widget.jobNumber!);
          break;
        case StepType.corrugation:
          stepDetails = await _apiService.getCorrugationDetails(widget.jobNumber!);
          break;
        case StepType.fluteLamination:
          stepDetails = await _apiService.getFluteLaminationDetails(widget.jobNumber!);
          break;
        case StepType.punching:
          stepDetails = await _apiService.getPunchingDetails(widget.jobNumber!);
          break;
        case StepType.flapPasting:
          stepDetails = await _apiService.getFlapPastingDetails(widget.jobNumber!);
          break;
        case StepType.qc:
          stepDetails = await _apiService.getQCDetails(widget.jobNumber!);
          break;
        case StepType.dispatch:
          stepDetails = await _apiService.getDispatchDetails(widget.jobNumber!);
          break;
        case StepType.paperStore:
          stepDetails = await _apiService.getPaperStoreStepByJob(widget.jobNumber!);
          break;
        default:
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
              ...details.entries.map((entry) {
                if (entry.key == 'id' || entry.key == 'jobStepId' || entry.key == 'jobNrcJobNo') {
                  return const SizedBox.shrink(); // Skip internal fields
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 120,
                        child: Text(
                          '${_formatFieldName(entry.key)}:',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${entry.value ?? 'N/A'}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
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
                // Refresh job details
                await _fetchJobDetails();
                
                // Refresh step statuses
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
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.blue),
            tooltip: 'View Job Details',
            onPressed: _showCompleteJobDetails,
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
                        // Show Step Details button right after the current active step
                        if (index == currentActiveStep && index > 0)
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