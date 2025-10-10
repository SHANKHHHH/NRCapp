import 'Machine.dart';
import 'WorkStep.dart';

class WorkStepAssignment {
  final WorkStep workStep;
  Machine? selectedMachine; // Keep for backward compatibility
  List<Machine> selectedMachines; // New: support multiple machines
  String? responsiblePerson;
  String? customPersonName;

  WorkStepAssignment({
    required this.workStep,
    this.selectedMachine,
    this.selectedMachines = const [],
    this.responsiblePerson,
    this.customPersonName,
  });

  // Helper method to get all selected machines (including single machine for compatibility)
  List<Machine> getAllSelectedMachines() {
    List<Machine> machines = List.from(selectedMachines);
    if (selectedMachine != null && !machines.contains(selectedMachine)) {
      machines.add(selectedMachine!);
    }
    return machines;
  }
}
