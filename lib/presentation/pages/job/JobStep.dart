import 'package:flutter/material.dart';
import 'package:nrc/constants/colors.dart';
import 'package:nrc/core/services/dio_service.dart';
import 'package:nrc/presentation/pages/job/work_action_form.dart';
import 'package:nrc/presentation/pages/job/work_form.dart';
import '../../../data/datasources/job_api.dart';
import '../../../data/models/Job.dart';
import '../../../data/models/WorkStepAssignment.dart';
import '../../../data/models/job_step_models.dart'; // Make sure this import is correct
import 'package:dio/dio.dart';

class JobTimelinePage extends StatefulWidget {
  final String? jobNumber;
  final List<dynamic>? assignedSteps; // Accept steps as List<Map<String, dynamic>> from API

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
  late final JobApi _jobApi;

  static const orderedStepNames = [
    'PaperStore',
    'PrintingDetails',
    'Corrugation',
    'FluteLaminateBoardConversion',
    'Punching',
    'SideFlapPasting',
    'QualityDept',
    'DispatchProcess',
  ];

  String getDisplayName(String stepName) {
    switch (stepName) {
      case 'PaperStore': return 'Paper Store';
      case 'PrintingDetails': return 'Printing';
      case 'Corrugation': return 'Corrugation';
      case 'FluteLaminateBoardConversion': return 'Flute Lamination';
      case 'Punching': return 'Punching';
      case 'SideFlapPasting': return 'Flap Pasting';
      case 'QualityDept': return 'Quality Control';
      case 'DispatchProcess': return 'Dispatch';
      default: return stepName;
    }
  }

  @override
  void initState() {
    super.initState();
    _jobApi = JobApi(DioService.instance);
    _initializeSteps();
    _syncPaperStoreStepWithBackend();
  }

  Future<void> _syncPaperStoreStepWithBackend() async {
    if (widget.jobNumber == null) return;
    try {
      final paperStore = await _jobApi.getPaperStoreStepByJob(widget.jobNumber!);
      if (paperStore != null) {
        final status = paperStore['status'];
        // Find the Paper Store step and update its status
        StepData? paperStoreStep;
        try {
          paperStoreStep = steps.firstWhere((step) => step.type == StepType.paperStore);
        } catch (_) {
          paperStoreStep = null;
        }
        if (paperStoreStep != null) {
          setState(() {
            if (status == 'in_progress') {
              paperStoreStep?.status = StepStatus.started;
            } else if (status == 'accept') {
              paperStoreStep?.status = StepStatus.completed;
            } else {
              paperStoreStep?.status = StepStatus.pending;
            }
          });
        }
      }
    } catch (e) {
      print('Error syncing Paper Store step: $e');
    }
  }

  void _initializeSteps() {
    steps = [
      StepData(
        type: StepType.jobAssigned,
        title: 'Job Assigned',
        description: 'Job has been assigned and ready to start',
        status: StepStatus.completed,
      ),
    ];

    // Sort and add steps from assignedSteps (API data)
    if (widget.assignedSteps != null && widget.assignedSteps!.isNotEmpty) {
      final sortedSteps = List<Map<String, dynamic>>.from(widget.assignedSteps!);
      sortedSteps.sort((a, b) {
        int aIndex = orderedStepNames.indexOf(a['stepName'] ?? '');
        int bIndex = orderedStepNames.indexOf(b['stepName'] ?? '');
        return aIndex.compareTo(bIndex);
      });
      for (final stepMap in sortedSteps) {
        final stepName = stepMap['stepName'] ?? '';
        final displayName = getDisplayName(stepName);
        steps.add(
          StepData(
            type: _getStepTypeFromString(stepName),
            title: displayName,
            description: _getStepDescription(displayName),
            // Optionally, you can map status from API if available
          ),
        );
      }
    }

    // Set first step as completed and second as ready to start
    if (steps.length > 1) {
      steps[1].status = StepStatus.pending;
      currentActiveStep = 1;
    } else {
      currentActiveStep = 0;
    }
  }

  // Helper to map string to StepType
  StepType _getStepTypeFromString(String step) {
    switch (step.toLowerCase()) {
      case 'paperstore':
        return StepType.paperStore;
      case 'printing':
        return StepType.printing;
      case 'corrugation':
        return StepType.corrugation;
      case 'flutelamination':
        return StepType.fluteLamination;
      case 'punching':
        return StepType.punching;
      case 'flappasting':
        return StepType.flapPasting;
      case 'qc':
        return StepType.qc;
      case 'dispatch':
        return StepType.dispatch;
      default:
        return StepType.jobAssigned;
    }
  }

  // Helper to get a description for each step
  String _getStepDescription(String displayName) {
    switch (displayName.toLowerCase()) {
      case 'paper store':
        return 'Check and prepare paper materials';
      case 'printing':
        return 'Print the materials as per specifications';
      case 'corrugation':
        return 'Apply corrugation process';
      case 'flute lamination':
        return 'Apply flute lamination';
      case 'punching':
        return 'Punch holes as required';
      case 'flap pasting':
        return 'Paste flaps and complete assembly';
      case 'quality control':
      case 'qc':
        return 'Final quality inspection';
      case 'dispatch':
        return 'Package and dispatch the order';
      default:
        return '';
    }
  }

  String _getStepStatusText(StepData step) {
    switch (step.status) {
      case StepStatus.pending:
        if (step.type == StepType.jobAssigned) {
          return 'Job Number: ${widget.jobNumber ?? ''}';
        }
        return 'Ready to start - Click to begin work';
      case StepStatus.started:
        return 'Work started - Click to add/edit details';
      case StepStatus.inProgress:
        return 'In progress - Details saved - Click to edit or complete';
      case StepStatus.completed:
        if (step.type == StepType.jobAssigned) {
          return 'Job Number: ${widget.jobNumber ?? ''}';
        }
        return 'Work completed ✓';
      case StepStatus.paused:
        return 'Work paused - Click to resume or edit';
    }
  }

  void _handleStepTap(StepData step) {
    if (step.type == StepType.jobAssigned) {
      _showCompleteJobDetails();
    } else if (step.status == StepStatus.pending && _isStepActive(step)) {
      _startWork(step);
    } else if (step.status == StepStatus.started || step.status == StepStatus.inProgress) {
      _showWorkForm(step);
    } else if (step.status == StepStatus.completed && step.formData.isNotEmpty) {
      _showCompletedStepDetails(step);
    }
  }

  bool _isStepActive(StepData step) {
    int stepIndex = steps.indexOf(step);
    return stepIndex == currentActiveStep;
  }

  void _startWork(StepData step) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.play_circle_filled, color: AppColors.maincolor),
            const SizedBox(width: 8),
            const Text('Start Work'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you ready to start work on:'),
            const SizedBox(height: 8),
            Text(
              step.title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.maincolor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              step.description,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.maincolor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final dialogContext = context;
              Navigator.pop(dialogContext); // Close confirmation dialog

              // Show loader
              late BuildContext loaderDialogContext;
              showDialog(
                context: dialogContext,
                barrierDismissible: false,
                useRootNavigator: true,
                builder: (context) {
                  loaderDialogContext = context;
                  return Dialog(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          CircularProgressIndicator(),
                          SizedBox(width: 16),
                          Expanded(child: Text('Starting work...')),
                        ],
                      ),
                    ),
                  );
                },
              );

              try {
                // Fetch job details if needed
                if (jobDetails == null) {
                  await _fetchJobDetails();
                }
                final job = jobDetails ?? {};

                // Construct body for 'in_progress' status
                final body = {
                  "jobStepId": 1, // Assuming this is correct for PaperStore
                  'jobNrcJobNo': widget.jobNumber ?? '',
                  'status': 'in_progress',
                  'sheetSize': job['boardSize'] ?? '',
                  'required': int.tryParse(job['noUps']?.toString() ?? '0') ?? 0,
                  'gsm': job['fluteType'] ?? '',
                  'issuedDate': DateTime.now().toUtc().toIso8601String(),
                };

                // Post initial status
                await _jobApi.postPaperStore(body);

                // On success, close only the loader dialog using the correct context
                if (!mounted) return;
                if (Navigator.of(loaderDialogContext, rootNavigator: true).canPop()) {
                  Navigator.of(loaderDialogContext, rootNavigator: true).pop();
                }
                setState(() {
                  step.status = StepStatus.started;
                });
                _showSuccessMessage('${step.title} work started!');
              } on DioException catch (e) {
                if (!mounted) return;
                if (Navigator.of(loaderDialogContext, rootNavigator: true).canPop()) {
                  Navigator.of(loaderDialogContext, rootNavigator: true).pop();
                }
                print('Error starting work: DioException');
                if (e.response != null) {
                  print('STATUS: ${e.response?.statusCode}');
                  print('DATA: ${e.response?.data}');
                } else {
                  print('Error sending request: ${e.message}');
                }
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text('Failed to start work. Error: ${e.response?.statusCode ?? 'Connection Error'}')),
                );
              } catch (e) {
                if (!mounted) return;
                if (Navigator.of(loaderDialogContext, rootNavigator: true).canPop()) {
                  Navigator.of(loaderDialogContext, rootNavigator: true).pop();
                }
                print('Unexpected error starting work: $e');
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text('An unexpected error occurred while starting work.')),
                );
              }
            },
            child: const Text('Start Work'),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchJobDetails() async {
    setState(() {
      _jobLoading = true;
      _jobError = null;
    });
    try {
      // final dio = Dio();
      // final jobApi = JobApi(dio);
      final job = await _jobApi.getJobByNrcJobNo(widget.jobNumber ?? '');
      setState(() {
        jobDetails = job;
        _jobLoading = false;
      });
    } catch (e) {
      setState(() {
        _jobError = 'Failed to load job details';
        _jobLoading = false;
      });
    }
  }

  void _showCompleteJobDetails() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Expanded(child: Text('Details are loading, please wait...')),
            ],
          ),
        ),
      ),
    );
    await _fetchJobDetails();
    Navigator.of(context).pop(); // Remove loader dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.work, color: AppColors.maincolor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Job Details: ${widget.jobNumber ?? 'JOB001'}',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: jobDetails == null
            ? const Text('No job details found.')
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: jobDetails!.entries.map((entry) => _detailRow(entry.key, entry.value?.toString() ?? '')).toList(),
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: AppColors.maincolor)),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showWorkForm(StepData step) async {
    if (step.type == StepType.paperStore) {
      // Show loader dialog immediately
      showDialog(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (context) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Expanded(child: Text('Loading...')),
              ],
            ),
          ),
        ),
      );

      // Fetch job details for pre-fill
      if (jobDetails == null) {
        await _fetchJobDetails();
      }
      final job = jobDetails ?? {};

      // Close loader
      Navigator.of(context).pop();

      final TextEditingController availableController = TextEditingController();
      final TextEditingController millController = TextEditingController();
      final TextEditingController extraMarginController = TextEditingController();
      final TextEditingController qualityController = TextEditingController();
      showDialog(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Row(
                  children: [
                    Icon(Icons.work_outline, color: AppColors.maincolor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        step.title,
                        style: TextStyle(
                          color: AppColors.maincolor,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.white,
                content: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _detailRow('Job NRC Job No', widget.jobNumber ?? ''),
                      _detailRow('Sheet Size', job['boardSize'] ?? ''),
                      _detailRow('Required', job['noUps']?.toString() ?? ''),
                      _detailRow('GSM', job['fluteType'] ?? ''),
                      const SizedBox(height: 12),
                      TextField(
                        controller: availableController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Available',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: millController,
                        decoration: InputDecoration(
                          labelText: 'Mill',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: extraMarginController,
                        decoration: InputDecoration(  
                          labelText: 'Extra Margin',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: qualityController,
                        decoration: InputDecoration(
                          labelText: 'Quality',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async {
                      print('Complete Work button pressed');
                      // POST to paper-store endpoint
                      // final dio = Dio();
                      // final jobApi = JobApi(dio);
                      final body = {
                        "jobStepId": 1,
                        'jobNrcJobNo': widget.jobNumber ?? '',
                        'status': 'accept',
                        'sheetSize': job['boardSize'] ?? '',
                        'required': int.tryParse(job['noUps']?.toString() ?? '0') ?? 0,
                        'available': int.tryParse(availableController.text) ?? 0,
                        'issuedDate': DateTime.now().toUtc().toIso8601String(),
                        'mill': millController.text,
                        'extraMargin': extraMarginController.text,
                        'gsm': job['fluteType'] ?? '',
                        'quality': qualityController.text,
                      };
                      print('Posting to paper-store endpoint with body: $body');
                      try {
                        // Get the Paper Store record (if exists) to get its id
                        final paperStore = await _jobApi.getPaperStoreStepByJob(widget.jobNumber!);
                        if (paperStore != null) {
                          await _jobApi.putPaperStore(widget.jobNumber!, body);
                          print('PUT to paper-store successful');
                        } else {
                          await _jobApi.postPaperStore(body);
                          print('POST to paper-store successful');
                        }
                        if (!mounted) return;
                        // Do NOT pop the dialog!
                        setState(() {
                          step.status = StepStatus.completed;
                          if (currentActiveStep + 1 < steps.length) {
                            currentActiveStep++;
                            steps[currentActiveStep].status = StepStatus.pending;
                          }
                        });
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(content: Text('Paper Store work completed and saved!')),
                        );
                      } on DioException catch (e) {
                        if (!mounted) return;
                        // Do NOT pop the dialog!
                        print('Error posting to paper-store: DioException');
                        if (e.response != null) {
                          // The server responded with an error
                          print('Dio error!');
                          print('STATUS: ${e.response?.statusCode}');
                          print('DATA: ${e.response?.data}');
                          print('HEADERS: ${e.response?.headers}');
                        } else {
                          // Error due to setting up or sending the request
                          print('Error sending request!');
                          print('Request URI: ${e.requestOptions.uri}');
                          print('Request Headers: ${e.requestOptions.headers}');
                          print('Request Data: ${e.requestOptions.data}');
                          print(e.message);
                        }
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(content: Text('Failed to save Paper Store work. Error: ${e.response?.statusCode ?? 'Connection Error'}')),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        // Do NOT pop the dialog!
                        print('Unexpected error posting to paper-store: $e');
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(content: Text('An unexpected error occurred.')),
                        );
                      }
                    },
                    child: const Text('Complete Work'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              );
            },
          );
        },
      );
      return;
    }
    final fieldNames = _getFieldNamesForStep(step.type);
    final initialValues = step.formData.map((key, value) => MapEntry(key, value.toString()));

    showDialog(
      context: context,
      builder: (context) => WorkForm(
        title: step.title,
        description: step.description,
        initialValues: initialValues,
        fieldNames: fieldNames,
        hasData: step.formData.isNotEmpty,
        onSubmit: (formData) {
          _submitForm(step, formData);
        },
        onComplete: (formData) {
          _completeWork(step, formData);
        },
      ),
    );
  }

  List<String> _getFieldNamesForStep(StepType type) {
    switch (type) {
      case StepType.paperStore:
        return ['Sheet Size', 'Required Qty', 'Available Qty', 'Issue Date', 'GSM', 'Remarks'];
      case StepType.printing:
        return ['Date', 'Operator Name', 'Colors Used', 'Quantity OK', 'Wastage', 'Machine', 'Remarks'];
      case StepType.corrugation:
        return ['Date', 'Operator Name', 'Machine No', 'Sheets Count', 'Size', 'GSM', 'Flute Type', 'Remarks'];
      case StepType.fluteLamination:
        return ['Date', 'Operator Name', 'Film Type', 'OK Quantity', 'Adhesive', 'Wastage', 'Remarks'];
      case StepType.punching:
        return ['Date', 'Operator Name', 'Machine', 'OK Quantity', 'Die Used', 'Wastage', 'Remarks'];
      case StepType.flapPasting:
        return ['Date', 'Operator Name', 'Machine No', 'Adhesive', 'Quantity', 'Wastage', 'Remarks'];
      case StepType.qc:
        return ['Date', 'Checked By', 'Pass Quantity', 'Reject Quantity', 'Reason for Rejection', 'Remarks'];
      case StepType.dispatch:
        return ['Date', 'Operator Name', 'No of Boxes', 'Dispatch No', 'Dispatch Date', 'Balance Qty', 'Remarks'];
      default:
        return [];
    }
  }

  void _submitForm(StepData step, Map<String, String> formData) {
    setState(() {
      step.formData = formData;
      step.status = StepStatus.inProgress;
    });
    _showSuccessMessage('${step.title} details saved successfully!');
  }

  void _completeWork(StepData step, Map<String, String> formData) {
    setState(() {
      step.formData = formData;
      step.status = StepStatus.completed;

      // Move to next step if available
      if (currentActiveStep + 1 < steps.length) {
        currentActiveStep++;
        steps[currentActiveStep].status = StepStatus.pending;
      }
    });

    Navigator.pop(context); // Close the form dialog
    _showSuccessMessage('${step.title} completed! Moving to next step.');
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 100,
          left: 16,
          right: 16,
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    int completedSteps = steps.where((step) => step.status == StepStatus.completed).length;

    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Job Progress',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.maincolor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.maincolor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$completedSteps of ${steps.length}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.maincolor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: completedSteps / steps.length,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.maincolor),
            minHeight: 8,
          ),
          const SizedBox(height: 8),
          Text(
            '${((completedSteps / steps.length) * 100).toInt()}% Complete',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: steps.length,
      itemBuilder: (context, index) {
        final step = steps[index];
        final isClickable = step.type == StepType.jobAssigned ||
            (step.status == StepStatus.pending && _isStepActive(step)) ||
            step.status == StepStatus.started ||
            step.status == StepStatus.inProgress ||
            (step.status == StepStatus.completed && step.formData.isNotEmpty);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Card(
            elevation: _isStepActive(step) ? 4 : 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: _isStepActive(step) && step.status != StepStatus.completed
                  ? BorderSide(color: AppColors.maincolor, width: 2)
                  : BorderSide.none,
            ),
            child: InkWell(
              onTap: isClickable ? () => _handleStepTap(step) : null,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _getStepColor(step.status),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Center(
                        child: _getStepIcon(step.status, index + 1),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _isStepActive(step) && step.status != StepStatus.completed
                                  ? AppColors.maincolor
                                  : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            step.description,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _getStepStatusText(step),
                            style: TextStyle(
                              fontSize: 13,
                              color: _getStatusTextColor(step.status),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isClickable)
                      Icon(
                        _getActionIcon(step),
                        color: _getActionIconColor(step),
                        size: 16,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _getActionIcon(StepData step) {
    if (step.status == StepStatus.pending && _isStepActive(step)) {
      return Icons.play_arrow;
    } else if (step.status == StepStatus.started || step.status == StepStatus.inProgress) {
      return Icons.edit;
    } else if (step.status == StepStatus.completed && step.formData.isNotEmpty) {
      return Icons.visibility;
    } else if (step.type == StepType.jobAssigned) {
      return Icons.info_outline;
    }
    return Icons.arrow_forward_ios;
  }

  Color _getActionIconColor(StepData step) {
    if (step.status == StepStatus.pending && _isStepActive(step)) {
      return AppColors.maincolor;
    } else if (step.status == StepStatus.started || step.status == StepStatus.inProgress) {
      return AppColors.maincolor;
    } else if (step.status == StepStatus.completed && step.formData.isNotEmpty) {
      return Colors.grey[600]!;
    }
    return AppColors.maincolor;
  }

  Color _getStepColor(StepStatus status) {
    switch (status) {
      case StepStatus.pending:
        return Colors.grey[200]!;
      case StepStatus.started:
        return Colors.orange[200]!;
      case StepStatus.inProgress:
        return AppColors.maincolor.withOpacity(0.2);
      case StepStatus.completed:
        return Colors.green[200]!;
      case StepStatus.paused:
        return Colors.blue[200]!;
    }
  }

  Widget _getStepIcon(StepStatus status, int stepNumber) {
    switch (status) {
      case StepStatus.pending:
        return Text(
          '$stepNumber',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
          ),
        );
      case StepStatus.started:
        return Icon(
          Icons.play_circle_filled,
          color: Colors.orange[700],
          size: 24,
        );
      case StepStatus.inProgress:
        return Icon(
          Icons.sync,
          color: AppColors.maincolor,
          size: 24,
        );
      case StepStatus.completed:
        return const Icon(
          Icons.check_circle,
          color: Colors.green,
          size: 24,
        );
      case StepStatus.paused:
        return Icon(
          Icons.pause_circle_filled,
          color: Colors.blue,
          size: 24,
        );
    }
  }

  Color _getStatusTextColor(StepStatus status) {
    switch (status) {
      case StepStatus.pending:
        return Colors.grey[600]!;
      case StepStatus.started:
        return Colors.orange[700]!;
      case StepStatus.inProgress:
        return AppColors.maincolor;
      case StepStatus.completed:
        return Colors.green[700]!;
      case StepStatus.paused:
        return Colors.blue;
    }
  }

  void _showCompletedStepDetails(StepData step) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${step.title} - Completed',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: step.formData.entries.map((entry) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(
                          entry.key,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const Text(': '),
                      Expanded(
                        child: Text(
                          entry.value.toString(),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: AppColors.maincolor)),
          ),
        ],
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
                'Job ${widget.jobNumber ?? widget.jobNumber ?? ''}',
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
            _buildProgressIndicator(),
            _buildStepsList(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
