import 'package:flutter/material.dart';

import '../../../constants/colors.dart';
import 'package:dio/dio.dart';
import '../../../data/datasources/job_api.dart';

class UserListPage extends StatefulWidget {
  const UserListPage({super.key});

  @override
  _UserListPageState createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  List<Map<String, dynamic>> users = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchQuery.isEmpty) return users;
    final query = _searchQuery.toLowerCase();
    return users.where((user) {
      final id = (user['id'] ?? '').toString().toLowerCase();
      final name = (user['name'] ?? '').toString().toLowerCase();
      return id.contains(query) || name.contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final dio = Dio();
      final jobApi = JobApi(dio);
      final fetchedUsers = await jobApi.getAllUsers();
      setState(() {
        users = fetchedUsers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load users';
        _isLoading = false;
      });
    }
  }

  // No edit/delete for API users in this version

  void _showUserDetailsDialog(Map<String, dynamic> user) {
    String notAvailable(dynamic v) => (v == null || (v is String && v.isEmpty)) ? 'Not Available' : v.toString();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
            Icon(Icons.person, color: Colors.blue),
              SizedBox(width: 8),
            Text('User Details', style: TextStyle(color: Colors.blue)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildUserDetailRow('ID', notAvailable(user['id'])),
              _buildUserDetailRow('Name', notAvailable(user['name'])),
              _buildUserDetailRow('Email', notAvailable(user['email'])),
              _buildUserDetailRow('Phone', notAvailable(user['phoneNumber'])),
              _buildUserDetailRow('Role', notAvailable(user['role'])),
              _buildUserDetailRow('Active', user['isActive'] == true ? 'Yes' : 'No'),
              _buildUserDetailRow('Last Login', notAvailable(user['lastLogin'])),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showEditUserDialog(user);
            },
            child: const Text('Edit User', style: TextStyle(color: Colors.blue)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showDeleteUserDialog(user);
            },
            child: const Text('Delete User', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showDeleteUserDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Confirm Delete', style: TextStyle(color: Colors.red)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to delete this user?'),
            const SizedBox(height: 12),
            _buildUserDetailRow('ID', user['id']),
            _buildUserDetailRow('Name', user['name']),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // Show loading dialog
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => Dialog(
                  backgroundColor: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Deleting user...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );

              try {
                final dio = Dio();
                final jobApi = JobApi(dio);
                final response = await jobApi.deleteUser(user['id']);
                Navigator.of(context).pop(); // Close loading dialog
                
                if (response.data['success'] == true) {
                  Navigator.pop(context); // Close confirm dialog
                  await _fetchUsers(); // Refresh the list
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: Row(
                        children: const [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 8),
                          Text('Success', style: TextStyle(color: Colors.green)),
                        ],
                      ),
                      content: const Text('User deleted successfully!'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                } else {
                  Navigator.of(context).pop(); // Close confirm dialog
                  _showErrorDialog(response.data['message'] ?? 'Failed to delete user.');
                }
              } catch (e) {
                Navigator.of(context).pop(); // Close confirm dialog
                _showErrorDialog('Something went wrong while deleting user.');
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildUserDetailRow(String label, dynamic value) {
    if (value == null || (value is String && value.isEmpty)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black54),
            ),
          ),
          Expanded(
            child: Text(
              value.toString(),
              style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditUserDialog(Map<String, dynamic> user) {
    print('Editing user: id=${user['id']}, name=${user['name']}, email=${user['email']}, phone=${user['phoneNumber']}, role=${user['role']}');
    final nameController = TextEditingController(text: user['name'] ?? '');
    print(user['name']);
    final emailController = TextEditingController(text: user['email'] ?? '');
    final phoneController = TextEditingController(text: user['phoneNumber'] ?? '');
    String role = user['role'] ?? '';
    final passwordController = TextEditingController();
    passwordController.text = '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 420,
              maxHeight: MediaQuery.of(context).size.height * 0.8, // Limit height
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.edit, color: Colors.blue, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Edit User',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),

                // Scrollable Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                      children: [
                        _buildStyledTextField(
                          controller: nameController,
                          label: 'Name',
                          icon: Icons.person_outline,
                        ),
                        const SizedBox(height: 20),

                        _buildStyledTextField(
                          controller: emailController,
                          label: 'Email',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 20),

                        _buildStyledTextField(
                  controller: phoneController,
                          label: 'Phone Number',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 20),

                        // Role Dropdown
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: DropdownButtonFormField<String>(
                            value: role.isNotEmpty ? role : null,
                            decoration: InputDecoration(
                              labelText: 'Role',
                              labelStyle: TextStyle(color: Colors.grey[600]),
                              prefixIcon: Icon(Icons.work_outline, color: Colors.grey[600]),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            dropdownColor: Colors.white,
                            items: ['admin', 'planner', 'production head', 'qc manager', 'dispatch executive']
                                .map((r) => DropdownMenuItem(
                              value: r,
                              child: Text(
                                r[0].toUpperCase() + r.substring(1),
                                style: const TextStyle(color: Colors.black),
                              ),
                            ))
                                .toList(),
                            onChanged: (value) => setState(() => role = value ?? ''),
                          ),
                        ),
                        const SizedBox(height: 20),

                        _buildStyledTextField(
                          controller: passwordController,
                          label: 'Password (leave blank to keep unchanged)',
                          icon: Icons.lock_outline,
                          obscure: true,
                        ),
                        const SizedBox(height: 32),

                        // Action Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.grey[700],
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () async {
                                final dio = Dio();
                                final jobApi = JobApi(dio);
                                final body = {
                                  'name': nameController.text.trim(),
                                  'email': emailController.text.trim(),
                                  'phoneNumber': phoneController.text.trim(),
                                  'role': role,
                                };
                                if (passwordController.text.isNotEmpty) {
                                  body['password'] = passwordController.text;
                                }

                                // Enhanced Loader
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (context) => Dialog(
                                    backgroundColor: Colors.transparent,
                                    child: Container(
                                      padding: const EdgeInsets.all(32),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.1),
                                            blurRadius: 20,
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const CircularProgressIndicator(
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'Updating user...',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.grey[700],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );

                                try {
                                  final response = await jobApi.updateUser(user['id'], body);
                                  Navigator.of(context).pop(); // Close loader
                                  if (response.data['success'] == true) {
                                    Navigator.pop(context); // Close dialog
                                    await _fetchUsers();
                                    _showSuccessDialog();
                                  } else {
                                    Navigator.of(context).pop();
                                    _showErrorDialog(response.data['message'] ?? 'Failed to update user.');
                                  }
                                } catch (e) {
                                  Navigator.of(context).pop();
                                  _showErrorDialog('Something went wrong while updating user.');
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 2,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.save, size: 16),
                                  SizedBox(width: 8),
                                  Text(
                                    'Save Changes',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
          prefixIcon: Icon(icon, color: Colors.grey[600], size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
        ),
      ),
    );
  }
  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.grey[100],
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildRoundedTextField({
    required TextEditingController controller,
    required String label,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: _inputDecoration(label),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Success', style: TextStyle(color: Colors.green)),
          ],
        ),
        content: const Text('User updated successfully!'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Error', style: TextStyle(color: Colors.red)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPinkWhite,
      appBar: AppBar(
        title: const Text('All Login IDs', style: TextStyle(color: AppColors.white),),
        backgroundColor: AppColors.maincolor,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.white),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search by ID or First Name',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        ),
                        onChanged: (value) => setState(() => _searchQuery = value),
                      ),
                    ),
                    Expanded(
                      child: _filteredUsers.isEmpty
          ? const Center(
        child: Text(
          'No Users Found',
          style: TextStyle(fontSize: 16, color: Colors.black54),
        ),
      )
          : ListView.separated(
        padding: const EdgeInsets.all(16),
                              itemCount: _filteredUsers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
                                final user = _filteredUsers[index];
          return Card(
            color: AppColors.white,
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
                                  child: InkWell(
                                    onTap: () => _showUserDetailsDialog(user),
                                    borderRadius: BorderRadius.circular(12),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              title: Text(
                                        '${user['name'] ?? ''} - ${user['id'] ?? ''}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (user['email'] != null)
                                            Text('Email: ${user['email']}', style: const TextStyle(color: Colors.black54)),
                                          if (user['phoneNumber'] != null)
                                            Text('Phone: ${user['phoneNumber']}', style: const TextStyle(color: Colors.black54)),
                                          Text('Role: ${user['role'] ?? ''}', style: const TextStyle(color: Colors.black54)),
                                          Text('Active: ${user['isActive'] == true ? 'Yes' : 'No'}', style: const TextStyle(color: Colors.black54)),
                                          if (user['lastLogin'] != null)
                                            Text('Last Login: ${user['lastLogin']}', style: const TextStyle(color: Colors.black54)),
                                          Text('Created: ${user['createdAt'] ?? ''}', style: const TextStyle(color: Colors.black54)),
                                          Text('Updated: ${user['updatedAt'] ?? ''}', style: const TextStyle(color: Colors.black54)),
                                        ],
              ),
              isThreeLine: true,
              ),
            ),
          );
        },
                            ),
                    ),
                  ],
      ),
    );
  }
}
