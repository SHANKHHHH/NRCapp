import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:nrc/constants/colors.dart';
import 'package:nrc/constants/strings.dart';
import '../../../data/models/job_model.dart';
import '../../../data/datasources/job_api.dart';
import '../../../data/repositories/job_repository.dart';
import 'JobDetailScreen.dart';
import 'jobMainCard.dart';

/// Elegant search bar and customer filter widget
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
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search TextField with elegant styling
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFE8E8E8),
                width: 1.5,
              ),
            ),
            child: TextField(
              controller: searchController,
              onChanged: (_) => onSearchChanged(),
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF1A1A1A),
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Search by Job Number or Customer',
                hintStyle: TextStyle(
                  color: const Color(0xFF9E9E9E).withOpacity(0.8),
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: Container(
                  padding: const EdgeInsets.all(14),
                  child: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFF9E9E9E),
                    size: 22,
                  ),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Customer Filter Dropdown with refined styling
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFE8E8E8),
                width: 1.5,
              ),
            ),
            child: DropdownButtonFormField<String>(
              value: selectedCustomer,
              onChanged: onCustomerChanged,
              isExpanded: true,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF9E9E9E),
                size: 24,
              ),
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF1A1A1A),
                fontWeight: FontWeight.w500,
              ),
              decoration: const InputDecoration(
                labelText: 'Filter by Customer',
                labelStyle: TextStyle(
                  color: Color(0xFF757575),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
              dropdownColor: Colors.white,
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text(
                    'All Customers',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF1A1A1A),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                ...customers.map((customer) => DropdownMenuItem<String>(
                  value: customer,
                  child: Text(
                    customer,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF1A1A1A),
                      fontWeight: FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}



/// Main screen with beautiful, clean UI
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
    JobApi(Dio(BaseOptions(baseUrl: '${AppStrings.baseUrl}/api'))),
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
        final matchesCustomer = _selectedCustomer == null ||
            _selectedCustomer!.isEmpty ||
            job.customerName == _selectedCustomer;
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Job Management',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),
        backgroundColor: AppColors.maincolor,
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.blue,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              strokeWidth: 3,
            ),
            const SizedBox(height: 24),
            Text(
              'Loading jobs...',
              style: TextStyle(
                fontSize: 16,
                color: const Color(0xFF757575).withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      )
          : _error != null
          ? Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFE8E8E8),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF000000).withOpacity(0.04),
                blurRadius: 12,
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
                  color: const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: Color(0xFF9E9E9E),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Something went wrong',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF757575),
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _fetchJobs,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Try Again',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      )
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
                ? Center(
              child: Container(
                margin: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.search_off_rounded,
                        size: 64,
                        color: const Color(0xFF9E9E9E).withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'No jobs found',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Try adjusting your search criteria\nor filter settings',
                      style: TextStyle(
                        fontSize: 16,
                        color: const Color(0xFF757575).withOpacity(0.8),
                        fontWeight: FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.only(
                top: 20,
                bottom: 32,
              ),
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