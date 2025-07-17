import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../data/models/job_model.dart';
import '../../../data/datasources/job_api.dart';
import '../../../data/repositories/job_repository.dart';
import 'JobDetailScreen.dart';
import 'jobMainCard.dart';

/// Search bar and customer filter widget
class SearchBarWidget extends StatelessWidget {
  final TextEditingController searchController;
  final String? selectedCustomer;
  final List<String> customers;
  final ValueChanged<String?> onCustomerChanged;
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
          TextField(
            controller: searchController,
            onChanged: (_) => onSearchChanged(),
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

/// Main screen for displaying and searching jobs
class AllJobsScreen extends StatefulWidget {
  const AllJobsScreen({Key? key}) : super(key: key);

  @override
  State<AllJobsScreen> createState() => _AllJobsScreenState();
}

class _AllJobsScreenState extends State<AllJobsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedCustomer;
  List<JobModel> _allJobs = [];
  List<JobModel> _filteredJobs = [];
  List<String> _customers = [];
  bool _isLoading = true;
  String? _error;

  // Use repository for fetching jobs
  final JobRepository _jobRepository = JobRepository(
    JobApi(Dio(BaseOptions(baseUrl: 'http://51.20.4.108:3000/api'))),
  );

  @override
  void initState() {
    super.initState();
    _fetchJobs();
  }

  /// Fetch jobs from the repository and update state
  Future<void> _fetchJobs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final jobs = await _jobRepository.fetchJobs();
      final customers = jobs.map((job) => job.customerName).toSet().toList();
      setState(() {
        _allJobs = jobs;
        _filteredJobs = jobs;
        _customers = customers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load jobs: $e';
        _isLoading = false;
      });
    }
  }

  /// Filter jobs based on search query and selected customer
  void _performSearch() {
    setState(() {
      _filteredJobs = _allJobs.where((job) {
        final matchesCustomer = _selectedCustomer == null || _selectedCustomer!.isEmpty || job.customerName == _selectedCustomer;
        final matchesQuery = _searchController.text.isEmpty ||
            job.nrcJobNo.toLowerCase().contains(_searchController.text.toLowerCase()) ||
            job.customerName.toLowerCase().contains(_searchController.text.toLowerCase());
        return matchesCustomer && matchesQuery;
      }).toList();
    });
  }

  void _onCustomerChanged(String? customer) {
    setState(() {
      _selectedCustomer = customer;
      _performSearch();
    });
  }

  void _navigateToJobDetail(JobModel job) {
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Column(
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



