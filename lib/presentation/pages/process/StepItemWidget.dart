import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../constants/colors.dart';
import '../../../data/models/job_step_models.dart';
import 'StepStatusHelper.dart';

class StepItemWidget extends StatelessWidget {
  final StepData step;
  final int index;
  final bool isActive;
  final String? jobNumber;
  final VoidCallback onTap;

  const StepItemWidget({
    Key? key,
    required this.step,
    required this.index,
    required this.isActive,
    required this.jobNumber,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isClickable = step.type == StepType.jobAssigned ||
        (step.status == StepStatus.pending && isActive) ||
        step.status == StepStatus.started ||
        step.status == StepStatus.inProgress ||
        step.status == StepStatus.completed ||
        step.status == StepStatus.hold; // Add hold status as clickable

    // Enhanced styling for hold status
    final isHoldStatus = step.status == StepStatus.hold;
    final isCompletedStatus = step.status == StepStatus.completed;
    final isInProgress = step.status == StepStatus.inProgress || step.status == StepStatus.started;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: isActive ? 6 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isHoldStatus
              ? BorderSide(color: Colors.orange, width: 2)
              : isActive && !isCompletedStatus
                  ? BorderSide(color: AppColors.maincolor, width: 2)
                  : BorderSide.none,
        ),
        child: InkWell(
          onTap: isClickable ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: isHoldStatus
                  ? LinearGradient(
                      colors: [Colors.orange[50]!, Colors.orange[100]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : isInProgress
                      ? LinearGradient(
                          colors: [AppColors.maincolor.withOpacity(0.05), AppColors.maincolor.withOpacity(0.1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Enhanced icon container with better styling
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: isHoldStatus
                          ? Colors.orange[200]
                          : StepStatusHelper.getStepColor(step.status),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: (isHoldStatus ? Colors.orange : AppColors.maincolor).withOpacity(0.3),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: isHoldStatus
                          ? Icon(
                              Icons.pause_circle_filled,
                              color: Colors.orange[700],
                              size: 28,
                            )
                          : StepStatusHelper.getStepIcon(step.status, index + 1),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Enhanced title with better typography
                        Text(
                          step.title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isHoldStatus
                                ? Colors.orange[800]
                                : isActive && !isCompletedStatus
                                    ? AppColors.maincolor
                                    : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Enhanced description
                        Text(
                          step.description,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Enhanced status text with better styling
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isHoldStatus
                                ? Colors.orange[100]
                                : StepStatusHelper.getStatusTextColor(step.status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isHoldStatus
                                  ? Colors.orange[300]!
                                  : StepStatusHelper.getStatusTextColor(step.status).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            StepStatusHelper.getStepStatusText(step, jobNumber),
                            style: TextStyle(
                              fontSize: 12,
                              color: StepStatusHelper.getStatusTextColor(step.status),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Enhanced action icon
                  if (isClickable)
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isHoldStatus
                            ? Colors.orange[100]
                            : StepStatusHelper.getActionIconColor(step, isActive).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        StepStatusHelper.getActionIcon(step, isActive),
                        color: StepStatusHelper.getActionIconColor(step, isActive),
                        size: 20,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}