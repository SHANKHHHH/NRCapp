import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/Job.dart';
import '../../../data/models/purchase_order.dart';

class PoAssignDetailsPage extends StatelessWidget {
  final Job job;
  final PurchaseOrder purchaseOrder;

  const PoAssignDetailsPage({
    Key? key,
    required this.job,
    required this.purchaseOrder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Job & PO Details'),
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () {
              context.push(
                '/edit-po/${job.jobNumber}',
                extra: {
                  'job': job,
                  'po': purchaseOrder,
                },
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Job Info'),
          Text('Job Number: ${job.jobNumber}'),
          Text('Customer: ${job.customer}'),
          Text('Plant: ${job.plant}'),
          // ... add all job fields as needed

          const SizedBox(height: 24),
          _buildSectionHeader('Purchase Order Info'),
          Text('PO Date: ${purchaseOrder.purchaseOrderDate}'),
          Text('Deliver Date: ${purchaseOrder.deliverDate}'),
          Text('Total PO: ${purchaseOrder.totalPo}'),
          Text('Dispatched: ${purchaseOrder.dispatchPo}'),
          Text('Pending: ${purchaseOrder.pending}'),
          Text('Dispatch Date: ${purchaseOrder.dispatchDate}'),
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
}
