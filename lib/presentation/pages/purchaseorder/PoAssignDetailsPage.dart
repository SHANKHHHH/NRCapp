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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Job & PO Details'),
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () async {
              final result = await context.push(
                '/edit-po/${job.jobNumber}',
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Job Info'),
          Text('Job Number: ${job.jobNumber}'),
          Text('Customer: ${job.customer}'),
          Text('Plant: ${job.plant}'),
          Text('Job Date: ${job.jobDate}'),
          Text('Delivery Date: ${job.deliveryDate}'),
          Text('Style: ${job.style ?? ''}'),
          Text('Die Code: ${job.dieCode ?? ''}'),
          Text('Board Size: ${job.boardSize ?? ''}'),
          Text('Flute Type: ${job.fluteType ?? ''}'),
          Text('No. of Ups: ${job.noOfUps ?? ''}'),
          Text('No. of Sheets: ${job.noOfSheets ?? ''}'),
          Text('Unit: ${job.unit ?? ''}'),
          Text('Job Month: ${job.jobMonth ?? ''}'),
          Text('Created By: ${job.createdBy ?? ''}'),
          Text('Created Date: ${job.createdDate ?? ''}'),
          Text('Artwork Received Date: ${job.artworkReceivedDate ?? ''}'),
          Text('Artwork Approval Date: ${job.artworkApprovalDate ?? ''}'),
          Text('Shade Card Date: ${job.shadeCardDate ?? ''}'),
          Text('Total Quantity: ${job.totalQuantity.toString()}'),
          Text('Dispatch Quantity: ${job.dispatchQuantity.toString()}'),
          Text('Pending Quantity: ${job.pendingQuantity.toString()}'),

          const SizedBox(height: 24),
          _buildSectionHeader('Purchase Order Info'),
          Text('PO Date: ${purchaseOrder.purchaseOrderDate}'),
          Text('Deliver Date: ${purchaseOrder.deliverDate}'),
          Text('Total PO: ${purchaseOrder.totalPo}'),
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
