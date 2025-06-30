import 'package:flutter/material.dart';
import '../../../data/models/Job.dart';
import 'JobDetailScreen.dart';

class JobMainCard extends StatelessWidget {
  final Job job;
  final VoidCallback onTap;

  const JobMainCard({
    Key? key,
    required this.job, required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => JobDetailScreen(job: job),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      job.jobNumber,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(job.status).withOpacity(0.15),
                      border: Border.all(color: _getStatusColor(job.status)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getStatusText(job.status),
                      style: TextStyle(
                        color: _getStatusColor(job.status),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.business, 'Customer', job.customer),
              _buildInfoRow(Icons.factory, 'Plant', job.plant),
              _buildInfoRow(Icons.calendar_today, 'Job Date', job.jobDate),
              _buildInfoRow(Icons.delivery_dining, 'Delivery Date', job.deliveryDate),
              const SizedBox(height: 8),
              Text(
                'Qty: ${job.totalQuantity} ${job.unit}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
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
            style: const TextStyle(fontSize: 12, color: Colors.grey),
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

  Color _getStatusColor(JobStatus status) {
    switch (status) {
      case JobStatus.active:
        return Colors.green;
      case JobStatus.inactive:
        return Colors.orange;
      case JobStatus.hold:
        return Colors.red;
      case JobStatus.workingStarted:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(JobStatus status) {
    switch (status) {
      case JobStatus.active:
        return 'Active';
      case JobStatus.inactive:
        return 'Inactive';
      case JobStatus.hold:
        return 'Hold';
      case JobStatus.workingStarted:
        return 'Working';
      default:
        return 'Unknown';
    }
  }
}
