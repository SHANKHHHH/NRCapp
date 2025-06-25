import 'package:flutter/material.dart';
import 'package:nrc/constants/colors.dart';

enum StepStatus { pending, inProgress, waitingApproval, accepted, rejected, onHold, completed }

enum StepType { jobAssigned, paperStore, printing, corrugation, fluteLamination, punching, flapPasting, qc, dispatch }

class StepData {
  final StepType type;
  final String title;
  StepStatus status;
  Map<String, dynamic> formData;
  String? rejectionReason;
  String? holdReason;

  StepData({
    required this.type,
    required this.title,
    this.status = StepStatus.pending,
    this.formData = const {},
    this.rejectionReason,
    this.holdReason,
  });
}

class JobTimelinePage extends StatefulWidget {
  final String? jobNumber;

  const JobTimelinePage({super.key, this.jobNumber});

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
      StepData(type: StepType.jobAssigned, title: 'Job Assigned', status: StepStatus.completed),
      StepData(type: StepType.paperStore, title: 'Paper Store'),
      StepData(type: StepType.printing, title: 'Printing Details'),
      StepData(type: StepType.corrugation, title: 'Corrugation'),
      StepData(type: StepType.fluteLamination, title: 'Flute Lamination'),
      StepData(type: StepType.punching, title: 'Punching'),
      StepData(type: StepType.flapPasting, title: 'Flap Pasting'),
      StepData(type: StepType.qc, title: 'QC'),
      StepData(type: StepType.dispatch, title: 'Dispatch'),
    ];

    // Set first step as completed and second as in progress
    steps[0].status = StepStatus.completed;
    steps[1].status = StepStatus.inProgress;
    currentActiveStep = 1;
  }

  String _getStepStatusText(StepData step) {
    switch (step.status) {
      case StepStatus.pending:
        return 'Pending';
      case StepStatus.inProgress:
        if (step.type == StepType.jobAssigned) {
          return 'Job Number: ${widget.jobNumber ?? 'JOB001'}';
        }
        return 'Click to fill details';
      case StepStatus.waitingApproval:
        return 'Waiting for Admin Approval';
      case StepStatus.accepted:
        return 'Accepted';
      case StepStatus.rejected:
        return 'Rejected - ${step.rejectionReason ?? 'See details'}';
      case StepStatus.onHold:
        return 'On Hold - ${step.holdReason ?? 'See details'}';
      case StepStatus.completed:
        if (step.type == StepType.jobAssigned) {
          return 'Job Number: ${widget.jobNumber ?? 'JOB001'}';
        }
        return 'Completed';
    }
  }

  void _handleStepTap(StepData step) {
    if (step.status == StepStatus.inProgress) {
      if (step.type == StepType.jobAssigned) {
        _showJobDetails();
      } else {
        _showFormDialog(step);
      }
    } else if (step.status == StepStatus.waitingApproval) {
      _showApprovalDialog(step);
    } else if (step.status == StepStatus.rejected || step.status == StepStatus.onHold) {
      _showFormDialog(step); // Allow re-filling for rejected/hold items
    }
  }

  void _showJobDetails() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Current Job Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Job Number: ${widget.jobNumber ?? 'JOB001'}'),
            const SizedBox(height: 8),
            const Text('Status: Assigned'),
            const SizedBox(height: 8),
            const Text('Ready to proceed with next step'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showFormDialog(StepData step) {
    final fieldNames = _getFieldNamesForStep(step.type);
    final initialValues = step.formData.map((key, value) => MapEntry(key, value.toString()));

    showDialog(
      context: context,
      builder: (context) => GenericForm(
        title: '${step.title} Details',
        initialValues: initialValues,
        fieldNames: fieldNames,
        onSubmit: (formData) {
          _submitForm(step, formData);
        },
      ),
    );
  }

  List<String> _getFieldNamesForStep(StepType type) {
    switch (type) {
      case StepType.paperStore:
        return ['sheetSize', 'required', 'available', 'issueDate', 'millExtraMargin', 'gsm', 'quantity'];
      case StepType.printing:
        return [
          'date',
          'shift',
          'oprName',
          'noOfColours',
          'inksUsed',
          'postPrintingFinishingOkQty',
          'wastage',
          'coatingType',
          'separateSheets',
          'extraSheets',
          'machine',
          'productionPlanning',
        ];
      case StepType.corrugation:
        return [
          'date',
          'shift',
          'oprName',
          'machineNo',
          'noOfSheets',
          'size',
          'gsm1',
          'gsm2',
          'flute',
          'remarks',
          'qcCheckSignBy',
          'productionPlanning',
        ]; // Example fields for corrugation
      case StepType.fluteLamination:
        return [
          'date',
          'shift',
          'operatorName',
          'film',
          'okQty',
          'qcCheckSignBy',
          'adhesive',
          'wastage',
          'productionPlanning',
        ]; // Example fields for flute lamination
      case StepType.punching:
        return [
          'date',
          'shift',
          'operatorName',
          'okQty',
          'machine',
          'qcCheckSignBy',
          'die',
          'wastage',
          'remarks',
          'productionPlanning',
        ]; // Example fields for punching
      case StepType.flapPasting:
        return [
          'machineNo',
          'date',
          'shift',
          'operatorName',
          'adhesive',
          'quantity',
          'wastage',
          'qcCheckSignBy',
          'remarks',
          'productionPlanning',
        ]
        ; // Example fields for flap pasting
      case StepType.qc:
        return [
          'date',
          'shift',
          'operatorName',
          'checkedBy',
          'rejectedQty',
          'passQty',
          'reasonForRejection',
          'remarks',
          'qcCheckSignBy',
          'productionPlanning',
        ]; // Example fields for quality control
      case StepType.dispatch:
        return [
          'date',
          'shift',
          'operatorName',
          'noOfBoxes',
          'dispatchNo',
          'dispatchDate',
          'remarks',
          'balanceQty',
          'qcCheckSignBy',
          'productionPlanning',
        ]
        ; // Example fields for dispatch
      default:
        return [];
    }
  }

  void _submitForm(StepData step, Map<String, String> formData) {
    setState(() {
      step.formData = formData;
      step.status = StepStatus.waitingApproval;
      step.rejectionReason = null; // Clear rejection reason
      step.holdReason = null; // Clear hold reason
    });

    _showSuccessMessage('${step.title} Data Filled');
  }

  void _showApprovalDialog(StepData step) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: Colors.white,
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        title: Text(
          'Review ${step.title}',
          style: TextStyle(
            color: AppColors.maincolor,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          'Please review the submitted data and choose an action:',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16,
          ),
        ),
        actions: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Cancel'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.yellow,
                  side: BorderSide(color: AppColors.translucentBlack),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showRejectDialog(step);
                },
                icon: const Icon(Icons.thumb_down_alt_outlined, size: 18),
                label: const Text('Reject'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.red,
                  side: BorderSide(color: AppColors.translucentBlack),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showHoldDialog(step);
                },
                icon: const Icon(Icons.pause_circle_outline, size: 18),
                label: const Text('Hold'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.grey,
                  side: BorderSide(color: AppColors.translucentBlack),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  _acceptStep(step);
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Accept'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(StepData step) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Reject ${step.title}',
          style: TextStyle(
            color: AppColors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.white,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Rejection Reason',
                labelStyle: TextStyle(color: AppColors.red),
                border: const OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.red, width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.red,
              side: BorderSide(color: Colors.red.shade200),
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) {
                _rejectStep(step, reasonController.text.trim());
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _showHoldDialog(StepData step) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Hold ${step.title}',
          style: TextStyle(
            color: AppColors.grey800,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please provide a reason for putting this step on hold:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Hold Reason',
                labelStyle: TextStyle(color: AppColors.grey800),
                border: const OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.grey800, width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.grey800,
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) {
                _holdStep(step, reasonController.text.trim());
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.grey800,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hold'),
          ),
        ],
      ),
    );
  }

  void _acceptStep(StepData step) {
    setState(() {
      step.status = StepStatus.accepted;

      // Move to next step if available
      if (currentActiveStep + 1 < steps.length) {
        currentActiveStep++;
        steps[currentActiveStep].status = StepStatus.inProgress;
      }
    });

    _showSuccessMessage('${step.title} Accepted');
  }

  void _rejectStep(StepData step, String reason) {
    setState(() {
      step.status = StepStatus.rejected;
      step.rejectionReason = reason;
    });

    _showSuccessMessage('${step.title} Rejected');
  }

  void _holdStep(StepData step, String reason) {
    setState(() {
      step.status = StepStatus.onHold;
      step.holdReason = reason;
    });

    _showSuccessMessage('${step.title} Put on Hold');
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        children: [
          Text(
            'Step ${currentActiveStep + 1} of ${steps.length}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: (currentActiveStep + 1) / steps.length,
            backgroundColor: Colors.grey[300],
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    final currentStep = steps[currentActiveStep];
    final isClickable = currentStep.status == StepStatus.inProgress ||
        currentStep.status == StepStatus.waitingApproval ||
        currentStep.status == StepStatus.rejected ||
        currentStep.status == StepStatus.onHold;

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
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
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getStepColor(currentStep.status),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: _getStepIcon(currentStep.status),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentStep.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getStepStatusText(currentStep),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (isClickable)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _handleStepTap(currentStep),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getButtonColor(currentStep.status),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      _getButtonText(currentStep),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              if (currentStep.status == StepStatus.waitingApproval)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.pending, color: Colors.orange[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Data Filled - Review details below and take action',
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        // Show filled data card when waiting for approval, accepted, rejected, or on hold
        if ((currentStep.status == StepStatus.waitingApproval ||
            currentStep.status == StepStatus.accepted ||
            currentStep.status == StepStatus.rejected ||
            currentStep.status == StepStatus.onHold) &&
            currentStep.formData.isNotEmpty)
          _buildFilledDataCard(currentStep),
      ],
    );
  }

  Color _getStepColor(StepStatus status) {
    switch (status) {
      case StepStatus.pending:
        return Colors.grey[100]!;
      case StepStatus.inProgress:
        return Colors.blue[100]!;
      case StepStatus.waitingApproval:
        return Colors.orange[100]!;
      case StepStatus.accepted:
        return Colors.green[100]!;
      case StepStatus.rejected:
        return Colors.red[100]!;
      case StepStatus.onHold:
        return Colors.amber[100]!;
      case StepStatus.completed:
        return Colors.green[100]!;
    }
  }

  Widget _getStepIcon(StepStatus status) {
    switch (status) {
      case StepStatus.pending:
        return Text(
          '${currentActiveStep + 1}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        );
      case StepStatus.inProgress:
        return Icon(Icons.play_arrow, color: Colors.blue[700], size: 20);
      case StepStatus.waitingApproval:
        return Icon(Icons.pending, color: Colors.orange[700], size: 20);
      case StepStatus.accepted:
        return Icon(Icons.check, color: Colors.green[700], size: 20);
      case StepStatus.rejected:
        return Icon(Icons.close, color: Colors.red[700], size: 20);
      case StepStatus.onHold:
        return Icon(Icons.pause, color: Colors.amber[700], size: 20);
      case StepStatus.completed:
        return Icon(Icons.check_circle, color: Colors.green[700], size: 20);
    }
  }

  Color _getButtonColor(StepStatus status) {
    switch (status) {
      case StepStatus.inProgress:
        return Colors.black87;
      case StepStatus.waitingApproval:
        return Colors.orange;
      case StepStatus.rejected:
        return Colors.red;
      case StepStatus.onHold:
        return Colors.amber;
      default:
        return Colors.black87;
    }
  }

  String _getButtonText(StepData step) {
    switch (step.status) {
      case StepStatus.inProgress:
        return step.type == StepType.jobAssigned ? 'View Details' : 'Fill Details';
      case StepStatus.waitingApproval:
        return 'Review & Take Action';
      case StepStatus.rejected:
        return 'Update Details';
      case StepStatus.onHold:
        return 'Update Details';
      default:
        return 'Action Required';
    }
  }

  Widget _buildFilledDataCard(StepData step) {
    Color cardColor;
    Color borderColor;
    Color iconColor;
    IconData icon;
    String title;

    switch (step.status) {
      case StepStatus.accepted:
        cardColor = Colors.green[50]!;
        borderColor = Colors.green[200]!;
        iconColor = Colors.green[700]!;
        icon = Icons.check_circle;
        title = 'Accepted Data - ${step.title}';
        break;
      case StepStatus.rejected:
        cardColor = Colors.red[50]!;
        borderColor = Colors.red[200]!;
        iconColor = Colors.red[700]!;
        icon = Icons.error;
        title = 'Rejected Data - ${step.title}';
        break;
      case StepStatus.onHold:
        cardColor = Colors.amber[50]!;
        borderColor = Colors.amber[200]!;
        iconColor = Colors.amber[700]!;
        icon = Icons.pause_circle;
        title = 'On Hold Data - ${step.title}';
        break;
      default:
        cardColor = Colors.blue[50]!;
        borderColor = Colors.blue[200]!;
        iconColor = Colors.blue[700]!;
        icon = Icons.description;
        title = 'Filled Data - ${step.title}';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...step.formData.entries.map((entry) => Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    _formatFieldName(entry.key),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                const Text(': ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Expanded(
                  child: Text(
                    entry.value.toString(),
                    style: const TextStyle(fontSize: 13),
                    softWrap: true,
                  ),
                ),
              ],
            ),
          )).toList(),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _getStatusBackgroundColor(step.status),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getStatusMessage(step),
                    style: TextStyle(
                      color: iconColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusBackgroundColor(StepStatus status) {
    switch (status) {
      case StepStatus.accepted:
        return Colors.green[100]!;
      case StepStatus.rejected:
        return Colors.red[100]!;
      case StepStatus.onHold:
        return Colors.amber[100]!;
      default:
        return Colors.green[50]!;
    }
  }

  String _getStatusMessage(StepData step) {
    switch (step.status) {
      case StepStatus.accepted:
        return 'Data accepted and step completed';
      case StepStatus.rejected:
        return 'Data rejected: ${step.rejectionReason ?? 'Please update details'}';
      case StepStatus.onHold:
        return 'Step on hold: ${step.holdReason ?? 'Please update details'}';
      default:
        return 'Data successfully filled and ready for approval';
    }
  }

  String _formatFieldName(String key) {
    // Convert camelCase to readable format
    switch (key) {
      case 'sheetSize':
        return 'Sheet Size';
      case 'required':
        return 'Required';
      case 'available':
        return 'Available';
      case 'issueDate':
        return 'Issue Date';
      case 'millExtraMargin':
        return 'Mill Extra Margin';
      case 'gsm':
        return 'GSM';
      case 'quantity':
        return 'Quantity';
      default:
        return key;
    }
  }

  Widget _buildCompletedSteps() {
    final completedSteps = steps.take(currentActiveStep).where((step) =>
    step.status == StepStatus.completed || step.status == StepStatus.accepted).toList();

    if (completedSteps.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Completed Steps',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          ...completedSteps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      step.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (step.formData.isNotEmpty)
                    GestureDetector(
                      onTap: () => _showCompletedStepDetails(step),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'View Details',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.maincolor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  void _showCompletedStepDetails(StepData step) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '${step.title} - Details',
          style: TextStyle(
            color: AppColors.maincolor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Container(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: step.formData.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 130,
                        child: Text(
                          _formatFieldName(entry.key),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppColors.black,
                          ),
                        ),
                      ),
                      const Text(': '),
                      Expanded(
                        child: Text(
                          entry.value.toString(),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
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
            style: TextButton.styleFrom(
              foregroundColor: AppColors.maincolor,
            ),
            child: const Text('Close'),
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
        title: Text('Job ${widget.jobNumber ?? 'JOB001'}'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProgressIndicator(),
            _buildCurrentStep(),
            const SizedBox(height: 20),
            _buildCompletedSteps(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class GenericForm extends StatelessWidget {
  final String title;
  final Map<String, String> initialValues;
  final List<String> fieldNames;
  final Function(Map<String, String>) onSubmit;

  const GenericForm({
    Key? key,
    required this.title,
    required this.initialValues,
    required this.fieldNames,
    required this.onSubmit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final controllers = fieldNames
        .map((field) => TextEditingController(text: initialValues[field]))
        .toList();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        title,
        style: TextStyle(
          color: AppColors.maincolor,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: Colors.white,
      content: Container(
        width: double.maxFinite,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(fieldNames.length, (index) {
                return _buildFormField(fieldNames[index], controllers[index]);
              }),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: AppColors.maincolor),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.maincolor,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            if (formKey.currentState!.validate()) {
              final formData = <String, String>{};
              for (int i = 0; i < controllers.length; i++) {
                formData[fieldNames[i]] = controllers[i].text;
              }
              onSubmit(formData);
              Navigator.pop(context);
            }
          },
          child: const Text('Submit'),
        ),
      ],
    );
  }

  Widget _buildFormField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: AppColors.maincolor),
          border: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.blue.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: AppColors.maincolor, width: 2),
          ),
          filled: true,
          fillColor: Colors.white, // Changed from Colors.blue[50] to white
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter $label';
          }
          return null;
        },
      ),
    );
  }
}
