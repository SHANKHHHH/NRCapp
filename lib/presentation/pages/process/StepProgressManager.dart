import '../../../data/models/job_step_models.dart';

class StepProgressManager {
  static void moveToNextStep(
      List<StepData> steps,
      int completedStepIndex,
      Function(int) onActiveStepChanged,
      Function(String) onShowMessage,
      ) {
    if (completedStepIndex <= steps.length - 1) {
      int nextStepIndex = completedStepIndex + 1;

      while (nextStepIndex < steps.length &&
          steps[nextStepIndex].status == StepStatus.completed) {
        nextStepIndex++;
      }

      if (nextStepIndex < steps.length) {
        onActiveStepChanged(nextStepIndex);
        steps[nextStepIndex].status = StepStatus.pending;
        onShowMessage(
            '${steps[completedStepIndex].title} completed! Moving to ${steps[nextStepIndex].title}.'
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
