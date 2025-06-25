import 'package:flutter/material.dart';

import '../../../constants/colors.dart';

class UserListPage extends StatefulWidget {
  const UserListPage({super.key});

  @override
  _UserListPageState createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  List<Map<String, String>> users = [
    {
      'firstName': 'John',
      'lastName': 'Doe',
      'empId': 'EMP001',
      'phone': '+91 9876543210',
      'email': 'john.doe@example.com',
      'role': 'Admin',
    },
    {
      'firstName': 'Jane',
      'lastName': 'Smith',
      'empId': 'EMP002',
      'phone': '+91 9123456789',
      'email': 'jane.smith@example.com',
      'role': 'Planner',
    },
  ];

  void _deleteUser(int index) {
    setState(() {
      users.removeAt(index);
    });
  }

  void _editUser(int index) {
    final user = users[index];
    final firstNameController = TextEditingController(text: user['firstName']);
    final lastNameController = TextEditingController(text: user['lastName']);
    final empIdController = TextEditingController(text: user['empId']);
    final phoneController = TextEditingController(text: user['phone']);
    final emailController = TextEditingController(text: user['email']);
    String role = user['role'] ?? 'User';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.edit, color: Colors.blue),
              SizedBox(width: 8),
              Text('Edit User', style: TextStyle(color: Colors.blue)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: firstNameController,
                  decoration: const InputDecoration(
                    labelText: 'First Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lastNameController,
                  decoration: const InputDecoration(
                    labelText: 'Last Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: empIdController,
                  decoration: const InputDecoration(
                    labelText: 'Employee ID',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email ID',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                  ),
                  items: ['Admin', 'Planner', 'Production Head', 'QC Manager', 'Dispatch Executive']
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (value) => role = value!,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.blue)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                setState(() {
                  users[index] = {
                    'firstName': firstNameController.text,
                    'lastName': lastNameController.text,
                    'empId': empIdController.text,
                    'phone': phoneController.text,
                    'email': emailController.text,
                    'role': role,
                  };
                });
                Navigator.pop(context);
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
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
      body: users.isEmpty
          ? const Center(
        child: Text(
          'No Users Found',
          style: TextStyle(fontSize: 16, color: Colors.black54),
        ),
      )
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: users.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final user = users[index];
          return Card(
            color: AppColors.white,
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              title: Text(
                '${user['firstName']} ${user['lastName']} - ${user['empId']}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              subtitle: Text(
                '${user['email']}\n${user['phone']} • ${user['role']}',
                style: const TextStyle(color: Colors.black54),
              ),
              isThreeLine: true,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: AppColors.maincolor),
                    onPressed: () => _editUser(index),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: AppColors.red),
                    onPressed: () => _deleteUser(index),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
