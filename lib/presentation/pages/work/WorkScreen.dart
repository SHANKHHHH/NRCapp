import 'package:flutter/material.dart';
import '../../../data/models/Job.dart';
import '../../../data/models/purchase_order.dart';
import '../../../data/models/WorkStepAssignment.dart';

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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (job != null) _buildJobCard(job!),
          if (po != null) ...[
            const SizedBox(height: 16),
            _buildPOCard(po!),
          ],
          if (assignmentSummary != null) ...[
            const SizedBox(height: 16),
            _buildAssignmentCard(assignmentSummary!),
          ],
        ],
      ),
    );
  }

  Widget _buildJobCard(Job job) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.work, color: Colors.blue[700], size: 24),
                const SizedBox(width: 8),
                Text('Job Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue[700])),
              ],
            ),
            const SizedBox(height: 16),
            _buildJobDetailRow(Icons.confirmation_number, 'Job Number', job.jobNumber),
            _buildJobDetailRow(Icons.person, 'Customer', job.customer),
            _buildJobDetailRow(Icons.factory, 'Plant', job.plant),
            _buildJobDetailRow(Icons.calendar_today, 'Job Date', job.jobDate),
            _buildJobDetailRow(Icons.delivery_dining, 'Delivery Date', job.deliveryDate),
            _buildJobDetailRow(Icons.style, 'Style', job.style),
            _buildJobDetailRow(Icons.code, 'Die Code', job.dieCode),
            _buildJobDetailRow(Icons.aspect_ratio, 'Board Size', job.boardSize),
            _buildJobDetailRow(Icons.layers, 'Flute Type', job.fluteType),
            _buildJobDetailRow(Icons.format_list_numbered, 'No. of Ups', job.noOfUps),
            _buildJobDetailRow(Icons.format_list_numbered, 'No. of Sheets', job.noOfSheets),
            _buildJobDetailRow(Icons.straighten, 'Unit', job.unit),
            _buildJobDetailRow(Icons.calendar_month, 'Job Month', job.jobMonth),
            _buildJobDetailRow(Icons.person_outline, 'Created By', job.createdBy),
            _buildJobDetailRow(Icons.date_range, 'Created Date', job.createdDate),
            _buildJobDetailRow(Icons.check, 'Artwork Received Date', job.artworkReceivedDate ?? ''),
            _buildJobDetailRow(Icons.check, 'Artwork Approval Date', job.artworkApprovalDate ?? ''),
            _buildJobDetailRow(Icons.check, 'Shade Card Date', job.shadeCardDate ?? ''),
            _buildJobDetailRow(Icons.numbers, 'Total Quantity', job.totalQuantity.toString()),
            _buildJobDetailRow(Icons.local_shipping, 'Dispatch Quantity', job.dispatchQuantity.toString()),
            _buildJobDetailRow(Icons.pending, 'Pending Quantity', job.pendingQuantity.toString()),
            _buildJobDetailRow(Icons.flag, 'Status', job.status.name),
            _buildJobDetailRow(Icons.trending_up, 'Job Demand', job.jobDemand?.name ?? ''),
            _buildJobDetailRow(Icons.warning, 'Approval Pending', job.isApprovalPending ? 'Yes' : 'No'),
          ],
        ),
      ),
    );
  }

  Widget _buildPOCard(PurchaseOrder po) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long, color: Colors.orange[700], size: 24),
                const SizedBox(width: 8),
                Text('Purchase Order', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange[700])),
              ],
            ),
            const SizedBox(height: 16),
            _buildPODetailRow(Icons.calendar_today, 'PO Date', po.purchaseOrderDate),
            _buildPODetailRow(Icons.local_shipping, 'Deliver Date', po.deliverDate),
            _buildPODetailRow(Icons.inventory, 'Total PO', po.totalPo.toString()),
            _buildPODetailRow(Icons.schedule, 'Dispatch Date', po.dispatchDate),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentCard(Map<String, dynamic> summary) {
    final String? demand = summary['demand'] as String?;
    final List<WorkStepAssignment> steps = (summary['steps'] as List<WorkStepAssignment>? ?? []);
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assignment, color: Colors.green[700], size: 24),
                const SizedBox(width: 8),
                Text('Assignment Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green[700])),
              ],
            ),
            const SizedBox(height: 16),
            _buildAssignmentDetailRow(Icons.trending_up, 'Demand', demand ?? 'Not specified'),
            const SizedBox(height: 12),
            const Text('Work Steps:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ...steps.map((assignment) => _buildStepAssignmentRow(assignment)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildJobDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.blue[600]),
          const SizedBox(width: 8),
          Text('$label: ', style: TextStyle(fontSize: 14, color: Colors.grey[700], fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  Widget _buildPODetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.orange[700]),
          const SizedBox(width: 8),
          Text('$label: ', style: TextStyle(fontSize: 14, color: Colors.grey[700], fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.green[700]),
          const SizedBox(width: 8),
          Text('$label: ', style: TextStyle(fontSize: 14, color: Colors.grey[700], fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  Widget _buildStepAssignmentRow(WorkStepAssignment assignment) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            assignment.workStep.displayName,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 4),
          if (assignment.selectedMachine != null)
            Text('Machine: '
                '${assignment.selectedMachine!.unit} - '
                '${assignment.selectedMachine!.machineCode} | '
                '${assignment.selectedMachine!.description}'),
          if (assignment.selectedMachine == null)
            const Text('Machine: Not required', style: TextStyle(color: Colors.green)),
        ],
      ),
    );
  }
}