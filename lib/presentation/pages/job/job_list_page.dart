import 'package:flutter/material.dart';
import 'package:nrc/constants/colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../routes/UserRoleManager.dart';
import '../../../data/models/Job.dart';
import 'JobDetailScreen.dart';
import 'JobCard.dart';
import 'JobStep.dart';

class JobListPage extends StatefulWidget {
  const JobListPage({super.key, String? userRole});

  @override
  _JobListPageState createState() => _JobListPageState();
}

class _JobListPageState extends State<JobListPage> {
  late String _userRole;
  List<Job> _jobs = [];
  List<Job> _filteredJobs = [];
  Set<JobStatus> _selectedFilters = {};

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _initializeJobs();
  }

  void _loadUserRole() async {
    _userRole = UserRoleManager().userRole ?? 'Guest';
    print('User Role in JobDetails: $_userRole');
    setState(() {});
  }

  void _initializeJobs() {
    _jobs = [
      Job(
        jobNumber: 'NRC001',
        customer: 'Fashion Hub Ltd.',
        plant: 'Plant A',
        jobDate: '2024-01-15',
        deliveryDate: '2024-01-25',
        createdDate: '2024-01-11',
        createdBy: 'Jane Smith',
        style: 'Style B',
        dieCode: 'DIE002',
        boardSize: '40x25',
        fluteType: 'C Flute',
        jobMonth: 'January',
        noOfUps: '18',
        noOfSheets: '150',
        totalQuantity: 2700,
        unit: 'PCS',
        dispatchQuantity: 500,
        pendingQuantity: 2200,
        shadeCardApprovalDate: '2024-01-13',
        nrcDeliveryDate: '2024-01-27',
        dispatchDate: '2024-01-20',
        pendingValidity: '2024-02-18',
        status: JobStatus.inactive,
      ),
      Job(
        jobNumber: 'NRC002',
        customer: 'Denim World',
        plant: 'Plant B',
        jobDate: '2024-01-16',
        deliveryDate: '2024-01-28',
        createdDate: '2024-01-10',
        createdBy: 'John Doe',
        style: 'Style A',
        dieCode: 'DIE001',
        boardSize: '30x20',
        fluteType: 'B Flute',
        jobMonth: 'January',
        noOfUps: '24',
        noOfSheets: '100',
        totalQuantity: 2400,
        unit: 'PCS',
        dispatchQuantity: 0,
        pendingQuantity: 2400,
        shadeCardApprovalDate: '2024-01-12',
        nrcDeliveryDate: '2024-01-24',
        dispatchDate: 'TBD',
        pendingValidity: '2024-02-15',
        status: JobStatus.inactive,
      ),
      Job(
        jobNumber: 'NRC003',
        customer: 'Corporate Wear Co.',
        plant: 'Plant C',
        jobDate: '2024-01-17',
        deliveryDate: '2024-01-30',
        createdDate: '2024-01-12',
        createdBy: 'Mike Johnson',
        style: 'Style C',
        dieCode: 'DIE003',
        boardSize: '35x22',
        fluteType: 'E Flute',
        jobMonth: 'January',
        noOfUps: '30',
        noOfSheets: '120',
        totalQuantity: 3600,
        unit: 'PCS',
        dispatchQuantity: 0,
        pendingQuantity: 3600,
        shadeCardApprovalDate: '2024-01-14',
        nrcDeliveryDate: '2024-01-29',
        dispatchDate: 'TBD',
        pendingValidity: '2024-02-20',
        status: JobStatus.inactive,
      ),
      Job(
        jobNumber: 'NRC004',
        customer: 'Tech Solutions Inc.',
        plant: 'Plant D',
        jobDate: '2024-01-18',
        deliveryDate: '2024-02-01',
        createdDate: '2024-01-13',
        createdBy: 'Sarah Wilson',
        style: 'Style D',
        dieCode: 'DIE004',
        boardSize: '45x30',
        fluteType: 'BC Flute',
        jobMonth: 'January',
        noOfUps: '20',
        noOfSheets: '200',
        totalQuantity: 4000,
        unit: 'PCS',
        dispatchQuantity: 0,
        pendingQuantity: 4000,
        shadeCardApprovalDate: '2024-01-15',
        nrcDeliveryDate: '2024-01-31',
        dispatchDate: 'TBD',
        pendingValidity: '2024-02-25',
        status: JobStatus.active,
        jobDemand: JobDemand.high,
        isApprovalPending: true,
      ),
    ];
    _filteredJobs = List.from(_jobs);
  }

  void _applyFilters() {
    setState(() {
      if (_selectedFilters.isEmpty) {
        _filteredJobs = List.from(_jobs);
      } else {
        _filteredJobs = _jobs.where((job) => _selectedFilters.contains(job.status)).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Production Jobs'),
        backgroundColor: AppColors.maincolor,
        foregroundColor: AppColors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(context),
          ),
          if (_userRole == 'Admin' || _userRole == 'Planner')
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showAddJobDialog(context),
            ),
        ],
      ),
      body: _filteredJobs.isEmpty
          ? const Center(
        child: Text(
          'No jobs found',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredJobs.length,
        itemBuilder: (context, index) {
          final job = _filteredJobs[index];
          return JobCard(
            job: job,
            onTap: () {
              if (job.status == JobStatus.active ||
                  job.status == JobStatus.hold ||
                  job.status == JobStatus.workingStarted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => JobTimelinePage(jobNumber: job.jobNumber, job: job),
                  ),
                );
              } else if (job.status == JobStatus.inactive) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('The Item is Inactive'),
                    content: const Text('To proceed, activate this job.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          // Update job status to active
                          setState(() {
                            final index = _jobs.indexWhere((j) => j.jobNumber == job.jobNumber);
                            if (index != -1) {
                              _jobs[index] = job.copyWith(status: JobStatus.active);
                              _applyFilters();
                            }
                          });
                          Navigator.pop(context); // Close dialog
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => JobDetailScreen(
                                job: job.copyWith(status: JobStatus.active),
                                onJobUpdate: _updateJob,
                              ),
                            ),
                          );
                        },
                        child: const Text('Activate & View Details'),
                      ),
                    ],
                  ),
                );
              }
            },
            onStatusUpdate: _updateJobStatus,
          );
        },
      ),
    );
  }

  void _navigateToJobDetail(Job job) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => JobDetailScreen(
          job: job,
          onJobUpdate: _updateJob,
        ),
      ),
    );
  }

  void _updateJob(Job updatedJob) {
    setState(() {
      final index = _jobs.indexWhere((j) => j.jobNumber == updatedJob.jobNumber);
      if (index != -1) {
        _jobs[index] = updatedJob;
      }
    });
    _applyFilters(); // Reapply filters after update
  }

  void _updateJobStatus(Job job, JobStatus newStatus) {
    setState(() {
      final index = _jobs.indexWhere((j) => j.jobNumber == job.jobNumber);
      if (index != -1) {
        _jobs[index] = job.copyWith(
          status: newStatus,
          isApprovalPending: false,
        );
      }
    });

    _applyFilters(); // Reapply filters after status update

    // Show success message
    final statusText = newStatus == JobStatus.workingStarted ? 'approved and work started' : 'rejected';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Job ${job.jobNumber} has been $statusText'),
        backgroundColor: newStatus == JobStatus.workingStarted ? Colors.green : Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Color _getStatusColor(JobStatus status) {
    switch (status) {
      case JobStatus.active:
        return AppColors.green;
      case JobStatus.inactive:
        return AppColors.red;
      case JobStatus.hold:
        return AppColors.grey;
      case JobStatus.workingStarted:
        return Colors.blue;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
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
                _buildDetailRow('Job Number', job.jobNumber),
                _buildDetailRow('Customer', job.customer),
                _buildDetailRow('Plant', job.plant),
                _buildDetailRow('Job Date', job.jobDate),
                _buildDetailRow('Delivery Date', job.deliveryDate),
                _buildDetailRow('Status', job.status.name.toUpperCase(),
                    valueColor: _getStatusColor(job.status)),
                if (job.jobDemand != null)
                  _buildDetailRow('Job Demand', job.jobDemand!.name.toUpperCase()),
                _buildDetailRow('Total Quantity', '${job.totalQuantity} ${job.unit}'),
                _buildDetailRow('Created By', job.createdBy),
                _buildDetailRow('Style', job.style),
                _buildDetailRow('Die Code', job.dieCode),
                _buildDetailRow('Board Size', job.boardSize),
                _buildDetailRow('Flute Type', job.fluteType),
                _buildDetailRow('No. of Ups', job.noOfUps),
                _buildDetailRow('No. of Sheets', job.noOfSheets),
                _buildDetailRow('Dispatch Quantity', '${job.dispatchQuantity} ${job.unit}'),
                _buildDetailRow('Pending Quantity', '${job.pendingQuantity} ${job.unit}'),
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
                color: Colors.black87,
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
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Filter Jobs'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filter by Status:'),
              const SizedBox(height: 16),
              ...JobStatus.values.map((status) => CheckboxListTile(
                title: Text(status.name.toUpperCase()),
                value: _selectedFilters.contains(status),
                onChanged: (value) {
                  setDialogState(() {
                    if (value == true) {
                      _selectedFilters.add(status);
                    } else {
                      _selectedFilters.remove(status);
                    }
                  });
                },
              )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedFilters.clear();
                });
                Navigator.pop(context);
                _applyFilters();
              },
              child: const Text('Clear'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _applyFilters();
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddJobDialog(BuildContext context) {
    final TextEditingController jobNumberController = TextEditingController();
    final TextEditingController customerController = TextEditingController();
    final TextEditingController plantController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Job'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: jobNumberController,
                decoration: const InputDecoration(
                  labelText: 'Job Number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: customerController,
                decoration: const InputDecoration(
                  labelText: 'Customer',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: plantController,
                decoration: const InputDecoration(
                  labelText: 'Plant',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (jobNumberController.text.isNotEmpty &&
                  customerController.text.isNotEmpty &&
                  plantController.text.isNotEmpty) {
                // Add the job logic here
                _addNewJob(
                  jobNumberController.text,
                  customerController.text,
                  plantController.text,
                );
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill all required fields'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _addNewJob(String jobNumber, String customer, String plant) {
    final newJob = Job(
      jobNumber: jobNumber,
      customer: customer,
      plant: plant,
      jobDate: DateTime.now().toString().substring(0, 10),
      deliveryDate: DateTime.now().add(const Duration(days: 14)).toString().substring(0, 10),
      createdDate: DateTime.now().toString().substring(0, 10),
      createdBy: _userRole,
      style: 'TBD',
      dieCode: 'TBD',
      boardSize: 'TBD',
      fluteType: 'TBD',
      jobMonth: _getMonthName(DateTime.now().month),
      noOfUps: '0',
      noOfSheets: '0',
      totalQuantity: 0,
      unit: 'PCS',
      dispatchQuantity: 0,
      pendingQuantity: 0,
      shadeCardApprovalDate: 'TBD',
      nrcDeliveryDate: 'TBD',
      dispatchDate: 'TBD',
      pendingValidity: 'TBD',
      status: JobStatus.hold,
    );

    setState(() {
      _jobs.add(newJob);
    });
    _applyFilters();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Job $jobNumber added successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  void _editJob(Job job) {
    print('Editing job: ${job.jobNumber}');
    // Navigate to edit screen or show edit dialog
    _navigateToJobDetail(job);
  }

  void _deleteJob(Job job) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Job'),
        content: Text('Are you sure you want to delete job ${job.jobNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _jobs.removeWhere((j) => j.jobNumber == job.jobNumber);
              });
              _applyFilters();
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Job ${job.jobNumber} deleted'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}