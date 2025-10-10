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
          StepType.printing,
          StepType.corrugation,
          StepType.fluteLamination,
          StepType.punching,
          StepType.dieCutting,
          StepType.flapPasting,
          StepType.qc,
          StepType.dispatch,
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
        print('DEBUG: Unknown step type, defaulting to StepType.jobAssigned');
        return StepType.jobAssigned;
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
    switch (type) {
      case StepType.paperStore:
        return ['Sheet Size', 'Required Qty', 'Available Qty', 'GSM', 'Mill', 'Extra Margin', 'Quality', 'Remarks'];
      case StepType.printing:
        return ['Quantity OK', 'Colors Used', 'Wastage', 'Inks Used', 'Coating Type', 'Separate Sheets', 'Extra Sheets', 'Remarks'];
      case StepType.corrugation:
        return ['Sheets Count', 'Size', 'GSM1 (Top Face)', 'GSM2 (Bottom Face)', 'Flute Type', 'Remarks'];
      case StepType.fluteLamination:
        return ['OK Quantity', 'Film Type', 'Adhesive', 'Wastage'];
      case StepType.punching:
        return ['OK Quantity', 'Die Used (diePunchCode)', 'Wastage', 'Remarks'];
      case StepType.dieCutting:
        return ['OK Quantity', 'Die Used (diePunchCode)', 'Wastage', 'Remarks'];
      case StepType.flapPasting:
        return ['Quantity', 'Adhesive', 'Wastage', 'Remarks'];
      case StepType.qc:
        return ['Pass Quantity', 'Reject Quantity', 'Reason for Rejection', 'Remarks'];
      case StepType.dispatch:
        return ['No of Boxes', 'Dispatch No', 'Balance Qty', 'Remarks'];
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

  static List<StepData> initializeSteps(List<dynamic>? assignedSteps, {String? userRole, List<String>? userRoles}) {
    print('DEBUG: Initializing steps with assignedSteps: $assignedSteps');
    print('DEBUG: User role: $userRole');
    print('DEBUG: User roles: $userRoles');
    
    List<StepData> steps = [
      StepData(
        type: StepType.jobAssigned,
        title: 'Job Assigned',
        description: 'Job has been assigned and ready to start',
        status: StepStatus.completed,
      ),
    ];

    // Reset dynamic mapping each time
    _dynamicStepNumberMap = {};

    if (assignedSteps != null && assignedSteps.isNotEmpty) {
      final sortedSteps = List<Map<String, dynamic>>.from(assignedSteps);
      print('DEBUG: Original assigned steps: $sortedSteps');
      
      // Sort primarily by provided stepNo if available; otherwise by canonical order
      sortedSteps.sort((a, b) {
        final aNo = a['stepNo'];
        final bNo = b['stepNo'];
        if (aNo != null && bNo != null) {
          final aNum = aNo is int ? aNo : int.tryParse(aNo.toString()) ?? 0;
          final bNum = bNo is int ? bNo : int.tryParse(bNo.toString()) ?? 0;
          return aNum.compareTo(bNum);
        }
        int aIndex = orderedStepNames.indexOf(a['stepName'] ?? '');
        int bIndex = orderedStepNames.indexOf(b['stepName'] ?? '');
        return aIndex.compareTo(bIndex);
      });
      
      print('DEBUG: Sorted steps: $sortedSteps');

      // Build steps list and dynamic step number mapping from the sorted order
      for (int i = 0; i < sortedSteps.length; i++) {
        final stepMap = sortedSteps[i];
        final stepName = stepMap['stepName'] ?? '';
        final displayName = getDisplayName(stepName);
        final stepType = getStepTypeFromString(stepName);
        
        print('DEBUG: Processing step - stepName: "$stepName", displayName: "$displayName", stepType: $stepType');

        // Filter steps based on user roles
        bool isStepAllowed = false;
        if (userRoles != null && userRoles.isNotEmpty) {
          // Use multiple roles if available
          isStepAllowed = isStepAllowedForRoles(stepType, userRoles);
          if (!isStepAllowed) {
            print('DEBUG: Skipping step "$displayName" - not allowed for roles: $userRoles');
            continue; // Skip this step if not allowed for the user's roles
          }
        } else if (userRole != null) {
          // Fallback to single role
          isStepAllowed = isStepAllowedForRole(stepType, userRole);
          if (!isStepAllowed) {
            print('DEBUG: Skipping step "$displayName" - not allowed for role: $userRole');
            continue; // Skip this step if not allowed for the user's role
          }
        } else {
          // No role restrictions
          isStepAllowed = true;
        }

        // Record the dynamic step number (prefer backend-provided stepNo)
        int dynamicStepNo;
        if (stepMap['stepNo'] != null) {
          dynamicStepNo = stepMap['stepNo'] is int
              ? stepMap['stepNo']
              : int.tryParse(stepMap['stepNo'].toString()) ?? (i + 1);
        } else {
          dynamicStepNo = i + 1;
        }
        _dynamicStepNumberMap[stepType] = dynamicStepNo;

        print('DEBUG: Adding step: $displayName ($stepType) with dynamic stepNo: $dynamicStepNo');
        steps.add(
          StepData(
            type: stepType,
            title: displayName,
            description: getStepDescription(displayName),
          ),
        );
      }
    }

    if (steps.length > 1) {
      steps[1].status = StepStatus.pending;
    }
    
    print('DEBUG: Final steps list:');
    for (int i = 0; i < steps.length; i++) {
      print('DEBUG: Step $i: ${steps[i].title} (${steps[i].type})');
    }

    return steps;
  }
}