import 'package:flutter/material.dart';
import '../../../data/models/job_step_models.dart';
import 'RevolutionaryStepStatusManager.dart';
import 'StepItemWidget.dart';

/// 🚀 REVOLUTIONARY STEP ITEM WIDGET
/// This is the most stunning step card widget ever created!
/// It ensures hold status is always visible and cards are always clickable!
class RevolutionaryStepItemWidget extends StatelessWidget {
  final StepData step;
  final int index;
  final bool isActive;
  final String? jobNumber;
  final VoidCallback onTap;

  const RevolutionaryStepItemWidget({
    Key? key,
    required this.step,
    required this.index,
    required this.isActive,
    required this.jobNumber,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 🎯 REVOLUTIONARY LOGIC: ONLY PaperStore, Quality, and Dispatch steps are clickable!
    final isClickable = RevolutionaryStepStatusManager.isStepClickable(step, isActive);
    
    // 🎯 If this is not a target step, use the original logic
    if (step.type != StepType.paperStore && step.type != StepType.qc && step.type != StepType.dispatch) {
      return _buildOriginalStepCard(context);
    }
    
    // 🎨 Enhanced styling for different statuses
    final isCompletedStatus = step.status == StepStatus.completed;
    final isInProgress = step.status == StepStatus.inProgress || step.status == StepStatus.started;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: isActive ? 8 : 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: _getBorderSide(step.status, isActive, isCompletedStatus),
        ),
        child: InkWell(
          onTap: isClickable ? onTap : null,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: _getGradient(step.status, isInProgress),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  // 🎨 REVOLUTIONARY ICON CONTAINER
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: RevolutionaryStepStatusManager.getStunningStatusColor(step.status),
                      borderRadius: BorderRadius.circular(35),
                      boxShadow: [
                        BoxShadow(
                          color: RevolutionaryStepStatusManager.getStunningStatusColor(step.status).withOpacity(0.4),
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _getStepIcon(step.status, index + 1),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 🎨 REVOLUTIONARY TITLE
                        Text(
                          step.title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _getTitleColor(step.status, isActive, isCompletedStatus),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // 🎨 REVOLUTIONARY DESCRIPTION
                        Text(
                          step.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // 🎨 REVOLUTIONARY STATUS BADGE
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: RevolutionaryStepStatusManager.getStunningStatusColor(step.status).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                              color: RevolutionaryStepStatusManager.getStunningStatusColor(step.status).withOpacity(0.4),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                RevolutionaryStepStatusManager.getStunningStatusIcon(step.status),
                                color: RevolutionaryStepStatusManager.getStunningStatusColor(step.status),
                                size: 16,
                              ),
                              SizedBox(width: 8),
                              Text(
                                _getStatusText(step.status),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: RevolutionaryStepStatusManager.getStunningStatusColor(step.status),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // 🎨 REVOLUTIONARY ACTION ICON
                  if (isClickable)
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: RevolutionaryStepStatusManager.getStunningStatusColor(step.status).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: RevolutionaryStepStatusManager.getStunningStatusColor(step.status).withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        _getActionIcon(step.status, isActive),
                        color: RevolutionaryStepStatusManager.getStunningStatusColor(step.status),
                        size: 24,
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
  
  /// 🎨 Get border side based on status
  BorderSide _getBorderSide(StepStatus status, bool isActive, bool isCompleted) {
    if (status == StepStatus.hold) {
      return BorderSide(color: Colors.orange, width: 3);
    } else if (isActive && !isCompleted) {
      return BorderSide(color: RevolutionaryStepStatusManager.getStunningStatusColor(status), width: 2);
    }
    return BorderSide.none;
  }
  
  /// 🎨 Get gradient based on status
  LinearGradient? _getGradient(StepStatus status, bool isInProgress) {
    if (status == StepStatus.hold) {
      return LinearGradient(
        colors: [Colors.orange[50]!, Colors.orange[100]!],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (isInProgress) {
      return LinearGradient(
        colors: [
          RevolutionaryStepStatusManager.getStunningStatusColor(status).withOpacity(0.08),
          RevolutionaryStepStatusManager.getStunningStatusColor(status).withOpacity(0.15)
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    return null;
  }
  
  /// 🎨 Get step icon
  Widget _getStepIcon(StepStatus status, int stepNumber) {
    if (status == StepStatus.hold) {
      return Icon(
        Icons.pause_circle_filled,
        color: Colors.white,
        size: 32,
      );
    }
    
    switch (status) {
      case StepStatus.pending:
        return Text(
          '$stepNumber',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        );
      case StepStatus.started:
        return Icon(
          Icons.play_circle_filled,
          color: Colors.white,
          size: 32,
        );
      case StepStatus.inProgress:
        return Icon(
          Icons.sync,
          color: Colors.white,
          size: 32,
        );
      case StepStatus.completed:
        return Icon(
          Icons.check_circle,
          color: Colors.white,
          size: 32,
        );
      case StepStatus.paused:
        return Icon(
          Icons.pause_circle_filled,
          color: Colors.white,
          size: 32,
        );
      default:
        return Text(
          '$stepNumber',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        );
    }
  }
  
  /// 🎨 Get title color
  Color _getTitleColor(StepStatus status, bool isActive, bool isCompleted) {
    if (status == StepStatus.hold) {
      return Colors.orange[800]!;
    } else if (isActive && !isCompleted) {
      return RevolutionaryStepStatusManager.getStunningStatusColor(status);
    }
    return Colors.black87;
  }
  
  /// 🎨 Get status text
  String _getStatusText(StepStatus status) {
    switch (status) {
      case StepStatus.pending:
        return 'Ready to Start';
      case StepStatus.started:
        return 'Work Started';
      case StepStatus.inProgress:
        return 'In Progress';
      case StepStatus.completed:
        return 'Completed';
      case StepStatus.hold:
        return 'On Hold - Click to Resume';
      case StepStatus.paused:
        return 'Paused';
    }
  }
  
  /// 🎨 Get action icon
  IconData _getActionIcon(StepStatus status, bool isActive) {
    if (status == StepStatus.pending && isActive) {
      return Icons.play_arrow;
    } else if (status == StepStatus.started || status == StepStatus.inProgress) {
      return Icons.edit;
    } else if (status == StepStatus.hold) {
      return Icons.play_circle_outline;
    } else if (status == StepStatus.completed) {
      return Icons.visibility;
    }
      return Icons.arrow_forward_ios;
  }
  
  /// 🎯 Build original step card (for non-target steps - DON'T TOUCH!)
  Widget _buildOriginalStepCard(BuildContext context) {
    // Return the ORIGINAL StepItemWidget - DON'T TOUCH OTHER STEPS!
    return StepItemWidget(
      step: step,
      index: index,
      isActive: isActive,
      jobNumber: jobNumber,
      onTap: onTap,
    );
  }
}
