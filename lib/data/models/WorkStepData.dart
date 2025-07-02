import '../../../data/models/WorkStep.dart';

class WorkStepData {
  static final List<WorkStep> workSteps = [
    WorkStep(step: 'paperStore', displayName: 'Paper Store', responsiblePersons: ['Store Manager', 'Inventory Officer']),
    WorkStep(step: 'printing', displayName: 'Printing', responsiblePersons: ['Print Operator', 'Print Supervisor', 'Quality Inspector']),
    WorkStep(step: 'corrugation', displayName: 'Corrugation', responsiblePersons: ['Corrugation Operator', 'Line Supervisor']),
    WorkStep(step: 'fluteLamination', displayName: 'Flute Lamination', responsiblePersons: ['Lamination Operator', 'Machine Operator']),
    WorkStep(step: 'punching', displayName: 'Punching', responsiblePersons: ['Punching Operator', 'Die Cutting Specialist']),
    WorkStep(step: 'flapPasting', displayName: 'Flap Pasting', responsiblePersons: ['Pasting Operator', 'Assembly Worker']),
    WorkStep(step: 'qc', displayName: 'Quality Control', responsiblePersons: ['QC Inspector', 'Quality Manager']),
    WorkStep(step: 'dispatch', displayName: 'Dispatch', responsiblePersons: ['Dispatch Officer', 'Logistics Coordinator']),
  ];
}