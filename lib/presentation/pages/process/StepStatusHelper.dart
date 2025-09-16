import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../constants/colors.dart';
import '../../../data/models/job_step_models.dart';

class StepStatusHelper {
  static String getStepStatusText(StepData step, String? jobNumber) {
    switch (step.status) {
      case StepStatus.pending:
        if (step.type == StepType.jobAssigned) {
          return 'Job Number: ${jobNumber ?? ''}';
        }
        return 'Ready to start - Click to begin work';
      case StepStatus.started:
        return 'Work started - Click to add/edit details';
      case StepStatus.inProgress:
        return 'In progress - Details saved - Click to edit or complete';
      case StepStatus.completed:
        if (step.type == StepType.jobAssigned) {
          return 'Job Number: ${jobNumber ?? ''}';
        }
        return 'Work completed ✓';
      case StepStatus.paused:
        return 'Work paused - Click to resume or edit';
    }
  }

  static Color getStepColor(StepStatus status) {
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

  static Widget getStepIcon(StepStatus status, int stepNumber) {
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

  static Color getStatusTextColor(StepStatus status) {
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

  static IconData getActionIcon(StepData step, bool isStepActive) {
    if (step.status == StepStatus.pending && isStepActive) {
      return Icons.play_arrow;
    } else if (step.status == StepStatus.started || step.status == StepStatus.inProgress) {
      return Icons.edit;
    } else if (step.status == StepStatus.completed) {
      return Icons.visibility;
    } else if (step.type == StepType.jobAssigned) {
      return Icons.info_outline;
    }
    return Icons.arrow_forward_ios;
  }

  static Color getActionIconColor(StepData step, bool isStepActive) {
    if (step.status == StepStatus.pending && isStepActive) {
      return AppColors.maincolor;
    } else if (step.status == StepStatus.started || step.status == StepStatus.inProgress) {
      return AppColors.maincolor;
    } else if (step.status == StepStatus.completed && step.formData.isNotEmpty) {
      return Colors.grey[600]!;
    }
    return AppColors.maincolor;
  }
}