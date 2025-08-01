import 'package:flutter/material.dart';
import 'package:nrc/data/datasources/job_api.dart';
import '../../../constants/colors.dart';
import '../process/JobApiService.dart';

class WorkActionForm extends StatefulWidget {
  final String title;
  final String description;
  final String? initialQty;
  final bool hasData;
  final void Function(Map<String, String> formData) onComplete;
  final void Function()? onStart;
  final void Function()? onPause;
  final void Function()? onStop;
  final String? jobNumber; // Add jobNumber parameter
  final int? stepNo; // Add stepNo parameter
  final JobApiService? apiService; // Add apiService parameter
  final int? expectedQuantity; // Add expectedQuantity parameter for validation

  const WorkActionForm({
    super.key,
    required this.title,
    required this.description,
    this.initialQty,
    required this.onComplete,
    this.onStart,
    this.onPause,
    this.onStop,
    this.hasData = false,
    this.jobNumber, // Add jobNumber
    this.stepNo, // Add stepNo
    this.apiService, // Add apiService
    this.expectedQuantity, // Add expectedQuantity
  });

  @override
  State<WorkActionForm> createState() => _WorkActionFormState();
}

class _WorkActionFormState extends State<WorkActionForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _qtyController = TextEditingController();
  String _status = 'pending';
  DateTime? _startTime;
  DateTime? _endTime;
  bool _isLoading = false;
  late JobApi _job;

  /// Helper function to format date in the correct format with milliseconds
  /// This preserves the local time but formats it as UTC for database storage
  String _formatDateWithMilliseconds() {
    final now = DateTime.now();
    // Get the current local time components
    final year = now.year.toString().padLeft(4, '0');
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final second = now.second.toString().padLeft(2, '0');
    final millisecond = now.millisecond.toString().padLeft(3, '0');
    
    // Format as if it were UTC time (this preserves the local time values)
    return '${year}-${month}-${day}T${hour}:${minute}:${second}.${millisecond}Z';
  }

  @override
  void initState() {
    super.initState();
    _qtyController.text = widget.initialQty ?? '';
    // Load current status from database if API service is available
    _loadCurrentStatus();
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  // Load current status from database
  void _loadCurrentStatus() async {
    if (widget.jobNumber == null || widget.stepNo == null || widget.apiService == null) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Get current step details from backend
      final stepDetails = await widget.apiService!.getJobPlanningStepDetails(widget.jobNumber!, widget.stepNo!);
      if (stepDetails != null) {
        final startDate = stepDetails['startDate'];
        final endDate = stepDetails['endDate'];
        final status = stepDetails['status'];
        setState(() {
          if (status == 'stop' || endDate != null) {
            // Work is completed - all disabled, show Ended Time
            _status = 'stopped';
            _startTime = DateTime.tryParse(startDate);
            _endTime = DateTime.tryParse(endDate);
            _isStartDisabled = true;
            _isPauseDisabled = true;
            _isStopDisabled = true;
          } else if (startDate != null && status == 'start') {
            // Work is started but not stopped yet - user needs to click stop
            _status = 'start';
            _startTime = DateTime.tryParse(startDate);
            _isStartDisabled = true;
            _isPauseDisabled = false;
            _isStopDisabled = false; // Stop button should be enabled
          } else {
            // No work started yet
            _isStartDisabled = false;
            _isPauseDisabled = false;
            _isStopDisabled = false;
          }
        });
      }
    } catch (e) {
      print('Error loading current status: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _handleStart() async {
    if (widget.jobNumber == null || widget.stepNo == null || widget.apiService == null) {
      // Fallback to original behavior if API parameters not provided
      if (_startTime == null) {
        _startTime = DateTime.now();
      }
      setState(() => _status = 'start');
      widget.onStart?.call();
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Only update startDate using JobApiService generic method
      await widget.apiService!.updateJobPlanningStepFields(
        widget.jobNumber!,
        widget.stepNo!,
        {'startDate': _formatDateWithMilliseconds()},
      );

      // Set local start time
      _startTime = DateTime.now();

      setState(() {
        _status = 'start';
        _isLoading = false;
      });

      widget.onStart?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.title} work started successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start work: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handlePause() {
    // Note: Pause functionality might need API integration based on your requirements
    setState(() => _status = 'paused');
    widget.onPause?.call();
  }

  void _handleStop() async {
    if (_status != 'start') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please start the task before stopping it.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Stop'),
        content: const Text('Are you sure you want to stop the work?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (widget.jobNumber == null || widget.stepNo == null || widget.apiService == null) {
      // Fallback to original behavior if API parameters not provided
      setState(() {
        _status = 'stopped';
        _endTime = DateTime.now();
      });
      widget.onStop?.call();
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Only update endDate using JobApiService generic method
      await widget.apiService!.updateJobPlanningStepFields(
        widget.jobNumber!,
        widget.stepNo!,
        {'endDate': _formatDateWithMilliseconds()},
      );

      setState(() {
        _status = 'stopped';
        _endTime = DateTime.now();
        _isLoading = false;
      });

      widget.onStop?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.title} work stopped successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to stop work: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleComplete() async {
    if (_formKey.currentState!.validate()) {
      if (_status != 'stopped') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please start and stop the task before completing.')),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        final formData = <String, String>{
          'Qty Sheet': _qtyController.text,
          'Status': _status,
          'Start Time': _startTime?.toString() ?? '',
          'End Time': _endTime?.toString() ?? DateTime.now().toString(),
        };

        // Debug print to see what's being sent
        print('WorkActionForm - Form Data being sent:');
        print('Qty Sheet: ${_qtyController.text}');
        print('Full formData: $formData');

        // Call the onComplete callback which will handle the specific step post operation
        widget.onComplete(formData);

        setState(() => _isLoading = false);
      } catch (e) {
        print("this is the issue");
        setState(() => _isLoading = false);

        if (mounted) {
          print(e);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to complete work: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Color _statusColor() {
    switch (_status) {
      case 'start':
        return Colors.orange;
      case 'paused':
        return Colors.blue;
      case 'stopped':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _statusText() {
    switch (_status) {
      case 'start':
        return 'Started';
      case 'paused':
        return 'Paused';
      case 'stopped':
        return 'Stopped';
      default:
        return 'Pending';
    }
  }

  // Add these fields to the state
  bool _isStartDisabled = false;
  bool _isPauseDisabled = false;
  bool _isStopDisabled = false;

  // Update button enabled checks
  bool _isStartEnabled() {
    return !_isLoading && !_isStartDisabled && (_status == 'pending' || _status == 'paused');
  }
  bool _isPauseEnabled() {
    return !_isLoading && !_isPauseDisabled && _status == 'start';
  }
  bool _isStopEnabled() {
    return !_isLoading && !_isStopDisabled && _status == 'start';
  }

  // Check if Complete button should be enabled
  bool _isCompleteEnabled() {
    return !_isLoading && _status == 'stopped';
  }

  // Helper method to get valid quantity range
  String _getValidQuantityRange() {
    if (widget.expectedQuantity == null || widget.expectedQuantity! <= 0) {
      return '';
    }
    
    final expectedQty = widget.expectedQuantity!;
    final tolerance500 = 500;
    final tolerancePercent = (expectedQty * 0.125).round();
    final tolerance = tolerance500 > tolerancePercent ? tolerance500 : tolerancePercent;
    
    final minAllowed = expectedQty - tolerance;
    final maxAllowed = expectedQty + tolerance;
    
    return '$minAllowed - $maxAllowed';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.work_outline, color: AppColors.maincolor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    color: AppColors.maincolor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
      backgroundColor: Colors.white,
      content: Container(
        width: double.maxFinite,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.5,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _qtyController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Qty Sheet',
                          labelStyle: TextStyle(color: AppColors.maincolor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppColors.maincolor, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                          hintText: widget.expectedQuantity != null 
                              ? 'Expected: ${widget.expectedQuantity} (Valid: ${_getValidQuantityRange()})'
                              : 'Enter quantity',
                          hintStyle: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter Qty Sheet';
                          }
                          
                          // Parse the entered quantity
                          final enteredQty = int.tryParse(value);
                          if (enteredQty == null) {
                            return 'Please enter a valid number';
                          }
                          
                          // If expected quantity is provided, validate against it
                          if (widget.expectedQuantity != null && widget.expectedQuantity! > 0) {
                            final expectedQty = widget.expectedQuantity!;
                            
                            // Calculate tolerance: ±500 or ±12.5%, whichever is greater
                            final tolerance500 = 500;
                            final tolerancePercent = (expectedQty * 0.125).round();
                            final tolerance = tolerance500 > tolerancePercent ? tolerance500 : tolerancePercent;
                            
                            final minAllowed = expectedQty - tolerance;
                            final maxAllowed = expectedQty + tolerance;
                            
                            // Debug print
                            print('Quantity Validation:');
                            print('  Expected: $expectedQty');
                            print('  Entered: $enteredQty');
                            print('  Tolerance: $tolerance (500 vs ${tolerancePercent})');
                            print('  Min Allowed: $minAllowed');
                            print('  Max Allowed: $maxAllowed');
                            
                            if (enteredQty < minAllowed || enteredQty > maxAllowed) {
                              return 'Enter valid quantity Nearby $expectedQty';
                            }
                          }
                          
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isStartEnabled() ? Colors.orange : Colors.grey,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _isStartEnabled() ? _handleStart : null,
                        child: _isLoading && _status == 'pending'
                            ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                            : const Text('Start'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isPauseEnabled() ? Colors.blue : Colors.grey,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _isPauseEnabled() ? _handlePause : null,
                        child: const Text('Pause'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isStopEnabled() ? Colors.red : Colors.grey,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _isStopEnabled() ? _handleStop : null,
                        child: _isLoading && _status == 'start'
                            ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                            : const Text('Stop'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _statusColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: _statusColor(), size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Status: ${_statusText()}',
                            style: TextStyle(
                              fontSize: 13,
                              color: _statusColor(),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Show timing information if available
                if (_startTime != null || _endTime != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_startTime != null)
                          Text(
                            'Started: ${_startTime!.toString().substring(0, 19)}',
                            style: const TextStyle(fontSize: 12, color: Colors.black87),
                          ),
                        if (_endTime != null && _status == 'stopped')
                          Text(
                            'Ended: ${_endTime!.toString().substring(0, 19)}',
                            style: const TextStyle(fontSize: 12, color: Colors.red),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isCompleteEnabled() ? Colors.green : Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 2,
                ),
                onPressed: _isCompleteEnabled() ? _handleComplete : null,
                child: _isLoading && _status == 'stopped'
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Complete Work',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _isLoading ? null : () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}