import 'package:flutter/material.dart';
import 'package:nrc/constants/colors.dart';
import 'package:nrc/presentation/pages/job/work_action_form.dart';
import 'package:nrc/presentation/pages/job/work_form.dart';
import '../../../data/models/Job.dart';
import '../../../data/models/WorkStepAssignment.dart';
import '../../../data/models/job_step_models.dart'; // Make sure this import is correct

class JobTimelinePage extends StatefulWidget {
  final String? jobNumber;
  final Job? job; // Pass the complete job object for details
  final List<WorkStepAssignment>? assignedSteps;

  const JobTimelinePage({super.key, this.jobNumber, this.job, this.assignedSteps});

  @override
  State<JobTimelinePage> createState() => _JobTimelinePageState();
}

class _JobTimelinePageState extends State<JobTimelinePage> {
  late List<StepData> steps;
  int currentActiveStep = 0;

  @override
  void initState() {
    super.initState();
    _initializeSteps();
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

    // Dynamically add steps from assignedSteps
    if (widget.assignedSteps != null && widget.assignedSteps!.isNotEmpty) {
      for (final assignment in widget.assignedSteps!) {
        steps.add(
          StepData(
            type: _getStepTypeFromString(assignment.workStep.step),
            title: assignment.workStep.displayName,
            description: _getStepDescription(assignment.workStep.displayName),
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
          return 'Job Number: ${widget.jobNumber ?? widget.job?.nrcJobNo ?? 'JOB001'}';
        }
        return 'Ready to start - Click to begin work';
      case StepStatus.started:
        return 'Work started - Click to add/edit details';
      case StepStatus.inProgress:
        return 'In progress - Details saved - Click to edit or complete';
      case StepStatus.completed:
        if (step.type == StepType.jobAssigned) {
          return 'Job Number: ${widget.jobNumber ?? widget.job?.nrcJobNo ?? 'JOB001'}';
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
            onPressed: () {
              setState(() {
                step.status = StepStatus.started;
              });
              Navigator.pop(context);
              _showSuccessMessage('${step.title} work started!');
            },
            child: const Text('Start Work'),
          ),
        ],
      ),
    );
  }

  void _showCompleteJobDetails() {
    final job = widget.job;
    print("object");
    print(job);

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
                'Job Details: ${widget.jobNumber ?? job?.nrcJobNo ?? 'JOB001'}',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow('Job Number', widget.jobNumber ?? job?.nrcJobNo ?? 'JOB001'),
                _detailRow('Status', job?.status ?? 'In Progress'),
                _detailRow('Current Step', steps[currentActiveStep].title),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue[600], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          job == null
                            ? 'Complete job details are not available. Please ensure the job object is passed to this page to view all details.'
                            : 'Full job details are shown below.',
                          style: const TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
                if (job != null) ...[
                  const SizedBox(height: 16),
                  _detailRow('Customer', job.customerName),
                  _detailRow('Style/SKU', job.styleItemSKU),
                  _detailRow('Flute Type', job.fluteType),
                  _detailRow('Board Size', job.boardSize ?? ''),
                  _detailRow('No. of Ups', job.noUps ?? ''),
                  _detailRow('Latest Rate', job.latestRate?.toString() ?? ''),
                  _detailRow('Previous Rate', job.preRate?.toString() ?? ''),
                  _detailRow('Dimensions', (job.length != null && job.width != null && job.height != null) ? '${job.length} x ${job.width} x ${job.height}' : ''),
                  _detailRow('Artwork Received', job.artworkReceivedDate ?? ''),
                  _detailRow('Artwork Approved', job.artworkApprovalDate ?? ''),
                  _detailRow('Shade Card Approval', job.shadeCardApprovalDate ?? ''),
                  _detailRow('Created At', job.createdAt ?? ''),
                  _detailRow('Updated At', job.updatedAt ?? ''),
                  if (job.purchaseOrder != null)
                    _detailRow('Purchase Order', 'Available'),
                  if (job.hasPoAdded)
                    _detailRow('PO Status', 'Added'),
                ],
              ],
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

  void _showWorkForm(StepData step) {
    if (step.type == StepType.paperStore) {
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
    } else {
      showDialog(
        context: context,
        builder: (context) => WorkActionForm(
          title: step.title,
          description: step.description,
          initialQty: step.formData['Qty Sheet']?.toString(),
          hasData: step.formData.isNotEmpty,
          onStart: () {
            setState(() {
              step.status = StepStatus.started;
            });
          },
          onPause: () {
            setState(() {
              step.status = StepStatus.paused;
            });
          },
          onStop: () {
            setState(() {
              step.status = StepStatus.completed;
            });
          },
          onComplete: (formData) {
            setState(() {
              step.formData = formData;
              step.status = StepStatus.completed;
              if (currentActiveStep + 1 < steps.length) {
                currentActiveStep++;
                steps[currentActiveStep].status = StepStatus.pending;
              }
            });
            Navigator.pop(context);
            _showSuccessMessage('${step.title} completed! Moving to next step.');
          },
        ),
      );
    }
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
                'Job ${widget.jobNumber ?? widget.job?.nrcJobNo ?? 'JOB001'}',
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
