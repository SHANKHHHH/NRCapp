import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../constants/colors.dart';
import '../../../data/models/job_step_models.dart';
import 'JobTimelineUI.dart';

class PaperStoreFormManager {
  static void showPaperStoreForm(
      BuildContext context,
      StepData step,
      String? jobNumber,
      Map<String, dynamic>? jobDetails,
      Function(Map<String, String>) onComplete,
      ) {
    final TextEditingController availableController = TextEditingController();
    final TextEditingController millController = TextEditingController();
    final TextEditingController extraMarginController = TextEditingController();
    final TextEditingController qualityController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(Icons.work_outline, color: AppColors.maincolor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      step.title,
                      style: TextStyle(
                        color: AppColors.maincolor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.white,
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    JobTimelineUI.buildDetailRow('Job NRC Job No', jobNumber ?? ''),
                    JobTimelineUI.buildDetailRow('Sheet Size', jobDetails?['boardSize'] ?? ''),
                    JobTimelineUI.buildDetailRow('Required', jobDetails?['noUps']?.toString() ?? ''),
                    JobTimelineUI.buildDetailRow('GSM', jobDetails?['fluteType'] ?? ''),
                    const SizedBox(height: 12),
                    TextField(
                      controller: availableController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Available',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: millController,
                      decoration: const InputDecoration(
                        labelText: 'Mill',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: extraMarginController,
                      decoration: const InputDecoration(
                        labelText: 'Extra Margin',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: qualityController,
                      decoration: const InputDecoration(
                        labelText: 'Quality',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    final formData = {
                      'available': availableController.text,
                      'mill': millController.text,
                      'extraMargin': extraMarginController.text,
                      'quality': qualityController.text,
                    };
                    Navigator.pop(context);
                    onComplete(formData);
                  },
                  child: const Text('Complete Work'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
