import 'package:flutter/material.dart';
import '../../../data/datasources/job_api.dart';
import '../../../data/models/Machine.dart';
import '../../../data/models/WorkStepAssignment.dart';
import 'package:dio/dio.dart';

class MachineSelectionWidget extends StatefulWidget {
  final List<WorkStepAssignment> selectedWorkStepAssignments;
  final VoidCallback onSelectionChanged;

  const MachineSelectionWidget({
    Key? key,
    required this.selectedWorkStepAssignments,
    required this.onSelectionChanged,
  }) : super(key: key);

  @override
  State<MachineSelectionWidget> createState() => _MachineSelectionWidgetState();
}

class _MachineSelectionWidgetState extends State<MachineSelectionWidget> {
  List<Machine> _machines = [];
  bool _isLoading = true;
  String? _error;

  bool _requiresMachine(String step) {
    return [
      'printing',
      'corrugation',
      'flutelamination',
      'punching',
      'flappasting',
    ].contains(step.toLowerCase());
  }

  IconData _getIcon(String step) {
    switch (step.toLowerCase()) {
      case 'printing':
        return Icons.print;
      case 'corrugation':
        return Icons.waves;
      case 'flutelamination':
        return Icons.layers;
      case 'punching':
        return Icons.radio_button_unchecked;
      case 'flappasting':
        return Icons.content_paste;
      default:
        return Icons.build;
    }
  }

  Color _getColor(String step) {
    switch (step.toLowerCase()) {
      case 'printing':
        return Colors.blue;
      case 'corrugation':
        return Colors.orange;
      case 'flutelamination':
        return Colors.green;
      case 'punching':
        return Colors.red;
      case 'flappasting':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchMachines();
  }

  void _fetchMachines() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final dio = Dio(); // Or use your existing Dio instance/provider
      final jobApi = JobApi(dio);
      final machines = await jobApi.getMachines();
      setState(() {
        _machines = machines;
        _isLoading = false;
      });
      // Debug print to see all machine types fetched
      print(_machines.map((m) => m.machineType).toSet());
    } catch (e) {
      setState(() {
        _error = 'Failed to load machines';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }

    if (widget.selectedWorkStepAssignments.isEmpty) {
      return const Card(
        margin: EdgeInsets.all(16),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Please select work steps first.',
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: Text(
            'Assign Machines to Work Steps',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.selectedWorkStepAssignments.length,
          itemBuilder: (context, index) {
            final assignment = widget.selectedWorkStepAssignments[index];
            final step = assignment.workStep.step;
            final color = _getColor(step);
            final icon = _getIcon(step);

            if (!_requiresMachine(step)) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(icon, color: color),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              assignment.workStep.displayName,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'No machine required for this step.',
                              style: TextStyle(color: Colors.green),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final stepLower = assignment.workStep.step.toLowerCase();

            final machines = _machines.where((machine) {
              final machineTypeLower = machine.machineType.toLowerCase();

              if (stepLower == 'flutelamination') {
                return machineTypeLower.contains('flute');
              } else if (stepLower == 'punching') {
                return machineTypeLower.contains('punching');
              } else if (stepLower == 'flappasting') {
                return machineTypeLower.contains('flap pasting');
              } else {
                return machineTypeLower == stepLower;
              }
            }).toList();

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                    color: color.withOpacity(0.3),
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icon, color: color),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              assignment.workStep.displayName,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (machines.isEmpty)
                        const Text(
                          'No machines available for this step.',
                          style: TextStyle(color: Colors.red),
                        )
                      else
                        Column(
                          children: machines.map((machine) {
                            return RadioListTile<Machine>(
                              value: machine,
                              groupValue: assignment.selectedMachine,
                              onChanged: (value) {
                                setState(() {
                                  assignment.selectedMachine = value;
                                });
                                widget.onSelectionChanged();
                              },
                              title: Text(
                                '${machine.unit} - ${machine.machineCode}',
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${machine.description} (${machine.type})'),
                                  Text('Capacity: ${machine.capacity}/8hrs'),
                                  Text('Status: ${machine.status}'),
                                  Text('Active: ${machine.isActive ? "Yes" : "No"}'),
                                  Text('Created: ${machine.createdAt}'),
                                  Text('Updated: ${machine.updatedAt}'),
                                  if (machine.remarks != null && machine.remarks!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        'Remarks: ${machine.remarks ?? "No remarks"}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                              dense: true,
                              activeColor: color,
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
