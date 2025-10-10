import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nrc/constants/colors.dart';
import 'package:nrc/constants/strings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../routes/UserRoleManager.dart';
import 'package:nrc/core/services/auth_service.dart';
import 'package:nrc/data/repositories/auth_repository.dart';
import 'package:dio/dio.dart';
import 'dart:convert';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final UserRoleManager userRoleManager = UserRoleManager();
  final AuthRepository _authRepository = AuthRepository(AuthService());

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    print('LoginScreen initialized');
    _checkExistingSession();
  }

  Future<void> _clearAllCaches() async {
    try {
      print('🔍 [LoginScreen] Clearing all caches...');
      final prefs = await SharedPreferences.getInstance();
      
      // Clear all data caches
      await prefs.remove('cached_job_plannings');
      await prefs.remove('cached_jobs');
      await prefs.remove('cached_machines');
      await prefs.remove('cached_users');
      await prefs.remove('cached_dashboard');
      await prefs.remove('cached_purchase_orders');
      await prefs.remove('cached_activity_logs');
      await prefs.remove('cached_status_overview');
      
      print('🔍 [LoginScreen] All caches cleared');
    } catch (e) {
      print('❌ [LoginScreen] Error clearing caches: $e');
    }
  }


  void _checkExistingSession() async {
    setState(() { _isLoading = true; });
    String? userId = await _authRepository.getUserId();
    String? accessToken = await _authRepository.getAccessToken();
    print('Checking existing session - userId: $userId, accessToken: ${accessToken != null ? 'present' : 'null'}');
    
    if (userId != null && accessToken != null) {
      final userData = await _authRepository.checkUserValidAndGetData(userId, accessToken);
      print('User data from session check: $userData');
      
      // The auth repository should have already saved the roles to SharedPreferences
      // Just reload them using UserRoleManager
      await userRoleManager.loadUserRole();
      final roles = userRoleManager.userRoles;
      print('Session check: Loaded roles from UserRoleManager: $roles');
      
      if (roles.isNotEmpty) {
        setState(() { _isLoading = false; });
        print('Session valid, navigating to /home');
        if (mounted) {
          context.pushReplacement('/home');
        } else {
          print('Widget not mounted during session check');
        }
        return;
      }
    }
    print('No valid session found');
    setState(() { _isLoading = false; });
  }

  void _performLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() { _isLoading = true; });
      // Remove hardcoded role setting
      // await userRoleManager.setUserRole('admin');

      try {
        print('🔐 [LoginScreen] Starting login process...');
        print('🔐 [LoginScreen] Email: ${_emailController.text}');
        print('🔐 [LoginScreen] Password: ${_passwordController.text}');
        print('🔐 [LoginScreen] Backend URL: ${AppStrings.baseUrl}');
        
        bool success = await _authRepository.login(
          email: _emailController.text,
          password: _passwordController.text,
        );
        print('🔐 [LoginScreen] Login result: $success');

      // Save role after login if present
      if (success) {
        // Explicitly refresh and persist fresh role details after login
        final userId = await _authRepository.getUserId();
        final accessToken = await _authRepository.getAccessToken();
        if (userId != null && accessToken != null) {
          final userData = await _authRepository.checkUserValidAndGetData(userId, accessToken);
          print('LoginPage: User data received: $userData');
          
          // The auth repository should have already saved the roles to SharedPreferences
          // Just reload them using UserRoleManager
          await userRoleManager.loadUserRole();
          final roles = userRoleManager.userRoles;
          print('LoginPage: Loaded roles from UserRoleManager: $roles');
          
          if (roles.isEmpty) {
            print('LoginPage: No roles found, trying fallback');
            // Fallback to stored role if backend did not return role
            final storedRole = await _authRepository.getUserRole();
            if (storedRole != null) {
              await userRoleManager.setUserRole(storedRole);
              print('LoginPage: Set fallback role: $storedRole');
            }
          }
        }
      }

      setState(() { _isLoading = false; });

      if (success) {
        _emailController.clear();
        _passwordController.clear();
        
        // Clear all caches to prevent cross-user contamination
        await _clearAllCaches();
        
        print('Login successful, navigating to /home');
        if (mounted) {
          context.pushReplacement('/home');
        } else {
          print('Widget not mounted, cannot navigate');
        }
      } else {
        print('Login failed');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed. Please check your credentials.')),
        );
      }
      } catch (e) {
        print('❌ [LoginScreen] Login error: $e');
        setState(() { _isLoading = false; });
        
        String errorMessage = 'Login failed. Please try again.';
        if (e is DioException) {
          switch (e.type) {
            case DioExceptionType.connectionTimeout:
              errorMessage = 'Connection timeout. Please check your internet connection.';
              break;
            case DioExceptionType.receiveTimeout:
              errorMessage = 'Server response timeout. Please try again.';
              break;
            case DioExceptionType.connectionError:
              errorMessage = 'Cannot connect to server. Please check your internet connection.';
              break;
            case DioExceptionType.badResponse:
              if (e.response?.statusCode == 401) {
                errorMessage = 'Invalid email or password.';
              } else if (e.response?.statusCode == 500) {
                errorMessage = 'Server error. Please try again later.';
              } else {
                errorMessage = 'Server error (${e.response?.statusCode}). Please try again.';
              }
              break;
            default:
              errorMessage = 'Network error. Please check your connection.';
          }
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
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
                          // Email
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            // Add test credentials for quick testing
                            onChanged: (value) {
                              if (value == 'admin') {
                                _emailController.text = 'admin@nrcontainers.com';
                                _passwordController.text = 'admin123';
                              }
                            },
                            decoration: InputDecoration(
                              hintText: 'Email',
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your Email';
                              }
                              final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                              if (!emailRegex.hasMatch(value)) {
                                return 'Please enter a valid Email';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),

                          // Password
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              hintText: 'Password',
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}