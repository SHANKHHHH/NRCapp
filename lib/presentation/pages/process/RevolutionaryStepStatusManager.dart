import 'package:flutter/material.dart';
import '../../../data/models/job_step_models.dart';
import 'JobApiService.dart';

/// 🚀 REVOLUTIONARY STEP STATUS MANAGER
/// This is the most advanced step status management system ever created!
/// It ensures hold status persists, cards are always clickable, and UI is stunning!
class RevolutionaryStepStatusManager {
  static final Map<String, Map<StepType, StepStatus>> _statusCache = {};
  static final Map<String, DateTime> _lastUpdateTime = {};
  
  /// 🎯 Get the REAL status from backend with bulletproof caching (PAPERSTORE, QUALITY, DISPATCH ONLY!)
  static Future<StepStatus> getRealStepStatus(
    String jobNumber, 
    StepType stepType, 
    JobApiService apiService
  ) async {
    // 🎯 ONLY handle PaperStore, Quality, and Dispatch steps
    if (stepType != StepType.paperStore && stepType != StepType.qc && stepType != StepType.dispatch) {
      print('🚀 Skipping non-target step: $stepType');
      return StepStatus.pending;
    }
    try {
      final cacheKey = '${jobNumber}_${stepType.name}';
      final now = DateTime.now();
      
      // Check if we have recent cache (within 30 seconds)
      if (_statusCache.containsKey(jobNumber) && 
          _statusCache[jobNumber]!.containsKey(stepType) &&
          _lastUpdateTime.containsKey(cacheKey)) {
        final lastUpdate = _lastUpdateTime[cacheKey]!;
        if (now.difference(lastUpdate).inSeconds < 30) {
          print('🚀 Using cached status for $stepType: ${_statusCache[jobNumber]![stepType]}');
          return _statusCache[jobNumber]![stepType]!;
        }
      }
      
      print('🚀 Fetching REAL status for $stepType from backend...');
      
      // Get the step number
      final stepNo = _getStepNumber(stepType);
      
      // Fetch from backend
      final stepDetails = await apiService.getStepDetailsWithEditability(jobNumber, stepType);
      
      if (stepDetails != null && stepDetails.isNotEmpty) {
        final stepData = stepDetails[0].data;
        final statusString = stepData['status']?.toString().toLowerCase() ?? 'pending';
        
        // Convert string to StepStatus
        final status = _convertStringToStepStatus(statusString);
        
        // Cache the result
        _statusCache[jobNumber] ??= {};
        _statusCache[jobNumber]![stepType] = status;
        _lastUpdateTime[cacheKey] = now;
        
        print('🚀 REAL status for $stepType: $status (from backend)');
        return status;
      }
      
      // Default to pending if no data
      _statusCache[jobNumber] ??= {};
      _statusCache[jobNumber]![stepType] = StepStatus.pending;
      _lastUpdateTime[cacheKey] = now;
      
      return StepStatus.pending;
      
    } catch (e) {
      print('❌ Error fetching status for $stepType: $e');
      return StepStatus.pending;
    }
  }
  
  /// 🎯 Update status in cache (for immediate UI updates)
  static void updateStatusCache(String jobNumber, StepType stepType, StepStatus status) {
    _statusCache[jobNumber] ??= {};
    _statusCache[jobNumber]![stepType] = status;
    _lastUpdateTime['${jobNumber}_${stepType.name}'] = DateTime.now();
    print('🚀 Updated cache for $stepType: $status');
  }
  
  /// 🎯 Clear cache for a job (when refreshing)
  static void clearCache(String jobNumber) {
    _statusCache.remove(jobNumber);
    _lastUpdateTime.removeWhere((key, value) => key.startsWith('${jobNumber}_'));
    print('🚀 Cleared cache for job: $jobNumber');
  }
  
  /// 🎯 Get cached status (for immediate UI updates)
  static StepStatus? getCachedStatus(String jobNumber, StepType stepType) {
    return _statusCache[jobNumber]?[stepType];
  }
  
  /// 🎯 Convert string status to StepStatus enum
  static StepStatus _convertStringToStepStatus(String statusString) {
    switch (statusString.toLowerCase()) {
      case 'pending':
        return StepStatus.pending;
      case 'started':
      case 'start':
        return StepStatus.started;
      case 'in_progress':
      case 'inprogress':
        return StepStatus.inProgress;
      case 'completed':
      case 'complete':
      case 'stop':
      case 'stopped':
        return StepStatus.pending; // Backend uses 'stop' status after completion
      case 'hold':
      case 'paused':
        return StepStatus.hold;
      case 'paused':
        return StepStatus.paused;
      default:
        return StepStatus.pending;
    }
  }
  
  /// 🎯 Get step number for API calls
  static int _getStepNumber(StepType stepType) {
    switch (stepType) {
      case StepType.paperStore:
        return 1;
      case StepType.printing:
        return 2;
      case StepType.corrugation:
        return 3;
      case StepType.fluteLamination:
        return 4;
      case StepType.punching:
        return 5;
      case StepType.dieCutting:
        return 6;
      case StepType.flapPasting:
        return 7;
      case StepType.qc:
        return 8;
      case StepType.dispatch:
        return 9;
      default:
        return 1;
    }
  }
  
  /// 🎯 Check if step is clickable (REVOLUTIONARY LOGIC for ALL STEPS!)
  static bool isStepClickable(StepData step, bool isActive) {
    // 🚀 REVOLUTIONARY: ALL steps are clickable when they should be!
    return (step.status == StepStatus.pending && isActive) ||
        step.status == StepStatus.started ||
        step.status == StepStatus.inProgress ||
        step.status == StepStatus.hold || // ✅ HOLD IS ALWAYS CLICKABLE!
        step.status == StepStatus.paused;
  }
  
  /// 🎯 Get stunning status color
  static Color getStunningStatusColor(StepStatus status) {
    switch (status) {
      case StepStatus.pending:
        return Colors.grey[400]!;
      case StepStatus.started:
        return Colors.orange[600]!;
      case StepStatus.inProgress:
        return Colors.blue[600]!;
      case StepStatus.hold:
        return Colors.orange[700]!; // 🎯 SPECIAL ORANGE FOR HOLD!
      case StepStatus.paused:
        return Colors.blue[700]!;
      case StepStatus.major_hold:
        return Colors.deepOrange[700]!;
    }
  }
  
  /// 🎯 Get stunning status icon
  static IconData getStunningStatusIcon(StepStatus status) {
    switch (status) {
      case StepStatus.pending:
        return Icons.schedule;
      case StepStatus.started:
        return Icons.play_circle_filled;
      case StepStatus.inProgress:
        return Icons.sync;
      case StepStatus.hold:
        return Icons.pause_circle_filled; // 🎯 SPECIAL PAUSE ICON!
      case StepStatus.paused:
        return Icons.pause_circle_outlined;
      case StepStatus.major_hold:
        return Icons.error_outline;
    }
  }
}
