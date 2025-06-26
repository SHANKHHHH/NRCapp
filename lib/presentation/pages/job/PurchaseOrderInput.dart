import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../data/models/Job.dart';
import 'JobDetailScreen.dart';
import 'jobMainCard.dart';

class JobService {
  static List<Job> getAllJobs() {
    return [
      Job(
        jobNumber: 'JOB001',
        jobDate: '2024-01-15',
        customer: 'ABC Corp',
        plant: 'Plant A',
        style: 'Regular',
        dieCode: 'DIE001',
        boardSize: '12x18',
        fluteType: 'B',
        noOfUps: '2',
        noOfSheets: '1000',
        totalQuantity: 2000,
        unit: 'Pieces',
        deliveryDate: '2024-02-15',
        nrcDeliveryDate: '2024-02-10',
        dispatchDate: '2024-02-14',
        dispatchQuantity: 1500,
        pendingQuantity: 500,
        pendingValidity: '2024-03-01',
        jobMonth: 'February',
        shadeCardApprovalDate: '2024-01-20',
        createdBy: 'Admin',
        createdDate: '2024-01-15',
        status: JobStatus.inactive,
      ),
      Job(
        jobNumber: 'JOB002',
        jobDate: '2024-01-20',
        customer: 'XYZ Ltd',
        plant: 'Plant B',
        style: 'Premium',
        dieCode: 'DIE002',
        boardSize: '15x20',
        fluteType: 'C',
        noOfUps: '4',
        noOfSheets: '800',
        totalQuantity: 3200,
        unit: 'Pieces',
        deliveryDate: '2024-02-20',
        nrcDeliveryDate: '2024-02-15',
        dispatchDate: '2024-02-18',
        dispatchQuantity: 3200,
        pendingQuantity: 0,
        pendingValidity: '2024-03-01',
        jobMonth: 'February',
        shadeCardApprovalDate: '2024-01-25',
        createdBy: 'Manager',
        createdDate: '2024-01-20',
        status: JobStatus.inactive,
      ),
      Job(
        jobNumber: 'JOB003',
        jobDate: '2024-01-25',
        customer: 'PQR Industries',
        plant: 'Plant C',
        style: 'Standard',
        dieCode: 'DIE003',
        boardSize: '10x15',
        fluteType: 'A',
        noOfUps: '1',
        noOfSheets: '1200',
        totalQuantity: 1200,
        unit: 'Pieces',
        deliveryDate: '2024-02-25',
        nrcDeliveryDate: '2024-02-20',
        dispatchDate: '2024-02-23',
        dispatchQuantity: 1200,
        pendingQuantity: 0,
        pendingValidity: '2024-03-01',
        jobMonth: 'February',
        shadeCardApprovalDate: '2024-01-30',
        createdBy: 'Supervisor',
        createdDate: '2024-01-25',
        status: JobStatus.inactive,
      ),
    ];
  }

  static List<String> getUniqueCustomers() {
    return getAllJobs().map((job) => job.customer).toSet().toList();
  }

  static List<Job> searchJobs(String query, String? selectedCustomer) {
    List<Job> jobs = getAllJobs();

    if (selectedCustomer != null && selectedCustomer.isNotEmpty) {
      jobs = jobs.where((job) => job.customer == selectedCustomer).toList();
    }

    if (query.isNotEmpty) {
      jobs = jobs.where((job) =>
      job.jobNumber.toLowerCase().contains(query.toLowerCase()) ||
          job.customer.toLowerCase().contains(query.toLowerCase())
      ).toList();
    }

    return jobs;
  }
}


class SearchBarWidget extends StatelessWidget {
  final TextEditingController searchController;
  final String? selectedCustomer;
  final List<String> customers;
  final Function(String?) onCustomerChanged;
  final VoidCallback onSearchChanged;

  const SearchBarWidget({
    Key? key,
    required this.searchController,
    required this.selectedCustomer,
    required this.customers,
    required this.onCustomerChanged,
    required this.onSearchChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search Field
          TextField(
            controller: searchController,
            onChanged: (value) => onSearchChanged(),
            decoration: InputDecoration(
              hintText: 'Search by Job Number or Customer',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          // Customer Dropdown
          DropdownButtonFormField<String>(
            value: selectedCustomer,
            onChanged: onCustomerChanged,
            decoration: InputDecoration(
              labelText: 'Filter by Customer',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('All Customers'),
              ),
              ...customers.map((customer) => DropdownMenuItem<String>(
                value: customer,
                child: Text(customer),
              )),
            ],
          ),
        ],
      ),
    );
  }
}



class JobListScreen extends StatefulWidget {
  const JobListScreen({Key? key}) : super(key: key);

  @override
  State<JobListScreen> createState() => _JobListScreenState();
}

class _JobListScreenState extends State<JobListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedCustomer;
  List<Job> _filteredJobs = [];
  List<String> _customers = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _customers = JobService.getUniqueCustomers();
    _filteredJobs = JobService.getAllJobs();
  }

  void _performSearch() {
    setState(() {
      _filteredJobs = JobService.searchJobs(_searchController.text, _selectedCustomer);
    });
  }

  void _onCustomerChanged(String? customer) {
    setState(() {
      _selectedCustomer = customer;
      _performSearch();
    });
  }

  void _navigateToJobDetail(Job job) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JobDetailScreen(job: job),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Management'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          SearchBarWidget(
            searchController: _searchController,
            selectedCustomer: _selectedCustomer,
            customers: _customers,
            onCustomerChanged: _onCustomerChanged,
            onSearchChanged: _performSearch,
          ),
          Expanded(
            child: _filteredJobs.isEmpty
                ? const Center(
              child: Text(
                'No jobs found',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
                : ListView.builder(
              itemCount: _filteredJobs.length,
              itemBuilder: (context, index) {
                final job = _filteredJobs[index];
                return JobMainCard(
                  job: job,
                  onTap: () => _navigateToJobDetail(job),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}



