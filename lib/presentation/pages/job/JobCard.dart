import 'package:flutter/material.dart';
import '../../../core/services/dio_service.dart';
import '../../../data/models/Job.dart';
import '../stepsselections/AssignWorkSteps.dart';
import 'ArtworkWorkflowWidget.dart';
import 'package:go_router/go_router.dart';
import 'package:nrc/data/models/purchase_order.dart';
import '../../../data/datasources/job_api.dart';
import 'package:dio/dio.dart';

// Search Bar Widget
class JobSearchBar extends StatelessWidget {
  final String searchQuery;
  final Function(String) onSearchChanged;

  const JobSearchBar({
    Key? key,
    required this.searchQuery,
    required this.onSearchChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        onChanged: onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search by NRC Job Number...',
          hintStyle: TextStyle(
            color: Colors.grey[500],
            fontSize: 15,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: Colors.grey[500],
            size: 22,
          ),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
            icon: Icon(
              Icons.clear,
              color: Colors.grey[500],
              size: 20,
            ),
            onPressed: () => onSearchChanged(''),
          )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          if (job.purchaseOrder != null) {
            context.push(
              '/job-details/${job.nrcJobNo}',
              extra: {
                'job': job,
                'po': job.purchaseOrder,
              },
            );
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Main Job Information
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildJobHeader(context),
                  const SizedBox(height: 20),
                  _buildJobInfo(),
                  const SizedBox(height: 20),
                  _buildJobMetrics(),
                ],
              ),
            ),

            // Divider
            Container(
              height: 1,
              color: Colors.grey.withOpacity(0.1),
            ),

            // Artwork Workflow Section
            Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
              ),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                childrenPadding: const EdgeInsets.only(left: 20, right: 16, bottom: 16),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.palette_outlined,
                        size: 20,
                        color: Colors.blue[700],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Artwork Workflow',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
                iconColor: Colors.grey[600],
                collapsedIconColor: Colors.grey[600],
                initiallyExpanded: false,
                children: [
                  ArtworkWorkflowWidget(
                    job: job,
                    onJobUpdate: onJobUpdate ?? (job) {},
                    isActive: true,
                  ),
                ],
              ),
            ),

            // Status Control Section
            if (_shouldShowStatusControls()) ...[
              Container(
                height: 1,
                color: Colors.grey.withOpacity(0.1),
              ),
              if (_buildStatusControlSection(context) != null)
                _buildStatusControlSection(context),
            ],

            // Purchase Order Button Section
            if ((job.artworkReceivedDate?.isNotEmpty ?? false) &&
                (job.artworkApprovalDate?.isNotEmpty ?? false) &&
                (job.shadeCardApprovalDate?.isNotEmpty ?? false) &&
                !job.hasPoAdded)
              Container(
                padding: const EdgeInsets.all(20),
                child: _buildPurchaseOrderButton(context),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                job.nrcJobNo,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  job.customerName,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Info Button
        Container(
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: IconButton(
            onPressed: () => _showCompleteJobDetails(context),
            icon: Icon(
              Icons.info_outline,
              color: Colors.blue[700],
              size: 20,
            ),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
            tooltip: 'View Complete Job Details',
          ),
        ),
        const SizedBox(width: 12),
        _buildStatusChip(),
      ],
    );
  }

  Widget _buildJobInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildInfoRow(Icons.category_outlined, 'Style/SKU', job.styleItemSKU),
          _buildInfoRow(Icons.settings_outlined, 'Flute Type', job.fluteType),
          if (job.boardSize != null && job.boardSize!.isNotEmpty)
            _buildInfoRow(Icons.straighten_outlined, 'Board Size', job.boardSize!),
          if (job.noUps != null && job.noUps!.isNotEmpty)
            _buildInfoRow(Icons.format_list_numbered_outlined, 'No. of Ups', job.noUps!),
          if (job.artworkReceivedDate != null && job.artworkReceivedDate!.isNotEmpty)
            _buildInfoRow(Icons.palette_outlined, 'Artwork Received', job.artworkReceivedDate!),
          if (job.artworkApprovalDate != null && job.artworkApprovalDate!.isNotEmpty)
            _buildInfoRow(Icons.check_circle_outline, 'Artwork Approved', job.artworkApprovalDate!),
          if (job.shadeCardApprovalDate != null && job.shadeCardApprovalDate!.isNotEmpty)
            _buildInfoRow(Icons.color_lens_outlined, 'Shade Card Approval', job.shadeCardApprovalDate!),
          if (job.createdAt != null && job.createdAt!.isNotEmpty)
            _buildInfoRow(Icons.calendar_today_outlined, 'Created At', job.createdAt!),
          if (job.updatedAt != null && job.updatedAt!.isNotEmpty)
            _buildInfoRow(Icons.update_outlined, 'Updated At', job.updatedAt!),
        ],
      ),
    );
  }

  Widget _buildJobMetrics() {
    if (job.latestRate == null &&
        (job.length == null || job.width == null || job.height == null)) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.withOpacity(0.05),
            Colors.blue.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (job.latestRate != null) ...[
            Expanded(child: _buildMetric('Latest Rate', '₹${job.latestRate!.toStringAsFixed(2)}')),
            if (job.length != null && job.width != null && job.height != null)
              Container(
                width: 1,
                height: 40,
                color: Colors.grey.withOpacity(0.3),
                margin: const EdgeInsets.symmetric(horizontal: 16),
              ),
          ],
          if (job.length != null && job.width != null && job.height != null)
            Expanded(child: _buildMetric('Dimensions', '${job.length} x ${job.width} x ${job.height}')),
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
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              size: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip() {
    Color chipColor = Colors.grey;
    String statusText;

    final jobStatus = _convertStringToJobStatus(job.status);
    switch (jobStatus) {
      case JobStatus.active:
        chipColor = Colors.green; // Changed to green as requested
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: chipColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        statusText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildStatusControlSection(BuildContext context) {
    final Widget statusAction = _buildStatusActionButtons(context);
    if (statusAction is SizedBox && statusAction.height == 0 && statusAction.width == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.settings_outlined,
                size: 20,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 8),
              Text(
                'Job Actions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          statusAction,
        ],
      ),
    );
  }

  Widget _buildStatusActionButtons(BuildContext context) {
    final jobStatus = _convertStringToJobStatus(job.status);
    switch (jobStatus) {
      case JobStatus.workingStarted:
        return Row(
          children: [
            Expanded(
              child: _buildActionButton(
                onPressed: () => _showStatusChangeDialog(context, JobStatus.hold),
                icon: Icons.pause_circle_outline,
                label: 'Hold Job',
                backgroundColor: Colors.orange[600]!,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                onPressed: () => _showStatusChangeDialog(context, JobStatus.completed),
                icon: Icons.check_circle_outline,
                label: 'Complete',
                backgroundColor: Colors.purple[600]!,
              ),
            ),
          ],
        );

      case JobStatus.hold:
        return Row(
          children: [
            Expanded(
              child: _buildActionButton(
                onPressed: () => _showStatusChangeDialog(context, JobStatus.active),
                icon: Icons.play_circle_outline,
                label: 'Activate',
                backgroundColor: Colors.green[600]!,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                onPressed: () => _showStatusChangeDialog(context, JobStatus.workingStarted),
                icon: Icons.work_outline,
                label: 'Start Work',
                backgroundColor: Colors.blue[600]!,
              ),
            ),
          ],
        );

      case JobStatus.active:
        // For active jobs, don't show any status action buttons
        // The purchase order button will be shown separately below
        return const SizedBox.shrink();

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color backgroundColor,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildPurchaseOrderButton(BuildContext context) {
    return FutureBuilder<List<Job>>(
      future: JobApi(DioService.instance).getJobsByNo(job.nrcJobNo),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(20),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          print('PO FutureBuilder error: ${snapshot.error}');
          return const SizedBox();
        }

        final jobs = snapshot.data;
        if (jobs == null || jobs.isEmpty) {
          return const SizedBox();
        }

        final latestJob = jobs.first;
        final poList = latestJob.purchaseOrders ?? [];
        final hasPO = poList.isNotEmpty || latestJob.hasPurchaseOrders == true;

        print('poList: $poList');
        print('hasPO: $hasPO');

        if (!hasPO) {
          return SizedBox(
            width: double.infinity,
            child: _buildActionButton(
              onPressed: () async {
                final result = await GoRouter.of(context).push('/add-po', extra: latestJob);
                if (result == true && onJobUpdate != null) {
                  onJobUpdate!(latestJob);
                }
              },
              icon: Icons.add_business_outlined,
              label: 'Add Purchase Order',
              backgroundColor: Colors.orange[600]!,
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.green.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.check_circle_outline,
                      color: Colors.green[700],
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Purchase Order Added',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Successfully linked to job',
                          style: TextStyle(
                            color: Colors.green[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: const Text(
                            'Purchase Order Details',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          content: SingleChildScrollView(
                            child: poList.isEmpty
                                ? const Text('No PO details available.')
                                : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: poList.map<Widget>((po) {
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: po.toJson().entries.map<Widget>((entry) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            SizedBox(
                                              width: 100,
                                              child: Text(
                                                '${entry.key}:',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                entry.value?.toString() ?? '',
                                                style: const TextStyle(fontSize: 13),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                );
                              }).toList(),
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
                    icon: Icons.visibility_outlined,
                    label: 'View Details',
                    backgroundColor: Colors.blue[600]!,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AssignWorkSteps(job: latestJob),
                        ),
                      );
                    },
                    icon: Icons.build_outlined,
                    label: 'Machine Details',
                    backgroundColor: Colors.orange[700]!,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  bool _shouldShowStatusControls() {
    final jobStatus = _convertStringToJobStatus(job.status);
    
    // Don't show status controls for active jobs if artwork workflow is complete
    // because the purchase order button will be shown separately
    if (jobStatus == JobStatus.active) {
      final allArtworkDatesFilled =
          (job.artworkReceivedDate?.isNotEmpty ?? false) &&
              (job.artworkApprovalDate?.isNotEmpty ?? false) &&
              (job.shadeCardApprovalDate?.isNotEmpty ?? false);
      
      // Only show status controls for active jobs if artwork workflow is incomplete
      return !allArtworkDatesFilled;
    }
    
    return jobStatus == JobStatus.workingStarted ||
        jobStatus == JobStatus.hold;
  }

  void _showStatusChangeDialog(BuildContext context, JobStatus newStatus) {
    String statusName = _getStatusDisplayName(newStatus);
    String actionVerb = _getStatusActionVerb(newStatus);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            '$actionVerb Job',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to change the status of job ${job.nrcJobNo} to $statusName?',
            style: const TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey[600]),
              ),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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

  JobStatus _convertStringToJobStatus(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return JobStatus.active;
      case 'inactive':
        return JobStatus.inactive;
      case 'hold':
        return JobStatus.hold;
      case 'working started':
      case 'workingstarted':
        return JobStatus.workingStarted;
      case 'completed':
        return JobStatus.completed;
      default:
        return JobStatus.inactive;
    }
  }

  Color _getStatusColor(JobStatus status) {
    switch (status) {
      case JobStatus.active:
        return Colors.green; // Changed to green as requested
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

  void _showCompleteJobDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.work_outline,
              color: Colors.blue[700],
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Complete Job Details',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: const BoxConstraints(maxHeight: 500),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailSection('Job Information', [
                  _buildDetailRow('NRC Job No', job.nrcJobNo),
                  _buildDetailRow('Customer Name', job.customerName),
                  _buildDetailRow('Style/SKU', job.styleItemSKU),
                  _buildDetailRow('Flute Type', job.fluteType),
                  _buildDetailRow('Status', _getStatusDisplayName(_convertStringToJobStatus(job.status))),
                ]),

                if (job.boardSize?.isNotEmpty == true ||
                    job.noUps?.isNotEmpty == true ||
                    job.length != null ||
                    job.width != null ||
                    job.height != null ||
                    job.latestRate != null)
                  _buildDetailSection('Specifications', [
                    if (job.boardSize?.isNotEmpty == true)
                      _buildDetailRow('Board Size', job.boardSize!),
                    if (job.noUps?.isNotEmpty == true)
                      _buildDetailRow('No. of Ups', job.noUps!),
                    if (job.length != null && job.width != null && job.height != null)
                      _buildDetailRow('Dimensions', '${job.length} x ${job.width} x ${job.height}'),
                    if (job.latestRate != null)
                      _buildDetailRow('Latest Rate', '₹${job.latestRate!.toStringAsFixed(2)}'),
                  ]),

                if (job.artworkReceivedDate?.isNotEmpty == true ||
                    job.artworkApprovalDate?.isNotEmpty == true ||
                    job.shadeCardApprovalDate?.isNotEmpty == true)
                  _buildDetailSection('Artwork Timeline', [
                    if (job.artworkReceivedDate?.isNotEmpty == true)
                      _buildDetailRow('Artwork Received', job.artworkReceivedDate!),
                    if (job.artworkApprovalDate?.isNotEmpty == true)
                      _buildDetailRow('Artwork Approved', job.artworkApprovalDate!),
                    if (job.shadeCardApprovalDate?.isNotEmpty == true)
                      _buildDetailRow('Shade Card Approval', job.shadeCardApprovalDate!),
                  ]),

                if (job.createdAt?.isNotEmpty == true ||
                    job.updatedAt?.isNotEmpty == true)
                  _buildDetailSection('Timeline', [
                    if (job.createdAt?.isNotEmpty == true)
                      _buildDetailRow('Created At', job.createdAt!),
                    if (job.updatedAt?.isNotEmpty == true)
                      _buildDetailRow('Updated At', job.updatedAt!),
                  ]),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(
                color: Colors.blue[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> details) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.grey.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              children: details,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}