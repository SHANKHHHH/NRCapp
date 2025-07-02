import 'package:flutter/material.dart';
import '../../../data/models/WorkStep.dart';
import '../../../data/models/WorkStepAssignment.dart';

class WorkStepSelectionWidget extends StatefulWidget {
  final List<WorkStep> workSteps;
  final List<WorkStepAssignment> selectedWorkStepAssignments;
  final ValueChanged<List<WorkStepAssignment>> onSelectionChanged;

  const WorkStepSelectionWidget({
    Key? key,
    required this.workSteps,
    required this.selectedWorkStepAssignments,
    required this.onSelectionChanged,
  }) : super(key: key);

  @override
  State<WorkStepSelectionWidget> createState() => _WorkStepSelectionWidgetState();
}

class _WorkStepSelectionWidgetState extends State<WorkStepSelectionWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  final Map<String, AnimationController> _cardAnimations = {};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Initialize animations for each work step
    for (var workStep in widget.workSteps) {
      _cardAnimations[workStep.step] = AnimationController(
        duration: const Duration(milliseconds: 200),
        vsync: this,
      );
    }

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    for (var controller in _cardAnimations.values) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _isSelected(WorkStep workStep) {
    return widget.selectedWorkStepAssignments
        .any((assignment) => assignment.workStep.step == workStep.step);
  }

  void _toggleSelection(WorkStep workStep) {
    final animationController = _cardAnimations[workStep.step];

    List<WorkStepAssignment> updatedAssignments =
    List.from(widget.selectedWorkStepAssignments);

    if (_isSelected(workStep)) {
      updatedAssignments
          .removeWhere((assignment) => assignment.workStep.step == workStep.step);
      animationController?.reverse();
    } else {
      updatedAssignments.add(WorkStepAssignment(workStep: workStep));
      animationController?.forward();
    }

    widget.onSelectionChanged(updatedAssignments);
  }

  IconData _getWorkStepIcon(String stepType) {
    switch (stepType.toLowerCase()) {
      case 'printing':
        return Icons.print;
      case 'corrugation':
        return Icons.waves;
      case 'flutelamination':
        return Icons.layers;
      case 'punching':
        return Icons.radio_button_unchecked;
      case 'flappasting':
        return Icons.content_paste;
      case 'cutting':
        return Icons.content_cut;
      case 'folding':
        return Icons.flip;
      case 'gluing':
        return Icons.join_inner;
      default:
        return Icons.work;
    }
  }

  Color _getWorkStepColor(String stepType) {
    switch (stepType.toLowerCase()) {
      case 'printing':
        return Colors.blue;
      case 'corrugation':
        return Colors.orange;
      case 'flutelamination':
        return Colors.green;
      case 'punching':
        return Colors.red;
      case 'flappasting':
        return Colors.purple;
      case 'cutting':
        return Colors.teal;
      case 'folding':
        return Colors.indigo;
      case 'gluing':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Selection Summary
        if (widget.selectedWorkStepAssignments.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.blue.shade600),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${widget.selectedWorkStepAssignments.length} work step${widget.selectedWorkStepAssignments.length == 1 ? '' : 's'} selected',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Instructions
        Container(
          margin: const EdgeInsets.only(bottom: 20),
          child: Text(
            'Select the work steps needed for this job:',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
              height: 1.4,
            ),
          ),
        ),

        // Work Steps Grid - Using Wrap instead of GridView for better scrolling
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
            final itemWidth = (constraints.maxWidth - (12 * (crossAxisCount - 1))) / crossAxisCount;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: widget.workSteps.map((workStep) {
                final isSelected = _isSelected(workStep);
                final color = _getWorkStepColor(workStep.step);
                final icon = _getWorkStepIcon(workStep.step);

                return SizedBox(
                  width: itemWidth,
                  child: AnimatedBuilder(
                    animation: _cardAnimations[workStep.step]!,
                    builder: (context, child) {
                      final scale = 1.0 + (_cardAnimations[workStep.step]!.value * 0.02);

                      return Transform.scale(
                        scale: scale,
                        child: GestureDetector(
                          onTap: () => _toggleSelection(workStep),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 140,
                            decoration: BoxDecoration(
                              color: isSelected ? color.withOpacity(0.1) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? color : Colors.grey.shade300,
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isSelected
                                      ? color.withOpacity(0.15)
                                      : Colors.grey.withOpacity(0.08),
                                  spreadRadius: 0,
                                  blurRadius: isSelected ? 8 : 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Icon and Selection Indicator
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          icon,
                                          color: color,
                                          size: 20,
                                        ),
                                      ),
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isSelected ? color : Colors.transparent,
                                          border: Border.all(
                                            color: isSelected ? color : Colors.grey.shade400,
                                            width: 2,
                                          ),
                                        ),
                                        child: isSelected
                                            ? const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 14,
                                        )
                                            : null,
                                      ),
                                    ],
                                  ),

                                  // Title
                                  Expanded(
                                    child: Center(
                                      child: Text(
                                        workStep.displayName,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected ? color : Colors.grey[800],
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),

                                  // Responsible Persons
                                  if (workStep.responsiblePersons.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        workStep.responsiblePersons.length > 1
                                            ? '${workStep.responsiblePersons.first} +${workStep.responsiblePersons.length - 1}'
                                            : workStep.responsiblePersons.first,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[600],
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              }).toList(),
            );
          },
        ),

        // Selected Items List
        if (widget.selectedWorkStepAssignments.isNotEmpty) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.playlist_add_check, color: Colors.grey[600], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Selected Work Steps:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.selectedWorkStepAssignments.map((assignment) {
                    final color = _getWorkStepColor(assignment.workStep.step);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: color.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getWorkStepIcon(assignment.workStep.step),
                            size: 14,
                            color: color,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            assignment.workStep.displayName,
                            style: TextStyle(
                              fontSize: 12,
                              color: color,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => _toggleSelection(assignment.workStep),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: color.withOpacity(0.2),
                              ),
                              child: Icon(
                                Icons.close,
                                size: 12,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}