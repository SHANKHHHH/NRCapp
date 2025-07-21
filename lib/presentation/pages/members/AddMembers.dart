import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../../constants/colors.dart';
import '../../../data/datasources/job_api.dart';

class CreateID extends StatefulWidget {
  const CreateID({super.key});

  @override
  State<CreateID> createState() => _CreateIDState();
}

class _CreateIDState extends State<CreateID> {
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController empIdController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  String? selectedRole;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F9FF),
      appBar: AppBar(
        title: const Text('Create Account', style: TextStyle(color: AppColors.white)),
        backgroundColor: AppColors.maincolor,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.white),
      ),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Create New Login ID',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.maincolor,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // First Name
                  TextFormField(
                    controller: firstNameController,
                    decoration: const InputDecoration(
                      labelText: "First Name",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Last Name
                  TextFormField(
                    controller: lastNameController,
                    decoration: const InputDecoration(
                      labelText: "Last Name",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Phone
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: "Phone Number",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Email
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: "Email",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Password
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Set Password',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Role Dropdown
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Select Role',
                      border: OutlineInputBorder(),
                    ),
                    value: selectedRole,
                    items: [
                      'Admin',
                      'Planner',
                      'Production Head',
                      'Dispatch Executive',
                      'QC Manager'
                    ]
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (value) {
                      setState(() => selectedRole = value);
                    },
                  ),
                  const SizedBox(height: 24),

                  // Create ID Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (passwordController.text.length <= 6) {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: AppColors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              title: Row(
                                children: const [
                                  Icon(Icons.error, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text(
                                    'Error',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                              content: const Text(
                                'Password must be greater than 6 characters.',
                                style: TextStyle(color: Colors.black87),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );
                          return;
                        }
                        print('Create ID button pressed');
                        // Show loader dialog
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => Dialog(
                            backgroundColor: AppColors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  CircularProgressIndicator(),
                                  SizedBox(width: 16),
                                  Expanded(child: Text('Creating ID...')),
                                ],
                              ),
                            ),
                          ),
                        );
                        print('Building request body');
                        final dio = Dio();
                        final jobApi = JobApi(dio);
                        final body = {
                          'email': emailController.text.trim(),
                          'password': passwordController.text,
                          'role': (selectedRole ?? '').toLowerCase().replaceAll(' ', ''),
                          'firstName': firstNameController.text.trim(),
                          'lastName': lastNameController.text.trim(),
                          'phonenumber': phoneController.text.trim(),
                        };
                        print('Request body: $body');
                        try {
                          print('Calling addMember...');
                          final response = await jobApi.addMember(body);
                          print('Response: ${response.data}');
                          Navigator.of(context).pop(); // Close loader
                          if (response.data['success'] == true) {
                            final userData = response.data['data'] ?? {};
                            final userId = userData['id'] ?? '';
                            final userRole = userData['role'] ?? '';
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: AppColors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                title: Row(
                                  children: const [
                                    Icon(Icons.check_circle, color: AppColors.maincolor),
                                    SizedBox(width: 8),
                                    Text(
                                      'Success',
                                      style: TextStyle(color: AppColors.maincolor),
                                    ),
                                  ],
                                ),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Login ID created successfully!',
                                      style: TextStyle(color: Colors.black87),
                                    ),
                                    if (userId.isNotEmpty || userRole.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      if (userId.isNotEmpty)
                                        Text('ID: $userId', style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold)),
                                      if (userRole.isNotEmpty)
                                        Text('Role: $userRole', style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold)),
                                    ],
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.maincolor,
                                    ),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            );
                          } else {
                            Navigator.of(context).pop(); // Close loader if not already closed
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: AppColors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                title: Row(
                                  children: const [
                                    Icon(Icons.error, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text(
                                      'Error',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                                content: Text(
                                  response.data['message'] ?? 'Failed to create Login ID.',
                                  style: const TextStyle(color: Colors.black87),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            );
                          }
                        } catch (e) {
                          print('Error in addMember: $e');
                          Navigator.of(context).pop(); // Close loader if not already closed
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: AppColors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              title: Row(
                                children: const [
                                  Icon(Icons.error, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text(
                                    'Error',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                              content: const Text(
                                'Failed to create Login ID. Please try again.',
                                style: TextStyle(color: Colors.black87),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.maincolor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Create ID',
                        style: TextStyle(fontSize: 16, color: AppColors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // View User List Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        context.push('/user-list');
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.maincolor,
                        side: const BorderSide(color: AppColors.maincolor),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'User Details',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
