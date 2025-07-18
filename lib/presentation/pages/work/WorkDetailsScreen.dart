import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../constants/colors.dart';
import '../../../data/models/Job.dart';
import '../../../data/models/WorkStepAssignment.dart';
import '../../../data/models/purchase_order.dart';

class WorkDetailsScreen extends StatelessWidget {
  final Job? job;
  final PurchaseOrder? po;
  final Map<String, dynamic>? assignmentSummary;

  const WorkDetailsScreen({
    Key? key,
    this.job,
    this.po,
    this.assignmentSummary,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Work Assignment Details'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _buildUnifiedCard(context),
      ),
    );
  }

  Widget _buildUnifiedCard(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.zero,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text(
                'WORK ASSIGNMENT DETAILS',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Colors.grey),
            const SizedBox(height: 16),

            // Job Section
            _buildSectionHeader(
              icon: Icons.work,
              title: 'JOB INFORMATION',
              color: Colors.blue,
            ),
            if (job != null) ...[
              _buildKeyValueRow('Job Number', job!.nrcJobNo),
              _buildKeyValueRow('Customer', job!.customerName),
              _buildKeyValueRow('Style/SKU', job!.styleItemSKU),
              _buildKeyValueRow('Status', job!.status),
              _buildKeyValueRow('Board Size', job!.boardSize ?? ''),
              _buildKeyValueRow('Flute Type', job!.fluteType),
              _buildKeyValueRow('No. of Ups', job!.noUps ?? ''),
              _buildKeyValueRow('Latest Rate', job!.latestRate?.toString() ?? ''),
              _buildKeyValueRow('Previous Rate', job!.preRate?.toString() ?? ''),
              _buildKeyValueRow('Dimensions', (job!.length != null && job!.width != null && job!.height != null) ? '${job!.length} x ${job!.width} x ${job!.height}' : ''),
              _buildKeyValueRow('Artwork Received', job!.artworkReceivedDate ?? ''),
              _buildKeyValueRow('Artwork Approved', job!.artworkApprovalDate ?? ''),
              _buildKeyValueRow('Shade Card Approval', job!.shadeCardApprovalDate ?? ''),
              _buildKeyValueRow('Created At', job!.createdAt ?? ''),
              _buildKeyValueRow('Updated At', job!.updatedAt ?? ''),
              if (job!.purchaseOrder != null)
                _buildKeyValueRow('Purchase Order', 'Available'),
              if (job!.hasPoAdded)
                _buildKeyValueRow('PO Status', 'Added'),
            ],

            // PO Section
            _buildSectionHeader(
              icon: Icons.receipt_long,
              title: 'PURCHASE ORDER',
              color: Colors.orange,
            ),
            if (po != null) ...[
              _buildKeyValueRow('PO Date', _formatDate(po!.poDate)),
              _buildKeyValueRow('Deliver Date', _formatDate(po!.deliveryDate)),
              _buildKeyValueRow('Dispatch Date', _formatDate(po!.dispatchDate)),
              _buildKeyValueRow('NRC Delivery Date', _formatDate(po!.nrcDeliveryDate)),
              _buildKeyValueRow('Total PO Quantity', po!.totalPOQuantity.toString()),
              _buildKeyValueRow('Unit', po!.unit),
              _buildKeyValueRow('Pending Validity', '${po!.pendingValidity} days'),
              _buildKeyValueRow('No. of Sheets', po!.noOfSheets.toString()),
              const SizedBox(height: 16),
            ],

            // Assignment Section
            _buildSectionHeader(
              icon: Icons.assignment,
              title: 'WORK ASSIGNMENT',
              color: Colors.green,
            ),
            if (assignmentSummary != null) ...[
              _buildKeyValueRow(
                'Demand',
                assignmentSummary!['demand'] ?? 'Not specified',
              ),
              const SizedBox(height: 8),
              const Text(
                'Work Steps:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              ...(assignmentSummary!['steps'] as List<WorkStepAssignment>?)
                  ?.map((step) => _buildWorkStepItem(step))
                  .toList() ??
                  [],
            ],
          ],
        ),
      ),
    );
  }
  // ... (keep all other helper methods the same as in your original code)
  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyValueRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              key,
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : 'N/A',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(String text, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkStepItem(WorkStepAssignment assignment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.translucentBlack),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            assignment.workStep.displayName,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          if (assignment.selectedMachine != null)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'Machine: ${assignment.selectedMachine!.machineCode} - '
                    '${assignment.selectedMachine!.description}',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 13,
                ),
              ),
            ),
          if (assignment.selectedMachine == null)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'No machine required',
                style: TextStyle(
                  color: Colors.green[400],
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}