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
        step.status == StepStatus.completed;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        elevation: isActive ? 4 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isActive && step.status != StepStatus.completed
              ? BorderSide(color: AppColors.maincolor, width: 2)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: isClickable ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: StepStatusHelper.getStepColor(step.status),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Center(
                    child: StepStatusHelper.getStepIcon(step.status, index + 1),
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
                          color: isActive && step.status != StepStatus.completed
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
                        StepStatusHelper.getStepStatusText(step, jobNumber),
                        style: TextStyle(
                          fontSize: 13,
                          color: StepStatusHelper.getStatusTextColor(step.status),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isClickable)
                  Icon(
                    StepStatusHelper.getActionIcon(step, isActive),
                    color: StepStatusHelper.getActionIconColor(step, isActive),
                    size: 16,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}