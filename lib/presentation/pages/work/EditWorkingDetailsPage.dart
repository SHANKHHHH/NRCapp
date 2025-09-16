import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../constants/colors.dart';
import 'package:dio/dio.dart';
import '../../../constants/strings.dart';
import '../../../data/datasources/job_api.dart';
import '../../../data/models/Machine.dart';
import '../../../data/models/WorkStep.dart';
import '../../../data/models/WorkStepAssignment.dart';
import '../../../data/models/WorkStepData.dart';
import '../../../data/models/job_step_models.dart';
import '../process/JobApiService.dart';
import 'package:go_router/go_router.dart';

class EditWorkingDetailsPage extends StatefulWidget {
  const EditWorkingDetailsPage({Key? key}) : super(key: key);

  @override
  State<EditWorkingDetailsPage> createState() => _EditWorkingDetailsPageState();
}

class _EditWorkingDetailsPageState extends State<EditWorkingDetailsPage> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _jobPlannings = [];
  String? _error;
  Set<int> _expandedCards = {}; // Track which cards are expanded
  List<Machine> _machines = [];
  Map<String, Map<String, dynamic>> _stepDetails = {}; // Cache for step details
  
  // JobApi instance
  late JobApi _jobApi;

  @override
  void initState() {
    super.initState();
    _initializeApiAndFetch();
  }

  void _initializeApiAndFetch() {
    final dio = Dio();
    dio.options.baseUrl = '${AppStrings.baseUrl}/api';
    _jobApi = JobApi(dio);
    _fetchJobPlannings();
    _fetchMachines();
  }

  Future<void> _fetchMachines() async {
    try {
      final machines = await _jobApi.getMachines();
      setState(() {
        _machines = machines;
      });
    } catch (e) {
      print('Failed to load machines: $e');
    }
  }

  Future<void> _fetchJobPlannings() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final plannings = await _jobApi.getAllJobPlannings();
      
      if (!mounted) return;
      
      // Filter to show only jobs with steps that have status "stop"
      final filteredPlannings = plannings.where((planning) {
        final steps = planning['steps'] as List<dynamic>? ?? [];
        return steps.any((step) => step['status']?.toString().toLowerCase() == 'stop');
      }).toList();
      
      setState(() {
        _jobPlannings = filteredPlannings;
        _isLoading = false;
      });

      // Automatically load step details for stopped steps
      if (mounted) {
        await _loadStepDetailsForStoppedSteps();
      }
    } catch (e) {
      print('Error fetching job plannings: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load job plannings: $e';
          _isLoading = false;
        });
      }
    }
  }

  // Automatically load step details for all stopped steps
  Future<void> _loadStepDetailsForStoppedSteps() async {
    if (!mounted) return;
    
    for (final planning in _jobPlannings) {
      if (!mounted) return;
      
      final jobNumber = planning['nrcJobNo']?.toString() ?? '';
      final steps = planning['steps'] as List<dynamic>? ?? [];
      
      for (final step in steps) {
        if (!mounted) return;
        
        final status = step['status']?.toString().toLowerCase() ?? '';
        if (status == 'stop') {
          final stepName = step['stepName']?.toString() ?? '';
          try {
            await _fetchAndDisplayStepDetails(jobNumber, stepName, step);
          } catch (e) {
            print('Error loading step details for $stepName: $e');
          }
        }
      }
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'Not specified';
    try {
      final date = DateTime.parse(dateString);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  String _formatDateForDisplay(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'Not specified';
    try {
      final date = DateTime.parse(dateString);
      const months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  String _formatDateTimeForDisplay(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'Not specified';
    try {
      final date = DateTime.parse(dateString);
      const months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '${date.day} ${months[date.month - 1]} ${date.year} at $hour:$minute';
    } catch (e) {
      return dateString;
    }
  }

  String _formatDateForEdit(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '';
    try {
      final date = DateTime.parse(dateString);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  String _formatDateTimeForEdit(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '';
    try {
      final date = DateTime.parse(dateString);
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}T$hour:$minute';
    } catch (e) {
      return dateString;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'start':
        return Colors.green;
      case 'planned':
        return Colors.blue;
      case 'stop':
        return Colors.red;
      case 'completed':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getDemandColor(String demand) {
    switch (demand.toLowerCase()) {
      case 'high':
        return '🔴 High Priority';
      case 'medium':
        return '🟡 Medium Priority';
      case 'low':
        return '🟢 Low Priority';
      default:
        return demand;
    }
  }

  Future<void> _updateStepStatus(String jobNumber, int stepNo, String newStatus) async {
    try {
      await _jobApi.updateJobPlanningStepComplete(jobNumber, stepNo, newStatus);
      
      // Refresh the data after update
      await _fetchJobPlannings();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Step status updated to $newStatus successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update step status: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  Future<void> _updateStepStatusAndUser(String jobNumber, int stepNo, String newStatus, String user) async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('Updating step details...'),
              ],
            ),
            backgroundColor: Colors.blue,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // First update the status
      await _jobApi.updateJobPlanningStepComplete(jobNumber, stepNo, newStatus);
      
      // Then update the user assignment if provided
      if (user.isNotEmpty) {
        await _jobApi.updateJobPlanningStepFields(jobNumber, stepNo, {'user': user});
      }
      
      // Refresh the data after update
      await _fetchJobPlannings();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Step details updated successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      print('Error updating step status and user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update step details: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  void _toggleCardExpansion(int jobPlanId) {
    setState(() {
      if (_expandedCards.contains(jobPlanId)) {
        _expandedCards.remove(jobPlanId);
      } else {
        _expandedCards.add(jobPlanId);
      }
    });
  }

  // Convert step name to WorkStep
  WorkStep _getWorkStepFromStepName(String stepName) {
    switch (stepName) {
      case 'PrintingDetails':
        return WorkStepData.workSteps.firstWhere((ws) => ws.step == 'printing');
      case 'Corrugation':
        return WorkStepData.workSteps.firstWhere((ws) => ws.step == 'corrugation');
      case 'FluteLaminateBoardConversion':
        return WorkStepData.workSteps.firstWhere((ws) => ws.step == 'fluteLamination');
      case 'Punching':
        return WorkStepData.workSteps.firstWhere((ws) => ws.step == 'punching');
      case 'SideFlapPasting':
        return WorkStepData.workSteps.firstWhere((ws) => ws.step == 'flapPasting');
      default:
        return WorkStepData.workSteps.first;
    }
  }

  // Find machine by ID
  Machine? _findMachineById(String? machineId) {
    if (machineId == null) return null;
    try {
      return _machines.firstWhere((machine) => machine.id.toString() == machineId);
    } catch (e) {
      return null;
    }
  }

  // Navigate to AssignWorkSteps with pre-filled data
  void _navigateToAssignWorkSteps(Map<String, dynamic> jobPlanning, Map<String, dynamic> step) {
    print('Navigating to AssignWorkSteps with edit mode');
    print('Job Planning: $jobPlanning');
    print('Step: $step');
    
    // Create WorkStepAssignment with pre-filled data
    final workStep = _getWorkStepFromStepName(step['stepName']);
    final machineDetails = step['machineDetails'] as List<dynamic>? ?? [];
    
    Machine? selectedMachine;
    if (machineDetails.isNotEmpty) {
      final machineDetail = machineDetails.first;
      final machineId = machineDetail['machineId'];
      if (machineId != null) {
        selectedMachine = _findMachineById(machineId.toString());
      }
    }

    final assignment = WorkStepAssignment(
      workStep: workStep,
      selectedMachine: selectedMachine,
    );

    print('Created assignment: ${assignment.workStep.step}');
    print('Selected machine: ${assignment.selectedMachine?.machineCode}');

    // Navigate to AssignWorkSteps with pre-filled data
    try {
      final result = context.push('/assign-work-steps', extra: {
        'jobPlanning': jobPlanning,
        'step': step,
        'assignment': assignment,
        'isEditMode': true,
      });
      
      // If we get a result back (indicating successful update), refresh the data
      if (result == true) {
        _fetchJobPlannings();
      }
    } catch (e) {
      print('Navigation error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Navigation error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Fetch step details based on step name
  Future<Map<String, dynamic>?> _fetchStepDetails(String jobNumber, String stepName) async {
    final cacheKey = '${jobNumber}_$stepName';
    
    // Return cached data if available
    if (_stepDetails.containsKey(cacheKey)) {
      return _stepDetails[cacheKey];
    }

    try {
      Map<String, dynamic>? details;
      
      switch (stepName) {
        case 'PaperStore':
          details = await _jobApi.getPaperStoreStepByJob(jobNumber);
          break;
        case 'PrintingDetails':
          details = await _jobApi.getPrintingDetails(jobNumber);
          break;
        case 'Corrugation':
          details = await _jobApi.getCorrugationDetails(jobNumber);
          break;
        case 'FluteLaminateBoardConversion':
          details = await _jobApi.getFluteLaminationDetails(jobNumber);
          break;
        case 'Punching':
          details = await _jobApi.getPunchingDetails(jobNumber);
          break;
        case 'SideFlapPasting':
          details = await _jobApi.getFlapPastingDetails(jobNumber);
          break;
        case 'QualityDept':
          details = await _jobApi.getQCDetails(jobNumber);
          break;
        case 'DispatchProcess':
          details = await _jobApi.getDispatchDetails(jobNumber);
          break;
        default:
          print('Unknown step name: $stepName');
          return null;
      }

      // Process the details to extract the actual data
      if (details != null) {
        print('Raw details for $stepName: $details');
        
        Map<String, dynamic> processedDetails = {};
        
        // Handle different response formats
        if (details.containsKey('data')) {
          // If response has a 'data' field, extract it
          final data = details['data'];
          print('Data field found for $stepName: $data');
          
          if (data is List && data.isNotEmpty) {
            // If data is a list, take the first item
            processedDetails = Map<String, dynamic>.from(data.first);
            print('Extracted first item from list for $stepName: $processedDetails');
          } else if (data is Map) {
            // If data is a map, use it directly
            processedDetails = Map<String, dynamic>.from(data);
            print('Extracted map data for $stepName: $processedDetails');
          }
        } else {
          // If no 'data' field, use the details directly
          processedDetails = Map<String, dynamic>.from(details);
          print('Using details directly for $stepName: $processedDetails');
        }
        
        // Cache the processed result
        _stepDetails[cacheKey] = processedDetails;
        return processedDetails;
      }
      
      return null;
    } catch (e) {
      print('Error fetching step details for $stepName: $e');
      return null;
    }
  }

  // Show step details dialog
  void _showStepDetailsDialog(String jobNumber, String stepName, Map<String, dynamic> step) async {
    final details = await _fetchStepDetails(jobNumber, stepName);
    
    if (details == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No details available for $stepName'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('$stepName Details'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStepDetailsContent(details, stepName),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _showEditStepDetailsDialog(jobNumber, stepName, details);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.maincolor,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Edit Details'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // Fetch and display step details for stopped steps
  Future<void> _fetchAndDisplayStepDetails(String jobNumber, String stepName, Map<String, dynamic> step) async {
    if (!mounted) return;
    
    try {
      final details = await _fetchStepDetails(jobNumber, stepName);
      
      if (!mounted) return;
      
      if (details == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No details available for $stepName'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Show the details directly in the step card
      if (mounted) {
        setState(() {
          // Store the details in the step object for display
          step['fetchedDetails'] = details;
        });
      }
    } catch (e) {
      print('Error fetching and displaying step details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load details for $stepName: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Build step details content
  Widget _buildStepDetailsContent(Map<String, dynamic> details, String stepName) {
    final List<Widget> detailWidgets = [];
    
    print('Building step details content for $stepName');
    print('Details: $details');
    
    details.forEach((key, value) {
      if (value != null && value.toString().isNotEmpty) {
        String displayValue = value.toString();
        
        // Format date fields
        if (_isDateField(key)) {
          if (_isDateTimeField(key)) {
            displayValue = _formatDateTimeForDisplay(value.toString());
          } else {
            displayValue = _formatDateForDisplay(value.toString());
          }
        }
        
        detailWidgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    '${_formatFieldName(key)}:',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    displayValue,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    });

    print('Generated ${detailWidgets.length} detail widgets for $stepName');
    return Column(children: detailWidgets);
  }

  // Check if field is a date field
  bool _isDateField(String fieldName) {
    final dateFields = [
      'date', 'issuedDate', 'dispatchDate', 'createdAt', 'updatedAt',
      'startDate', 'endDate'
    ];
    return dateFields.any((field) => fieldName.toLowerCase().contains(field));
  }

  // Check if field is a datetime field
  bool _isDateTimeField(String fieldName) {
    final dateTimeFields = [
      'issuedDate', 'dispatchDate', 'createdAt', 'updatedAt',
      'startDate', 'endDate'
    ];
    return dateTimeFields.any((field) => fieldName.toLowerCase().contains(field));
  }

  // Format field names for display
  String _formatFieldName(String fieldName) {
    // Handle common field name mappings
    final fieldMappings = {
      'jobNrcJobNo': 'Job Number',
      'jobStepId': 'Job Step ID',
      'oprName': 'Operator Name',
      'machineNo': 'Machine Number',
      'qcCheckSignBy': 'QC Check Sign By',
      'reasonForRejection': 'Reason for Rejection',
      'rejectedQty': 'Rejected Quantity',
      'balanceQty': 'Balance Quantity',
      'dispatchNo': 'Dispatch Number',
      'extraMargin': 'Extra Margin',
      'sheetSize': 'Sheet Size',
      'issuedDate': 'Issued Date',
      'dispatchDate': 'Dispatch Date',
      'createdAt': 'Created At',
      'updatedAt': 'Updated At',
      'startDate': 'Start Date',
      'endDate': 'End Date',
      'gsm1': 'GSM 1',
      'gsm2': 'GSM 2',
      'noUps': 'No Ups',
    };

    // Check if we have a direct mapping
    if (fieldMappings.containsKey(fieldName)) {
      return fieldMappings[fieldName]!;
    }

    // For other fields, use regex to add spaces before uppercase letters
    String formatted = fieldName.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match.group(1)} ${match.group(2)}'
    );

    // Capitalize first letter of each word
    return formatted.split(' ')
        .map((word) => word.isNotEmpty ? word[0].toUpperCase() + word.substring(1).toLowerCase() : '')
        .join(' ')
        .trim();
  }

  // Check if field is a numeric field
  bool _isNumericField(String fieldName) {
    final numericFields = [
      'id', 'jobStepId', 'quantity', 'available', 'wastage', 'rejectedQty', 
      'balanceQty', 'gsm1', 'gsm2', 'mill', 'extraMargin', 'noUps'
    ];
    return numericFields.any((field) => fieldName.toLowerCase().contains(field));
  }

  // Check if field should be an integer
  bool _isIntegerField(String fieldName) {
    final integerFields = [
      'id', 'jobStepId', 'quantity', 'available', 'wastage', 'rejectedQty', 
      'balanceQty', 'mill', 'extraMargin', 'noUps'
    ];
    return integerFields.any((field) => fieldName.toLowerCase().contains(field));
  }

  // Special handling for ID fields to ensure they are always integers
  bool _isIdField(String fieldName) {
    return fieldName.toLowerCase() == 'id' || fieldName.toLowerCase() == 'jobstepid';
  }

  // Get step number from step name
  int _getStepNumberFromStepName(String stepName) {
    switch (stepName) {
      case 'PaperStore':
        return 1;
      case 'PrintingDetails':
        return 2;
      case 'Corrugation':
        return 3;
      case 'FluteLaminateBoardConversion':
        return 4;
      case 'Punching':
        return 5;
      case 'SideFlapPasting':
        return 6;
      case 'QualityDept':
        return 7;
      case 'DispatchProcess':
        return 8;
      default:
        return 1;
    }
  }

  // Map database field names to form field names expected by JobApiService
  Map<String, String> _mapDatabaseFieldsToFormFields(String stepName, Map<String, dynamic> updatedDetails) {
    final Map<String, String> formData = {};
    
    switch (stepName) {
      case 'PrintingDetails':
        // Map database fields to form fields for Printing
        formData['Qty Sheet'] = updatedDetails['quantity']?.toString() ?? '';
        formData['Operator Name'] = updatedDetails['oprName']?.toString() ?? '';
        formData['Wastage'] = updatedDetails['wastage']?.toString() ?? '';
        formData['Machine'] = updatedDetails['machine']?.toString() ?? '';
        break;
        
      case 'Corrugation':
        // Map database fields to form fields for Corrugation
        formData['Qty Sheet'] = updatedDetails['quantity']?.toString() ?? '';
        formData['Shift'] = updatedDetails['shift']?.toString() ?? '';
        formData['Operator Name'] = updatedDetails['oprName']?.toString() ?? '';
        formData['Machine No'] = updatedDetails['machineNo']?.toString() ?? '';
        formData['Size'] = updatedDetails['size']?.toString() ?? '';
        formData['GSM 1'] = updatedDetails['gsm1']?.toString() ?? '';
        formData['GSM 2'] = updatedDetails['gsm2']?.toString() ?? '';
        formData['Flute Type'] = updatedDetails['flute']?.toString() ?? '';
        formData['Remarks'] = updatedDetails['remarks']?.toString() ?? '';
        formData['QC Check Sign By'] = updatedDetails['qcCheckSignBy']?.toString() ?? '';
        break;
        
      case 'FluteLaminateBoardConversion':
        // Map database fields to form fields for Flute Lamination
        formData['Qty Sheet'] = updatedDetails['quantity']?.toString() ?? '';
        formData['Shift'] = updatedDetails['shift']?.toString() ?? '';
        formData['Operator Name'] = updatedDetails['operatorName']?.toString() ?? '';
        formData['Film Type'] = updatedDetails['film']?.toString() ?? '';
        formData['QC Sign By'] = updatedDetails['qcCheckSignBy']?.toString() ?? '';
        formData['Adhesive'] = updatedDetails['adhesive']?.toString() ?? '';
        formData['Wastage'] = updatedDetails['wastage']?.toString() ?? '';
        break;
        
      case 'Punching':
        // Map database fields to form fields for Punching
        formData['Qty Sheet'] = updatedDetails['quantity']?.toString() ?? '';
        formData['Operator Name'] = updatedDetails['operatorName']?.toString() ?? '';
        formData['Machine'] = updatedDetails['machine']?.toString() ?? '';
        formData['Die Used'] = updatedDetails['die']?.toString() ?? '';
        formData['Wastage'] = updatedDetails['wastage']?.toString() ?? '';
        formData['Remarks'] = updatedDetails['remarks']?.toString() ?? '';
        break;
        
      case 'SideFlapPasting':
        // Map database fields to form fields for Side Flap Pasting
        formData['Operator Name'] = updatedDetails['operatorName']?.toString() ?? '';
        formData['Machine No'] = updatedDetails['machineNo']?.toString() ?? '';
        formData['Adhesive'] = updatedDetails['adhesive']?.toString() ?? '';
        formData['Quantity'] = updatedDetails['quantity']?.toString() ?? '';
        formData['Wastage'] = updatedDetails['wastage']?.toString() ?? '';
        formData['Remarks'] = updatedDetails['remarks']?.toString() ?? '';
        break;
        
      case 'QualityDept':
        // Map database fields to form fields for Quality Control
        formData['Qty Sheet'] = updatedDetails['quantity']?.toString() ?? '';
        formData['Checked By'] = updatedDetails['checkedBy']?.toString() ?? '';
        formData['Reject Quantity'] = updatedDetails['rejectedQty']?.toString() ?? '';
        formData['Reason for Rejection'] = updatedDetails['reasonForRejection']?.toString() ?? '';
        formData['Remarks'] = updatedDetails['remarks']?.toString() ?? '';
        break;
        
      case 'DispatchProcess':
        // Map database fields to form fields for Dispatch
        formData['Operator Name'] = updatedDetails['operatorName']?.toString() ?? '';
        formData['Quantity'] = updatedDetails['quantity']?.toString() ?? '';
        formData['Dispatch No'] = updatedDetails['dispatchNo']?.toString() ?? '';
        formData['Balance Qty'] = updatedDetails['balanceQty']?.toString() ?? '';
        formData['Remarks'] = updatedDetails['remarks']?.toString() ?? '';
        break;
    }
    
    print('Original updatedDetails: $updatedDetails');
    print('Mapped formData: $formData');
    
    return formData;
  }

  // Show edit step details dialog
  void _showEditStepDetailsDialog(String jobNumber, String stepName, Map<String, dynamic> currentDetails) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return _EditStepDetailsDialog(
          jobNumber: jobNumber,
          stepName: stepName,
          currentDetails: currentDetails,
          onUpdate: (updatedDetails) async {
            Navigator.of(dialogContext).pop();
            await _updateStepDetails(jobNumber, stepName, updatedDetails);
          },
          onCancel: () {
            Navigator.of(dialogContext).pop();
          },
        );
      },
    );
  }

  // Update step details
  Future<void> _updateStepDetails(String jobNumber, String stepName, Map<String, dynamic> updatedDetails) async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Text('Updating $stepName details...'),
              ],
            ),
            backgroundColor: Colors.blue,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Get the step number based on step name
      int stepNo = _getStepNumberFromStepName(stepName);
      
      switch (stepName) {
        case 'PaperStore':
          // For PaperStore, use the direct API call with the updated details
          await _jobApi.putPaperStore(jobNumber, updatedDetails);
          break;
        default:
          // For other steps, we need to map the database field names to form field names
          final Map<String, String> formData = _mapDatabaseFieldsToFormFields(stepName, updatedDetails);
          print('Mapped form data for $stepName: $formData');
          
          // Use JobApiService methods which have the proper format
          final jobApiService = JobApiService(_jobApi);
          
          switch (stepName) {
            case 'PrintingDetails':
              await jobApiService.putStepDetails(StepType.printing, jobNumber, formData, stepNo);
              break;
            case 'Corrugation':
              await jobApiService.putStepDetails(StepType.corrugation, jobNumber, formData, stepNo);
              break;
            case 'FluteLaminateBoardConversion':
              await jobApiService.putStepDetails(StepType.fluteLamination, jobNumber, formData, stepNo);
              break;
            case 'Punching':
              await jobApiService.putStepDetails(StepType.punching, jobNumber, formData, stepNo);
              break;
            case 'SideFlapPasting':
              await jobApiService.putStepDetails(StepType.flapPasting, jobNumber, formData, stepNo);
              break;
            case 'QualityDept':
              await jobApiService.putStepDetails(StepType.qc, jobNumber, formData, stepNo);
              break;
            case 'DispatchProcess':
              await jobApiService.putStepDetails(StepType.dispatch, jobNumber, formData, stepNo);
              break;
          }
          break;
      }
      
      // Clear cache for this step
      final cacheKey = '${jobNumber}_$stepName';
      _stepDetails.remove(cacheKey);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$stepName details updated successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      print('Error updating step details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update $stepName details: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  void _showStatusUpdateDialog(String jobNumber, int stepNo, String currentStatus) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return _StatusUpdateDialog(
          jobNumber: jobNumber,
          stepNo: stepNo,
          currentStatus: currentStatus,
          onUpdate: (selectedStatus, selectedUser) {
            Navigator.of(dialogContext).pop();
            _updateStepStatusAndUser(jobNumber, stepNo, selectedStatus, selectedUser);
          },
          onCancel: () {
            Navigator.of(dialogContext).pop();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Edit Working Details',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),
        backgroundColor: AppColors.maincolor,
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: AppColors.maincolor,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      body: Builder(
        builder: (context) {
          try {
            if (_isLoading) {
              return Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.maincolor),
                  strokeWidth: 3,
                ),
              );
            }
            
            if (_error != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _fetchJobPlannings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.maincolor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }
            
            if (_jobPlannings.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.work_off,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No stopped jobs found',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            }
            
            return RefreshIndicator(
              onRefresh: _fetchJobPlannings,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Stopped Jobs',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_jobPlannings.length} Stopped Jobs',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ..._jobPlannings.map((planning) => _buildJobPlanningCard(planning)).toList(),
                  ],
                ),
              ),
            );
          } catch (e) {
            print('Error in build method: $e');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'An error occurred while building the UI',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {});
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.maincolor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }

    Widget _buildJobPlanningCard(Map<String, dynamic> planning) {
    final nrcJobNo = planning['nrcJobNo']?.toString() ?? 'N/A';
    final jobPlanId = planning['jobPlanId']?.toString() ?? 'N/A';
    final jobDemand = planning['jobDemand']?.toString() ?? 'N/A';
    final createdAt = planning['createdAt']?.toString();
    final updatedAt = planning['updatedAt']?.toString();
    final steps = planning['steps'] as List<dynamic>? ?? [];
    final isExpanded = _expandedCards.contains(int.tryParse(jobPlanId) ?? 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.maincolor.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Tooltip(
                            message: nrcJobNo,
                            child: Text(
                              nrcJobNo,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Plan ID: $jobPlanId',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: jobDemand.toLowerCase() == 'high' 
                            ? Colors.red.withOpacity(0.1)
                            : jobDemand.toLowerCase() == 'medium'
                                ? Colors.orange.withOpacity(0.1)
                                : Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: jobDemand.toLowerCase() == 'high'
                              ? Colors.red.withOpacity(0.3)
                              : jobDemand.toLowerCase() == 'medium'
                                  ? Colors.orange.withOpacity(0.3)
                                  : Colors.green.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        _getDemandColor(jobDemand),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: jobDemand.toLowerCase() == 'high'
                              ? Colors.red
                              : jobDemand.toLowerCase() == 'medium'
                                  ? Colors.orange
                                  : Colors.green,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Created: ${_formatDate(createdAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.update, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Updated: ${_formatDate(updatedAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child:                      Text(
                       'Stopped Steps (${steps.where((step) => step['status']?.toString().toLowerCase() == 'stop').length})',
                       style: const TextStyle(
                         fontSize: 14,
                         fontWeight: FontWeight.w600,
                         color: Colors.black87,
                       ),
                     ),
                    ),
                    IconButton(
                      onPressed: () => _toggleCardExpansion(int.tryParse(jobPlanId) ?? 0),
                      icon: Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: AppColors.maincolor,
                      ),
                      tooltip: isExpanded ? 'Collapse Details' : 'Expand Details',
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Steps Section (only show if expanded)
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (steps.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'No steps defined for this job',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                                     else
                     ...steps.where((step) => step['status']?.toString().toLowerCase() == 'stop')
                         .map((step) => _buildStepCard(step, nrcJobNo)).toList(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStepCard(Map<String, dynamic> step, String jobNumber) {
    final stepNo = step['stepNo']?.toString() ?? 'N/A';
    final stepName = step['stepName']?.toString() ?? 'N/A';
    final status = step['status']?.toString() ?? 'N/A';
    final startDate = step['startDate']?.toString();
    final endDate = step['endDate']?.toString();
    final user = step['user']?.toString();
    final machineDetails = step['machineDetails'] as List<dynamic>? ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getStatusColor(status).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    stepNo,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(status),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                                         Tooltip(
                       message: stepName,
                       child: Text(
                         stepName,
                         style: const TextStyle(
                           fontSize: 16,
                           fontWeight: FontWeight.w600,
                           color: Colors.black87,
                         ),
                         overflow: TextOverflow.ellipsis,
                         maxLines: 1,
                       ),
                     ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(status),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
                     if (user != null && user.isNotEmpty) ...[
             const SizedBox(height: 12),
             Row(
               children: [
                 Icon(Icons.person, size: 16, color: Colors.grey[600]),
                 const SizedBox(width: 8),
                 Expanded(
                   child: Text(
                     'Assigned to: $user',
                     style: TextStyle(
                       fontSize: 12,
                       color: Colors.grey[600],
                     ),
                     overflow: TextOverflow.ellipsis,
                     maxLines: 1,
                   ),
                 ),
               ],
             ),
           ],
          
                     if (startDate != null) ...[
             const SizedBox(height: 8),
             Row(
               children: [
                 Icon(Icons.play_arrow, size: 16, color: Colors.grey[600]),
                 const SizedBox(width: 8),
                 Expanded(
                   child: Text(
                     'Started: ${_formatDate(startDate)}',
                     style: TextStyle(
                       fontSize: 12,
                       color: Colors.grey[600],
                     ),
                     overflow: TextOverflow.ellipsis,
                     maxLines: 1,
                   ),
                 ),
               ],
             ),
           ],
           
           if (endDate != null) ...[
             const SizedBox(height: 8),
             Row(
               children: [
                 Icon(Icons.stop, size: 16, color: Colors.grey[600]),
                 const SizedBox(width: 8),
                 Expanded(
                   child: Text(
                     'Completed: ${_formatDate(endDate)}',
                     style: TextStyle(
                       fontSize: 12,
                       color: Colors.grey[600],
                     ),
                     overflow: TextOverflow.ellipsis,
                     maxLines: 1,
                   ),
                 ),
               ],
             ),
           ],
          
          if (machineDetails.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Machines:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            ...machineDetails.map((machine) => _buildMachineDetail(machine)).toList(),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showStatusUpdateDialog(jobNumber, int.tryParse(stepNo) ?? 0, status),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Update Status'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.maincolor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _navigateToAssignWorkSteps(
                    {'nrcJobNo': jobNumber}, // Create a minimal job planning object
                    step,
                  ),
                  icon: const Icon(Icons.build, size: 16),
                  label: const Text('Edit Machine'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (status.toLowerCase() == 'stop') ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _fetchAndDisplayStepDetails(jobNumber, stepName, step),
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Load Step Details'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Display fetched details if available
            if (step['fetchedDetails'] != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.purple, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Step Details:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.purple,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => _showStepDetailsDialog(jobNumber, stepName, step),
                          icon: const Icon(Icons.visibility, color: Colors.purple, size: 20),
                          tooltip: 'View Full Details',
                        ),
                        IconButton(
                          onPressed: () => _showEditStepDetailsDialog(jobNumber, stepName, step['fetchedDetails']),
                          icon: const Icon(Icons.edit, color: Colors.purple, size: 20),
                          tooltip: 'Edit Details',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildStepDetailsContent(step['fetchedDetails'], stepName),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildMachineDetail(Map<String, dynamic> machine) {
    final machineId = machine['machineId']?.toString() ?? 'N/A';
    final machineCode = machine['machineCode']?.toString() ?? 'N/A';
    final machineType = machine['machineType']?.toString() ?? 'N/A';
    final unit = machine['unit']?.toString();
    final machineDetails = machine['machine'] as Map<String, dynamic>?;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                     Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Row(
                 children: [
                   Icon(Icons.build, size: 16, color: Colors.grey[600]),
                   const SizedBox(width: 8),
                   Expanded(
                     child: Text(
                       'ID: $machineId',
                       style: const TextStyle(
                         fontSize: 12,
                         fontWeight: FontWeight.w600,
                         color: Colors.black87,
                       ),
                       overflow: TextOverflow.ellipsis,
                       maxLines: 1,
                     ),
                   ),
                 ],
               ),
               if (machineCode != 'N/A') ...[
                 const SizedBox(height: 4),
                 Row(
                   children: [
                     const SizedBox(width: 24), // Align with text above
                     Expanded(
                       child: Text(
                         'Code: $machineCode',
                         style: TextStyle(
                           fontSize: 12,
                           color: Colors.grey[600],
                         ),
                         overflow: TextOverflow.ellipsis,
                         maxLines: 1,
                       ),
                     ),
                   ],
                 ),
               ],
             ],
           ),
                     const SizedBox(height: 4),
           Text(
             'Type: $machineType',
             style: TextStyle(
               fontSize: 12,
               color: Colors.grey[600],
             ),
             overflow: TextOverflow.ellipsis,
             maxLines: 1,
           ),
           if (unit != null && unit.isNotEmpty) ...[
             const SizedBox(height: 4),
             Text(
               'Unit: $unit',
               style: TextStyle(
                 fontSize: 12,
                 color: Colors.grey[600],
               ),
               overflow: TextOverflow.ellipsis,
               maxLines: 1,
             ),
           ],
                     if (machineDetails != null) ...[
             const SizedBox(height: 4),
             Text(
               'Description: ${machineDetails['description'] ?? 'N/A'}',
               style: TextStyle(
                 fontSize: 12,
                 color: Colors.grey[600],
               ),
               overflow: TextOverflow.ellipsis,
               maxLines: 1,
             ),
             const SizedBox(height: 4),
             Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text(
                   'Status: ${machineDetails['status'] ?? 'N/A'}',
                   style: TextStyle(
                     fontSize: 12,
                     color: Colors.grey[600],
                   ),
                   overflow: TextOverflow.ellipsis,
                   maxLines: 1,
                 ),
                 const SizedBox(height: 4),
                 Text(
                   'Capacity: ${machineDetails['capacity'] ?? 'N/A'}',
                   style: TextStyle(
                     fontSize: 12,
                     color: Colors.grey[600],
                   ),
                   overflow: TextOverflow.ellipsis,
                   maxLines: 1,
                 ),
               ],
             ),
           ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Clear any cached data
    _stepDetails.clear();
    super.dispose();
  }
}

// Separate dialog widget for editing step details
class _EditStepDetailsDialog extends StatefulWidget {
  final String jobNumber;
  final String stepName;
  final Map<String, dynamic> currentDetails;
  final Function(Map<String, dynamic>) onUpdate;
  final VoidCallback onCancel;

  _EditStepDetailsDialog({
    required this.jobNumber,
    required this.stepName,
    required this.currentDetails,
    required this.onUpdate,
    required this.onCancel,
  });

  @override
  State<_EditStepDetailsDialog> createState() => _EditStepDetailsDialogState();
}

class _EditStepDetailsDialogState extends State<_EditStepDetailsDialog> {
  final Map<String, TextEditingController> _controllers = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    widget.currentDetails.forEach((key, value) {
      if (value != null) {
        String formattedValue = value.toString();
        
        // Format date fields for editing
        if (_isDateField(key)) {
          if (_isDateTimeField(key)) {
            formattedValue = _formatDateTimeForEdit(value.toString());
          } else {
            formattedValue = _formatDateForEdit(value.toString());
          }
        }
        
        _controllers[key] = TextEditingController(text: formattedValue);
      }
    });
  }

  bool _isDateField(String fieldName) {
    final dateFields = [
      'date', 'issuedDate', 'dispatchDate', 'createdAt', 'updatedAt',
      'startDate', 'endDate'
    ];
    return dateFields.any((field) => fieldName.toLowerCase().contains(field));
  }

  bool _isDateTimeField(String fieldName) {
    final dateTimeFields = [
      'issuedDate', 'dispatchDate', 'createdAt', 'updatedAt',
      'startDate', 'endDate'
    ];
    return dateTimeFields.any((field) => fieldName.toLowerCase().contains(field));
  }

  String _formatDateForEdit(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '';
    try {
      final date = DateTime.parse(dateString);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  String _formatDateTimeForEdit(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '';
    try {
      final date = DateTime.parse(dateString);
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}T$hour:$minute';
    } catch (e) {
      return dateString;
    }
  }

  String _formatDateForDisplay(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'Not specified';
    try {
      final date = DateTime.parse(dateString);
      const months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  String _formatDateTimeForDisplay(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'Not specified';
    try {
      final date = DateTime.parse(dateString);
      const months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '${date.day} ${months[date.month - 1]} ${date.year} at $hour:$minute';
    } catch (e) {
      return dateString;
    }
  }

  String _formatFieldName(String fieldName) {
    return fieldName
        .replaceAll(RegExp(r'([A-Z])'), ' \$1')
        .split(' ')
        .map((word) => word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '')
        .join(' ')
        .trim();
  }

  // Check if field is a numeric field
  bool _isNumericField(String fieldName) {
    final numericFields = [
      'id', 'jobStepId', 'quantity', 'available', 'wastage', 'rejectedQty', 
      'balanceQty', 'gsm1', 'gsm2', 'mill', 'extraMargin', 'noUps'
    ];
    return numericFields.any((field) => fieldName.toLowerCase().contains(field));
  }

  // Check if field should be an integer
  bool _isIntegerField(String fieldName) {
    final integerFields = [
      'id', 'jobStepId', 'quantity', 'available', 'wastage', 'rejectedQty', 
      'balanceQty', 'mill', 'extraMargin', 'noUps'
    ];
    return integerFields.any((field) => fieldName.toLowerCase().contains(field));
  }

  // Special handling for ID fields to ensure they are always integers
  bool _isIdField(String fieldName) {
    return fieldName.toLowerCase() == 'id' || fieldName.toLowerCase() == 'jobstepid';
  }

  // Check if field should remain as string even if it contains numbers
  bool _isStringField(String fieldName) {
    final stringFields = [
      'mill', 'extraMargin', 'quality', 'sheetSize', 'gsm', 'film', 'adhesive',
      'machine', 'machineNo', 'die', 'shift', 'oprName', 'operatorName',
      'checkedBy', 'reasonForRejection', 'remarks', 'dispatchNo'
    ];
    return stringFields.any((field) => fieldName.toLowerCase().contains(field));
  }

  void _handleUpdate() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Collect updated values
      final updatedDetails = <String, dynamic>{};
      _controllers.forEach((key, controller) {
        String value = controller.text;
        
        // Convert date formats back to ISO format for API
        if (_isDateField(key) && value.isNotEmpty) {
          try {
            if (_isDateTimeField(key)) {
              // Parse datetime and convert to ISO format
              final date = DateTime.parse(value);
              value = date.toIso8601String();
            } else {
              // Parse date and convert to ISO format
              final date = DateTime.parse(value);
              value = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}T00:00:00.000Z';
            }
          } catch (e) {
            // If parsing fails, keep original value
            print('Date parsing error for $key: $e');
          }
        }
        
        // Check if field should remain as string first
        if (_isStringField(key)) {
          updatedDetails[key] = value; // Keep as string
        }
        // Convert numeric fields to appropriate types
        else if (_isNumericField(key) && value.isNotEmpty) {
          try {
            // Special handling for ID fields - always ensure they are integers
            if (_isIdField(key)) {
              final intValue = int.tryParse(value);
              if (intValue != null && intValue > 0) {
                updatedDetails[key] = intValue;
              } else {
                print('Warning: Invalid ID value for $key: $value, using 0');
                updatedDetails[key] = 0;
              }
            } else if (_isIntegerField(key)) {
              final intValue = int.tryParse(value);
              if (intValue != null) {
                updatedDetails[key] = intValue;
              } else {
                print('Warning: Could not parse $key as integer: $value');
                updatedDetails[key] = 0; // Default to 0 for invalid integers
              }
            } else {
              final doubleValue = double.tryParse(value);
              if (doubleValue != null) {
                updatedDetails[key] = doubleValue;
              } else {
                print('Warning: Could not parse $key as double: $value');
                updatedDetails[key] = 0.0; // Default to 0.0 for invalid doubles
              }
            }
          } catch (e) {
            print('Numeric parsing error for $key: $e');
            // For critical fields like id, use default values
            if (_isIdField(key)) {
              updatedDetails[key] = 0;
            } else {
              updatedDetails[key] = value; // Keep as string if parsing fails
            }
          }
        } else {
          updatedDetails[key] = value;
        }
      });
      
      // Debug: Print the updated details before sending
      print('=== UPDATED DETAILS BEING SENT ===');
      print('Step Name: ${widget.stepName}');
      print('Job Number: ${widget.jobNumber}');
      print('Updated Details: $updatedDetails');
      print('=== END UPDATED DETAILS ===');
      
      // Validate that critical fields are present and valid
      if (updatedDetails.containsKey('id') && (updatedDetails['id'] == null || updatedDetails['id'] == 0)) {
        print('Warning: Invalid ID value detected, removing from update');
        updatedDetails.remove('id');
      }
      
      if (updatedDetails.containsKey('jobStepId') && (updatedDetails['jobStepId'] == null || updatedDetails['jobStepId'] == 0)) {
        print('Warning: Invalid jobStepId value detected, removing from update');
        updatedDetails.remove('jobStepId');
      }
      
      widget.onUpdate(updatedDetails);
    } catch (e) {
      print('Error updating step details: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit ${widget.stepName} Details'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...widget.currentDetails.entries.map((entry) {
              if (entry.value != null) {
                final isDateField = _isDateField(entry.key);
                final isDateTimeField = _isDateTimeField(entry.key);
                
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _controllers[entry.key],
                        decoration: InputDecoration(
                          labelText: _formatFieldName(entry.key),
                          border: const OutlineInputBorder(),
                          helperText: isDateField 
                            ? (isDateTimeField ? 'Format: YYYY-MM-DDTHH:MM' : 'Format: YYYY-MM-DD')
                            : null,
                        ),
                        keyboardType: isDateField ? TextInputType.datetime : TextInputType.text,
                      ),
                      if (isDateField) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Current: ${isDateTimeField ? _formatDateTimeForDisplay(entry.value.toString()) : _formatDateForDisplay(entry.value.toString())}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            }).toList(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : widget.onCancel,
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleUpdate,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.maincolor,
            foregroundColor: Colors.white,
          ),
          child: _isLoading 
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text('Update'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }
}

// Separate dialog widget for status updates
class _StatusUpdateDialog extends StatefulWidget {
  final String jobNumber;
  final int stepNo;
  final String currentStatus;
  final Function(String, String) onUpdate;
  final VoidCallback onCancel;

  _StatusUpdateDialog({
    required this.jobNumber,
    required this.stepNo,
    required this.currentStatus,
    required this.onUpdate,
    required this.onCancel,
  });

  @override
  State<_StatusUpdateDialog> createState() => _StatusUpdateDialogState();
}

class _StatusUpdateDialogState extends State<_StatusUpdateDialog> {
  String _selectedStatus = '';
  String _selectedUser = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.currentStatus;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'start':
        return Colors.green;
      case 'planned':
        return Colors.blue;
      case 'stop':
        return Colors.red;
      case 'completed':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  void _handleUpdate() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      widget.onUpdate(_selectedStatus, _selectedUser);
    } catch (e) {
      print('Error updating status: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Update Step Details'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Job: ${widget.jobNumber}'),
          Text('Step: ${widget.stepNo}'),
          const SizedBox(height: 16),
          const Text('Select new status:'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedStatus,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: ['planned', 'start', 'stop', 'completed'].map((status) {
              return DropdownMenuItem<String>(
                value: status,
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _getStatusColor(status),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(status.toUpperCase()),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedStatus = value!;
              });
            },
          ),
          const SizedBox(height: 16),
          const Text('Assign User (Optional):'),
          const SizedBox(height: 8),
          TextFormField(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Enter user ID (e.g., NRC001)',
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onChanged: (value) {
              _selectedUser = value;
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : widget.onCancel,
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleUpdate,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.maincolor,
            foregroundColor: Colors.white,
          ),
          child: _isLoading 
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text('Update'),
        ),
      ],
    );
  }
}
