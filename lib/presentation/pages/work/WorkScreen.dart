import 'package:flutter/material.dart';
import 'package:nrc/constants/colors.dart';
import '../../../data/models/Job.dart';
import '../../../data/models/purchase_order.dart';
import '../../../data/models/WorkStepAssignment.dart';
import '../job/JobStep.dart';
import 'WorkDetailsScreen.dart';

class WorkScreen extends StatelessWidget {
  final Job? job;
  final PurchaseOrder? po;
  final Map<String, dynamic>? assignmentSummary;

  const WorkScreen({Key? key, this.job, this.po, this.assignmentSummary}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Work Assignment Summary'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => JobTimelinePage(
                  jobNumber: job?.jobNumber,
                  job: job,
                  assignedSteps: assignmentSummary?['steps'],
                ),
              ),
            );
          },
          child: _buildSummaryCard(context),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'WORK ASSIGNMENT SUMMARY',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[600]),
              ],
            ),
            const SizedBox(height: 16),

            // Job Summary
            if (job != null) _buildSummaryItem(
              icon: Icons.work,
              title: 'Job',
              value: job!.jobNumber,
              color: Colors.blue,
            ),

            // PO Summary
            if (po != null) _buildSummaryItem(
              icon: Icons.receipt_long,
              title: 'Purchase Order',
              value: 'N/A',
              color: Colors.orange,
            ),

            // Assignment Summary
            if (assignmentSummary != null) _buildSummaryItem(
              icon: Icons.assignment,
              title: 'Work Steps',
              value: '${(assignmentSummary!['steps'] as List<WorkStepAssignment>?)?.length ?? 0} steps',
              color: Colors.green,
            ),

            if (assignmentSummary != null && assignmentSummary!['demand'] != null)
              _buildSummaryItem(
                icon: Icons.trending_up,
                title: 'Demand',
                value: assignmentSummary!['demand'],
                color: Colors.purple,
              ),

            const SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WorkDetailsScreen(
                        job: job,
                        po: po,
                        assignmentSummary: assignmentSummary,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('View Complete Details'),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap card for new page',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


