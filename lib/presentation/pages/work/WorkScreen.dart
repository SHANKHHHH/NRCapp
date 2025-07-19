import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:nrc/constants/colors.dart';
import '../../../data/models/Job.dart';
import '../../../data/models/purchase_order.dart';
import '../../../data/models/WorkStepAssignment.dart';
import '../job/JobStep.dart';
import 'WorkDetailsScreen.dart';
import '../../../data/datasources/job_api.dart';

class WorkScreen extends StatefulWidget {
  const WorkScreen({Key? key}) : super(key: key);

  @override
  State<WorkScreen> createState() => _WorkScreenState();
}

class _WorkScreenState extends State<WorkScreen> {
  List<Map<String, dynamic>> jobPlannings = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchAllJobPlannings();
  }

  Future<void> _fetchAllJobPlannings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final dio = Dio();
      final jobApi = JobApi(dio);
      final plannings = await jobApi.getAllJobPlannings();
      setState(() {
        jobPlannings = plannings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load job plannings';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Work Assignment Summary'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : jobPlannings.isEmpty
                  ? const Center(child: Text('No job plannings found.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: jobPlannings.length,
                      itemBuilder: (context, index) {
                        final planning = jobPlannings[index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => WorkDetailsScreen(
                                  nrcJobNo: planning['nrcJobNo'],
                                ),
                              ),
                            );
                          },
                          child: _buildSummaryCard(context, planning),
                        );
                      },
                    ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, Map<String, dynamic> jobPlanning) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'WORK ASSIGNMENT SUMMARY',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[600]),
              ],
            ),
            const SizedBox(height: 16),
            _buildSummaryItem(
              icon: Icons.confirmation_number,
              title: 'Job Plan ID',
              value: jobPlanning['jobPlanId'].toString(),
              color: Colors.blue,
            ),
            _buildSummaryItem(
              icon: Icons.work,
              title: 'NRC Job No',
              value: jobPlanning['nrcJobNo'] ?? '',
              color: Colors.blue,
            ),
            _buildSummaryItem(
              icon: Icons.trending_up,
              title: 'Job Demand',
              value: jobPlanning['jobDemand'] ?? '',
              color: Colors.purple,
            ),
            _buildSummaryItem(
              icon: Icons.calendar_today,
              title: 'Created At',
              value: jobPlanning['createdAt'] ?? '',
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WorkDetailsScreen(
                        nrcJobNo: jobPlanning['nrcJobNo'],
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('View Complete Details'),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap card for new page',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


