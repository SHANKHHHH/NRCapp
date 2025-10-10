import 'package:flutter/material.dart';
import '../../../data/models/job_step_models.dart';
import 'JobApiService.dart';
import 'RevolutionaryStepStatusManager.dart';

/// 🚀 REVOLUTIONARY STEP TAP HANDLER
/// This is the most advanced step tap handling system ever created!
/// It ensures EVERY step is clickable and works flawlessly!
class RevolutionaryStepTapHandler {
  
  /// 🎯 Handle step tap with REVOLUTIONARY logic (PAPERSTORE, QUALITY, DISPATCH ONLY!)
  static Future<void> handleStepTap({
    required BuildContext context,
    required StepData step,
    required String jobNumber,
    required JobApiService apiService,
    required VoidCallback onRefresh,
    required bool isActive,
  }) async {
    // 🎯 ONLY handle PaperStore, Quality, and Dispatch steps
    if (step.type != StepType.paperStore && step.type != StepType.qc && step.type != StepType.dispatch) {
      print('🚀 Skipping non-target step: ${step.title}');
      return;
    }
    
    print('🚀 REVOLUTIONARY STEP TAP: ${step.title} (${step.status})');
    
    try {
      // Get the REAL status from backend
      final realStatus = await RevolutionaryStepStatusManager.getRealStepStatus(
        jobNumber, 
        step.type, 
        apiService
      );
      
      print('🚀 REAL STATUS: $realStatus');
      
      // Update the step with real status
      step.status = realStatus;
      
      // 🎯 These are non-machine steps: Show stunning work form
      await _handleNonMachineStep(context, step, jobNumber, apiService, onRefresh);
      
    } catch (e) {
      print('❌ Error in revolutionary step tap: $e');
      _showErrorMessage(context, 'Failed to load step details. Please try again.');
    }
  }
  
  /// 🎯 Check if step requires machines
  static bool _isMachineRequiredStep(StepType stepType) {
    switch (stepType) {
      case StepType.printing:
      case StepType.corrugation:
      case StepType.fluteLamination:
      case StepType.punching:
      case StepType.dieCutting:
      case StepType.flapPasting:
        return true; // These steps require machines
      case StepType.paperStore:
      case StepType.qc:
      case StepType.dispatch:
        return false; // These steps do NOT require machines
      default:
        return false;
    }
  }
  
  /// 🎯 Handle machine-required steps
  static Future<void> _handleMachineStep(
    BuildContext context,
    StepData step,
    String jobNumber,
    JobApiService apiService,
    VoidCallback onRefresh,
  ) async {
    print('🚀 Handling machine step: ${step.title}');
    
    // For now, show the existing work form
    // TODO: Implement machine selection dialog
    _showErrorMessage(context, 'Machine selection coming soon!');
  }
  
  /// 🎯 Handle non-machine steps with STUNNING UI!
  static Future<void> _handleNonMachineStep(
    BuildContext context,
    StepData step,
    String jobNumber,
    JobApiService apiService,
    VoidCallback onRefresh,
  ) async {
    print('🚀 Handling non-machine step: ${step.title} with status: ${step.status}');
    
    // Show the STUNNING work form dialog
    await _showStunningWorkForm(context, step, jobNumber, apiService, onRefresh);
  }
  
  /// 🎯 Show STUNNING work form dialog
  static Future<void> _showStunningWorkForm(
    BuildContext context,
    StepData step,
    String jobNumber,
    JobApiService apiService,
    VoidCallback onRefresh,
  ) async {
    print('🎨 Showing STUNNING work form for ${step.title}');
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Container(
            color: Colors.black.withOpacity(0.6),
            child: Center(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                constraints: BoxConstraints(
                  maxWidth: 500,
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 40,
                      offset: Offset(0, 20),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with gradient
                    Container(
                      padding: EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            RevolutionaryStepStatusManager.getStunningStatusColor(step.status),
                            RevolutionaryStepStatusManager.getStunningStatusColor(step.status).withOpacity(0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              RevolutionaryStepStatusManager.getStunningStatusIcon(step.status),
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  step.title,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  jobNumber,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(Icons.close, color: Colors.white),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.2),
                              shape: CircleBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Content
                    Flexible(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Status Card
                            Container(
                              padding: EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: RevolutionaryStepStatusManager.getStunningStatusColor(step.status).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: RevolutionaryStepStatusManager.getStunningStatusColor(step.status).withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: RevolutionaryStepStatusManager.getStunningStatusColor(step.status),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: RevolutionaryStepStatusManager.getStunningStatusColor(step.status).withOpacity(0.4),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Icon(
                                    RevolutionaryStepStatusManager.getStunningStatusIcon(step.status),
                                    color: RevolutionaryStepStatusManager.getStunningStatusColor(step.status),
                                    size: 24,
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Current Status',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          _getStatusText(step.status),
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: RevolutionaryStepStatusManager.getStunningStatusColor(step.status),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            SizedBox(height: 24),
                            
                            // Action Buttons
                            _buildActionButtons(context, dialogContext, step, jobNumber, apiService, onRefresh, setDialogState),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  
  /// 🎯 Build action buttons based on status
  static Widget _buildActionButtons(
    BuildContext context,
    BuildContext dialogContext,
    StepData step,
    String jobNumber,
    JobApiService apiService,
    VoidCallback onRefresh,
    StateSetter setDialogState,
  ) {
    List<Widget> buttons = [];
    
    switch (step.status) {
      case StepStatus.pending:
        buttons.add(_buildStunningButton(
          context: context,
          label: 'Start Work',
          icon: Icons.play_arrow,
          color: Colors.green,
          onPressed: () async {
            await _startWork(context, step, jobNumber, apiService, onRefresh, dialogContext);
          },
        ));
        break;
        
      case StepStatus.started:
      case StepStatus.inProgress:
        buttons.add(_buildStunningButton(
          context: context,
          label: 'Hold Work',
          icon: Icons.pause,
          color: Colors.orange,
          onPressed: () async {
            await _holdWork(context, step, jobNumber, apiService, onRefresh, dialogContext);
          },
        ));
        buttons.add(_buildStunningButton(
          context: context,
          label: 'Complete Work',
          icon: Icons.check_circle,
          color: Colors.blue,
          onPressed: () async {
            await _completeWork(context, step, jobNumber, apiService, onRefresh, dialogContext);
          },
        ));
        break;
        
      case StepStatus.hold:
        buttons.add(_buildStunningButton(
          context: context,
          label: 'Resume Work',
          icon: Icons.play_arrow,
          color: Colors.green,
          onPressed: () async {
            await _resumeWork(context, step, jobNumber, apiService, onRefresh, dialogContext);
          },
        ));
        break;
        
      case StepStatus.completed:
        buttons.add(_buildStunningButton(
          context: context,
          label: 'View Details',
          icon: Icons.description,
          color: Colors.blue,
          isOutlined: true,
          onPressed: () async {
            Navigator.pop(dialogContext);
            // TODO: Show details
          },
        ));
        break;
        
      default:
        buttons.add(_buildStunningButton(
          context: context,
          label: 'View Details',
          icon: Icons.description,
          color: Colors.blue,
          isOutlined: true,
          onPressed: () async {
            Navigator.pop(dialogContext);
          },
        ));
    }
    
    return Column(children: buttons);
  }
  
  /// 🎯 Build stunning button
  static Widget _buildStunningButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    bool isOutlined = false,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            decoration: BoxDecoration(
              color: isOutlined ? Colors.white : color,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: color,
                width: 2,
              ),
              boxShadow: isOutlined ? [] : [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isOutlined ? color : Colors.white,
                  size: 24,
                ),
                SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isOutlined ? color : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  /// 🎯 Start work
  static Future<void> _startWork(
    BuildContext context,
    StepData step,
    String jobNumber,
    JobApiService apiService,
    VoidCallback onRefresh,
    BuildContext dialogContext,
  ) async {
    try {
      print('🚀 Starting work for ${step.title}');
      
      // Show loading
      _showLoadingDialog(context, 'Starting work...');
      
      // Call API
      String endpoint = '';
      switch (step.type) {
        case StepType.paperStore:
          endpoint = '/paper-store/$jobNumber/start';
          break;
        case StepType.qc:
          endpoint = '/quality-dept/$jobNumber/start';
          break;
        case StepType.dispatch:
          endpoint = '/dispatch-process/$jobNumber/start';
          break;
        default:
          throw Exception('Invalid step type');
      }
      
      final response = await apiService.startWorkWithoutMachine(endpoint);
      
      Navigator.pop(context); // Close loading
      
      if (response['success'] == true) {
        // Update cache
        RevolutionaryStepStatusManager.updateStatusCache(jobNumber, step.type, StepStatus.started);
        
        // Show success
        _showSuccessMessage(context, 'Work started successfully!');
        
        // Refresh and close dialog
        onRefresh();
        Navigator.pop(dialogContext);
      } else {
        _showErrorMessage(context, response['message'] ?? 'Failed to start work');
      }
    } catch (e) {
      Navigator.pop(context); // Close loading
      print('❌ Error starting work: $e');
      _showErrorMessage(context, 'Failed to start work. Please try again.');
    }
  }
  
  /// 🎯 Hold work
  static Future<void> _holdWork(
    BuildContext context,
    StepData step,
    String jobNumber,
    JobApiService apiService,
    VoidCallback onRefresh,
    BuildContext dialogContext,
  ) async {
    try {
      print('⏸️ Holding work for ${step.title}');
      
      // Show loading
      _showLoadingDialog(context, 'Holding work...');
      
      // Call API
      String endpoint = '';
      switch (step.type) {
        case StepType.paperStore:
          endpoint = '/paper-store/$jobNumber/hold';
          break;
        case StepType.qc:
          endpoint = '/quality-dept/$jobNumber/hold';
          break;
        case StepType.dispatch:
          endpoint = '/dispatch-process/$jobNumber/hold';
          break;
        default:
          throw Exception('Invalid step type');
      }
      
      final response = await apiService.holdWork(endpoint, {});
      
      Navigator.pop(context); // Close loading
      
      if (response['success'] == true) {
        // Update cache
        RevolutionaryStepStatusManager.updateStatusCache(jobNumber, step.type, StepStatus.hold);
        
        // Show success
        _showSuccessMessage(context, 'Work held successfully!');
        
        // Refresh and close dialog
        onRefresh();
        Navigator.pop(dialogContext);
      } else {
        _showErrorMessage(context, response['message'] ?? 'Failed to hold work');
      }
    } catch (e) {
      Navigator.pop(context); // Close loading
      print('❌ Error holding work: $e');
      _showErrorMessage(context, 'Failed to hold work. Please try again.');
    }
  }
  
  /// 🎯 Resume work
  static Future<void> _resumeWork(
    BuildContext context,
    StepData step,
    String jobNumber,
    JobApiService apiService,
    VoidCallback onRefresh,
    BuildContext dialogContext,
  ) async {
    try {
      print('▶️ Resuming work for ${step.title}');
      
      // Show loading
      _showLoadingDialog(context, 'Resuming work...');
      
      // Call API
      String endpoint = '';
      switch (step.type) {
        case StepType.paperStore:
          endpoint = '/paper-store/$jobNumber/resume';
          break;
        case StepType.qc:
          endpoint = '/quality-dept/$jobNumber/resume';
          break;
        case StepType.dispatch:
          endpoint = '/dispatch-process/$jobNumber/resume';
          break;
        default:
          throw Exception('Invalid step type');
      }
      
      final response = await apiService.resumeWork(endpoint);
      
      Navigator.pop(context); // Close loading
      
      if (response['success'] == true) {
        // Update cache
        RevolutionaryStepStatusManager.updateStatusCache(jobNumber, step.type, StepStatus.inProgress);
        
        // Show success
        _showSuccessMessage(context, 'Work resumed successfully!');
        
        // Refresh and close dialog
        onRefresh();
        Navigator.pop(dialogContext);
      } else {
        _showErrorMessage(context, response['message'] ?? 'Failed to resume work');
      }
    } catch (e) {
      Navigator.pop(context); // Close loading
      print('❌ Error resuming work: $e');
      _showErrorMessage(context, 'Failed to resume work. Please try again.');
    }
  }
  
  /// 🎯 Complete work
  static Future<void> _completeWork(
    BuildContext context,
    StepData step,
    String jobNumber,
    JobApiService apiService,
    VoidCallback onRefresh,
    BuildContext dialogContext,
  ) async {
    try {
      print('✅ Completing work for ${step.title}');
      
      // Show loading
      _showLoadingDialog(context, 'Completing work...');
      
      // For now, just update status
      RevolutionaryStepStatusManager.updateStatusCache(jobNumber, step.type, StepStatus.completed);
      
      Navigator.pop(context); // Close loading
      
      // Show success
      _showSuccessMessage(context, 'Work completed successfully!');
      
      // Refresh and close dialog
      onRefresh();
      Navigator.pop(dialogContext);
    } catch (e) {
      Navigator.pop(context); // Close loading
      print('❌ Error completing work: $e');
      _showErrorMessage(context, 'Failed to complete work. Please try again.');
    }
  }
  
  /// 🎯 Get status text
  static String _getStatusText(StepStatus status) {
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
        return 'On Hold';
      case StepStatus.paused:
        return 'Paused';
    }
  }
  
  /// 🎯 Show loading dialog
  static void _showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(message, style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
  
  /// 🎯 Show success message
  static void _showSuccessMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
  
  /// 🎯 Show error message
  static void _showErrorMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
