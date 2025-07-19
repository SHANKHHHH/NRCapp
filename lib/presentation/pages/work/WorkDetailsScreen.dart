import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../constants/colors.dart';
import '../../../data/models/Job.dart';
import '../../../data/models/WorkStepAssignment.dart';
import '../../../data/models/purchase_order.dart';

import 'package:dio/dio.dart';
import '../../../data/datasources/job_api.dart';

class WorkDetailsScreen extends StatefulWidget {
  final String nrcJobNo;

  const WorkDetailsScreen({
    Key? key,
    required this.nrcJobNo,
  }) : super(key: key);

  @override
  State<WorkDetailsScreen> createState() => _WorkDetailsScreenState();
}

class _WorkDetailsScreenState extends State<WorkDetailsScreen> {
  Map<String, dynamic>? jobPlanning;
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? jobDetails;
  bool _jobLoading = true;
  String? _jobError;
  bool _jobDetailsExpanded = false;

  @override
  void initState() {
    super.initState();
    _fetchJobPlanning();
    _fetchJobDetails();
  }

  Future<void> _fetchJobPlanning() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final dio = Dio();
      final jobApi = JobApi(dio);
      final planning = await jobApi.getJobPlanningByNrcJobNo(widget.nrcJobNo);
      setState(() {
        jobPlanning = planning;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load job planning details';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchJobDetails() async {
    setState(() {
      _jobLoading = true;
      _jobError = null;
    });
    try {
      final dio = Dio();
      final jobApi = JobApi(dio);
      print(widget.nrcJobNo);
      final job = await jobApi.getJobByNrcJobNo(widget.nrcJobNo);
      setState(() {
        jobDetails = job;
        _jobLoading = false;
      });
    } catch (e) {
      setState(() {
        _jobError = 'Failed to load job details';
        _jobLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Work Assignment Details'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      backgroundColor: Colors.white,
      body: _isLoading || _jobLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _jobError != null
                  ? Center(child: Text(_jobError!))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: _buildUnifiedCard(context),
                    ),
    );
  }

  Widget _buildUnifiedCard(BuildContext context) {
    if (jobPlanning == null) {
      return const Center(child: Text('No job planning details found.'));
    }
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.zero,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Job Details Section
            if (jobDetails != null && jobDetails!.isNotEmpty) ...[
              _buildSectionHeader(
                icon: Icons.work,
                title: 'JOB DETAILS',
                color: Colors.blue,
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _jobDetailsExpanded = !_jobDetailsExpanded;
                  });
                },
                child: Row(
                  children: [
                    Text(
                      _jobDetailsExpanded ? 'Hide Details' : 'Show Details',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Icon(
                      _jobDetailsExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.blue,
                    ),
                  ],
                ),
              ),
              if (_jobDetailsExpanded)
                ...jobDetails!.entries.map((entry) => _buildKeyValueRow(entry.key, entry.value?.toString() ?? '')),
              const SizedBox(height: 16),
            ],
            const Center(
              child: Text(
                'WORK ASSIGNMENT DETAILS',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Colors.grey),
            const SizedBox(height: 16),

            // Job Planning Section
            _buildSectionHeader(
              icon: Icons.confirmation_number,
              title: 'JOB PLANNING',
              color: Colors.blue,
            ),
            _buildKeyValueRow('Job Plan ID', jobPlanning!['jobPlanId'].toString()),
            _buildKeyValueRow('NRC Job No', jobPlanning!['nrcJobNo'] ?? ''),
            _buildKeyValueRow('Job Demand', jobPlanning!['jobDemand'] ?? ''),
            _buildKeyValueRow('Created At', jobPlanning!['createdAt'] ?? ''),
            _buildKeyValueRow('Updated At', jobPlanning!['updatedAt'] ?? ''),

            // Steps Section
            _buildSectionHeader(
              icon: Icons.assignment,
              title: 'WORK STEPS',
              color: Colors.green,
            ),
            if (jobPlanning!['steps'] != null && jobPlanning!['steps'] is List)
              ...((jobPlanning!['steps'] as List).map((step) => _buildStepItem(step)).toList()),
          ],
        ),
      ),
    );
  }

  Widget _buildStepItem(dynamic step) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.translucentBlack),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            step['stepName'] ?? '',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text('Status: ${step['status'] ?? ''}', style: const TextStyle(color: Colors.black54)),
          if (step['user'] != null)
            Text('User: ${step['user']}', style: const TextStyle(color: Colors.black54)),
          if (step['startDate'] != null)
            Text('Start: ${step['startDate']}', style: const TextStyle(color: Colors.black54)),
          if (step['endDate'] != null)
            Text('End: ${step['endDate']}', style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
  // ... (keep all other helper methods the same as in your original code)
  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyValueRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              key,
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : 'N/A',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(String text, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkStepItem(WorkStepAssignment assignment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.translucentBlack),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            assignment.workStep.displayName,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          if (assignment.selectedMachine != null)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'Machine: ${assignment.selectedMachine!.machineCode} - '
                    '${assignment.selectedMachine!.description}',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 13,
                ),
              ),
            ),
          if (assignment.selectedMachine == null)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'No machine required',
                style: TextStyle(
                  color: Colors.green[400],
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}