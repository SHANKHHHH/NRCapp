import 'package:flutter/material.dart';
import '../../../constants/colors.dart';
import '../../../data/datasources/job_api.dart';
import '../../../data/models/Machine.dart';
import '../../../data/models/WorkStep.dart';
import '../../../data/models/WorkStepAssignment.dart';
import '../../../data/models/WorkStepData.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';

class EditMachinesPage extends StatefulWidget {
  const EditMachinesPage({super.key});

  @override
  State<EditMachinesPage> createState() => _EditMachinesPageState();
}

class _EditMachinesPageState extends State<EditMachinesPage> {
  List<Map<String, dynamic>> jobPlannings = [];
  bool _isLoading = true;
  String? _error;
  JobApi? _jobApi;
  List<Machine> _machines = [];

  // Steps to exclude from display
  final List<String> _excludedSteps = ['PaperStore', 'QualityDept', 'DispatchProcess'];

  @override
  void initState() {
    super.initState();
    _initializeApiAndLoad();
  }



  void _initializeApiAndLoad() {
    final dio = Dio();
    _jobApi = JobApi(dio);
    _fetchJobPlannings();
    _fetchMachines();
  }

  Future<void> _fetchJobPlannings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final jobPlanningsData = await _jobApi!.getAllJobPlannings();
      setState(() {
        jobPlannings = jobPlanningsData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load job plannings: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchMachines() async {
    try {
      final machines = await _jobApi!.getMachines();
      setState(() {
        _machines = machines;
      });
    } catch (e) {
      print('Failed to load machines: $e');
    }
  }

  List<Map<String, dynamic>> _getFilteredSteps(Map<String, dynamic> jobPlanning) {
    final steps = jobPlanning['steps'] as List<dynamic>? ?? [];
    return steps.where((step) {
      final stepName = step['stepName'] as String? ?? '';
      final machineDetails = step['machineDetails'] as List<dynamic>? ?? [];
      
      if (_excludedSteps.contains(stepName)) {
        return false;
      }

      return machineDetails.any((machine) {
        final machineType = machine['machineType'] as String? ?? '';
        return machineType == 'Not assigned';
      });
    }).map((step) => step as Map<String, dynamic>).toList();
  }

  // Convert step name to WorkStep
  WorkStep _getWorkStepFromStepName(String stepName) {
    switch (stepName) {
      case 'PrintingDetails':
        return WorkStepData.workSteps.firstWhere((ws) => ws.step == 'printing');
      case 'Corrugation':
        return WorkStepData.workSteps.firstWhere((ws) => ws.step == 'corrugation');
      case 'FluteLaminateBoardConversion':
        return WorkStepData.workSteps.firstWhere((ws) => ws.step == 'fluteLamination');
      case 'Punching':
        return WorkStepData.workSteps.firstWhere((ws) => ws.step == 'punching');
      case 'SideFlapPasting':
        return WorkStepData.workSteps.firstWhere((ws) => ws.step == 'flapPasting');
      default:
        return WorkStepData.workSteps.first;
    }
  }

  // Find machine by ID
  Machine? _findMachineById(String? machineId) {
    if (machineId == null) return null;
    try {
      return _machines.firstWhere((machine) => machine.id.toString() == machineId);
    } catch (e) {
      return null;
    }
  }

  // Navigate to AssignWorkSteps with pre-filled data
  void _navigateToAssignWorkSteps(Map<String, dynamic> jobPlanning, Map<String, dynamic> step) {
    print('Navigating to AssignWorkSteps with edit mode');
    print('Job Planning: $jobPlanning');
    print('Step: $step');
    
    // Create WorkStepAssignment with pre-filled data
    final workStep = _getWorkStepFromStepName(step['stepName']);
    final machineDetails = step['machineDetails'] as List<dynamic>? ?? [];
    
    Machine? selectedMachine;
    if (machineDetails.isNotEmpty) {
      final machineDetail = machineDetails.first;
      final machineId = machineDetail['machineId'];
      if (machineId != null) {
        selectedMachine = _findMachineById(machineId.toString());
      }
    }

    final assignment = WorkStepAssignment(
      workStep: workStep,
      selectedMachine: selectedMachine,
    );

    print('Created assignment: ${assignment.workStep.step}');
    print('Selected machine: ${assignment.selectedMachine?.machineCode}');

    // Navigate to AssignWorkSteps with pre-filled data
    try {
      final result = context.push('/assign-work-steps', extra: {
        'jobPlanning': jobPlanning,
        'step': step,
        'assignment': assignment,
        'isEditMode': true,
      });
      
      // If we get a result back (indicating successful update), refresh the data
      if (result == true) {
        _fetchJobPlannings();
      }
    } catch (e) {
      print('Navigation error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Navigation error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Machines'),
        backgroundColor: AppColors.maincolor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchJobPlannings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchJobPlannings,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : jobPlannings.isEmpty
                  ? const Center(
                      child: Text('No job plannings found'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: jobPlannings.length,
                      itemBuilder: (context, jobIndex) {
                        final jobPlanning = jobPlannings[jobIndex];
                        final filteredSteps = _getFilteredSteps(jobPlanning);
                        
                        if (filteredSteps.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: AppColors.maincolor,
                                      child: Icon(
                                        Icons.work,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Job: ${jobPlanning['nrcJobNo'] ?? 'N/A'}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text('Demand: ${jobPlanning['jobDemand'] ?? 'N/A'}'),
                                          Text('Job Plan ID: ${jobPlanning['jobPlanId'] ?? 'N/A'}'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Steps Requiring Machine Assignment:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...filteredSteps.map((step) => Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: Colors.orange,
                                          child: Icon(
                                            Icons.build,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Step ${step['stepNo']}: ${step['stepName']}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text('Status: ${step['status'] ?? 'N/A'}'),
                                              Text('Machine Type: Not assigned'),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit, color: Colors.blue),
                                              onPressed: () => _navigateToAssignWorkSteps(jobPlanning, step),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                )).toList(),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchJobPlannings,
        backgroundColor: AppColors.maincolor,
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }
} 