import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:nrc/constants/strings.dart';
import '../../../data/models/job_model.dart';
import '../../../data/datasources/job_api.dart';

class JobDetailScreen extends StatelessWidget {
  final JobModel job;

  const JobDetailScreen({Key? key, required this.job}) : super(key: key);

  Future<void> _startWork(BuildContext context) async {
    // Show elegant loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF000000).withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                strokeWidth: 3,
              ),
              SizedBox(height: 24),
              Text(
                'Updating job status...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A1A1A),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );

    try {
      await JobApi(Dio(BaseOptions(baseUrl: '${AppStrings.baseUrl}/api')))
          .updateJobStatus(job.nrcJobNo, 'ACTIVE');

      // Remove loader - use mounted check if this was a StatefulWidget
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();

        // Show elegant success dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF000000).withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.green,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Job Is Active Now',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Job ${job.nrcJobNo} has been successfully activated',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF757575),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.of(context, rootNavigator: true).pop();
                        context.go('/home');
                      },
                      child: const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        showDialog(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF000000).withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      color: Colors.red,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Update Failed',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Failed to update job: $e',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF757575),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.of(context, rootNavigator: true).pop();
                        context.go('/home');
                      },
                      child: const Text(
                        'OK',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          job.nrcJobNo,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.blue,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 20),
            _buildJobDetailsCard(),
            const SizedBox(height: 20),
            _buildProductionDetailsCard(),
            const SizedBox(height: 20),
            _buildDeliveryDetailsCard(),
            const SizedBox(height: 32),
            _buildActionButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE8E8E8),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  job.nrcJobNo,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const Spacer(),
              _buildStatusChip(),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            job.customerName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.access_time_rounded,
                size: 16,
                color: Color(0xFF757575),
              ),
              const SizedBox(width: 8),
              Text(
                'Created: ${_formatDate(job.createdAt)}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF757575),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          if (job.jobDemand != null && job.jobDemand!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  'Job Demand: ',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF757575),
                  ),
                ),
                _buildJobDemandChip(),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildJobDetailsCard() {
    return _buildCard(
      title: 'Job Details',
      icon: Icons.work_outline_rounded,
      children: [
        _buildDetailRow('Style', job.styleItemSKU),
        _buildDetailRow('Flute Type', job.fluteType),
        _buildDetailRow('Box Dimensions', job.boxDimensions ?? '-'),
        _buildDetailRow('Die Punch Code', job.diePunchCode?.toString() ?? '-'),
        _buildDetailRow('Board Size', job.boardSize ?? '-'),
        _buildDetailRow('No. of Colors', job.noOfColor ?? '-'),
      ],
    );
  }

  Widget _buildProductionDetailsCard() {
    return _buildCard(
      title: 'Production Details',
      icon: Icons.precision_manufacturing_rounded,
      children: [
        _buildDetailRow('Length', job.length?.toString() ?? '-'),
        _buildDetailRow('Width', job.width?.toString() ?? '-'),
        _buildDetailRow('Height', job.height?.toString() ?? '-'),
        _buildDetailRow('Top Face GSM', job.topFaceGSM ?? '-'),
        _buildDetailRow('Fluting GSM', job.flutingGSM ?? '-'),
        _buildDetailRow('Bottom Liner GSM', job.bottomLinerGSM ?? '-'),
      ],
    );
  }

  Widget _buildDeliveryDetailsCard() {
    return _buildCard(
      title: 'Timeline',
      icon: Icons.schedule_rounded,
      children: [
        _buildDetailRow('Created At', _formatDate(job.createdAt)),
        _buildDetailRow('Updated At', _formatDate(job.updatedAt)),
      ],
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE8E8E8),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: const Color(0xFF757575),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFF5F5F5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF757575),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip() {
    final status = job.status.toUpperCase();
    Color backgroundColor;
    Color borderColor;
    Color textColor;

    switch (status) {
      case 'ACTIVE':
        backgroundColor = Colors.green.withOpacity(0.1);
        borderColor = Colors.green.withOpacity(0.3);
        textColor = Colors.green;
        break;
      case 'INACTIVE':
        backgroundColor = Colors.orange.withOpacity(0.1);
        borderColor = Colors.orange.withOpacity(0.3);
        textColor = Colors.orange;
        break;
      default:
        backgroundColor = const Color(0xFFFAFAFA);
        borderColor = const Color(0xFFE8E8E8);
        textColor = const Color(0xFF757575);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildJobDemandChip() {
    if (job.jobDemand == null || job.jobDemand!.isEmpty) {
      return const SizedBox.shrink();
    }

    Color backgroundColor;
    Color borderColor;
    Color textColor;

    switch (job.jobDemand!.toLowerCase()) {
      case 'high':
        backgroundColor = Colors.red.withOpacity(0.1);
        borderColor = Colors.red.withOpacity(0.3);
        textColor = Colors.red;
        break;
      case 'medium':
        backgroundColor = Colors.orange.withOpacity(0.1);
        borderColor = Colors.orange.withOpacity(0.3);
        textColor = Colors.orange;
        break;
      case 'low':
        backgroundColor = Colors.green.withOpacity(0.1);
        borderColor = Colors.green.withOpacity(0.3);
        textColor = Colors.green;
        break;
      default:
        backgroundColor = const Color(0xFFFAFAFA);
        borderColor = const Color(0xFFE8E8E8);
        textColor = const Color(0xFF757575);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Text(
        job.jobDemand!.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context) {
    if (job.status.toUpperCase() == 'INACTIVE') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => _startWork(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
            shadowColor: Colors.green.withOpacity(0.3),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.play_arrow_rounded, size: 24),
              SizedBox(width: 12),
              Text(
                'Start Work with this Job',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.blue.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.work_rounded,
              color: Colors.blue,
              size: 24,
            ),
            SizedBox(width: 12),
            Text(
              'Work is in Progress',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.blue,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      );
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'Not specified';
    try {
      final date = DateTime.parse(dateString);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return dateString;
    }
  }
}