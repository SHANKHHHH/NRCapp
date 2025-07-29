import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/Job.dart';
import '../../../data/models/purchase_order.dart';

class PoAssignDetailsPage extends StatefulWidget {
  final Job job;
  final PurchaseOrder purchaseOrder;

  const PoAssignDetailsPage({
    Key? key,
    required this.job,
    required this.purchaseOrder,
  }) : super(key: key);

  @override
  _PoAssignDetailsPageState createState() => _PoAssignDetailsPageState();
}

class _PoAssignDetailsPageState extends State<PoAssignDetailsPage> {
  late Job job;
  late PurchaseOrder purchaseOrder;

  @override
  void initState() {
    super.initState();
    job = widget.job;
    purchaseOrder = widget.purchaseOrder;
    
    // Debug prints to see the actual data
    print('Job data debug:');
    print('artworkReceivedDate: ${job.artworkReceivedDate}');
    print('artworkApprovalDate: ${job.artworkApprovalDate}');
    print('shadeCardApprovalDate: ${job.shadeCardApprovalDate}');
    print('createdAt: ${job.createdAt}');
    print('updatedAt: ${job.updatedAt}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Job & PO Details'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () async {
              final result = await context.push(
                '/edit-po/${job.nrcJobNo}',
                extra: {
                  'job': job,
                  'po': purchaseOrder,
                },
              );
              if (result != null && result is Job) {
                setState(() {
                  job = result;
                  purchaseOrder = result.purchaseOrder!;
                });
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Job Info Card
            _buildJobInfoCard(),
            const SizedBox(height: 20),
            
            // Purchase Order Info Card
            _buildPurchaseOrderCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildJobInfoCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.blue[50]!, Colors.blue[100]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.work, color: Colors.blue[700], size: 24),
                const SizedBox(width: 12),
                Text(
                  'Job Information',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildInfoRow(Icons.confirmation_number, 'Job Number', job.nrcJobNo),
            _buildInfoRow(Icons.person, 'Customer', job.customerName),
            _buildInfoRow(Icons.category, 'Style/SKU', job.styleItemSKU),
            _buildInfoRow(Icons.settings, 'Flute Type', job.fluteType),
            _buildInfoRow(Icons.aspect_ratio, 'Board Size', job.boardSize ?? 'N/A'),
            _buildInfoRow(Icons.format_list_numbered, 'No. of Ups', job.noUps ?? 'N/A'),
            _buildInfoRow(Icons.attach_money, 'Latest Rate', job.latestRate?.toString() ?? 'N/A'),
            _buildInfoRow(Icons.money_off, 'Previous Rate', job.preRate?.toString() ?? 'N/A'),
            _buildInfoRow(Icons.straighten, 'Dimensions', 
              (job.length != null && job.width != null && job.height != null) 
                ? '${job.length} x ${job.width} x ${job.height}' 
                : 'N/A'),
            _buildInfoRow(Icons.download, 'Artwork Received', _formatDateForDisplay(job.artworkReceivedDate ?? '')),
            _buildInfoRow(Icons.check_circle, 'Artwork Approved', _formatDateForDisplay(job.artworkApprovalDate ?? '')),
            _buildInfoRow(Icons.color_lens, 'Shade Card Approved', _formatDateForDisplay(job.shadeCardApprovalDate ?? '')),
            _buildInfoRow(Icons.calendar_today, 'Created', _formatDateForDisplay(job.createdAt ?? '')),
            _buildInfoRow(Icons.update, 'Last Updated', _formatDateForDisplay(job.updatedAt ?? '')),
            if (job.purchaseOrder != null)
              _buildInfoRow(Icons.assignment, 'Purchase Order', 'Available', Colors.green),
            if (job.hasPoAdded)
              _buildInfoRow(Icons.assignment_turned_in, 'PO Status', 'Added', Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseOrderCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.orange[50]!, Colors.orange[100]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.add_business, color: Colors.orange[700], size: 24),
                const SizedBox(width: 12),
                Text(
                  'Purchase Order Details',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildInfoRow(Icons.calendar_today, 'PO Date', _formatDateWithTime(purchaseOrder.poDate)),
            _buildInfoRow(Icons.local_shipping, 'Delivery Date', _formatDateWithTime(purchaseOrder.deliveryDate)),
            _buildInfoRow(Icons.schedule, 'Dispatch Date', _formatDateWithTime(purchaseOrder.dispatchDate)),
            _buildInfoRow(Icons.calendar_today, 'NRC Delivery Date', _formatDateWithTime(purchaseOrder.nrcDeliveryDate)),
            _buildInfoRow(Icons.inventory, 'Total PO Quantity', '${purchaseOrder.totalPOQuantity}'),
            _buildInfoRow(Icons.straighten, 'Unit', purchaseOrder.unit),
            _buildInfoRow(Icons.circle, 'Pending Validity', '${purchaseOrder.pendingValidity} days'),
            _buildInfoRow(Icons.format_list_numbered, 'No. of Sheets', '${purchaseOrder.noOfSheets}'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: Colors.blue[600]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? 'Not Available' : value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatDateWithTime(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateForDisplay(String isoDate) {
    if (isoDate.isEmpty) return '';
    
    // Debug print to see what format we're receiving
    print('_formatDateForDisplay input: $isoDate');
    
    try {
      // Handle different date formats
      DateTime date;
      
      // Try parsing as ISO format first
      if (isoDate.contains('T') && isoDate.contains('Z')) {
        date = DateTime.parse(isoDate);
      } else if (isoDate.contains('T')) {
        // Handle ISO without Z
        date = DateTime.parse(isoDate);
      } else {
        // Try parsing as simple date
        date = DateTime.parse(isoDate);
      }
      
      final formattedDate = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      print('_formatDateForDisplay output: $formattedDate');
      return formattedDate;
    } catch (e) {
      print('_formatDateForDisplay error: $e for input: $isoDate');
      return isoDate; // Return original if parsing fails
    }
  }
}
