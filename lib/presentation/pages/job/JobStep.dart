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
    _syncPaperStoreStepWithBackend();
  }

  void _initializeSteps() {
    steps = StepDataManager.initializeSteps(widget.assignedSteps);
    if (steps.length > 1) {
      currentActiveStep = 1;
    }
  }

  Future<void> _syncPaperStoreStepWithBackend() async {
    if (widget.jobNumber == null) return;

    await _apiService.syncPaperStoreStep(widget.jobNumber!, (status) {
      final paperStoreStepIndex = steps.indexWhere((step) => step.type == StepType.paperStore);
      if (paperStoreStepIndex != -1) {
        setState(() {
          steps[paperStoreStepIndex].status = status;
          if (status == StepStatus.completed) {
            StepProgressManager.moveToNextStep(
              steps,
              paperStoreStepIndex,
                  (newActiveStep) => currentActiveStep = newActiveStep,
                  (message) => DialogManager.showSuccessMessage(context, message),
            );
          }
        });
      }
    });
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
    if (step.type == StepType.jobAssigned) {
      _showCompleteJobDetails();
      return;
    }

    final isActive = _isStepActive(step);

    if (step.status == StepStatus.pending && isActive) {
      DialogManager.showStartWorkDialog(context, step, () => _startWork(step));
    } else if (step.status == StepStatus.started || step.status == StepStatus.inProgress) {
      _showWorkForm(step);
    } else if (step.status == StepStatus.completed && step.formData.isNotEmpty) {
      DialogManager.showCompletedStepDetails(context, step);
    } else {
      DialogManager.showErrorMessage(
          context,
          '${step.title} is not available yet. Complete previous steps first.'
      );
    }
  }

  bool _isStepActive(StepData step) {
    int stepIndex = steps.indexOf(step);
    return stepIndex == currentActiveStep;
  }

  Future<void> _startWork(StepData step) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (context) => JobTimelineUI.buildLoadingDialog('Starting work...'),
    );

    try {
      await _performStartWork(step);
      if (mounted) Navigator.pop(context);

      setState(() {
        step.status = StepStatus.started;
      });

      DialogManager.showSuccessMessage(context, '${step.title} work started!');
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

    if (step.type == StepType.paperStore) {
      await _apiService.startPaperStoreWork(widget.jobNumber!, jobDetails ?? {});
    }

    await _apiService.updateStepStatus(widget.jobNumber!, stepNo, "start");
  }

  void _showWorkForm(StepData step) async {
    if (step.type == StepType.paperStore) {
      await _showPaperStoreForm(step);
      return;
    }

    final fieldNames = StepDataManager.getFieldNamesForStep(step.type);
    final initialValues = step.formData.map((key, value) => MapEntry(key, value.toString()));

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WorkForm(
        title: step.title,
        description: step.description,
        initialValues: initialValues,
        fieldNames: fieldNames,
        hasData: step.formData.isNotEmpty,
        onSubmit: (formData) => _submitForm(step, formData),
        onComplete: (formData) async => await _handleWorkFormComplete(step, formData),
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
      await _apiService.completePaperStoreWork(widget.jobNumber!, jobDetails ?? {}, formData);

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

      DialogManager.showSuccessMessage(context, 'Paper Store work completed and saved!');
    } catch (e) {
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

      await _apiService.updateStepStatus(widget.jobNumber!, stepNo, "stop");
      await _apiService.postStepDetails(step.type, widget.jobNumber!, formData, stepNo);

      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context); // Close loading dialog
      }

      final stepIndex = steps.indexOf(step);
      setState(() {
        step.formData = formData;
        step.status = StepStatus.completed;
      });

      StepProgressManager.moveToNextStep(
        steps,
        stepIndex,
            (newActiveStep) => setState(() => currentActiveStep = newActiveStep),
            (message) => DialogManager.showSuccessMessage(context, message),
      );

      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context); // Close WorkForm dialog
      }

      DialogManager.showSuccessMessage(context, '${step.title} completed successfully!');

    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      DialogManager.showErrorMessage(context, 'Failed to complete work: ${e.toString()}');
    }
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
      body: SingleChildScrollView(
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
    );
  }
}