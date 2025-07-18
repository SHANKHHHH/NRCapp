import 'package:flutter/material.dart';
import '../../../data/models/Job.dart';
import '../stepsselections/AssignWorkSteps.dart';
import 'ArtworkWorkflowWidget.dart';
import 'package:go_router/go_router.dart';
import 'package:nrc/data/models/purchase_order.dart';

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
            '/job-details/${job.nrcJobNo}',
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
            // Main Job Information
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
            // Show Artwork Workflow as a dropdown/expansion
            ExpansionTile(
              title: Text(
                'Artwork Workflow',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
              initiallyExpanded: false,
              children: [
                ArtworkWorkflowWidget(
                  job: job,
                  onJobUpdate: onJobUpdate ?? (job) {},
                  isActive: true,
                ),
              ],
            ),
            // Status Control Section (other controls)
            if (_shouldShowStatusControls()) ...[
              if (_buildStatusControlSection(context) != null)
                _buildStatusControlSection(context),
            ],
            // Always show Add PO button at the bottom if all artwork dates are filled and PO not added
            if ((job.artworkReceivedDate?.isNotEmpty ?? false) &&
                (job.artworkApprovalDate?.isNotEmpty ?? false) &&
                (job.shadeCardApprovalDate?.isNotEmpty ?? false) &&
                !job.hasPoAdded)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 16),
                child: _buildPurchaseOrderButton(context),
              ),
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
                job.nrcJobNo,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                job.customerName,
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
        _buildInfoRow(Icons.category, 'Style/SKU', job.styleItemSKU),
        _buildInfoRow(Icons.settings, 'Flute Type', job.fluteType),
        if (job.boardSize != null && job.boardSize!.isNotEmpty)
          _buildInfoRow(Icons.straighten, 'Board Size', job.boardSize!),
        if (job.noUps != null && job.noUps!.isNotEmpty)
          _buildInfoRow(Icons.format_list_numbered, 'No. of Ups', job.noUps!),
        if (job.artworkReceivedDate != null && job.artworkReceivedDate!.isNotEmpty)
          _buildInfoRow(Icons.palette, 'Artwork Received', job.artworkReceivedDate!),
        if (job.artworkApprovalDate != null && job.artworkApprovalDate!.isNotEmpty)
          _buildInfoRow(Icons.check_circle, 'Artwork Approved', job.artworkApprovalDate!),
        if (job.shadeCardApprovalDate != null && job.shadeCardApprovalDate!.isNotEmpty)
          _buildInfoRow(Icons.color_lens, 'Shade Card Approval', job.shadeCardApprovalDate!),
        if (job.createdAt != null && job.createdAt!.isNotEmpty)
          _buildInfoRow(Icons.calendar_today, 'Created At', job.createdAt!),
        if (job.updatedAt != null && job.updatedAt!.isNotEmpty)
          _buildInfoRow(Icons.update, 'Updated At', job.updatedAt!),
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
          if (job.latestRate != null)
            _buildMetric('Latest Rate', '₹${job.latestRate!.toStringAsFixed(2)}'),
          if (job.length != null && job.width != null && job.height != null)
            _buildMetric('Dimensions', '${job.length} x ${job.width} x ${job.height}'),
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
    Color chipColor = Colors.grey; // default value
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
      default:
        chipColor = Colors.grey;
        statusText = job.status.toString();
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

  Widget _buildStatusControlSection(BuildContext context) {
    final Widget statusAction = _buildStatusActionButtons(context);
    // If statusAction is a SizedBox.shrink (no button), collapse the space
    if (statusAction is SizedBox && statusAction.height == 0 && statusAction.width == 0) {
      return const SizedBox.shrink();
    }
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
          const SizedBox(height: 12),
          statusAction,
        ],
      ),
    );
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
      // Check if all artwork dates are filled
        final allArtworkDatesFilled =
            (job.artworkReceivedDate?.isNotEmpty ?? false) &&
                (job.artworkApprovalDate?.isNotEmpty ?? false) &&
                (job.shadeCardApprovalDate?.isNotEmpty ?? false);

        if (!allArtworkDatesFilled) {
          return const SizedBox.shrink();
        }

        // Show PO button based on current state
        return _buildPurchaseOrderButton(context);

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPurchaseOrderButton(BuildContext context) {
    final hasUpdatedAt = job.updatedAt != null && job.updatedAt!.isNotEmpty;
    if (!hasUpdatedAt) {
      // Show Add PO button
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () async {
            // Navigate to PurchaseOrderInput page and wait for result
            final result = await GoRouter.of(context).push('/add-po', extra: job);

            // If PO was successfully added, refresh the job card
            if (result == true && onJobUpdate != null) {
              onJobUpdate!(job);
            }
          },
          icon: const Icon(Icons.add_business),
          label: const Text('Add PO'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange[600],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      );
    } else {
      // Show View Details and Add Machine Details buttons
      return Column(
        children: [
          // Confirmation that PO is added
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                const SizedBox(width: 8),
                Text(
                  'Purchase Order Added Successfully',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // View Details button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                context.push(
                  '/job-details/${job.nrcJobNo}',
                  extra: {
                    'job': job,
                    'po': job.purchaseOrder,
                  },
                );
              },
              icon: const Icon(Icons.visibility),
              label: const Text('View PO Details'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Add Machine Details button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                // Navigate to AssignWorkSteps page
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AssignWorkSteps(job: job),
                  ),
                );
              },
              icon: const Icon(Icons.build),
              label: const Text('Add Machine Details'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      );
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
            'Are you sure you want to change the status of job ${job.nrcJobNo} to $statusName?',
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