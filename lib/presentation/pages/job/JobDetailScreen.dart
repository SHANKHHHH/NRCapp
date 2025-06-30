import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/Job.dart';

class JobDetailScreen extends StatelessWidget {
  final Job job;
  final Function(Job)? onJobUpdate;

  const JobDetailScreen({
    Key? key,
    required this.job,
    this.onJobUpdate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(job.jobNumber),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 16),
            _buildJobDetailsCard(),
            const SizedBox(height: 16),
            _buildProductionDetailsCard(),
            const SizedBox(height: 16),
            _buildDeliveryDetailsCard(),
            const SizedBox(height: 24),
            if (job.status == JobStatus.inactive || job.status == JobStatus.active)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final updatedJob = job.copyWith(status: JobStatus.workingStarted);
                    if (onJobUpdate != null) {
                      onJobUpdate!(updatedJob);
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Started working on job ${job.jobNumber}'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    context.go('/job-list'); // Go directly to job list page
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Start Working with this Job',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            if (job.status == JobStatus.workingStarted)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue),
                ),
                child: const Text(
                  'Work Started',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
            if (job.status == JobStatus.hold)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red),
                ),
                child: const Text(
                  'Hold',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  job.jobNumber,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              job.customer,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Created: ${job.createdDate} by ${job.createdBy}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            // Show job demand if available
            if (job.jobDemand != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text(
                    'Job Demand: ',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  _buildJobDemandChip(),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildJobDetailsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Job Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildDetailRow('Job Date', job.jobDate),
            _buildDetailRow('Plant', job.plant),
            _buildDetailRow('Style', job.style),
            _buildDetailRow('Die Code', job.dieCode),
            _buildDetailRow('Board Size', job.boardSize),
            _buildDetailRow('Flute Type', job.fluteType),
            _buildDetailRow('Job Month', job.jobMonth),
          ],
        ),
      ),
    );
  }

  Widget _buildProductionDetailsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Production Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildDetailRow('No. of Ups', job.noOfUps),
            _buildDetailRow('No. of Sheets', job.noOfSheets),
            _buildDetailRow('Total Quantity', '${job.totalQuantity} ${job.unit}'),
            _buildDetailRow('Dispatch Quantity', '${job.dispatchQuantity} ${job.unit}'),
            _buildDetailRow('Pending Quantity', '${job.pendingQuantity} ${job.unit}'),
            _buildDetailRow('Shade Card Approval', job.shadeCardApprovalDate),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryDetailsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Delivery Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildDetailRow('Delivery Date', job.deliveryDate),
            _buildDetailRow('NRC Delivery Date', job.nrcDeliveryDate),
            _buildDetailRow('Dispatch Date', job.dispatchDate),
            _buildDetailRow('Pending Validity', job.pendingValidity),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildJobDemandChip() {
    if (job.jobDemand == null) return const SizedBox.shrink();

    Color chipColor;
    switch (job.jobDemand!) {
      case JobDemand.high:
        chipColor = Colors.red[100]!;
        break;
      case JobDemand.medium:
        chipColor = Colors.yellow[100]!;
        break;
      case JobDemand.low:
        chipColor = Colors.green[100]!;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        job.jobDemand!.name.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showJobDemandDialog(BuildContext context) {
    JobDemand? selectedDemand;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Select Job Demand'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Please select the demand level for job ${job.jobNumber}:'),
              const SizedBox(height: 16),
              ...JobDemand.values.map((demand) => RadioListTile<JobDemand>(
                title: Text(demand.name.toUpperCase()),
                value: demand,
                groupValue: selectedDemand,
                onChanged: (value) {
                  setState(() {
                    selectedDemand = value;
                  });
                },
              )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedDemand == null ? null : () {
                Navigator.pop(context);
                _submitJobDemand(context, selectedDemand!);
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  void _submitJobDemand(BuildContext context, JobDemand demand) {
    // Update the job with the selected demand and set it to approval pending
    final updatedJob = job.copyWith(
      jobDemand: demand,
      isApprovalPending: true,
    );

    if (onJobUpdate != null) {
      onJobUpdate!(updatedJob);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Job ${job.jobNumber} submitted for approval with ${demand.name.toUpperCase()} demand'),
        backgroundColor: Colors.green,
      ),
    );

    // Pop all routes until the job list (JobCard) page is reached
    context.push('/job-list');
  }

  void _showEditDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Job'),
        content: Text('Edit functionality for job ${job.jobNumber} will be implemented here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAddPODialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Purchase Order'),
        content: Text('Add PO functionality for job ${job.jobNumber} will be implemented here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}