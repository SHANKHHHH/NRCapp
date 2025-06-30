import 'package:flutter/material.dart';
import '../../../data/models/Job.dart';
import 'ArtworkWorkflowWidget.dart';
import 'package:go_router/go_router.dart';

class EnhancedJobCard extends StatelessWidget {
  final Job job;
  final Function(Job, JobStatus)? onStatusUpdate;
  final Function(Job)? onJobUpdate;

  const EnhancedJobCard({
    Key? key,
    required this.job,
    this.onStatusUpdate,
    this.onJobUpdate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (job.purchaseOrder != null) {
          context.push(
            '/job-details/${job.jobNumber}',
            extra: {
              'job': job,
              'po': job.purchaseOrder,
            },
          );
        } else {
          // Optionally show a message: "No PO assigned for this job"
        }
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            // Main Job Information (No onClick anymore)
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildJobHeader(),
                  const SizedBox(height: 12),
                  _buildJobInfo(),
                  const SizedBox(height: 12),
                  _buildJobMetrics(),
                ],
              ),
            ),

            // Artwork Workflow Section
            if (job.status == JobStatus.active)
              ArtworkWorkflowWidget(
                job: job,
                onJobUpdate: onJobUpdate ?? (job) {},
                isActive: true,
              ),

            // Status Control Section
            if (_shouldShowStatusControls())
              _buildStatusControlSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildJobHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                job.jobNumber,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                job.customer,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            _buildJobDemandChip(),
            const SizedBox(width: 8),
            _buildStatusChip(),
          ],
        ),
      ],
    );
  }

  Widget _buildJobInfo() {
    return Column(
      children: [
        _buildInfoRow(Icons.factory, 'Plant', job.plant),
        _buildInfoRow(Icons.calendar_today, 'Job Date', job.jobDate),
        _buildInfoRow(Icons.delivery_dining, 'Delivery', job.deliveryDate),
        if (job.artworkReceivedDate != null && job.artworkReceivedDate!.isNotEmpty)
          _buildInfoRow(Icons.palette, 'Artwork Received', job.artworkReceivedDate!),
      ],
    );
  }

  Widget _buildJobMetrics() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMetric('Total Qty', '${job.totalQuantity}'),
          _buildMetric('Dispatched', '${job.dispatchQuantity}'),
          _buildMetric('Pending', '${job.pendingQuantity}'),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
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
        statusText = 'Working';
        break;
      case JobStatus.hold:
        chipColor = Colors.grey;
        statusText = 'Hold';
        break;
      case JobStatus.completed:
        chipColor = Colors.purple;
        statusText = 'Completed';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        statusText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildJobDemandChip() {
    if (job.jobDemand == null) {
      return const SizedBox.shrink();
    }

    Color chipColor;
    IconData icon;

    switch (job.jobDemand!) {
      case JobDemand.high:
        chipColor = Colors.red[100]!;
        icon = Icons.priority_high;
        break;
      case JobDemand.medium:
        chipColor = Colors.yellow[100]!;
        icon = Icons.remove;
        break;
      case JobDemand.low:
        chipColor = Colors.green[100]!;
        icon = Icons.trending_down;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12),
          const SizedBox(width: 4),
          Text(
            job.jobDemand!.name.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusControlSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _getStatusControlTitle(),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          _buildStatusActionButtons(context),
        ],
      ),
    );
  }

  String _getStatusControlTitle() {
    switch (job.status) {
      case JobStatus.workingStarted:
        return 'Job In Progress';
      case JobStatus.hold:
        return 'Job is On Hold';
      case JobStatus.active:
        return 'Job is Active';
      default:
        return 'Job Status';
    }
  }

  Widget _buildStatusActionButtons(BuildContext context) {
    switch (job.status) {
      case JobStatus.workingStarted:
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showStatusChangeDialog(context, JobStatus.hold),
                icon: const Icon(Icons.pause_circle_filled),
                label: const Text('Hold Job'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[600],
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showStatusChangeDialog(context, JobStatus.completed),
                icon: const Icon(Icons.check_circle),
                label: const Text('Complete'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple[600],
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        );

      case JobStatus.hold:
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showStatusChangeDialog(context, JobStatus.active),
                icon: const Icon(Icons.play_circle_filled),
                label: const Text('Activate'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showStatusChangeDialog(context, JobStatus.workingStarted),
                icon: const Icon(Icons.work),
                label: const Text('Start Work'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        );

      case JobStatus.active:
        final allArtworkDatesFilled =
            (job.artworkReceivedDate?.isNotEmpty ?? false) &&
                (job.artworkApprovalDate?.isNotEmpty ?? false) &&
                (job.shadeCardDate?.isNotEmpty ?? false);

        if (!allArtworkDatesFilled) {
          return const SizedBox.shrink();
        }

        if (!job.hasPoAdded) {
          // Navigate to PurchaseOrderInput page
          return SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                GoRouter.of(context).push('/add-po', extra: job);
              },
              icon: const Icon(Icons.add_business),
              label: const Text('Add PO'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[600],
                foregroundColor: Colors.white,
              ),
            ),
          );
        }

        // If PO is already added, show confirmation
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green[700]),
              const SizedBox(width: 8),
              Text(
                'PO added for this job',
                style: TextStyle(
                  color: Colors.green[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  bool _shouldShowStatusControls() {
    return job.status == JobStatus.active ||
        job.status == JobStatus.workingStarted ||
        job.status == JobStatus.hold;
  }

  void _showStatusChangeDialog(BuildContext context, JobStatus newStatus) {
    String statusName = _getStatusDisplayName(newStatus);
    String actionVerb = _getStatusActionVerb(newStatus);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('$actionVerb Job'),
          content: Text(
            'Are you sure you want to change the status of job ${job.jobNumber} to $statusName?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (onStatusUpdate != null) {
                  onStatusUpdate!(job, newStatus);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _getStatusColor(newStatus),
                foregroundColor: Colors.white,
              ),
              child: Text(actionVerb),
            ),
          ],
        );
      },
    );
  }

  String _getStatusDisplayName(JobStatus status) {
    switch (status) {
      case JobStatus.active:
        return 'Active';
      case JobStatus.inactive:
        return 'Inactive';
      case JobStatus.workingStarted:
        return 'Working Started';
      case JobStatus.hold:
        return 'Hold';
      case JobStatus.completed:
        return 'Completed';
    }
  }

  String _getStatusActionVerb(JobStatus status) {
    switch (status) {
      case JobStatus.active:
        return 'Activate';
      case JobStatus.inactive:
        return 'Deactivate';
      case JobStatus.workingStarted:
        return 'Start Working';
      case JobStatus.hold:
        return 'Hold';
      case JobStatus.completed:
        return 'Complete';
    }
  }

  Color _getStatusColor(JobStatus status) {
    switch (status) {
      case JobStatus.active:
        return Colors.green;
      case JobStatus.inactive:
        return Colors.orange;
      case JobStatus.workingStarted:
        return Colors.blue;
      case JobStatus.hold:
        return Colors.grey;
      case JobStatus.completed:
        return Colors.purple;
    }
  }
}