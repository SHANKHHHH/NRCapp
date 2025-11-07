import '../../../data/models/job_step_models.dart';

class StepProgressManager {
  // Define which steps can run in parallel
  // Note: Temporarily adjusted due to backend validation requirements
  static const Map<StepType, List<StepType>> parallelSteps = {
    StepType.corrugation: [StepType.printing], // Corrugation can run in parallel with printing
    StepType.printing: [StepType.corrugation], // Printing can run in parallel with corrugation
  };

  // Check if a step can run in parallel with another step
  static bool canRunInParallel(StepType stepType) {
    return parallelSteps.containsKey(stepType);
  }

  // Get all steps that can run in parallel with the given step
  static List<StepType> getParallelSteps(StepType stepType) {
    return parallelSteps[stepType] ?? [];
  }

  // Check if all parallel steps are completed
  static bool areAllParallelStepsCompleted(List<StepData> steps, StepType stepType) {
    final parallelStepTypes = getParallelSteps(stepType);
    if (parallelStepTypes.isEmpty) return true;

    for (final parallelStepType in parallelStepTypes) {
      final parallelStep = steps.firstWhere(
        (step) => step.type == parallelStepType,
        orElse: () => StepData(
          type: parallelStepType,
          title: '',
          description: '',
          status: StepStatus.paused, // Default to paused/stopped if not found
        ),
      );
      
      if (parallelStep.status != StepStatus.paused) {
        return false;
      }
    }
    return true;
  }

  // Check if a step should be activated (considering parallel execution)
  // UPDATED LOGIC: Steps can activate when previous steps are STARTED (matches new backend logic)
  // - Current step can START when previous step is at 'start' status
  // - Current step can STOP when previous step is at 'stop' status
  static bool shouldActivateStep(List<StepData> steps, int stepIndex) {
    if (stepIndex <= 0) return false;
    
    final step = steps[stepIndex];
    
    print('🔍 ACTIVATION CHECK for ${step.title} (index: $stepIndex):');
    
    // Special case: FluteLamination requires both Printing AND Corrugation to be started or completed (matches backend)
    if (step.type == StepType.fluteLamination) {
      final printingStep = steps.firstWhere(
        (s) => s.type == StepType.printing,
        orElse: () => StepData(type: StepType.printing, title: '', description: '', status: StepStatus.paused),
      );
      final corrugationStep = steps.firstWhere(
        (s) => s.type == StepType.corrugation,
        orElse: () => StepData(type: StepType.corrugation, title: '', description: '', status: StepStatus.paused),
      );
      
      // Both Printing and Corrugation must be started or stopped for FluteLamination to start (matches backend logic)
      final printingReady = printingStep.status == StepStatus.started || printingStep.status == StepStatus.paused;
      final corrugationReady = corrugationStep.status == StepStatus.started || corrugationStep.status == StepStatus.paused;
      
      print('  - Printing status: ${printingStep.status} (ready: $printingReady)');
      print('  - Corrugation status: ${corrugationStep.status} (ready: $corrugationReady)');
      print('  - FluteLamination can start: ${printingReady && corrugationReady}');
      
      return printingReady && corrugationReady;
    }
    
    // Special case: SideFlapPasting requires either Punching OR Die Cutting to be started or completed (matches backend)
    if (step.type == StepType.flapPasting) {
      final punchingStep = steps.firstWhere(
        (s) => s.type == StepType.punching,
        orElse: () => StepData(type: StepType.punching, title: '', description: '', status: StepStatus.paused),
      );
      final dieCuttingStep = steps.firstWhere(
        (s) => s.type == StepType.dieCutting,
        orElse: () => StepData(type: StepType.dieCutting, title: '', description: '', status: StepStatus.paused),
      );
      
      // Either Punching OR Die Cutting must be started or stopped for SideFlapPasting to start (matches backend logic)
      final punchingReady = punchingStep.status == StepStatus.started || punchingStep.status == StepStatus.paused;
      final dieCuttingReady = dieCuttingStep.status == StepStatus.started || dieCuttingStep.status == StepStatus.paused;
      
      print('  - Punching status: ${punchingStep.status} (ready: $punchingReady)');
      print('  - Die Cutting status: ${dieCuttingStep.status} (ready: $dieCuttingReady)');
      print('  - SideFlapPasting can start: ${punchingReady || dieCuttingReady}');
      
      return punchingReady || dieCuttingReady;
    }
    
    // If this step can run in parallel, check if previous steps are started
    if (canRunInParallel(step.type)) {
      print('  - Step can run in parallel, checking previous non-parallel steps...');
      // Check if all previous non-parallel steps are started or completed
      for (int i = 1; i < stepIndex; i++) {
        final previousStep = steps[i];
        print('    Previous step $i: ${previousStep.title} (${previousStep.type}) - Status: ${previousStep.status}');
        
        if (!canRunInParallel(previousStep.type) && 
            previousStep.status != StepStatus.started && 
            previousStep.status != StepStatus.inProgress &&
            previousStep.status != StepStatus.paused) {
          print('    ❌ Blocked by non-parallel step: ${previousStep.title} (status: ${previousStep.status})');
          return false;
        }
      }
      print('  ✅ All previous non-parallel steps are ready');
      return true;
    } else {
      print('  - Step cannot run in parallel, checking all previous steps...');
      // For non-parallel steps, check if all previous steps are started or stopped
      // This allows parallel work while maintaining completion order
      for (int i = 1; i < stepIndex; i++) {
        final previousStep = steps[i];
        print('    Previous step $i: ${previousStep.title} (${previousStep.type}) - Status: ${previousStep.status}');
        
        if (previousStep.status != StepStatus.started && 
            previousStep.status != StepStatus.inProgress &&
            previousStep.status != StepStatus.paused) {
          print('    ❌ Blocked by previous step: ${previousStep.title} (status: ${previousStep.status})');
          return false;
        }
      }
      print('  ✅ All previous steps are ready');
      return true;
    }
  }

  static void moveToNextStep(
      List<StepData> steps,
      int completedStepIndex,
      Function(int) onActiveStepChanged,
      Function(String) onShowMessage,
      ) {
    if (completedStepIndex <= steps.length - 1) {
      // Find all steps that should be activated
      List<int> nextStepIndices = [];

      for (int i = completedStepIndex + 1; i < steps.length; i++) {
        if (shouldActivateStep(steps, i)) {
          nextStepIndices.add(i);
          steps[i].status = StepStatus.pending;
        }
      }

      if (nextStepIndices.isNotEmpty) {
        // Activate all found steps
        for (int stepIndex in nextStepIndices) {
          onActiveStepChanged(stepIndex);
          
          // If this step can run in parallel, also activate its parallel steps
          final step = steps[stepIndex];
          if (canRunInParallel(step.type)) {
            final parallelStepTypes = getParallelSteps(step.type);
            for (final parallelStepType in parallelStepTypes) {
              final parallelStepIndex = steps.indexWhere((s) => s.type == parallelStepType);
              if (parallelStepIndex != -1 && shouldActivateStep(steps, parallelStepIndex)) {
                steps[parallelStepIndex].status = StepStatus.pending;
                onActiveStepChanged(parallelStepIndex);
              }
            }
          }
        }
        
        // Create a message listing all activated steps
        String stepNames = nextStepIndices.map((i) => steps[i].title).join(', ');
        onShowMessage(
            '${steps[completedStepIndex].title} completed! Activated: $stepNames'
        );
      } else {
        // Only show "job completed" if ALL steps including Flap Pasting are stopped
        bool allStepsStopped = steps.every((step) => step.status == StepStatus.paused);
        if (allStepsStopped) {
          onShowMessage('All job steps stopped! Job is ready for final review.');
        } else {
          // Just show that this specific step stopped
          onShowMessage('${steps[completedStepIndex].title} stopped!');
        }
      }
    }
  }

  static bool isStepClickable(StepData step, bool isActive) {
    return (step.status == StepStatus.pending && isActive) ||
        step.status == StepStatus.started ||
        step.status == StepStatus.inProgress ||
        step.status == StepStatus.hold || // Add hold status as clickable
        (step.status == StepStatus.paused && step.formData.isNotEmpty);
  }
}
