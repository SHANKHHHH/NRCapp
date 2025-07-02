import '../../presentation/pages/work/AssignWorkSteps.dart';
import 'Machine.dart';
import 'WorkStep.dart';

class WorkStepAssignment {
  final WorkStep workStep;
  Machine? selectedMachine;
  String? responsiblePerson;
  String? customPersonName;

  WorkStepAssignment({
    required this.workStep,
    this.selectedMachine,
    this.responsiblePerson,
    this.customPersonName,
  });
}