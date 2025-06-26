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
              Text(
                job.jobNumber,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
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
}
