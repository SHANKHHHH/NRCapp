import 'package:flutter/material.dart';
import '../../../constants/colors.dart';
import '../../../data/models/job_step_models.dart';


class WorkForm extends StatefulWidget {
  final String title;
  final String description;
  final Map<String, String> initialValues;
  final List<String> fieldNames;
  final bool hasData;
  final Function(Map<String, String>) onSubmit;
  final Function(Map<String, String>) onComplete;

  const WorkForm({
    Key? key,
    required this.title,
    required this.description,
    required this.initialValues,
    required this.fieldNames,
    required this.hasData,
    required this.onSubmit,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<WorkForm> createState() => _WorkFormState();
}

class _WorkFormState extends State<WorkForm> {
  final _formKey = GlobalKey<FormState>();
  late List<TextEditingController> _controllers;
  String _status = 'pending';

  @override
  void initState() {
    super.initState();
    _controllers = widget.fieldNames
        .map((field) => TextEditingController(text: widget.initialValues[field]))
        .toList();
    // Restore status if present
    if (widget.initialValues['Status'] != null) {
      _status = widget.initialValues['Status']!;
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _handleStart() {
    setState(() => _status = 'started');
  }

  void _handlePause() {
    setState(() => _status = 'paused');
  }

  void _handleStop() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Stop'),
        content: const Text('Are you sure the job is done?'),
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
    if (confirmed == true) {
      setState(() => _status = 'stopped');
    }
  }

  Color _statusColor() {
    switch (_status) {
      case 'started':
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
      case 'started':
        return 'Started';
      case 'paused':
        return 'Paused';
      case 'stopped':
        return 'Stopped';
      default:
        return 'Pending';
    }
  }

  void _handleSubmit() {
    if (_formKey.currentState!.validate()) {
      final formData = <String, String>{};
      for (int i = 0; i < _controllers.length; i++) {
        formData[widget.fieldNames[i]] = _controllers[i].text;
      }
      formData['Status'] = _status;
      widget.onSubmit(formData);
      Navigator.pop(context);
    }
  }

  void _handleComplete() {
    if (_formKey.currentState!.validate()) {
      final formData = <String, String>{};
      for (int i = 0; i < _controllers.length; i++) {
        formData[widget.fieldNames[i]] = _controllers[i].text;
      }
      formData['Status'] = _status;
      widget.onComplete(formData);
    }
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
                const SizedBox(height: 16),
                ...List.generate(widget.fieldNames.length, (index) {
                  return _buildFormField(widget.fieldNames[index], _controllers[index]);
                }),
              ],
            ),
          ),
        ),
      ),
      actions: [
        Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // First row with Cancel and Save
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[600],
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.maincolor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _handleSubmit,
                      child: const Text('Save Details'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Second row with Complete Work button (full width)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 2,
                  ),
                  onPressed: _handleComplete,
                  child: Row(
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
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFormField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
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
            return 'Please enter $label';
          }
          return null;
        },
      ),
    );
  }
}