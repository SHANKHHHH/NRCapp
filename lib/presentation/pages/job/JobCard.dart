import 'package:flutter/material.dart';
import '../../../data/models/Job.dart';

class JobCard extends StatelessWidget {
  final Job job;
  final VoidCallback onTap;
  final Function(Job, JobStatus)? onStatusUpdate;

  const JobCard({
    Key? key,
    required this.job,
    required this.onTap,
    this.onStatusUpdate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
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
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      _buildJobDemandChip(),
                      IconButton(
                        icon: const Icon(Icons.info_outline, color: Colors.grey),
                        tooltip: 'View Details',
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text('Job Details: ${job.jobNumber}'),
                              content: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _detailRow('Job Number', job.jobNumber),
                                    _detailRow('Status', job.status.name),
                                    if (job.jobDemand != null)
                                      _detailRow('Job Demand', job.jobDemand!.name),
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[50],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.blue[200]!),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.info, color: Colors.blue[600], size: 20),
                                          const SizedBox(width: 8),
                                          const Expanded(
                                            child: Text(
                                              'Full job details are shown below.',
                                              style: TextStyle(fontSize: 12, color: Colors.blue),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    _detailRow('Customer', job.customer),
                                    _detailRow('Plant', job.plant),
                                    _detailRow('Job Date', job.jobDate),
                                    _detailRow('Delivery Date', job.deliveryDate),
                                    _detailRow('Created Date', job.createdDate),
                                    _detailRow('Created By', job.createdBy),
                                    _detailRow('Style', job.style),
                                    _detailRow('Die Code', job.dieCode),
                                    _detailRow('Board Size', job.boardSize),
                                    _detailRow('Flute Type', job.fluteType),
                                    _detailRow('Job Month', job.jobMonth),
                                    _detailRow('No. of Ups', job.noOfUps.toString()),
                                    _detailRow('No. of Sheets', job.noOfSheets.toString()),
                                    _detailRow('Total Quantity', job.totalQuantity.toString()),
                                    _detailRow('Unit', job.unit),
                                    _detailRow('Dispatch Quantity', job.dispatchQuantity.toString()),
                                    _detailRow('Pending Quantity', job.pendingQuantity.toString()),
                                    _detailRow('Shade Card Approval', job.shadeCardApprovalDate),
                                    _detailRow('NRC Delivery Date', job.nrcDeliveryDate),
                                    _detailRow('Dispatch Date', job.dispatchDate),
                                    _detailRow('Pending Validity', job.pendingValidity),
                                    _detailRow('Status', job.status.name),
                                    if (job.jobDemand != null)
                                      _detailRow('Job Demand', job.jobDemand!.name),
                                    _detailRow('Approval Pending', job.isApprovalPending ? 'Yes' : 'No'),
                                  ],
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.business, 'Customer', job.customer),
                  _buildInfoRow(Icons.factory, 'Plant', job.plant),
                  _buildInfoRow(Icons.calendar_today, 'Job Date', job.jobDate),
                  _buildInfoRow(Icons.delivery_dining, 'Delivery Date', job.deliveryDate),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatusChip(),
                      Text(
                        'Qty: ${job.totalQuantity} ${job.unit}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Approval Section
          if (job.isApprovalPending && onStatusUpdate != null)
            _buildApprovalSection(context),

          // Hold Section if working started
          if (job.status == JobStatus.workingStarted && onStatusUpdate != null)
            _buildHoldSection(context),

          // Resume Section if on hold
          if (job.status == JobStatus.hold && onStatusUpdate != null)
            _buildResumeSection(context),
        ],
      ),
    );
  }

  Widget _buildApprovalSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Approval Required',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 8),
          if (job.jobDemand != null)
            Text(
              'Job Demand: ${job.jobDemand!.name.toUpperCase()}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _showApprovalDialog(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Approve'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _showApprovalDialog(context, false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Reject'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHoldSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Job In Progress',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.blueAccent,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _showHoldConfirmationDialog(context),
            icon: const Icon(Icons.pause_circle_filled),
            label: const Text('Hold This Job'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[800],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumeSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Job is On Hold',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.deepOrange,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _showResumeDialog(context, JobStatus.active),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Mark as Active'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _showResumeDialog(context, JobStatus.workingStarted),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Start Working'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip() {
    Color chipColor;
    String statusText;

    switch (job.status) {
      case JobStatus.active:
        chipColor = Colors.green;
        statusText = 'Active';
        break;
      case JobStatus.inactive:
        chipColor = Colors.orange;
        statusText = 'Inactive';
        break;
      case JobStatus.workingStarted:
        chipColor = Colors.blue;
        statusText = 'WORKING STARTED';
        break;
      case JobStatus.hold:
        chipColor = Colors.grey;
        statusText = 'Hold';
        break;
    }

    return Chip(
      label: Text(
        statusText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: chipColor,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildJobDemandChip() {
    if (job.jobDemand == null) {
      return const SizedBox.shrink();
    }

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
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showApprovalDialog(BuildContext context, bool isApprove) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isApprove ? 'Approve Job' : 'Reject Job'),
        content: Text(
          isApprove
              ? 'Are you sure you want to approve job ${job.jobNumber}? This will start the working process.'
              : 'Are you sure you want to reject job ${job.jobNumber}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (onStatusUpdate != null) {
                onStatusUpdate!(
                  job,
                  isApprove ? JobStatus.workingStarted : JobStatus.hold,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isApprove ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(isApprove ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
  }

  void _showHoldConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hold Job'),
        content: Text('Do you want to hold the job ${job.jobNumber}? This will pause the working process.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (onStatusUpdate != null) {
                onStatusUpdate!(job, JobStatus.hold);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hold Job'),
          ),
        ],
      ),
    );
  }

  void _showResumeDialog(BuildContext context, JobStatus newStatus) {
    final isStartWorking = newStatus == JobStatus.workingStarted;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isStartWorking ? 'Resume and Start Working' : 'Resume Job'),
        content: Text(
          isStartWorking
              ? 'Do you want to resume and start working on job ${job.jobNumber}?'
              : 'Do you want to resume and mark job ${job.jobNumber} as active?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (onStatusUpdate != null) {
                onStatusUpdate!(job, newStatus);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isStartWorking ? Colors.blue : Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text(isStartWorking ? 'Start Working' : 'Mark Active'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
