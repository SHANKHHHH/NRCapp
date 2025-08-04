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
          status: StepStatus.completed, // Default to completed if not found
        ),
      );
      
      if (parallelStep.status != StepStatus.completed) {
        return false;
      }
    }
    return true;
  }

  // Check if a step should be activated (considering parallel execution)
  static bool shouldActivateStep(List<StepData> steps, int stepIndex) {
    if (stepIndex <= 0) return false;
    
    final step = steps[stepIndex];
    
    // If this step can run in parallel, check if previous steps are completed
    if (canRunInParallel(step.type)) {
      // Check if all previous non-parallel steps are completed
      for (int i = 1; i < stepIndex; i++) {
        final previousStep = steps[i];
        if (!canRunInParallel(previousStep.type) && previousStep.status != StepStatus.completed) {
          return false;
        }
      }
      return true;
    } else {
      // For non-parallel steps, check if all previous steps are completed
      for (int i = 1; i < stepIndex; i++) {
        if (steps[i].status != StepStatus.completed) {
          return false;
        }
      }
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
        onShowMessage('All job steps completed! Job is ready for final review.');
      }
    }
  }

  static bool isStepClickable(StepData step, bool isActive) {
    return step.type == StepType.jobAssigned ||
        (step.status == StepStatus.pending && isActive) ||
        step.status == StepStatus.started ||
        step.status == StepStatus.inProgress ||
        (step.status == StepStatus.completed && step.formData.isNotEmpty);
  }
}
