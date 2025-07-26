import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nrc/constants/colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../routes/UserRoleManager.dart';
import 'package:nrc/core/services/auth_service.dart';
import 'package:nrc/data/repositories/auth_repository.dart';
import 'package:dio/dio.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _empIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final UserRoleManager userRoleManager = UserRoleManager();
  final AuthRepository _authRepository = AuthRepository(AuthService());

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    print('LoginScreen initialized');
  }

  void _performLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() { _isLoading = true; });
      // Set role as constant 'Admin'
      await userRoleManager.setUserRole('Admin');

      bool success = await _authRepository.login(
        id: _empIdController.text,
        password: _passwordController.text,
      );

      setState(() { _isLoading = false; });

      if (success) {
        _empIdController.clear();
        _passwordController.clear();
        context.pushReplacement('/home');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed. Please check your credentials.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF2F4F7),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
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
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
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