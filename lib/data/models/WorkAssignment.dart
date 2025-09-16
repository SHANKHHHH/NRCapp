// models/work_assignment.dart

import 'Job.dart';
import 'purchase_order.dart';
import 'WorkStepAssignment.dart';

class WorkAssignment {
  final Job job;
  final PurchaseOrder? po;
  final String? demand;
  final List<WorkStepAssignment> steps;

  WorkAssignment({
    required this.job,
    this.po,
    this.demand,
    this.steps = const [],
  });
}
