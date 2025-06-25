import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nrc/constants/colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../routes/UserRoleManager.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _empIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _selectedRole;
  final List<String> _roles = [
    'Admin',
    'Planner',
    'Production Head',
    'Dispatch Executive',
    'QC Manager',
  ];

  final UserRoleManager userRoleManager = UserRoleManager();

  @override
  void initState() {
    super.initState();
    print('LoginScreen initialized');
    print('Initial selectedRole: $_selectedRole');
  }

  void _performLogin() async {
    if (_formKey.currentState!.validate()) {
      print('Employee ID: ${_empIdController.text}');
      print('Password: ${_passwordController.text}');
      print('Role: $_selectedRole');

      if (_selectedRole != null) {
        print('Selected Role: $_selectedRole');

        // Save the selected role using UserRoleManager
        await userRoleManager.setUserRole(_selectedRole!);

        // Clear the form after successful validation
        _empIdController.clear();
        _passwordController.clear();

        // Navigate to home
        context.pushReplacement('/home');
        print('Navigating to home with role: ${userRoleManager.userRole}'); // Debug print
      } else {
        print('No role selected.'); // Debug print
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please select a role.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF2F4F7),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 150, 24, 24),
          child: Column(
            children: [
              // Logo
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(38),
                  image: DecorationImage(
                    image: AssetImage('assets/images/nrcLogo.jpg'),
                  ),
                ),
              ),

              SizedBox(height: 40),

              // Form Card
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 15,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Employee ID
                      TextFormField(
                        controller: _empIdController,
                        decoration: InputDecoration(
                          hintText: 'Employee ID',
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your Employee ID';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),

                      // Password
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: 'Password',
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your Password';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),

                      // Role Dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedRole,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        hint: Text('Select your Role'),
                        items: _roles.map((String role) {
                          return DropdownMenuItem<String>(
                            value: role,
                            child: Text(role),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedRole = value;
                            print('Role selected: $_selectedRole'); // Debug print
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select your Role';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 24),

                      // Continue Button
                      ElevatedButton(
                        onPressed: _performLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.maincolor,
                          minimumSize: Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Login',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _empIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}