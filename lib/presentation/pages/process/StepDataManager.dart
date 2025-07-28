import 'package:flutter/material.dart';
import 'package:nrc/constants/colors.dart';
import '../../../data/models/job_step_models.dart';

class StepDataManager {
  static const orderedStepNames = [
    'PaperStore',
    'PrintingDetails',
    'Corrugation',
    'FluteLaminateBoardConversion',
    'Punching',
    'SideFlapPasting',
    'QualityDept',
    'DispatchProcess',
  ];

  // Role-based step filtering
  static List<StepType> getStepsForRole(String? userRole) {
    switch (userRole?.toLowerCase()) {
      case 'production_head':
      case 'production head':
        return [
          StepType.corrugation,
          StepType.fluteLamination,
          StepType.punching,
          StepType.flapPasting,
        ];
      case 'printer':
        return [StepType.printing];
      case 'qc_manager':
      case 'qc manager':
        return [StepType.qc];
      case 'dispatch_executive':
      case 'dispatch executive':
        return [StepType.dispatch];
      case 'admin':
        return [
          StepType.paperStore,
          StepType.printing,
          StepType.corrugation,
          StepType.fluteLamination,
          StepType.punching,
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
          StepType.flapPasting,
          StepType.qc,
          StepType.dispatch,
        ];
    }
  }

  static bool isStepAllowedForRole(StepType stepType, String? userRole) {
    final allowedSteps = getStepsForRole(userRole);
    return allowedSteps.contains(stepType);
  }

  static String getDisplayName(String stepName) {
    switch (stepName) {
      case 'PaperStore': return 'Paper Store';
      case 'PrintingDetails': return 'Printing';
      case 'Corrugation': return 'Corrugation';
      case 'FluteLaminateBoardConversion': return 'Flute Lamination';
      case 'Punching': return 'Punching';
      case 'SideFlapPasting': return 'Flap Pasting';
      case 'QualityDept': return 'Quality Control';
      case 'DispatchProcess': return 'Dispatch';
      default: return stepName;
    }
  }

  static StepType getStepTypeFromString(String step) {
    switch (step.toLowerCase()) {
      case 'paperstore':
        return StepType.paperStore;
      case 'printingdetails':
        return StepType.printing;
      case 'corrugation':
        return StepType.corrugation;
      case 'flutelaminateboardconversion':
        return StepType.fluteLamination;
      case 'punching':
        return StepType.punching;
      case 'sideflappasting':
        return StepType.flapPasting;
      case 'qualitydept':
        return StepType.qc;
      case 'dispatchprocess':
        return StepType.dispatch;
      default:
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
        return ['Sheet Size', 'Required Qty', 'Available Qty', 'Issue Date', 'GSM', 'Remarks'];
      case StepType.printing:
        return ['Date', 'Operator Name', 'Colors Used', 'Quantity OK', 'Wastage', 'Machine', 'Remarks'];
      case StepType.corrugation:
        return ['Date', 'Operator Name', 'Machine No', 'Sheets Count', 'Size', 'GSM', 'Flute Type', 'Remarks'];
      case StepType.fluteLamination:
        return ['Date', 'Operator Name', 'Film Type', 'OK Quantity', 'Adhesive', 'Wastage', 'Remarks'];
      case StepType.punching:
        return ['Date', 'Operator Name', 'Machine', 'OK Quantity', 'Die Used', 'Wastage', 'Remarks'];
      case StepType.flapPasting:
        return ['Date', 'Operator Name', 'Machine No', 'Adhesive', 'Quantity', 'Wastage', 'Remarks'];
      case StepType.qc:
        return ['Date', 'Checked By', 'Pass Quantity', 'Reject Quantity', 'Reason for Rejection', 'Remarks'];
      case StepType.dispatch:
        return ['Date', 'Operator Name', 'No of Boxes', 'Dispatch No', 'Dispatch Date', 'Balance Qty', 'Remarks'];
      default:
        return [];
    }
  }

  static int getStepNumber(StepType stepType) {
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
        return 6;
      case StepType.qc:
        return 7;
      case StepType.dispatch:
        return 8;
      default:
        return 1;
    }
  }

  static List<StepData> initializeSteps(List<dynamic>? assignedSteps, {String? userRole}) {
    List<StepData> steps = [
      StepData(
        type: StepType.jobAssigned,
        title: 'Job Assigned',
        description: 'Job has been assigned and ready to start',
        status: StepStatus.completed,
      ),
    ];

    if (assignedSteps != null && assignedSteps.isNotEmpty) {
      final sortedSteps = List<Map<String, dynamic>>.from(assignedSteps);
      sortedSteps.sort((a, b) {
        int aIndex = orderedStepNames.indexOf(a['stepName'] ?? '');
        int bIndex = orderedStepNames.indexOf(b['stepName'] ?? '');
        return aIndex.compareTo(bIndex);
      });

      for (final stepMap in sortedSteps) {
        final stepName = stepMap['stepName'] ?? '';
        final displayName = getDisplayName(stepName);
        final stepType = getStepTypeFromString(stepName);

        // Filter steps based on user role
        if (userRole != null && !isStepAllowedForRole(stepType, userRole)) {
          continue; // Skip this step if not allowed for the user's role
        }

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

    return steps;
  }
}