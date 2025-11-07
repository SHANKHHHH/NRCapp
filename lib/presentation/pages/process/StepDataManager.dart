import 'package:flutter/material.dart';
import 'package:nrc/constants/colors.dart';
import '../../../data/models/job_step_models.dart';

class StepDataManager {
  // Maps the current planning's StepType to its dynamic step number (1-based)
  // This is computed each time initializeSteps is called based on assignedSteps order
  static Map<StepType, int> _dynamicStepNumberMap = {};
  static const orderedStepNames = [
    'PaperStore',
    'PrintingDetails', // Printing comes 3rd
    'Corrugation', // Corrugation comes 4th
    'FluteLaminateBoardConversion',
    'Punching',
    'Die Cutting', // Die Cutting step
    'SideFlapPasting',
    'QualityDept',
    'DispatchProcess',
  ];

  // Role-based step filtering for single role
  // This mapping MUST match the backend roleStepMapping in machineAccess.ts
  static List<StepType> getStepsForRole(String? userRole) {
    switch (userRole?.toLowerCase()) {
      case 'corrugator':
        return [StepType.corrugation];
      case 'flutelaminator':
        return [StepType.fluteLamination]; // Maps to FluteLaminateBoardConversion in backend
      case 'pasting_operator':
        return [StepType.flapPasting];
      case 'punching_operator':
        return [StepType.punching, StepType.dieCutting];
      case 'production_head':
      case 'production head':
        return [
          StepType.corrugation,
          StepType.fluteLamination,
          StepType.punching,
          StepType.dieCutting,
          StepType.flapPasting,
        ];
      case 'printer':
        return [StepType.printing];
      case 'qc_manager':
      case 'qc manager':
        return [StepType.qc];
      case 'dispatch_executive':
      case 'dispatch executive':
        return [StepType.dispatch, StepType.paperStore];
      case 'paperstore':
        return [
          StepType.paperStore,
        ];
      case 'flyingsquad':
        return [
          StepType.paperStore,
          StepType.printing,
          StepType.corrugation,
          StepType.fluteLamination,
          StepType.punching,
          StepType.dieCutting,
          StepType.flapPasting,
          StepType.qc,
          StepType.dispatch,
        ];
      default:
      // For unknown roles, return all steps
        return [
          StepType.paperStore,
          StepType.printing,
          StepType.corrugation,
          StepType.fluteLamination,
          StepType.punching,
          StepType.dieCutting,
          StepType.flapPasting,
          StepType.qc,
          StepType.dispatch,
        ];
    }
  }

  // Role-based step filtering for multiple roles
  static List<StepType> getStepsForRoles(List<String> userRoles) {
    Set<StepType> allAllowedSteps = {};
    
    print('DEBUG: getStepsForRoles called with roles: $userRoles');
    
    for (String role in userRoles) {
      final roleSteps = getStepsForRole(role);
      print('DEBUG: Role $role allows steps: $roleSteps');
      allAllowedSteps.addAll(roleSteps);
    }
    
    print('DEBUG: All allowed steps: $allAllowedSteps');
    
    // Convert back to list and sort by canonical order
    List<StepType> orderedSteps = [];
    final canonicalOrder = [
      StepType.paperStore,
      StepType.printing,
      StepType.corrugation,
      StepType.fluteLamination,
      StepType.punching,
      StepType.dieCutting,
      StepType.flapPasting,
      StepType.qc,
      StepType.dispatch,
    ];
    
    for (StepType stepType in canonicalOrder) {
      if (allAllowedSteps.contains(stepType)) {
        orderedSteps.add(stepType);
      }
    }
    
    return orderedSteps;
  }

  static bool isStepAllowedForRole(StepType stepType, String? userRole) {
    final allowedSteps = getStepsForRole(userRole);
    return allowedSteps.contains(stepType);
  }

  static bool isStepAllowedForRoles(StepType stepType, List<String> userRoles) {
    final allowedSteps = getStepsForRoles(userRoles);
    return allowedSteps.contains(stepType);
  }

  static String getDisplayName(String stepName) {
    switch (stepName) {
      case 'PaperStore': return 'Paper Store';
      case 'PrintingDetails': return 'Printing';
      case 'Corrugation': return 'Corrugation';
      case 'FluteLaminateBoardConversion': return 'Flute Lamination';
      case 'Punching': return 'Punching';
      case 'Die Cutting': return 'Die Cutting';
      case 'SideFlapPasting': return 'Flap Pasting';
      case 'QualityDept': return 'Quality Control';
      case 'DispatchProcess': return 'Dispatch';
      default: return stepName;
    }
  }

  static StepType getStepTypeFromString(String step) {
    print('DEBUG: Converting step string: "$step" to StepType');
    switch (step.toLowerCase()) {
      case 'paperstore':
        print('DEBUG: Converting to StepType.paperStore');
        return StepType.paperStore;
      case 'printingdetails':
        print('DEBUG: Converting to StepType.printing');
        return StepType.printing;
      case 'corrugation':
        print('DEBUG: Converting to StepType.corrugation');
        return StepType.corrugation;
      case 'flutelaminateboardconversion':
        print('DEBUG: Converting to StepType.fluteLamination');
        return StepType.fluteLamination;
      case 'punching':
        print('DEBUG: Converting to StepType.punching');
        return StepType.punching;
      case 'die cutting':
        print('DEBUG: Converting to StepType.dieCutting');
        return StepType.dieCutting;
      case 'sideflappasting':
        print('DEBUG: Converting to StepType.flapPasting');
        return StepType.flapPasting;
      case 'qualitydept':
        print('DEBUG: Converting to StepType.qc');
        return StepType.qc;
      case 'dispatchprocess':
        print('DEBUG: Converting to StepType.dispatch');
        return StepType.dispatch;
          default:
            print('DEBUG: Unknown step type, defaulting to StepType.paperStore');
            return StepType.paperStore;
    }
  }

  static StepStatus _convertBackendStatusToStepStatus(String backendStatus) {
    switch (backendStatus.toLowerCase()) {
      case 'planned':
        return StepStatus.pending;
      case 'start':
        return StepStatus.started;
      case 'in_progress':
        return StepStatus.inProgress;
      case 'paused':
        return StepStatus.paused;
      case 'hold':
        return StepStatus.hold;
      case 'major_hold':
        return StepStatus.major_hold;
      case 'stop':
      case 'stopped':
        return StepStatus.paused; // Backend uses 'stop' status
      case 'completed':
        return StepStatus.paused; // Backend uses 'stop' status
      default:
        return StepStatus.pending;
    }
  }

  static String getStepDescription(String displayName) {
    switch (displayName.toLowerCase()) {
      case 'paper store':
        return 'Check and prepare paper materials';
      case 'printing':
        return 'Print the materials as per specifications';
      case 'corrugation':
        return 'Apply corrugation process';
      case 'flute lamination':
        return 'Apply flute lamination';
      case 'punching':
        return 'Punch holes as required';
      case 'die cutting':
        return 'Cut materials using die cutting process';
      case 'flap pasting':
        return 'Paste flaps and complete assembly';
      case 'quality control':
      case 'qc':
        return 'Final quality inspection';
      case 'dispatch':
        return 'Package and dispatch the order';
      default:
        return '';
    }
  }

  static List<String> getFieldNamesForStep(StepType type) {
    // 🎯 SIMPLIFIED FORMS: Only show essential fields
    // All other fields (machine codes, operator names, dates, etc.) are auto-populated from job details and user info
    switch (type) {
      case StepType.paperStore:
        // PaperStore: No fields (all data comes from completion form after stop)
        // Auto-populated: Required Qty (from PO quantity), Sheet Size, GSM, Mill, Quality, Extra Margin (from job details)
        return [];
      
      case StepType.printing:
        // Printing: No fields (all data comes from completion form after stop)
        // Auto-populated: Colors, Inks, Coating, Sheets, Machine codes, Operator (from job details + system)
        return [];
      
      case StepType.corrugation:
        // Corrugation: No fields (all data comes from completion form after stop)
        // Auto-populated: Size, GSM1, GSM2, Flute Type, Machine codes, Operator (from job details + system)
        return [];
      
      case StepType.fluteLamination:
        // FluteLamination: No fields (all data comes from completion form after stop)
        // Auto-populated: Film Type, Adhesive (from job details)
        return [];
      
      case StepType.punching:
        // Punching: No fields (all data comes from completion form after stop)
        // Auto-populated: Die Used (from job's diePunchCode), Machine codes, Operator
        return [];
      
      case StepType.dieCutting:
        // Die Cutting: No fields (all data comes from completion form after stop)
        // Auto-populated: Die Used (from job's diePunchCode), Machine codes, Operator
        return [];
      
      case StepType.flapPasting:
        // Flap Pasting: No fields (all data comes from completion form after stop)
        // Auto-populated: Adhesive (from job details), Machine codes, Operator
        return [];
      
      case StepType.qc:
        // Quality Control: No fields (all data comes from completion form after stop)
        // Auto-populated: Machine codes, Operator
        return [];
      
      case StepType.dispatch:
        // Dispatch: No fields (all data comes from completion form after stop)
        // Auto-populated: Dispatch No (from system), Balance Qty (calculated)
        return [];
      
      default:
        return [];
    }
  }

  static int getStepNumber(StepType stepType) {
    // Prefer dynamic mapping from the current planning if available
    if (_dynamicStepNumberMap.isNotEmpty && _dynamicStepNumberMap.containsKey(stepType)) {
      return _dynamicStepNumberMap[stepType]!;
    }

    // Fallback to legacy static mapping
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
      case StepType.flapPasting:
        return 6; // SideFlapPasting in backend uses stepNo: 6
      case StepType.dieCutting:
        return 6; // DieCutting not used (keep original)
      case StepType.qc:
        return 7; // QualityDept uses stepNo: 7
      case StepType.dispatch:
        return 8; // DispatchProcess uses stepNo: 8
      default:
        return 1;
    }
  }

  static List<StepData> initializeSteps(List<dynamic>? assignedSteps, {String? userRole, List<String>? userRoles}) {
    print('🔄 CLEAN INIT: Starting fresh step initialization');
    print('🔄 CLEAN INIT: User role: $userRole, User roles: $userRoles');
    
    List<StepData> steps = [];
    _dynamicStepNumberMap = {};

    if (assignedSteps == null || assignedSteps.isEmpty) {
      print('🔄 CLEAN INIT: No assigned steps, returning empty list');
      return steps;
    }

    // Get the current user role
    String? currentRole = userRole;
    if (userRoles != null && userRoles.isNotEmpty) {
      currentRole = userRoles.first;
    }
    
    print('🔄 CLEAN INIT: Current role: $currentRole');

    // Process each assigned step
    for (final stepData in assignedSteps) {
      final stepName = stepData['stepName'] ?? '';
      final stepType = getStepTypeFromString(stepName);
      final displayName = getDisplayName(stepName);
      
      print('🔄 CLEAN INIT: Processing step: $stepName -> $stepType');
      
      // Check if this step should be shown for the current role
      bool shouldShowStep = _shouldShowStepForRole(stepType, currentRole);
      print('🔄 CLEAN INIT: Should show $displayName for role $currentRole: $shouldShowStep');
      
      if (!shouldShowStep) {
        continue;
      }
      
      // Convert backend status
      String backendStatus = stepData['status'] ?? 'planned';
      StepStatus stepStatus = _convertBackendStatusToStepStatus(backendStatus);
      
      // Add the step
      steps.add(StepData(
        type: stepType,
        title: displayName,
        description: getStepDescription(displayName),
        status: stepStatus,
      ));
      
      print('🔄 CLEAN INIT: Added step: $displayName with status: $stepStatus');
    }
    
    print('🔄 CLEAN INIT: Final steps count: ${steps.length}');
    for (int i = 0; i < steps.length; i++) {
      print('🔄 CLEAN INIT: Step $i: ${steps[i].title} (${steps[i].type}) - ${steps[i].status}');
    }
    
    return steps;
  }
  
  // Clean role filtering logic
  static bool _shouldShowStepForRole(StepType stepType, String? role) {
    if (role == null) {
      return true; // Show all steps if no role
    }
    
    switch (role.toLowerCase()) {
      case 'flutelaminator':
        return stepType == StepType.fluteLamination;
      case 'paperstore':
        return stepType == StepType.paperStore;
      case 'punching_operator':
        return stepType == StepType.punching;
      case 'printer':
        return stepType == StepType.printing;
      case 'corrugator':
        return stepType == StepType.corrugation;
      case 'pasting_operator':
        return stepType == StepType.flapPasting;
      case 'qc_manager':
        return stepType == StepType.qc;
      case 'dispatch_executive':
        return stepType == StepType.dispatch;
      case 'admin':
      case 'planner':
      case 'production_head':
      case 'flyingsquad':
        return true; // These roles see all steps
      default:
        return false; // Unknown roles see no steps
    }
  }

}