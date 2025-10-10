import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:nrc/constants/colors.dart';
import 'package:nrc/constants/strings.dart';

class FlyingSquadStepUpdate extends StatefulWidget {
  final Map<String, dynamic> step;
  final VoidCallback? onUpdate;

  const FlyingSquadStepUpdate({
    Key? key,
    required this.step,
    this.onUpdate,
  }) : super(key: key);

  @override
  State<FlyingSquadStepUpdate> createState() => _FlyingSquadStepUpdateState();
}

class _FlyingSquadStepUpdateState extends State<FlyingSquadStepUpdate> {
  final _formKey = GlobalKey<FormState>();
  final _remarksController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _remarksController.text = widget.step['remarks'] ?? '';
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _performQCUpdate() async {
    if (!_formKey.currentState!.validate()) return;

    // Check if step is in planned status
    final stepStatus = widget.step['status']?.toString().toLowerCase();
    if (stepStatus == 'planned') {
      _showErrorMessage('QC check cannot be performed for planned steps. Please start the step first.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      
      final dio = Dio();
      
      // Try the QC-only endpoint first
      if (widget.step['jobPlanning']?['nrcJobNo'] != null && widget.step['stepNo'] != null) {
        try {
          final response = await dio.patch(
            '${AppStrings.baseUrl}/api/job-planning/${widget.step['jobPlanning']?['nrcJobNo']}/steps/${widget.step['stepNo']}/qc',
            data: {
              'qcCheckSignBy': 'flying-squad-user', // Will be overridden by backend
              'qcCheckAt': DateTime.now().toIso8601String(),
              'remarks': _remarksController.text.trim(),
            },
            options: Options(
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
            ),
          );

          if (response.statusCode == 200) {
            _showSuccessMessage('QC check completed successfully');
            widget.onUpdate?.call();
            Navigator.of(context).pop();
            return;
          }
        } catch (e) {
          print('QC-only endpoint failed, trying fallback: $e');
          // Check if it's a 404 error indicating planned step
          if (e is DioException && e.response?.statusCode == 404) {
            final errorMsg = e.response?.data?['error']?.toString() ?? '';
            if (errorMsg.contains('not found') || errorMsg.contains('planned')) {
              _showErrorMessage('QC check cannot be performed for planned steps. Please start the step first.');
              setState(() { _isLoading = false; });
              return;
            }
          }
        }
      }

      // Fallback to original endpoint
      final response = await dio.post(
        '${AppStrings.baseUrl}/flying-squad/qc-check',
        data: {
          'stepId': widget.step['id'],
          'remarks': _remarksController.text.trim(),
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        _showSuccessMessage('QC check completed successfully');
        widget.onUpdate?.call();
        Navigator.of(context).pop();
      } else {
        _showErrorMessage('Failed to perform QC check');
      }
    } catch (e) {
      print('Error performing QC check: $e');
      
      // Handle 404 errors for planned steps with user-friendly message
      if (e is DioException && e.response?.statusCode == 404) {
        final errorMsg = e.response?.data?['error']?.toString() ?? '';
        if (errorMsg.contains('not found') || errorMsg.contains('planned')) {
          _showErrorMessage('QC check cannot be performed for planned steps. Please start the step first.');
        } else {
          _showErrorMessage('Step not found or not ready for QC check');
        }
      } else if (e is DioException && e.response?.statusCode == 400) {
        // Handle 400 Bad Request errors
        final errorMsg = e.response?.data?['error']?.toString() ?? 'Invalid request';
        _showErrorMessage(errorMsg);
      } else if (e is DioException) {
        // Handle other Dio errors
        final errorMsg = e.response?.data?['error']?.toString() ?? e.message ?? 'Unknown error';
        _showErrorMessage(errorMsg);
      } else {
        _showErrorMessage('Error performing QC check: ${e.toString()}');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flying Squad - QC Update'),
        backgroundColor: AppColors.maincolor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step Information Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Step Information',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow('Step Name', widget.step['stepName'] ?? 'N/A'),
                      _buildInfoRow('Job Number', widget.step['jobPlanning']?['nrcJobNo'] ?? 'N/A'),
                      _buildInfoRow('Step Number', widget.step['stepNo']?.toString() ?? 'N/A'),
                      _buildInfoRow('Status', widget.step['status'] ?? 'N/A'),
                      if (widget.step['machineDetails'] != null && widget.step['machineDetails'].isNotEmpty)
                        _buildInfoRow('Machine', widget.step['machineDetails'][0]['machineCode'] ?? 'N/A'),
                      _buildInfoRow('QC Status', _getQCStatus()),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // QC Update Section
              Text(
                'QC Update',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              // Remarks Field
              TextFormField(
                controller: _remarksController,
                decoration: const InputDecoration(
                  labelText: 'QC Remarks',
                  hintText: 'Enter QC check remarks...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter QC remarks';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              
              // Warning Message
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'As Flying Squad, you can only update QC-related fields. Other step details cannot be modified.',
                        style: TextStyle(color: Colors.orange.shade700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _performQCUpdate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.maincolor,
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Complete QC Check'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _getQCStatus() {
    final stepDetail = _getStepDetail();
    if (stepDetail != null && stepDetail['qcCheckSignBy'] != null && stepDetail['qcCheckAt'] != null) {
      return 'Completed';
    }
    return 'Pending';
  }

  Map<String, dynamic>? _getStepDetail() {
    // Get the step-specific detail based on step name
    final stepName = widget.step['stepName']?.toString().toLowerCase() ?? '';
    
    if (stepName.contains('paper') && widget.step['paperStore'] != null) {
      return widget.step['paperStore'];
    } else if (stepName.contains('printing') && widget.step['printingDetails'] != null) {
      return widget.step['printingDetails'];
    } else if (stepName.contains('corrugation') && widget.step['corrugation'] != null) {
      return widget.step['corrugation'];
    } else if (stepName.contains('flute') && widget.step['flutelam'] != null) {
      return widget.step['flutelam'];
    } else if (stepName.contains('punching') && widget.step['punching'] != null) {
      return widget.step['punching'];
    } else if (stepName.contains('flap') && widget.step['sideFlapPasting'] != null) {
      return widget.step['sideFlapPasting'];
    } else if (stepName.contains('quality') && widget.step['qualityDept'] != null) {
      return widget.step['qualityDept'];
    } else if (stepName.contains('dispatch') && widget.step['dispatchProcess'] != null) {
      return widget.step['dispatchProcess'];
    }
    
    return null;
  }
}
