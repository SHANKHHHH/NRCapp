import '../../../constants/colors.dart';
import '../../../data/models/job_model.dart';
import 'package:flutter/material.dart';

class JobMainCard extends StatelessWidget {
  final JobModel job;
  final VoidCallback? onTap;

  const JobMainCard({Key? key, required this.job, this.onTap}) : super(key: key);

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
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.blue.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.blue.withOpacity(0.1),
          highlightColor: Colors.blue.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.maincolor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        job.nrcJobNo,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const Spacer(),
                    _buildStatusBadge(job.status),
                  ],
                ),

                const SizedBox(height: 16),

                // Job Details
                _buildDetailRow(
                  icon: Icons.person_outline,
                  label: 'Customer',
                  value: job.customerName,
                ),

                const SizedBox(height: 12),

                _buildDetailRow(
                  icon: Icons.style_outlined,
                  label: 'Style',
                  value: job.styleItemSKU,
                ),

                const SizedBox(height: 12),

                _buildDetailRow(
                  icon: Icons.layers_outlined,
                  label: 'Flute',
                  value: job.fluteType,
                ),

                const SizedBox(height: 16),

                // Action Row
                Row(
                  children: [
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.blue,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: AppColors.maincolor,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.black.withOpacity(0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color statusColor;
    Color textColor;

    // You can customize these colors based on different status values
    switch (status.toLowerCase()) {
      case 'completed':
      case 'done':
        statusColor = Colors.blue.withOpacity(0.2);
        textColor = AppColors.maincolor;
        break;
      case 'pending':
      case 'in progress':
        statusColor = Colors.black.withOpacity(0.1);
        textColor = Colors.black;
        break;
      case 'cancelled':
      case 'failed':
        statusColor = Colors.black.withOpacity(0.2);
        textColor = Colors.black;
        break;
      default:
        statusColor = Colors.blue.withOpacity(0.1);
        textColor = AppColors.maincolor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: textColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}