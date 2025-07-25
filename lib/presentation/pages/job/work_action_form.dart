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
      // Get current step status from database
      final response = await _job.getJobPlanningStepsByNrcJobNo(widget.jobNumber!);

      // Find the current step in the response
      if (response?['success'] == true && response?['data'] != null) {
        final stepData = response?['data'];
        if (stepData['stepNo'] == widget.stepNo) {
          setState(() {
            _status = stepData['status'] ?? 'pending';
            if (stepData['startDate'] != null) {
              _startTime = DateTime.parse(stepData['startDate']);
            }
            if (stepData['endDate'] != null) {
              _endTime = DateTime.parse(stepData['endDate']);
            }
          });
        }
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
      // Call API to update job planning step status to 'start' with startDate
      await widget.apiService!.updateJobPlanningStepComplete(
          widget.jobNumber!,
          widget.stepNo!,
          "start"
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
      // Call API to update job planning step with end time
      await widget.apiService!.updateJobPlanningStepComplete(
          widget.jobNumber!,
          widget.stepNo!,
          "stop"
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

  // Check if Start button should be enabled
  bool _isStartEnabled() {
    return !_isLoading && (_status == 'pending' || _status == 'paused');
  }

  // Check if Pause button should be enabled
  bool _isPauseEnabled() {
    return !_isLoading && _status == 'start';
  }

  // Check if Stop button should be enabled
  bool _isStopEnabled() {
    return !_isLoading && _status == 'start';
  }

  // Check if Complete button should be enabled
  bool _isCompleteEnabled() {
    return !_isLoading && _status == 'stopped';
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
                  child: TextFormField(
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
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter Qty Sheet';
                      }
                      return null;
                    },
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
                        if (_endTime != null)
                          Text(
                            'Ended: ${_endTime!.toString().substring(0, 19)}',
                            style: const TextStyle(fontSize: 12, color: Colors.black87),
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