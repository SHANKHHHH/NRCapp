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
  late List<StepData> steps;
  int currentActiveStep = 0;
  Map<String, dynamic>? jobDetails;
  bool _jobLoading = false;
  String? _jobError;
  late final JobApiService _apiService;

  @override
  void initState() {
    super.initState();
    _apiService = JobApiService(JobApi(DioService.instance));
    _initializeSteps();
    _initializeStepsWithBackendSync();
  }

  void _initializeSteps() {
    steps = StepDataManager.initializeSteps(widget.assignedSteps);
    if (steps.length > 1) {
      currentActiveStep = 1;
    }
  }

  Future<void> _initializeStepsWithBackendSync() async {
    if (widget.jobNumber == null) return;

    print('Starting backend sync for ${steps.length} steps...');

    // Sync all steps with backend
    for (int i = 1; i < steps.length; i++) {
      await _syncStepWithBackend(steps[i], i);
    }

    print('Backend sync completed. Determining current active step...');

    // After syncing all steps, determine the current active step
    _determineCurrentActiveStep();

    print('Initialization complete. Current active step: $currentActiveStep');
  }

  void _determineCurrentActiveStep() {
    setState(() {
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

      if (stepDetails != null) {
        final status = stepDetails['status'];
        final startDate = stepDetails['startDate'];
        final endDate = stepDetails['endDate'];

        print('Step ${step.title}: status=$status, startDate=$startDate, endDate=$endDate');

        setState(() {
          if (status == 'stop' && endDate != null) {
            step.status = StepStatus.completed;
            print('Step ${step.title} marked as COMPLETED');
          } else if (status == 'start' && startDate != null && endDate == null) {
            step.status = StepStatus.started;
            print('Step ${step.title} marked as STARTED (in progress)');
          } else if (status == 'planned') {
            step.status = StepStatus.pending;
            print('Step ${step.title} marked as PENDING (planned)');
            bool allPreviousCompleted = true;
            for (int j = 1; j < stepIndex; j++) {
              if (steps[j].status != StepStatus.completed) {
                allPreviousCompleted = false;
                break;
              }
            }
            if (allPreviousCompleted) {
              currentActiveStep = stepIndex;
              print('Forcing step ${step.title} to be active due to planned status');
            }
          } else {
            step.status = StepStatus.pending;
            print('Step ${step.title} marked as PENDING (fallback for status: $status)');
          }
        });

        // For Paper Store, also sync with paper store API
        if (step.type == StepType.paperStore) {
          await _syncPaperStoreStepWithBackend();
        }
      } else {
        setState(() {
          step.status = StepStatus.pending;
          print('Step ${step.title} marked as PENDING (no details found)');
        });
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
    print('Step tapped: ${step.title}, Status: ${step.status}');

    if (step.type == StepType.jobAssigned) {
      _showCompleteJobDetails();
      return;
    }

    final isActive = _isStepActive(step);
    print('Step ${step.title} - isActive: $isActive, status: ${step.status}');

    if (step.status == StepStatus.pending && isActive) {
      print('Showing start work dialog for ${step.title}');
      DialogManager.showStartWorkDialog(context, step, () => _startWork(step));
    } else if (step.status == StepStatus.started || step.status == StepStatus.inProgress) {
      print('Showing work form for ${step.title}');
      _showWorkForm(step);
    } else if (step.status == StepStatus.completed && step.formData.isNotEmpty) {
      print('Showing completed step details for ${step.title}');
      DialogManager.showCompletedStepDetails(context, step);
    } else {
      print('Step ${step.title} is not available. Status: ${step.status}, Active: $isActive');
      DialogManager.showErrorMessage(
          context,
          '${step.title} is not available yet. Complete previous steps first.'
      );
    }
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
      DialogManager.showErrorMessage(context, 'Failed to start work: ${e.toString()}');
    }
  }

  Future<void> _performStartWork(StepData step) async {
    final stepNo = StepDataManager.getStepNumber(step.type);

    if (jobDetails == null) {
      await _fetchJobDetails();
    }

    // Update job planning step status to 'start' with start date
    await _apiService.updateJobPlanningStepComplete(widget.jobNumber!, stepNo, "start");

    // For Paper Store, also create/update paper store record
    if (step.type == StepType.paperStore) {
      await _apiService.startPaperStoreWork(widget.jobNumber!, jobDetails ?? {});
    }
  }

  void _showWorkForm(StepData step) async {
    if (step.type == StepType.paperStore) {
      await _showPaperStoreForm(step);
      return;
    }

    final stepNo = StepDataManager.getStepNumber(step.type);

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
        onComplete: (formData) async {
          // Format date into proper UTC ISO string with .000Z
          String formatUtcDateToFixedIso(dynamic value) {
            if (value is DateTime) {
              final utc = value.toUtc();
              return "${utc.toIso8601String().split('.').first}.000Z";
            } else if (value is String) {
              final utc = DateTime.parse(value).toUtc();
              return "${utc.toIso8601String().split('.').first}.000Z";
            }
            return DateTime.now().toUtc().toIso8601String();
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
      jobDetails,
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
      await _apiService.completePaperStoreWork(widget.jobNumber!, jobDetails ?? {}, formData);

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
      showDialog(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (context) => JobTimelineUI.buildLoadingDialog('Completing work...'),
      );

      final stepNo = StepDataManager.getStepNumber(step.type);

      // Post step details to backend first
      await _apiService.postStepDetails(step.type, widget.jobNumber!, formData, stepNo);

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

    DialogManager.showJobDetailsDialog(context, widget.jobNumber, jobDetails);
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
              JobTimelineUI.buildProgressIndicator(steps),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: steps.length,
                itemBuilder: (context, index) {
                  final step = steps[index];
                  return StepItemWidget(
                    step: step,
                    index: index,
                    isActive: _isStepActive(step),
                    jobNumber: widget.jobNumber,
                    onTap: () => _handleStepTap(step),
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