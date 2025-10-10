import 'package:flutter/material.dart';
import '../../../constants/colors.dart';
import '../../../data/models/job_step_models.dart';
import 'MachineCardWidget.dart';
import 'StepStatusHelper.dart';

class ExpandableStepCardWidget extends StatefulWidget {
  final StepData step;
  final int index;
  final bool isActive;
  final String? jobNumber;
  final Future<List<Map<String, dynamic>>?>? machineDetailsFuture;
  final VoidCallback? onStartWork;
  final Function(String machineId)? onStartWorkWithMachine;

  const ExpandableStepCardWidget({
    Key? key,
    required this.step,
    required this.index,
    required this.isActive,
    this.jobNumber,
    this.machineDetailsFuture,
    this.onStartWork,
    this.onStartWorkWithMachine,
  }) : super(key: key);

  @override
  State<ExpandableStepCardWidget> createState() => _ExpandableStepCardWidgetState();
}

class _ExpandableStepCardWidgetState extends State<ExpandableStepCardWidget> {
  bool _isExpanded = false;
  List<Map<String, dynamic>>? _machineDetails;
  bool _isLoadingMachines = false;

  @override
  Widget build(BuildContext context) {
    final isClickable = widget.step.type == StepType.jobAssigned ||
        (widget.step.status == StepStatus.pending && widget.isActive) ||
        widget.step.status == StepStatus.started ||
        widget.step.status == StepStatus.inProgress ||
        widget.step.status == StepStatus.completed;

    final hasMultipleMachines = _machineDetails != null && 
        _machineDetails!.length > 1;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        elevation: widget.isActive ? 4 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: widget.isActive && widget.step.status != StepStatus.completed
              ? BorderSide(color: AppColors.maincolor, width: 2)
              : BorderSide.none,
        ),
        child: Column(
          children: [
            // Main step card
            InkWell(
              onTap: isClickable ? _handleStepTap : null,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: StepStatusHelper.getStepColor(widget.step.status),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Center(
                        child: StepStatusHelper.getStepIcon(widget.step.status, widget.index + 1),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.step.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: widget.isActive && widget.step.status != StepStatus.completed
                                  ? AppColors.maincolor
                                  : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.step.description,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            StepStatusHelper.getStepStatusText(widget.step, widget.jobNumber),
                            style: TextStyle(
                              fontSize: 13,
                              color: StepStatusHelper.getStatusTextColor(widget.step.status),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Show expand/collapse icon if multiple machines, otherwise show action icon
                    if (hasMultipleMachines)
                      Icon(
                        _isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: AppColors.maincolor,
                        size: 20,
                      )
                    else if (isClickable)
                      Icon(
                        StepStatusHelper.getActionIcon(widget.step, widget.isActive),
                        color: StepStatusHelper.getActionIconColor(widget.step, widget.isActive),
                        size: 16,
                      ),
                  ],
                ),
              ),
            ),
            // Expanded machine list
            if (_isExpanded)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Text(
                      'Available Machines:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_isLoadingMachines)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_machineDetails != null && _machineDetails!.isNotEmpty)
                      ..._machineDetails!.map((machine) => 
                        MachineCardWidget(
                          machineInfo: machine,
                          onStartWork: () => _startWorkWithMachine(machine),
                          isAvailable: _isMachineAvailable(machine),
                        ),
                      ).toList()
                    else
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'No machines available',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _handleStepTap() async {
    if (_machineDetails != null && _machineDetails!.length > 1) {
      // Multiple machines - toggle expansion
      setState(() {
        _isExpanded = !_isExpanded;
      });
    } else if (_machineDetails != null && _machineDetails!.length == 1) {
      // Single machine - start work directly
      _startWorkWithMachine(_machineDetails!.first);
    } else {
      // Load machine details first
      await _loadMachineDetails();
      if (_machineDetails != null && _machineDetails!.length > 0) {
        if (_machineDetails!.length == 1) {
          _startWorkWithMachine(_machineDetails!.first);
        } else {
          setState(() {
            _isExpanded = true;
          });
        }
      } else {
        // No machine details - use old flow
        widget.onStartWork?.call();
      }
    }
  }

  Future<void> _loadMachineDetails() async {
    if (_isLoadingMachines || _machineDetails != null) return;

    setState(() {
      _isLoadingMachines = true;
    });

    try {
      final machines = await widget.machineDetailsFuture;
      if (mounted) {
        setState(() {
          _machineDetails = machines;
          _isLoadingMachines = false;
        });
      }
    } catch (e) {
      print('Error loading machine details: $e');
      if (mounted) {
        setState(() {
          _isLoadingMachines = false;
        });
      }
    }
  }

  void _startWorkWithMachine(Map<String, dynamic> machine) {
    final machineId = machine['machineId'] ?? machine['machineCode'];
    if (machineId != null) {
      widget.onStartWorkWithMachine?.call(machineId.toString());
    }
  }

  bool _isMachineAvailable(Map<String, dynamic> machine) {
    // For now, assume all machines are available
    // This will be updated when we add machine status tracking
    return true;
  }
}
