import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:nrc/constants/strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../constants/colors.dart';
import '../../../data/models/WorkStepAssignment.dart';
import '../process/DialogManager.dart'; // Make sure this path is correct

class ReviewStepWidget extends StatelessWidget {
  final String? selectedDemand;
  final List<WorkStepAssignment> selectedWorkStepAssignments;
  final dynamic selectedJob;

  const ReviewStepWidget({
    Key? key,
    required this.selectedDemand,
    required this.selectedWorkStepAssignments,
    required this.selectedJob,
  }) : super(key: key);

  Color _getDemandColor(String? demand) {
    switch (demand?.toLowerCase()) {
      case 'high':
        return Colors.redAccent;
      case 'medium':
        return Colors.amber;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getStepIcon(String step) {
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
      case 'cutting':
        return Icons.content_cut;
      case 'folding':
        return Icons.flip;
      case 'gluing':
        return Icons.join_inner;
      default:
        return Icons.work;
    }
  }

  String getBackendStepName(String step) {
    switch (step.toLowerCase()) {
      case 'paperstore':
        return 'PaperStore';
      case 'printing':
        return 'PrintingDetails';
      case 'corrugation':
        return 'Corrugation';
      case 'flutelamination':
        return 'FluteLaminateBoardConversion';
      case 'punching':
        return 'Punching';
      case 'flappasting':
        return 'SideFlapPasting';
      case 'qc':
        return 'QualityDept';
      case 'dispatch':
        return 'DispatchProcess';
      default:
        return step;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color demandColor = _getDemandColor(selectedDemand);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: Text(
            'Review Assignment Summary',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildReviewItem(
            icon: Icons.flag,
            label: 'Job Demand',
            value: selectedDemand ?? 'Not selected',
            color: demandColor,
          ),
        ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Work Step Assignments',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: selectedWorkStepAssignments.length,
          itemBuilder: (context, index) {
            final assignment = selectedWorkStepAssignments[index];
            final step = assignment.workStep.step;
            final icon = _getStepIcon(step);
            final color = _getDemandColor(step);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icon, color: color),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Step ${index + 1}: ${assignment.workStep.displayName}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Responsible: ${assignment.workStep.responsiblePersons.join(', ')}',
                        style: const TextStyle(color: Colors.black87),
                      ),
                      const SizedBox(height: 4),
                      if (assignment.selectedMachine != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              'Machine: ${assignment.selectedMachine!.unit} - ${assignment.selectedMachine!.machineCode}',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            Text('Description: ${assignment.selectedMachine!.description}'),
                            Text('Type: ${assignment.selectedMachine!.type}'),
                            Text('Capacity: ${assignment.selectedMachine!.capacity}/8hrs'),
                            if (assignment.selectedMachine!.remarks != null &&
                                assignment.selectedMachine!.remarks!.isNotEmpty)
                              Text('Remarks: ${assignment.selectedMachine!.remarks}'),
                          ],
                        )
                      else
                        const Text(
                          'Machine: Not required',
                          style: TextStyle(color: Colors.green),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),

        // ✅ Done Button
        Center(
          child: ElevatedButton(
            onPressed: () => _submitJobPlanning(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Done'),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildReviewItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Submission Logic
  void _submitJobPlanning(BuildContext context) async {
    try {
      final dio = Dio();
      final url = '${AppStrings.baseUrl}/api/job-planning/';

      final payload = {
        "nrcJobNo": selectedJob?.nrcJobNo ?? 'UNKNOWN',
        "jobDemand": selectedDemand ?? 'low',
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

      if (response.statusCode == 200 || response.statusCode == 201) {
        DialogManager.showSuccessMessage(context, "Job planning submitted successfully.");
      } else {
        DialogManager.showErrorMessage(context, "Failed to submit. Status: ${response.statusCode}");
      }
    } catch (e) {
      DialogManager.showErrorMessage(context, "Error: ${e.toString()}");
    }
  }
}
