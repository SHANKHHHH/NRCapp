import 'package:flutter/material.dart';
import 'package:nrc/constants/colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../routes/UserRoleManager.dart';

import 'JobStep.dart';

class Job {
  final String nrcJobNo;
  final String styleItemSKU;
  final String customerName;
  final String boxDimensions;
  final int noUps;
  final String status;
  final String priority;
  final DateTime createdDate;
  final DateTime? dueDate;

  Job({
    required this.nrcJobNo,
    required this.styleItemSKU,
    required this.customerName,
    required this.boxDimensions,
    required this.noUps,
    required this.status,
    required this.priority,
    required this.createdDate,
    this.dueDate,
  });
}

class JobListPage extends StatefulWidget {
  const JobListPage({super.key, String? userRole});

  @override
  _JobListPageState createState() => _JobListPageState();
}

class _JobListPageState extends State<JobListPage> {
  late String _userRole;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  void _loadUserRole() async {
    _userRole = UserRoleManager().userRole ?? 'Guest'; // Retrieve user role from UserRoleManager
    print('User Role in JobDetails: $_userRole');
    setState(() {});
  }

  List<Job> get jobs => [
    Job(
      nrcJobNo: 'NRC001',
      styleItemSKU: 'SKU-TEE-001',
      customerName: 'Fashion Hub Ltd.',
      boxDimensions: '30x20x15 cm',
      noUps: 24,
      status: 'Confirmed',
      priority: 'High',
      createdDate: DateTime.now().subtract(const Duration(days: 2)),
      dueDate: DateTime.now().add(const Duration(days: 3)),
    ),
    Job(
      nrcJobNo: 'NRC002',
      styleItemSKU: 'SKU-JEAN-002',
      customerName: 'Denim World',
      boxDimensions: '40x25x20 cm',
      noUps: 18,
      status: 'Hold',
      priority: 'Medium',
      createdDate: DateTime.now().subtract(const Duration(days: 1)),
      dueDate: DateTime.now().add(const Duration(days: 5)),
    ),
    Job(
      nrcJobNo: 'NRC003',
      styleItemSKU: 'SKU-SHIRT-003',
      customerName: 'Corporate Wear Co.',
      boxDimensions: '35x22x18 cm',
      noUps: 30,
      status: 'Rejected',
      priority: 'Low',
      createdDate: DateTime.now().subtract(const Duration(days: 5)),
      dueDate: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Production Jobs'),
        backgroundColor: AppColors.maincolor,
        foregroundColor: AppColors.white,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: jobs.length,
        itemBuilder: (context, index) {
          final job = jobs[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 1,
            color: AppColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border(
                  left: BorderSide(
                    color: _getStatusColor(job.status),
                    width: 4,
                  ),
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => JobTimelinePage(),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Job Number and Priority Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            job.nrcJobNo,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              job.priority,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // All Information in Single Container
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Customer Name
                            Text(
                              'Customer: ${job.customerName}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            const SizedBox(height: 6),

                            // SKU
                            Text(
                              'SKU: ${job.styleItemSKU}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),

                            const SizedBox(height: 4),

                            // Box Dimensions
                            Text(
                              'Box Size: ${job.boxDimensions}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),

                            const SizedBox(height: 4),

                            // UPS
                            Text(
                              'UPS: ${job.noUps}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),

                            const SizedBox(height: 4),

                            // Due Date
                            Text(
                              'Due Date: ${job.dueDate != null ? _formatDate(job.dueDate!) : 'Not set'}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Action Buttons (if user has permissions)
                      if (_userRole == 'Admin' || _userRole == 'Planner') ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (_userRole == 'Admin' || _userRole == 'Planner')
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () {
                                  // Implement edit
                                },
                              ),
                            if (_userRole == 'Admin')
                              IconButton(
                                icon: const Icon(Icons.delete, size: 20),
                                onPressed: () {
                                  // Implement delete
                                },
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return AppColors.green;
      case 'rejected':
        return AppColors.red;
      case 'hold':
        return AppColors.grey;
      default:
        return AppColors.black;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }


  bool _isOverdue(DateTime dueDate) {
    return dueDate.isBefore(DateTime.now());
  }


  void _showJobDetails(BuildContext context, Job job) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildDetailRow('NRC Job No.', job.nrcJobNo),
                _buildDetailRow('Style Item SKU', job.styleItemSKU),
                _buildDetailRow('Customer Name', job.customerName),
                _buildDetailRow('Box Dimensions', job.boxDimensions),
                _buildDetailRow('No. UPS', '${job.noUps}'),
                _buildDetailRow('Status', job.status,
                    valueColor: _getStatusColor(job.status)),
                _buildDetailRow('Priority', job.priority),
                _buildDetailRow('Created Date', _formatDate(job.createdDate)),
                if (job.dueDate != null)
                  _buildDetailRow('Due Date', _formatDate(job.dueDate!)),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: valueColor ?? Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Jobs'),
        content: const Text('Filter options will go here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _showAddJobDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Job'),
        content: const Text('Form UI coming soon.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _editJob(Job job) {
    // Implement the edit functionality here
    // You can navigate to an edit page or show a dialog to edit the job details
    print('Editing job: ${job.nrcJobNo}');
    // Example: Navigate to an edit page
    // context.push('/edit-job', extra: job);
  }

  void _deleteJob(Job job) {
    // Implement the delete functionality here
    print('Deleting job: ${job.nrcJobNo}');
    // Example: Show a confirmation dialog before deleting
  }
}