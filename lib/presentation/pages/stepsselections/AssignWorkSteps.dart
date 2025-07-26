import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../data/datasources/job_api.dart';
import '../../../data/models/Job.dart';
import '../../../data/models/Machine.dart';
import '../../../data/models/WorkStep.dart';
import '../../../data/models/WorkStepAssignment.dart';
import '../../../data/models/WorkStepData.dart';
import '../process/DialogManager.dart';
import 'DemandStepWidget.dart';
import 'MachineSelectionWidget.dart';
import '../work/WorkScreen.dart';
import 'ReviewStepWidget.dart';
import 'WorkStepSelectionWidget.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../constants/colors.dart';
import '../../../constants/strings.dart';

class AssignWorkSteps extends StatefulWidget {
  final Job? job;
  const AssignWorkSteps({Key? key, this.job}) : super(key: key);

  @override
  _AssignWorkStepsState createState() => _AssignWorkStepsState();
}

class _AssignWorkStepsState extends State<AssignWorkSteps>
    with TickerProviderStateMixin {
  int currentStep = 0;
  String? selectedDemand;
  List<WorkStepAssignment> selectedWorkStepAssignments = [];
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  bool canProceedToNextStep() {
    switch (currentStep) {
      case 0:
        return selectedDemand != null;
      case 1:
        return selectedWorkStepAssignments.isNotEmpty;
      case 2:
        return selectedWorkStepAssignments.every((assignment) =>
        assignment.selectedMachine != null ||
            !_requiresMachine(assignment.workStep.step));
      default:
        return true;
    }
  }

  bool _requiresMachine(String workStepType) {
    return [
      'printing',
      'corrugation',
      'fluteLamination',
      'punching',
      'flapPasting'
    ].contains(workStepType);
  }

  void _onDemandChanged(String? demand) {
    setState(() {
      selectedDemand = demand;
    });
  }

  void _onWorkStepSelectionChanged(List<WorkStepAssignment> assignments) {
    // Define the desired order
    final orderedTypes = [
      'paperstore',
      'printing',
      'corrugation',
      'flutelamination',
      'punching',
      'flappasting',
      'qc',
      'dispatch',
    ];
    assignments.sort((a, b) {
      int aIndex = orderedTypes.indexOf(a.workStep.step.toLowerCase());
      int bIndex = orderedTypes.indexOf(b.workStep.step.toLowerCase());
      return aIndex.compareTo(bIndex);
    });
    setState(() {
      selectedWorkStepAssignments = assignments;
    });
  }

  void _onMachineSelectionChanged() {
    setState(() {
      // Trigger rebuild when machine selection changes
    });
  }

  void _nextStep() {
    if (currentStep < 3 && canProceedToNextStep()) {
      _animationController.reset();
      setState(() {
        currentStep++;
      });
      _animationController.forward();
    }
  }

  void _previousStep() {
    if (currentStep > 0) {
      _animationController.reset();
      setState(() {
        currentStep--;
      });
      _animationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Work Assignment',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 22,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.grey[200],
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Indicator - Fixed at top
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              color: Colors.white,
              child: _buildProgressIndicator(),
            ),

            // Main Content - Scrollable
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), // Extra bottom padding for navigation
                  child: _buildCurrentStepContent(),
                ),
              ),
            ),
          ],
        ),
      ),
      // Bottom Navigation - Fixed at bottom using floatingActionButton area
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.15),
              spreadRadius: 0,
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: _buildNavigationButtons(),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Row(
      children: List.generate(4, (index) {
        bool isActive = index <= currentStep;
        bool isCompleted = index < currentStep;

        return Expanded(
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted
                      ? Colors.green
                      : isActive
                      ? Colors.blue
                      : Colors.grey[300],
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.grey[600],
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              if (index < 3)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    color: index < currentStep ? Colors.green : Colors.grey[300],
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildCurrentStepContent() {
    final stepTitles = [
      'Select Job Demand',
      'Choose Work Steps',
      'Assign Machines',
      'Review & Start'
    ];

    final stepSubtitles = [
      'Choose the demand level for this job',
      'Select the required work steps',
      'Assign machines to each step',
      'Review your selections and start work'
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 0,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              stepTitles[currentStep],
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              stepSubtitles[currentStep],
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            _buildStepWidget(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepWidget() {
    switch (currentStep) {
      case 0:
        return DemandStepWidget(
          selectedDemand: selectedDemand,
          onDemandChanged: _onDemandChanged,
        );
      case 1:
        return WorkStepSelectionWidget(
          workSteps: WorkStepData.workSteps,
          selectedWorkStepAssignments: selectedWorkStepAssignments,
          onSelectionChanged: _onWorkStepSelectionChanged,
        );
      case 2:
        return MachineSelectionWidget(
          selectedWorkStepAssignments: selectedWorkStepAssignments,
          onSelectionChanged: _onMachineSelectionChanged,
        );
      case 3:
        return ReviewStepWidget(
          selectedDemand: selectedDemand,
          selectedWorkStepAssignments: selectedWorkStepAssignments,
          selectedJob: widget.job, // Pass the job from AssignWorkSteps
        );
      default:
        return Container();
    }
  }

  Widget _buildNavigationButtons() {
    return Row(
      children: [
        if (currentStep > 0)
          Expanded(
            child: OutlinedButton(
              onPressed: _previousStep,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(color: Colors.grey[400]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.arrow_back, size: 18),
                  SizedBox(width: 8),
                  Text('Back', style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ),
        if (currentStep > 0) const SizedBox(width: 16),
        Expanded(
          flex: currentStep == 0 ? 1 : 2,
          child: ElevatedButton(
            onPressed: currentStep == 3
                ? () => _startWork(context)
                : canProceedToNextStep()
                ? _nextStep
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: currentStep == 3 ? Colors.green : Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (currentStep == 3)
                  const Icon(Icons.play_arrow, size: 18)
                else
                  const Text('Next', style: TextStyle(fontSize: 16)),
                if (currentStep == 3) const SizedBox(width: 8),
                if (currentStep == 3)
                  const Text('Start Work', style: TextStyle(fontSize: 16))
                else
                  const Icon(Icons.arrow_forward, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _startWork(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.green.shade50, Colors.white],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green.shade100,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green.shade600,
                    size: 50,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Work Started Successfully!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Your work assignment has been created and the process has begun.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildSummaryRow(
                        'Total Steps',
                        '${selectedWorkStepAssignments.length}',
                        Icons.list_alt,
                      ),
                      const SizedBox(height: 8),
                      _buildSummaryRow(
                        'Demand Level',
                        selectedDemand ?? 'Not specified',
                        Icons.trending_up,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _resetForm();
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('New Assignment'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          await _submitJobPlanning(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[600], size: 20),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  void _resetForm() {
    _animationController.reset();
    setState(() {
      currentStep = 0;
      selectedDemand = null;
      selectedWorkStepAssignments.clear();
    });
    _animationController.forward();
  }

  String getBackendStepName(String step) {
    switch (step.toLowerCase()) {
      case 'paperstore': return 'PaperStore';
      case 'printing': return 'PrintingDetails';
      case 'corrugation': return 'Corrugation';
      case 'flutelamination': return 'FluteLaminateBoardConversion';
      case 'punching': return 'Punching';
      case 'flappasting': return 'SideFlapPasting';
      case 'qc': return 'QualityDept';
      case 'dispatch': return 'DispatchProcess';
      default: return step;
    }
  }

  Future<void> _submitJobPlanning(BuildContext context) async {
    // Show loader dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final dio = Dio();
      final url = '${AppStrings.baseUrl}/api/job-planning/';
      final payload = {
        "nrcJobNo": widget.job?.nrcJobNo ?? 'UNKNOWN',
        "jobDemand": selectedDemand?.toLowerCase() ?? 'low',
        "steps": selectedWorkStepAssignments.asMap().entries.map((entry) {
          final index = entry.key;
          final assignment = entry.value;
          return {
            "stepNo": index + 1,
            "stepName": getBackendStepName(assignment.workStep.step),
            "machineDetails": assignment.selectedMachine?.machineCode ?? 'Not Required',
          };
        }).toList(),
      };
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      final response = await dio.post(
        url,
        data: payload,
        options: Options(
          headers: {
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );
      Navigator.of(context).pop(); // Dismiss loader
      if (response.statusCode == 200 || response.statusCode == 201) {
        context.go('/home');
      } else {
        DialogManager.showErrorMessage(context, "Failed to submit. Status:  {response.statusCode}");
      }
    } catch (e) {
      Navigator.of(context).pop(); // Dismiss loader
      DialogManager.showErrorMessage(context, "Error:  {e.toString()}");
    }
  }
}