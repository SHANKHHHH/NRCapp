import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../constants/colors.dart';
import '../../../data/models/job_step_models.dart';

class StepStatusHelper {
  static String getStepStatusText(StepData step, String? jobNumber) {
    switch (step.status) {
      case StepStatus.pending:
        return 'Ready to start - Click to begin work';
      case StepStatus.started:
        return 'Work started - Click to add/edit details';
      case StepStatus.inProgress:
        return 'In progress - Details saved - Click to edit or complete';
      case StepStatus.paused:
        // Check if step has formData - if so, it's completed, not just paused
        if (step.formData.isNotEmpty) {
          if (step.type == StepType.paperStore) {
            return 'Work completed - Accepted';
          } else {
            return 'Work completed - Click to view details';
          }
        }
        return 'Work paused - Click to resume or edit';
      case StepStatus.hold:
        // Enhanced text for hold status with better UX
        if (step.type == StepType.paperStore) {
          return 'Paper preparation paused - Click to resume work';
        } else if (step.type == StepType.qc) {
          return 'Quality check paused - Click to resume work';
        } else if (step.type == StepType.dispatch) {
          return 'Dispatch paused - Click to resume work';
        }
        return 'Work paused - Click to resume or edit';
      case StepStatus.major_hold:
        return 'MAJOR HOLD: Work is on major hold - Only admin/planner can resume';
    }
  }

  static Color getStepColor(StepStatus status, [StepData? step]) {
    switch (status) {
      case StepStatus.pending:
        return Colors.grey[200]!;
      case StepStatus.started:
        return Colors.orange[200]!;
      case StepStatus.inProgress:
        return AppColors.maincolor.withOpacity(0.2);
      case StepStatus.paused:
        // Show green for completed work (with formData), blue for paused
        if (step != null && step.formData.isNotEmpty) {
          return Colors.green[200]!;
        }
        return Colors.blue[200]!;
      case StepStatus.hold:
        return Colors.orange[300]!;
      case StepStatus.major_hold:
        return Colors.deepOrange[300]!;
    }
  }

  static Widget getStepIcon(StepStatus status, int stepNumber, [StepData? step]) {
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
      case StepStatus.paused:
        // Show check icon for completed work (with formData), pause icon for paused
        if (step != null && step.formData.isNotEmpty) {
          return Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 24,
          );
        }
        return Icon(
          Icons.pause_circle_filled,
          color: Colors.blue,
          size: 24,
        );
      case StepStatus.hold:
        return Icon(
          Icons.pause_circle_outlined,
          color: Colors.orange[700],
          size: 24,
        );
      case StepStatus.major_hold:
        return Icon(
          Icons.error_outline,
          color: Colors.deepOrange[700],
          size: 24,
        );
    }
  }

  static Color getStatusTextColor(StepStatus status, [StepData? step]) {
    switch (status) {
      case StepStatus.pending:
        return Colors.grey[600]!;
      case StepStatus.started:
        return Colors.orange[700]!;
      case StepStatus.inProgress:
        return AppColors.maincolor;
      case StepStatus.paused:
        // Show green for completed work (with formData), blue for paused
        if (step != null && step.formData.isNotEmpty) {
          return Colors.green;
        }
        return Colors.blue;
      case StepStatus.hold:
        return Colors.orange[700]!;
      case StepStatus.major_hold:
        return Colors.deepOrange[700]!;
    }
  }

  static IconData getActionIcon(StepData step, bool isStepActive) {
    if (step.status == StepStatus.pending && isStepActive) {
      return Icons.play_arrow;
    } else if (step.status == StepStatus.started || step.status == StepStatus.inProgress) {
      return Icons.edit;
    } else if (step.status == StepStatus.hold) {
      return Icons.play_circle_outline;
    }
    return Icons.arrow_forward_ios;
  }

  static Color getActionIconColor(StepData step, bool isStepActive) {
    if (step.status == StepStatus.pending && isStepActive) {
      return AppColors.maincolor;
    } else if (step.status == StepStatus.started || step.status == StepStatus.inProgress) {
      return AppColors.maincolor;
    } else if (step.status == StepStatus.hold) {
      return Colors.orange[700]!;
    }
    return AppColors.maincolor;
  }
}