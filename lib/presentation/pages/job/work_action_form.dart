import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nrc/data/datasources/job_api.dart';
import 'dart:convert';
import '../../../constants/colors.dart';
import '../process/JobApiService.dart';
import '../process/StepDataManager.dart';
import '../../../data/models/job_step_models.dart';
import '../../../core/services/dio_service.dart';

class WorkActionForm extends StatefulWidget {
  final String title;
  final String description;
  final String? initialQty;
  final bool hasData;
  final String? initialStatus; // Add initial status parameter
  final void Function(Map<String, String> formData) onComplete;
  final void Function()? onStart;
  final void Function()? onPause;
  final void Function()? onStop;
  final void Function(String)? onHold;
  final void Function(String)? onMajorHold;
  final void Function(String)? onResume;
  final BuildContext? parentContext; // Parent context for showing nested dialogs
  final String? jobNumber; // Add jobNumber parameter
  final int? stepNo; // Add stepNo parameter
  final JobApiService? apiService; // Add apiService parameter
  final int? expectedQuantity; // Add expectedQuantity parameter for validation
  final StepType? stepType; // Add stepType parameter for dynamic fields
  final Map<String, dynamic>? jobData; // Add jobData parameter for auto-population
  final int? jobPlanId;
  final int? jobStepId;
  final String? machineId; // Add machineId parameter for machine-specific work
  final String? nrcJobNo; // Add nrcJobNo parameter
  final int? initialAvailableQuantity;

  const WorkActionForm({
    super.key,
    required this.title,
    required this.description,
    this.initialQty,
    this.initialStatus, // Add initialStatus
    required this.onComplete,
    this.onStart,
    this.onPause,
    this.onStop,
    this.onHold,
    this.onMajorHold,
    this.onResume,
    this.hasData = false,
    this.jobNumber, // Add jobNumber
    this.stepNo, // Add stepNo
    this.apiService, // Add apiService
    this.expectedQuantity, // Add expectedQuantity
    this.stepType, // Add stepType
    this.jobData, // Add jobData
    this.jobPlanId,
    this.machineId, // Add machineId
    this.nrcJobNo, // Add nrcJobNo
    this.parentContext, // Add parentContext
    this.jobStepId,
    this.initialAvailableQuantity,
  });

  @override
  State<WorkActionForm> createState() => _WorkActionFormState();
}

class _WorkActionFormState extends State<WorkActionForm> {
  final _formKey = GlobalKey<FormState>();
  late Map<String, TextEditingController> _controllers;
  String _status = 'pending';
  DateTime? _startTime;
  DateTime? _endTime;
  bool _isLoading = false;
  late JobApi _job;
  
  // Cascading quantity validation
  int? _availableQuantity;
  int? _remainingQuantity; // Remaining after other machines' submission
  bool _isLoadingAvailableQty = false;
  
  // Dispatch cumulative tracking
  int? _jobTotalQuantity; // Total PO quantity for the job
  int? _totalDispatchedQty; // Total quantity already dispatched
  
  // Track if stop button was just pressed
  bool _stopButtonJustPressed = false;

  // Get adjusted available quantity for Flap Pasting (multiplies by No. of Ups)
  int? get _adjustedAvailableQuantity {
    if (widget.stepType == StepType.flapPasting && _availableQuantity != null && widget.jobData != null) {
      final noUps = widget.jobData!['noUps'];
      if (noUps != null) {
      final rawNoUps = noUps is int ? noUps : int.tryParse(noUps.toString());
      final noUpsInt = (rawNoUps == null || rawNoUps <= 0) ? 1 : rawNoUps;
        return _availableQuantity! * noUpsInt;
      }
    }
    return _availableQuantity;
  }

  /// Helper: return current time in IST (UTC+05:30) with milliseconds and proper offset
  String _formatDateWithMilliseconds() {
    final nowUtc = DateTime.now().toUtc();
    final ist = nowUtc.add(const Duration(hours: 5, minutes: 30));
    final year = ist.year.toString().padLeft(4, '0');
    final month = ist.month.toString().padLeft(2, '0');
    final day = ist.day.toString().padLeft(2, '0');
    final hour = ist.hour.toString().padLeft(2, '0');
    final minute = ist.minute.toString().padLeft(2, '0');
    final second = ist.second.toString().padLeft(2, '0');
    final millisecond = ist.millisecond.toString().padLeft(3, '0');
    return '$year-$month-${day}T$hour:$minute:$second.$millisecond+05:30';
  }

  /// Helper: format IST wall-clock time but mark as Z (UTC) to match existing backend expectations
  String _formatIstAsZulu() {
    final nowUtc = DateTime.now().toUtc();
    final ist = nowUtc.add(const Duration(hours: 5, minutes: 30));
    final y = ist.year.toString().padLeft(4, '0');
    final m = ist.month.toString().padLeft(2, '0');
    final d = ist.day.toString().padLeft(2, '0');
    final hh = ist.hour.toString().padLeft(2, '0');
    final mm = ist.minute.toString().padLeft(2, '0');
    final ss = ist.second.toString().padLeft(2, '0');
    final ms = ist.millisecond.toString().padLeft(3, '0');
    return '$y-$m-${d}T$hh:$mm:$ss.${ms}Z';
  }

  /// Load available quantity from previous step for cascading validation
  /// Also calculate remaining quantity after subtracting what other machines submitted
  Future<void> _loadAvailableQuantity() async {
    if (widget.apiService == null || widget.jobNumber == null || widget.stepType == null) {
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingAvailableQty = true;
      });
    }

    try {
      // Get available quantity from previous step
      final availableQty = await widget.apiService!.getPreviousStepAvailableQuantity(
        widget.jobNumber!, 
        widget.stepType!,
        jobPlanId: widget.jobPlanId,
      );
      
      int remainingQty = availableQty ?? 0;
      
      // If we have stepNo and nrcJobNo, fetch other machines' submitted quantities
      if (widget.stepNo != null && widget.nrcJobNo != null && widget.machineId != null) {
        try {
          final machinesStatus = await widget.apiService!.getMachineWorkStatus(
            widget.nrcJobNo!,
            widget.stepNo!,
            jobPlanId: widget.jobPlanId,
          );
          
          // Calculate total submitted by OTHER machines (exclude current machine)
          int totalSubmittedByOthers = 0;
          
          if (machinesStatus != null && machinesStatus['machineWork'] != null) {
            for (var machine in machinesStatus['machineWork']) {
              // Skip current machine
              if (machine['machineId'] == widget.machineId) {
                continue;
              }
              
              // Only count machines that have submitted data (stop or completed status)
              if (machine['status'] == 'stop' && machine['formData'] != null) {
                final formData = machine['formData'];
                
                // Extract OK quantity and wastage
                int okQty = 0;
                int wastage = 0;
                
                // Handle various field name variations
                if (formData['Quantity OK'] != null) {
                  okQty = int.tryParse(formData['Quantity OK'].toString()) ?? 0;
                } else if (formData['OK Quantity'] != null) {
                  okQty = int.tryParse(formData['OK Quantity'].toString()) ?? 0;
                } else if (formData['quantity'] != null) {
                  okQty = int.tryParse(formData['quantity'].toString()) ?? 0;
                } else if (formData['Sheets Count'] != null) {
                  okQty = int.tryParse(formData['Sheets Count'].toString()) ?? 0;
                }
                
                if (formData['Wastage'] != null) {
                  wastage = int.tryParse(formData['Wastage'].toString()) ?? 0;
                } else if (formData['wastage'] != null) {
                  wastage = int.tryParse(formData['wastage'].toString()) ?? 0;
                }
                
                totalSubmittedByOthers += (okQty + wastage);
                print('🔍 Machine ${machine['machineCode']} submitted: OK=$okQty, Wastage=$wastage, Total=${okQty + wastage}');
              }
            }
          }
          
          // Calculate remaining quantity
          remainingQty = (availableQty ?? 0) - totalSubmittedByOthers;
          if (remainingQty < 0) remainingQty = 0; // Prevent negative
          
          print('🔍 Multi-machine Quantity Calculation:');
          print('   Available from previous step: $availableQty');
          print('   Already submitted by other machines: $totalSubmittedByOthers');
          print('   Remaining for this machine: $remainingQty');
        } catch (e) {
          print('Warning: Could not fetch other machines\' data: $e');
          // If we can't get other machines' data, use full available quantity
          remainingQty = availableQty ?? 0;
        }
      }
      
      if (mounted) {
        setState(() {
          _availableQuantity = availableQty;
          _remainingQuantity = remainingQty;
          _isLoadingAvailableQty = false;
        });
        print('🔍 Loaded available quantity: $_availableQuantity, remaining: $_remainingQuantity for step: ${widget.stepType!.name}');
      }
    } catch (e) {
      print('Error loading available quantity: $e');
      if (mounted) {
        setState(() {
          _isLoadingAvailableQty = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _job = JobApi(DioService.instance); // Initialize JobApi instance
    _initializeControllers();
    _availableQuantity = widget.initialAvailableQuantity;
    _autoPopulateFields();
    // Load current status from database if API service is available
    _loadCurrentStatus();
    // Load available quantity for cascading validation
    _loadAvailableQuantity();
  }

  void _initializeControllers() {
    _controllers = {};
    if (widget.stepType != null) {
      final fieldNames = StepDataManager.getFieldNamesForStep(widget.stepType!);
      for (String fieldName in fieldNames) {
        _controllers[fieldName] = TextEditingController();
        // Set initial value for quantity fields
        if (fieldName.toLowerCase().contains('quantity') || fieldName.toLowerCase().contains('qty')) {
          _controllers[fieldName]!.text = widget.initialQty ?? '';
        }
      }
    } else {
      // Fallback to default fields if stepType is not provided
      _controllers['Qty Sheet'] = TextEditingController(text: widget.initialQty ?? '');
      _controllers['Emp Id'] = TextEditingController();
      _controllers['Rejected Qty'] = TextEditingController();
      _controllers['Reason for Rejection'] = TextEditingController();
    }
  }

  void _autoPopulateFields() async {
    // Auto-fill Employee ID from logged-in user
    await _autoFillEmployeeId();
    
    // Fetch step details directly like the job details dialog does
    if (widget.apiService == null) {
      print('🔍 [AutoPopulate] API service is null');
      return;
    }
    
    try {
      final stepNo = StepDataManager.getStepNumber(widget.stepType!);
      final stepDetails = await widget.apiService!.getJobPlanningStepDetails(widget.jobNumber!, stepNo);
      
      print('🔍 [AutoPopulate] Step details: $stepDetails');
      
      if (stepDetails != null && stepDetails is Map) {
        // Get job planning data
        final jobPlanning = stepDetails['jobPlanning'];
        if (jobPlanning != null && jobPlanning is Map) {
          final nrcJobNo = jobPlanning['nrcJobNo'];
          print('🔍 [AutoPopulate] Job number: $nrcJobNo');
          
          // Fetch job details using the job number
          final jobDetails = await widget.apiService!.fetchJobDetails(nrcJobNo);
          if (jobDetails != null && jobDetails.isNotEmpty) {
            final jobData = jobDetails[0];
            print('🔍 [AutoPopulate] Job data: ${jobData.nrcJobNo}, ${jobData.boardSize}, ${jobData.topFaceGSM}, ${jobData.bottomLinerGSM}, ${jobData.fluteType}');
            
            // Direct field mapping using job data properties
            for (String fieldName in _controllers.keys) {
              String? value;
              
              // Direct field mapping using job data properties
              if (fieldName.toLowerCase().contains('required qty') || 
                  fieldName.toLowerCase().contains('quantity') ||
                  fieldName.toLowerCase().contains('pass quantity') ||
                  fieldName.toLowerCase().contains('qty sheet') ||
                  fieldName.toLowerCase().contains('no of boxes')) {
                // Try purchase orders first, then noUps
                if (jobData.purchaseOrders != null && jobData.purchaseOrders!.isNotEmpty) {
                  value = jobData.purchaseOrders![0].totalPOQuantity?.toString();
                }
                if (value == null || value.isEmpty) {
                  value = jobData.noUps?.toString();
                }
              }
              
              // Handle Sheets Count separately - only auto-populate for non-Corrugation steps
              if (fieldName.toLowerCase().contains('sheets count') && 
                  widget.stepType != StepType.corrugation) {
                if (jobData.purchaseOrders != null && jobData.purchaseOrders!.isNotEmpty) {
                  value = jobData.purchaseOrders![0].totalPOQuantity?.toString();
                }
                if (value == null || value.isEmpty) {
                  value = jobData.noUps?.toString();
                }
              } else if (fieldName.toLowerCase().contains('available qty') && 
                  widget.stepType != StepType.paperStore) {
                // Handle Available Qty separately - only auto-populate for non-PaperStore steps
                if (jobData.purchaseOrders != null && jobData.purchaseOrders!.isNotEmpty) {
                  value = jobData.purchaseOrders![0].totalPOQuantity?.toString();
                }
                if (value == null || value.isEmpty) {
                  value = jobData.noUps?.toString();
                }
              } else if (fieldName.toLowerCase().contains('size')) {
                // Auto-populate boardSize for ALL steps
                value = jobData.boardSize?.toString() ?? jobData.boxDimensions?.toString();
              } else if (fieldName.toLowerCase().contains('quantity ok') || 
                  fieldName.toLowerCase().contains('ok quantity')) {
                if (widget.stepType == StepType.printing || 
                    widget.stepType == StepType.fluteLamination ||
                    widget.stepType == StepType.punching) {
                  // For Printing, Flute Lamination, and Punching, this should be user input (empty)
                  value = null;
                } else {
                  // For other steps, auto-populate from job data
                  if (jobData.purchaseOrders != null && jobData.purchaseOrders!.isNotEmpty) {
                    value = jobData.purchaseOrders![0].totalPOQuantity?.toString();
                  }
                  if (value == null || value.isEmpty) {
                    value = jobData.noUps?.toString();
                  }
                }
              } else if (fieldName.toLowerCase().contains('quantity') && 
                  widget.stepType == StepType.flapPasting) {
                // For Flap Pasting, Quantity should be user input (empty)
                value = null;
              } else if ((fieldName.toLowerCase().contains('adhesive') || 
                         fieldName.toLowerCase().contains('wastage') || 
                         fieldName.toLowerCase().contains('remarks')) && 
                         widget.stepType == StepType.flapPasting) {
                // For Flap Pasting, these fields should be user input (empty)
                value = null;
              } else if (fieldName.toLowerCase().contains('gsm1') || fieldName.toLowerCase().contains('top face')) {
                value = jobData.topFaceGSM?.toString();
              } else if (fieldName.toLowerCase().contains('gsm2') || fieldName.toLowerCase().contains('bottom face')) {
                value = jobData.bottomLinerGSM?.toString();
              } else if (fieldName.toLowerCase().contains('flute type')) {
                value = jobData.fluteType?.toString();
              } else if (fieldName.toLowerCase().contains('die used')) {
                value = jobData.diePunchCode?.toString();
              } else if (fieldName.toLowerCase().contains('colors used')) {
                value = jobData.noOfColor?.toString();
              } else if (fieldName.toLowerCase().contains('process colors')) {
                value = jobData.processColors?.toString();
              } else if (fieldName.toLowerCase().contains('special colors')) {
                value = jobData.specialColor1?.toString() ?? 
                        jobData.specialColor2?.toString() ?? 
                        jobData.specialColor3?.toString() ?? 
                        jobData.specialColor4?.toString();
              }
              
              // Set the value if found - prioritize job data over existing individual step data
              if (value != null && value.isNotEmpty) {
                // For auto-populated fields, always use job data regardless of existing values
                if (fieldName.toLowerCase().contains('gsm1') || 
                    fieldName.toLowerCase().contains('gsm2') ||
                    fieldName.toLowerCase().contains('top face') ||
                    fieldName.toLowerCase().contains('bottom face') ||
                    fieldName.toLowerCase().contains('flute type') ||
                    fieldName.toLowerCase().contains('die used') ||
                    fieldName.toLowerCase().contains('colors used') ||
                    fieldName.toLowerCase().contains('process colors') ||
                    fieldName.toLowerCase().contains('special colors') ||
                    fieldName.toLowerCase().contains('required qty')) {
                  _controllers[fieldName]!.text = value;
                  print('🔍 [AutoPopulate] Set $fieldName to: $value (from job data)');
                } else if (_controllers[fieldName]!.text.isEmpty) {
                  // For other fields, only set if empty
                  _controllers[fieldName]!.text = value;
                  print('🔍 [AutoPopulate] Set $fieldName to: $value');
                }
              } else {
                // For GSM fields, if no value from job data, keep them editable
                if (fieldName.toLowerCase().contains('gsm1') || 
                    fieldName.toLowerCase().contains('gsm2') ||
                    fieldName.toLowerCase().contains('top face') ||
                    fieldName.toLowerCase().contains('bottom face')) {
                  print('🔍 [AutoPopulate] No job data for $fieldName, keeping editable');
                }
              }
            }
          }
        }
      }
    } catch (e) {
      print('🔍 [AutoPopulate] Error fetching step details: $e');
    }
    
    // Force UI update after populating fields
    setState(() {});
  }

  Future<void> _autoFillEmployeeId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      
      if (userId != null && userId.isNotEmpty) {
        // Find Employee ID field and auto-fill it
        if (_controllers.containsKey('Emp Id')) {
          _controllers['Emp Id']!.text = userId;
        }
        // Also check for other possible employee ID field names
        for (String fieldName in _controllers.keys) {
          if (fieldName.toLowerCase().contains('emp') || 
              fieldName.toLowerCase().contains('employee') ||
              fieldName.toLowerCase().contains('operator')) {
            _controllers[fieldName]!.text = userId;
          }
        }
      }
    } catch (e) {
      print('Error auto-filling employee ID: $e');
    }
  }

  bool _isStepSpecificLockedField(String fieldName) {
    if (widget.stepType == null) return false;
    
    switch (widget.stepType!) {
      case StepType.paperStore:
        // PaperStore: Lock Sheet Size and Required Qty only if they have values
        if (fieldName.toLowerCase().contains('required qty') ||
            (fieldName.toLowerCase().contains('sheet') && fieldName.toLowerCase().contains('size'))) {
          return _controllers[fieldName]?.text.isNotEmpty == true;
        }
        return false;
        
      case StepType.printing:
        // Printing: Lock Colors Used only if it has a value
        if (fieldName.toLowerCase().contains('colors used')) {
          return _controllers[fieldName]?.text.isNotEmpty == true;
        }
        return false;
               
      case StepType.corrugation:
        // Corrugation: Lock Size, GSM1, GSM2, Flute Type only if they have values
        if (fieldName.toLowerCase().contains('size') ||
            fieldName.toLowerCase().contains('gsm1') ||
            fieldName.toLowerCase().contains('gsm2') ||
            fieldName.toLowerCase().contains('top face') ||
            fieldName.toLowerCase().contains('bottom face') ||
            fieldName.toLowerCase().contains('flute type')) {
          return _controllers[fieldName]?.text.isNotEmpty == true;
        }
        return false;
        
      case StepType.punching:
      case StepType.dieCutting:
        // Punching & Die Cutting: Lock Die Used only if it has a value
        if (fieldName.toLowerCase().contains('die used')) {
          return _controllers[fieldName]?.text.isNotEmpty == true;
        }
        return false;
        
      default:
        return false;
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    _okQuantityController.dispose();
    _completeRemarkController.dispose();
    super.dispose();
  }

  // Load current status from database
  void _loadCurrentStatus() async {
    if (widget.jobNumber == null || widget.stepNo == null || widget.apiService == null) {
      return;
    }

    // 🚀 REVOLUTIONARY: Use initialStatus for PaperStore, Quality, Dispatch steps
    if (widget.initialStatus != null && 
        (widget.stepType == StepType.paperStore || 
         widget.stepType == StepType.qc || 
         widget.stepType == StepType.dispatch)) {
      print('🚀 Using initialStatus for ${widget.stepType}: ${widget.initialStatus}');
      if (mounted) {
        setState(() {
          _status = widget.initialStatus!;
          if (_status == 'hold') {
            _isStartDisabled = true;
            _isPauseDisabled = true;
            _isStopDisabled = false;
            print('🚀 Set hold status with correct button states');
          } else if (_status == 'start' || _status == 'started') {
            _isStartDisabled = true;
            _isPauseDisabled = false;
            _isStopDisabled = false;
            print('🚀 Set start status with correct button states');
          } else if (_status == 'major_hold') {
            _isStartDisabled = true;
            _isPauseDisabled = true;
            _isStopDisabled = true;
            print('🚀 Set major_hold status with correct button states');
          } else if (_status == 'pending' || _status == 'planned') {
            // Pending status - show start button
            _isStartDisabled = false;
            _isPauseDisabled = true;
            _isStopDisabled = true;
            print('🚀 Set pending status with correct button states');
          }
        });
      }
      return;
    }

    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      // For machine-specific work, get machine status instead of step status
      if (widget.machineId != null && widget.nrcJobNo != null) {
        // Get available machines to find the current machine status
        final machinesData = await widget.apiService!.getAvailableMachines(
          widget.nrcJobNo!,
          widget.stepNo!,
          jobPlanId: widget.jobPlanId,
        );
        if (machinesData != null && machinesData['machines'] is List) {
          final machines = machinesData['machines'] as List;
          final currentMachine = machines.firstWhere(
            (machine) => machine['machineId'] == widget.machineId,
            orElse: () => null,
          );
          
          if (currentMachine != null) {
            final machineStatus = currentMachine['status'];
            final startDate = currentMachine['startedAt'];
            final endDate = currentMachine['completedAt'];
            
            if (mounted) {
              setState(() {
              if (machineStatus == 'stop') {
                // Machine is stopped but may not be completed yet
                // Check if formData exists to determine if work is completed
                final formData = currentMachine['formData'];
                bool isCompleted = false;
                
                if (formData != null) {
                  // formData can be a Map or a string (JSON)
                  if (formData is Map) {
                    isCompleted = formData.isNotEmpty;
                  } else if (formData is String) {
                    // Parse JSON string to check if it has content
                    try {
                      final parsed = Map<String, dynamic>.from(jsonDecode(formData));
                      isCompleted = parsed.isNotEmpty;
                    } catch (e) {
                      isCompleted = false;
                    }
                  }
                }
                
                                 _status = 'stop'; // Always 'stop' when machineStatus is 'stop'
                 _startTime = DateTime.tryParse(startDate);
                 _endTime = DateTime.tryParse(endDate);
                 _isStartDisabled = true;
                 _isPauseDisabled = true;
                 _isStopDisabled = true;
                 print('Machine work is stopped, status: $machineStatus');
              } else if (endDate != null && machineStatus != 'stop') {
                // Machine work is completed
                _status = 'stopped';
                _startTime = DateTime.tryParse(startDate);
                _endTime = DateTime.tryParse(endDate);
                _isStartDisabled = true;
                _isPauseDisabled = true;
                _isStopDisabled = true;
                print('Machine work is completed, status: $machineStatus');
              } else if (machineStatus == 'in_progress') {
                // Machine is working - show hold and stop buttons
                _status = 'start';
                _startTime = DateTime.tryParse(startDate);
                _isStartDisabled = true;
                _isPauseDisabled = false;
                _isStopDisabled = false;
                print('Machine is working, showing hold and stop buttons');
              } else if (machineStatus == 'hold') {
                // Machine is on hold - show resume and stop buttons
                _status = 'hold';
                _startTime = DateTime.tryParse(startDate);
                _isStartDisabled = true;
                _isPauseDisabled = true;
                _isStopDisabled = false;
                print('Machine is on hold, showing resume and stop buttons');
              } else if (machineStatus == 'major_hold') {
                // Machine is on major hold - disable all buttons except admin resume
                _status = 'major_hold';
                _startTime = DateTime.tryParse(startDate);
                _isStartDisabled = true;
                _isPauseDisabled = true;
                _isStopDisabled = true;
                print('Machine is on major hold, disabling all buttons');
              } else {
                // Machine is available - show start button
                _isStartDisabled = false;
                _isPauseDisabled = true;
                _isStopDisabled = true;
                print('Machine is available, showing start button');
              }
              });
            }
            return;
          }
        }
      }
      
      // Fallback to step status for non-machine work
      final stepDetails = await widget.apiService!.getJobPlanningStepDetails(widget.jobNumber!, widget.stepNo!);
      if (stepDetails != null) {
        final startDate = stepDetails['startDate'];
        final endDate = stepDetails['endDate'];
        final status = stepDetails['status'];
        if (mounted) {
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
            print('Step is already started, setting status to start and enabling stop button');
          } else if (status == 'in_progress') {
            // Work is in progress - show resume button
            _status = 'in_progress';
            _startTime = DateTime.tryParse(startDate);
            _isStartDisabled = true;
            _isPauseDisabled = true;
            _isStopDisabled = true;
            print('Step is in progress, setting status to in_progress and enabling resume button');
          } else if (status == 'hold') {
            // Work is on hold - show resume button
            _status = 'hold';
            _startTime = DateTime.tryParse(startDate);
            _isStartDisabled = true;
            _isPauseDisabled = true;
            _isStopDisabled = true;
            print('Step is on hold, setting status to hold and enabling resume button');
          } else if (status == 'major_hold') {
            // Work is on major hold - disable all buttons
            _status = 'major_hold';
            _startTime = DateTime.tryParse(startDate);
            _isStartDisabled = true;
            _isPauseDisabled = true;
            _isStopDisabled = true;
            print('Step is on major hold, disabling all buttons');
          } else {
            // No work started yet
            _isStartDisabled = false;
            _isPauseDisabled = false;
            _isStopDisabled = false;
          }
          });
        }
      }
    } catch (e) {
      print('Error loading current status: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleStart() async {
    // If this is machine-specific work, use machine API
    if (widget.machineId != null && widget.nrcJobNo != null && widget.stepNo != null && widget.apiService != null) {
      // Check if machine is actually assigned (not null/undefined)
      if (widget.machineId == 'null' || widget.machineId == 'undefined' || widget.machineId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text('No machine assigned for this step.\nPlease contact the planner to assign a machine.'),
                ),
              ],
            ),
            backgroundColor: Colors.orange[700],
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return;
      }
      
      if (mounted) {
        setState(() => _isLoading = true);
      }
      
      try {
        final formData = _collectFormData();
        final result = await widget.apiService!.startWorkOnMachine(
          widget.nrcJobNo!,
          widget.stepNo!,
          widget.machineId!,
          formData: formData,
          jobPlanId: widget.jobPlanId,
        );
        
        if (result != null) {
          print('Work started on machine: ${widget.machineId}');
          _startTime = DateTime.now();
          
          if (mounted) {
            setState(() {
              _status = 'start';
              _isLoading = false;
            });
          }
          
          widget.onStart?.call();
          print('✅ Work started on machine - data will auto-refresh');
        } else {
          print('Failed to start work on machine');
          if (mounted) {
            setState(() => _isLoading = false);
          }
        }
      } catch (e) {
        print('Error starting work on machine: $e');
        if (mounted) {
          setState(() => _isLoading = false);
        }
        
        // Show user-friendly error message
        if (mounted) {
          _showWorkflowError(e, 'start');
        }
      }
      return;
    }

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
      // Update JobStep status - backend handles startDate automatically
      await widget.apiService!.updateJobPlanningStepFields(
        widget.jobNumber!,
        widget.stepNo!,
        {
          'status': 'start',
        },
        jobPlanId: widget.jobPlanId,
        jobStepId: widget.jobStepId,
      );

      // Also update individual step status to in_progress
      if (widget.stepType != null) {
        // Machine-specific start is handled by startWorkOnMachine API
        // No need to call old updateStepStatusGeneric API
      }

      // Set local start time
      _startTime = DateTime.now();

      setState(() {
        _status = 'start';
        _isLoading = false;
      });

      widget.onStart?.call();

      if (mounted) {
        print('✅ Work started - data will auto-refresh');
      }
    } catch (e) {
      setState(() => _isLoading = false);

      if (mounted) {
        // Only show error for actual failures, not validation warnings
        if (!e.toString().contains('400') && 
            !e.toString().contains('validation') &&
            !e.toString().contains('Bad Request') &&
            !e.toString().contains('already')) {
          print('Start work validation warning (operation may have succeeded): $e');
        }
      }
    }
  }

  void _handlePause() {
    // Note: Pause functionality might need API integration based on your requirements
    setState(() => _status = 'paused');
    widget.onPause?.call();
  }

  void _handleHold() async {
    if (_status != 'start' && _status != 'in_progress') {
      return;
    }

    // Show remarks dialog for hold action
    final remarks = await _showRemarksDialog('Hold Work', hintText: 'Enter reason for holding the work');
    if (remarks != null) {
      setState(() => _status = 'hold');
      
      // If this is machine-specific work, call the machine API
      if (widget.machineId != null && widget.nrcJobNo != null && widget.stepNo != null && widget.apiService != null) {
        try {
          final formData = _collectFormData();
          final result = await widget.apiService!.holdWorkOnMachine(
            widget.nrcJobNo!,
            widget.stepNo!,
            widget.machineId!,
            formData: formData,
            holdReason: remarks,
            jobPlanId: widget.jobPlanId,
          );
          
          if (result != null) {
            print('✅ Work held on machine: ${widget.machineId} - data will auto-refresh');
          } else {
            print('Failed to hold work on machine');
            setState(() => _status = 'start'); // Revert status on failure
          }
        } catch (e) {
          print('Error holding work on machine: $e');
          setState(() => _status = 'start'); // Revert status on error
          
          // Show user-friendly error message
          if (mounted) {
            _showWorkflowError(e, 'hold');
          }
        }
      } else if (widget.stepType != null && widget.jobNumber != null && widget.apiService != null) {
        // Call backend API for non-machine steps (PaperStore, Quality, Dispatch)
        try {
          String endpoint = '';
          switch (widget.stepType) {
            case StepType.paperStore:
              endpoint = '/paper-store/${widget.jobNumber}/hold';
              break;
            case StepType.qc:
              endpoint = '/quality-dept/${widget.jobNumber}/hold';
              break;
            case StepType.dispatch:
              endpoint = '/dispatch-process/${widget.jobNumber}/hold';
              break;
            default:
              print('Hold not supported for step type: ${widget.stepType}');
              return;
          }
          
          final response = await widget.apiService!.holdWork(endpoint, {'holdRemark': remarks});
          
          if (response['success'] == true) {
            print('${widget.title} work held successfully');
          } else {
            print('Failed to hold ${widget.title} work');
            setState(() => _status = 'start'); // Revert status on failure
          }
        } catch (e) {
          print('Error holding ${widget.title} work: $e');
          setState(() => _status = 'start'); // Revert status on error
        }
      } else {
        // Fallback: Call the original callback for non-machine work
        widget.onHold?.call(remarks);
      }
    }
  }

  void _handleMajorHold() async {
    if (_status != 'start' && _status != 'in_progress') {
      return;
    }

    // Show remarks dialog for major hold action
    final remarks = await _showRemarksDialog('Major Hold Work', hintText: 'Enter reason for major hold (machine breakdown, major issue)');
    if (remarks != null) {
      setState(() => _status = 'major_hold');
      
      // If this is machine-specific work, call the machine API
      if (widget.machineId != null && widget.nrcJobNo != null && widget.stepNo != null && widget.apiService != null) {
        try {
          final formData = _collectFormData();
          final result = await widget.apiService!.majorHoldWorkOnMachine(
            widget.nrcJobNo!,
            widget.stepNo!,
            widget.machineId!,
            formData: formData,
            majorHoldReason: remarks,
            jobPlanId: widget.jobPlanId,
          );
          
          if (result != null) {
            print('✅ Work major held on machine: ${widget.machineId} - data will auto-refresh');
          } else {
            print('Failed to major hold work on machine');
            setState(() => _status = 'start'); // Revert status on failure
          }
        } catch (e) {
          print('Error major holding work on machine: $e');
          setState(() => _status = 'start'); // Revert status on error
          
          // Show user-friendly error message
          if (mounted) {
            _showWorkflowError(e, 'major hold');
          }
        }
      } else {
        // Fallback: Call the original callback for non-machine work
        widget.onMajorHold?.call(remarks);
      }
    }
  }

  void _handleResume() async {
    if (_status != 'hold') {
      return;
    }

    // Show remarks dialog for resume action
    final remarks = await _showRemarksDialog('Resume Work', hintText: 'Enter remarks for resuming the work');
    if (remarks != null) {
      setState(() => _status = 'start');
      
      // If this is machine-specific work, call the machine API
      if (widget.machineId != null && widget.nrcJobNo != null && widget.stepNo != null && widget.apiService != null) {
        try {
          final formData = _collectFormData();
          final result = await widget.apiService!.resumeWorkOnMachine(
            widget.nrcJobNo!,
            widget.stepNo!,
            widget.machineId!,
            formData: formData,
            jobPlanId: widget.jobPlanId,
          );
          
          if (result != null) {
            print('✅ Work resumed on machine: ${widget.machineId} - data will auto-refresh');
          } else {
            print('Failed to resume work on machine');
            setState(() => _status = 'hold'); // Revert status on failure
          }
        } catch (e) {
          print('Error resuming work on machine: $e');
          setState(() => _status = 'hold'); // Revert status on error
          
          // Show user-friendly error message
          if (mounted) {
            _showWorkflowError(e, 'resume');
          }
        }
      } else if (widget.stepType != null && widget.jobNumber != null && widget.apiService != null) {
        // Call backend API for non-machine steps (PaperStore, Quality, Dispatch)
        try {
          String endpoint = '';
          switch (widget.stepType) {
            case StepType.paperStore:
              endpoint = '/paper-store/${widget.jobNumber}/resume';
              break;
            case StepType.qc:
              endpoint = '/quality-dept/${widget.jobNumber}/resume';
              break;
            case StepType.dispatch:
              endpoint = '/dispatch-process/${widget.jobNumber}/resume';
              break;
            default:
              print('Resume not supported for step type: ${widget.stepType}');
              return;
          }
          
          final response = await widget.apiService!.resumeWork(endpoint);
          
          if (response['success'] == true) {
            print('✅ ${widget.title} work resumed successfully - data will auto-refresh');
            setState(() => _status = 'in_progress');
          } else {
            print('Failed to resume ${widget.title} work');
            setState(() => _status = 'hold'); // Revert status on failure
          }
        } catch (e) {
          print('Error resuming ${widget.title} work: $e');
          setState(() => _status = 'hold'); // Revert status on error
        }
      } else {
        // Fallback: Call the original callback for non-machine work
        widget.onResume?.call(remarks);
      }
    }
  }

  Future<String?> _showRemarksDialog(String title, {String? hintText}) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText ?? 'Enter remarks (optional)',
            border: const OutlineInputBorder(),
            helperText: _getRemarksHelperText(title),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _getRemarksHelperText(String title) {
    switch (title.toLowerCase()) {
      case 'hold work':
        return 'Enter reason for holding the work';
      case 'resume work':
        return 'Enter remarks for resuming the work';
      case 'complete work':
        return 'Enter completion remarks';
      default:
        return 'Enter remarks (optional)';
    }
  }

  /// Show user-friendly workflow error messages
  void _showWorkflowError(dynamic error, String action) {
    String errorMessage = 'Failed to $action work';
    
    // Parse error to get user-friendly message
    final errorStr = error.toString();
    
    // Check for specific HTTP status codes first (order matters!)
    if (errorStr.contains('403') || errorStr.contains('Access denied') || errorStr.contains('do not have access')) {
      errorMessage = 'Access denied. You do not have permission to start work on this machine.';
    } else if (errorStr.contains('401')) {
      errorMessage = 'Please login again';
    } else if (errorStr.contains('404')) {
      errorMessage = 'Job step not found';
    } else if (errorStr.contains('DioException') || errorStr.contains('400')) {
      // 400 Bad Request - likely workflow validation error
      if (errorStr.contains('Previous step') || errorStr.contains('must be completed')) {
        errorMessage = 'Previous step not completed. Please complete the previous step first.';
      } else if (errorStr.contains('Cannot start') || errorStr.contains('Cannot stop') || 
                 errorStr.contains('Cannot hold') || errorStr.contains('Cannot resume')) {
        // Try to extract the specific error message
        final match = RegExp(r'Cannot (start|stop|hold|resume).*?(?=\.|,|\n|$)', caseSensitive: false)
            .firstMatch(errorStr);
        if (match != null) {
          errorMessage = match.group(0)!;
          // Make it more user-friendly
          if (errorMessage.contains('must be completed')) {
            errorMessage = 'Previous step not completed. Please complete the previous step first.';
          }
        } else {
          errorMessage = 'Previous step not completed';
        }
      } else if (errorStr.contains('workflow') || errorStr.contains('Workflow')) {
        errorMessage = 'Cannot $action this step. Please complete previous steps first.';
      } else {
        errorMessage = 'Cannot $action this step. Please complete the previous step before starting this one.';
      }
    }
    
    // Show error snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Unable to ${action.toUpperCase()}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  SizedBox(height: 4),
                  Text(errorMessage, style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  /// Collect form data for machine-specific work
  Map<String, dynamic> _collectFormData() {
    final formData = <String, dynamic>{};
    
    // Collect all form field values
    for (final field in _controllers.keys) {
      final controller = _controllers[field];
      if (controller != null && controller.text.isNotEmpty) {
        formData[field] = controller.text;
      }
    }
    
    // Add status and timing information
    formData['status'] = _status;
    if (_startTime != null) {
      formData['startTime'] = _startTime!.toIso8601String();
    }
    if (_endTime != null) {
      formData['endTime'] = _endTime!.toIso8601String();
    }
    
    return formData;
  }

  void _handleStop() async {
    if (_status != 'start' && _status != 'in_progress' && _status != 'hold') {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.white,
        title: const Text('Confirm Stop'),
        content: const Text('This will stop the machine. You can complete the work details after stopping.'),
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

    // If this is machine-specific work, use machine API
    if (widget.machineId != null && widget.nrcJobNo != null && widget.stepNo != null && widget.apiService != null) {
      setState(() => _isLoading = true);
      
      try {
        // ✅ UPDATED: Stop button does NOT send formData anymore
        final result = await widget.apiService!.stopWorkOnMachine(
          widget.nrcJobNo!,
          widget.stepNo!,
          widget.machineId!,
          jobPlanId: widget.jobPlanId,
          // NO formData parameter - backend only changes status
        );
        
                         if (result != null) {
          print('✅ Machine stopped successfully');
          
          // Update local state to show "Complete Work" button immediately
          if (mounted) {
            setState(() {
              _status = 'stop';
              _endTime = DateTime.now();
              _isLoading = false;
              _stopButtonJustPressed = true; // Mark that stop was just pressed
            });
          }
          
          widget.onStop?.call();
          
          print('✅ Work stopped - status changed to stop');
        } else{
          print('Failed to stop work on machine');
          setState(() {
            _isLoading = false;
            _status = _status == 'start' ? 'start' : 'hold'; // Revert status on failure
          });
        }
      } catch (e) {
        print('Error stopping work on machine: $e');
        setState(() {
          _isLoading = false;
          _status = _status == 'start' ? 'start' : 'hold'; // Revert status on error
        });
        
        // Show user-friendly error message
        if (mounted) {
          _showWorkflowError(e, 'stop');
        }
      }
      return;
    }

    if (widget.jobNumber == null || widget.stepNo == null || widget.apiService == null) {
      // Fallback to original behavior if API parameters not provided
      setState(() {
        _status = 'stop';
        _endTime = DateTime.now();
      });
      widget.onStop?.call();
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Update JobStep endDate and status
      await widget.apiService!.updateJobPlanningStepFields(
        widget.jobNumber!,
        widget.stepNo!,
        {
          'endDate': _formatDateWithMilliseconds(),
          'status': 'stop',
        },
        jobPlanId: widget.jobPlanId,
        jobStepId: widget.jobStepId,
      );

      // Also update individual step status to accept
      if (widget.stepType != null) {
        // Machine-specific complete is handled by completeWorkOnMachine API
        // No need to call old updateStepStatusGeneric API
      }

      setState(() {
        _status = 'stop';
        _endTime = DateTime.now();
        _isLoading = false;
        _stopButtonJustPressed = true; // Mark that stop was just pressed
      });

      widget.onStop?.call();

      if (mounted) {
        print('✅ Work stopped successfully - status changed to stop');
        // 🧭 For non-machine steps we wait for user to click Complete; machines handled above
      }
    } catch (e) {
      setState(() => _isLoading = false);

      if (mounted) {
        // Log all errors to console for debugging
        print('Stop work error: $e');
        
          print('Stop work validation warning or server error (operation may have succeeded): $e');
      }
    }
  }

  void _showCompletionFormWithContext() async {
    // Use parent context if available, otherwise fallback to widget context
    final contextToUse = widget.parentContext ?? context;
    
    // Check if context is still valid
    if (!mounted || contextToUse == null) {
      print('⚠️ Context not available for showing completion form');
      return;
    }

    // Close the work dialog first (before setState)
    if (mounted && Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
    
    // Set status to 'stop' and mark that stop button was pressed
    setState(() {
      _status = 'stop';
      _endTime = DateTime.now();
      _stopButtonJustPressed = true;
    });

    // Get available quantity from previous step for validation
    int? availableQuantity = _availableQuantity;
    if (availableQuantity == null &&
        widget.apiService != null &&
        widget.jobNumber != null &&
        widget.stepType != null) {
      final fetchedQuantity = await widget.apiService!.getPreviousStepAvailableQuantity(
        widget.jobNumber!,
        widget.stepType!,
        jobPlanId: widget.jobPlanId,
      );
      
      if (mounted) {
        setState(() {
          _availableQuantity = fetchedQuantity;
        });
      }
      availableQuantity = fetchedQuantity;
    }

    // For Dispatch, get dispatch tracking data
    int? totalDispatchedQty;
    dynamic dispatchHistory;
    int? jobTotalQuantity;
    
    // Get job data if not already available (needed for Flap Pasting noUps calculation)
    Map<String, dynamic>? jobDataForDialog = widget.jobData;
    
    // For PaperStore and Dispatch, get job total quantity from purchase orders
    // Also fetch job data for Flap Pasting if not available
    if ((widget.stepType == StepType.paperStore || widget.stepType == StepType.dispatch || 
         (widget.stepType == StepType.flapPasting && jobDataForDialog == null))
        && widget.apiService != null && widget.jobNumber != null) {
      try {
        print('🔍 [PO Fetch] Fetching job data for ${widget.stepType} step');
        
        // For Dispatch, get dispatch tracking data
        if (widget.stepType == StepType.dispatch) {
          final dispatchDetailsResponse = await widget.apiService!.getStepDetailsWithEditability(
            widget.jobNumber!,
            StepType.dispatch,
            jobPlanId: widget.jobPlanId,
          );
          totalDispatchedQty = 0; // Default to 0 if no records
          if (dispatchDetailsResponse.isNotEmpty) {
            final dispatchData = dispatchDetailsResponse[0].data;
            totalDispatchedQty = dispatchData['totalDispatchedQty'] ?? 0;
            dispatchHistory = dispatchData['dispatchHistory'];
          }
        }
        
        // Get purchase orders to calculate total quantity (for both PaperStore and Dispatch)
        // Also get job data for Flap Pasting noUps calculation
        final allJobs = await _job.getJobsByNo(widget.jobNumber!);
        print('🔍 [PO Fetch] All jobs: ${allJobs.length}');
        if (allJobs.isNotEmpty) {
          final job = allJobs[0];
          
          // Build jobData map for Flap Pasting
          if (widget.stepType == StepType.flapPasting && jobDataForDialog == null) {
            jobDataForDialog = {
              'id': job.id,
              'nrcJobNo': job.nrcJobNo,
              'noUps': job.noUps,
              'purchaseOrders': job.purchaseOrders,
            };
            if (job.purchaseOrders != null && job.purchaseOrders!.isNotEmpty) {
              jobDataForDialog!['totalPOQuantity'] = job.purchaseOrders![0].totalPOQuantity;
            }
            print('🔍 [PO Fetch] Fetched jobData for Flap Pasting: noUps=${job.noUps}');
          }
          
          // Calculate total PO quantity for PaperStore and Dispatch
          if ((widget.stepType == StepType.paperStore || widget.stepType == StepType.dispatch) 
              && job.purchaseOrders != null) {
            final List pos = job.purchaseOrders!;
            
            // For PaperStore and Dispatch, use only the PO linked to the job planning
            if ((widget.stepType == StepType.paperStore || widget.stepType == StepType.dispatch) && widget.jobPlanId != null) {
              try {
                print('🔍 [PO Fetch] Fetching job planning for ${widget.stepType}, jobPlanId: ${widget.jobPlanId}');
                final jobPlanningData = await widget.apiService!.getJobPlanningStepsByNrcJobNo(
                  widget.jobNumber!,
                  jobPlanId: widget.jobPlanId,
                );
                
                print('🔍 [PO Fetch] Job planning data: $jobPlanningData');
                
                if (jobPlanningData != null && jobPlanningData is Map) {
                  final purchaseOrderId = jobPlanningData['purchaseOrderId'];
                  print('🔍 [PO Fetch] purchaseOrderId from job planning: $purchaseOrderId');
                  
                  if (purchaseOrderId != null) {
                    // Find matching PO
                    print('🔍 [PO Fetch] Looking for PO with id: $purchaseOrderId');
                    
                    for (var po in pos) {
                      final poId = po.id.toString();
                      final poQty = po.totalPOQuantity;
                      print('🔍 [PO Fetch] Checking PO: id=$poId, quantity=$poQty');
                      if (poId == purchaseOrderId.toString()) {
                        jobTotalQuantity = poQty;
                        print('✅ [PO Fetch] Found matching PO! Quantity: $jobTotalQuantity');
                        break;
                      }
                    }
                    
                    if (jobTotalQuantity == null) {
                      print('⚠️ [PO Fetch] No matching PO found, will use sum');
                    }
                  } else {
                    print('⚠️ [PO Fetch] purchaseOrderId is null in job planning data');
                  }
                } else {
                  print('⚠️ [PO Fetch] jobPlanningData is null or not a Map');
                }
              } catch (e, stackTrace) {
                print('⚠️ [PO Fetch] Error fetching job planning: $e');
                print('⚠️ [PO Fetch] Stack trace: $stackTrace');
              }
            }
            
            // If not found, use sum of all POs
            if (jobTotalQuantity == null) {
              jobTotalQuantity = pos.fold<int>(0, (sum, po) {
                final poQty = po.totalPOQuantity;
                final intQty = poQty is int ? poQty : (int.tryParse(poQty?.toString() ?? '0') ?? 0);
                return sum + intQty;
              });
              print('🔍 [PO Fetch] Total PO Quantity (sum): $jobTotalQuantity');
            }
          }
        }
        
        // Store in state for validation
        if (mounted) {
          setState(() {
            _totalDispatchedQty = totalDispatchedQty;
            _jobTotalQuantity = jobTotalQuantity;
          });
        }
      } catch (e) {
        print('Error fetching tracking data: $e');
      }
    }

    // Show completion form dialog using the context
    final result = await showDialog<Map<String, String>>(
      context: contextToUse,
      barrierDismissible: false, // Prevent closing by tapping outside
      builder: (context) => CompletionFormDialog(
        availableQuantity: _availableQuantity,
        stepType: widget.stepType,
        totalDispatchedQty: totalDispatchedQty,
        dispatchHistory: dispatchHistory,
        jobTotalQuantity: jobTotalQuantity,
        jobData: jobDataForDialog ?? widget.jobData, // Use fetched jobData if available, otherwise fallback to widget.jobData
      ),
    );

    if (result != null) {
      // Complete the work with the form data
      await _completeWorkWithFormData(result);
    } else {
      // If user cancelled, show a message
      print('⚠️ Completion form was cancelled');
      if (mounted) {
        try {
          ScaffoldMessenger.of(contextToUse).showSnackBar(
            const SnackBar(
              content: Text('Work stopped. Please complete the work details later.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        } catch (e) {
          print('Could not show snackbar: $e');
        }
      }
    }
  }

  Future<void> _completeWorkWithFormData(Map<String, String> formData) async {
    if (widget.apiService == null || widget.jobNumber == null || widget.stepNo == null) {
      print('Missing API parameters for completion');
      return;
    }

    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      // Calculate wastage: Previous Step OK Qty - Current Step OK Qty
      int? wastage;
      if (formData['OK Quantity'] != null) {
        final okQuantity = int.tryParse(formData['OK Quantity']!);
        if (okQuantity != null && _availableQuantity != null) {
          wastage = _availableQuantity! - okQuantity;
          if (wastage < 0) wastage = 0; // Prevent negative wastage
        }
      }

      // Add wastage to form data
      if (wastage != null) {
        formData['Wastage'] = wastage.toString();
      }

      // Add complete remark - handle both 'Complete Remark' and 'completeRemark' keys
      if (formData['Complete Remark'] != null && formData['Complete Remark']!.isNotEmpty) {
        formData['completeRemark'] = formData['Complete Remark']!;
        print('🔍 Adding complete remark: ${formData['Complete Remark']}');
      } else if (formData['completeRemark'] != null && formData['completeRemark']!.isNotEmpty) {
        print('🔍 Complete remark already present: ${formData['completeRemark']}');
      }

      // ✅ FIXED: Map form data fields to backend schema for all steps
      if (widget.stepType == StepType.paperStore) {
        // PaperStore backend expects 'available' field
        final availableFromOk = formData['OK Quantity'];
        final availableFromLong = formData['Available Quantity'];
        final availableFromShort = formData['Available Qty'];
        final resolvedAvailable = (availableFromLong?.isNotEmpty == true)
            ? availableFromLong
            : (availableFromShort?.isNotEmpty == true)
                ? availableFromShort
                : availableFromOk;
        if (resolvedAvailable != null) {
          formData['available'] = resolvedAvailable;
          formData['Available Qty'] = resolvedAvailable;
        }
        formData['quantity'] = _availableQuantity?.toString() ?? resolvedAvailable ?? '0';
        // Map 'Complete Remark' to 'remarks' and 'Remarks' for PaperStore backend
        if (formData['Complete Remark'] != null && formData['Complete Remark']!.isNotEmpty) {
          formData['remarks'] = formData['Remarks'] = formData['Complete Remark']!;
        }
      } else if (widget.stepType == StepType.printing) {
        // Printing backend expects 'quantity' field
        if (formData['OK Quantity'] != null) {
          formData['quantity'] = formData['Quantity OK'] = formData['OK Quantity']!;
        }
        // Map 'Complete Remark' to 'remarks' and 'Remarks' for Printing backend
        if (formData['Complete Remark'] != null && formData['Complete Remark']!.isNotEmpty) {
          formData['remarks'] = formData['Remarks'] = formData['Complete Remark']!;
        }
      } else if (widget.stepType == StepType.corrugation) {
        // Corrugation: "Sheets Count" -> 'quantity' field
        if (formData['OK Quantity'] != null) {
          formData['quantity'] = formData['Sheets Count'] = formData['OK Quantity']!;
        }
        // Map 'Complete Remark' to 'remarks' and 'Remarks' for Corrugation backend
        if (formData['Complete Remark'] != null && formData['Complete Remark']!.isNotEmpty) {
          formData['remarks'] = formData['Remarks'] = formData['Complete Remark']!;
        }
      } else if (widget.stepType == StepType.fluteLamination || 
                 widget.stepType == StepType.punching || 
                 widget.stepType == StepType.dieCutting) {
        // Flute Lamination, Punching, Die Cutting backend expects 'quantity' field
        if (formData['OK Quantity'] != null) {
          formData['quantity'] = formData['okQuantity'] = formData['OK Quantity']!;
        }
        // Map 'Complete Remark' to 'remarks' and 'Remarks' for Flute Lamination/Punching/Die Cutting backend
        if (formData['Complete Remark'] != null && formData['Complete Remark']!.isNotEmpty) {
          formData['remarks'] = formData['Remarks'] = formData['Complete Remark']!;
        }
      } else if (widget.stepType == StepType.flapPasting) {
        // Flap Pasting backend expects 'quantity' field
        if (formData['OK Quantity'] != null) {
          formData['quantity'] = formData['Quantity'] = formData['OK Quantity']!;
        }
        // Map 'Complete Remark' to 'remarks' and 'Remarks' for Flap Pasting backend
        if (formData['Complete Remark'] != null && formData['Complete Remark']!.isNotEmpty) {
          formData['remarks'] = formData['Remarks'] = formData['Complete Remark']!;
        }
      } else if (widget.stepType == StepType.qc) {
        // QC backend expects 'quantity' (Pass Quantity) and 'rejectedQty' fields
        if (formData['Pass Quantity'] != null) {
          formData['quantity'] = formData['passQuantity'] = formData['Pass Quantity']!;
        }
        // Set default rejectedQty if not provided
        if (formData['Reject Quantity'] == null) {
          formData['rejectedQty'] = formData['rejectQuantity'] = '0';
        } else {
          formData['rejectedQty'] = formData['rejectQuantity'] = formData['Reject Quantity']!;
        }
        if (formData['Reason for Rejection'] != null) {
          formData['reasonForRejection'] = formData['Reason for Rejection']!;
        }
        // Map 'Complete Remark' to 'remarks' and 'Remarks' for Quality backend
        if (formData['Complete Remark'] != null && formData['Complete Remark']!.isNotEmpty) {
          formData['remarks'] = formData['Remarks'] = formData['Complete Remark']!;
          print('🔍 Mapping Complete Remark to remarks for QC: ${formData['Complete Remark']}');
        }
      } else if (widget.stepType == StepType.dispatch) {
        // Dispatch backend expects 'quantity' field - get from 'No of Boxes' or 'quantity'
        if (formData['No of Boxes'] != null) {
          formData['quantity'] = formData['noOfBoxes'] = formData['No of Boxes']!;
        } else if (formData['OK Quantity'] != null) {
          formData['quantity'] = formData['noOfBoxes'] = formData['No of Boxes'] = formData['OK Quantity']!;
        }
        // Map 'Complete Remark' to 'remarks' and 'Remarks' for Dispatch backend
        if (formData['Complete Remark'] != null && formData['Complete Remark']!.isNotEmpty) {
          formData['remarks'] = formData['Remarks'] = formData['Complete Remark']!;
        }
      }

      // ✅ FIXED: Only call machine completion API for machine-based steps
      // For non-machine steps, let JobStep.dart handle the API call to avoid duplicate calls
      if (widget.machineId != null && widget.nrcJobNo != null) {
        // Call machine completion API
        print('✅ Completing work on machine ${widget.machineId}');
        print('✅ Form data keys: ${formData.keys.toList()}');
        print('✅ Form data values: ${formData.values.toList()}');
        print('✅ Form data complete: $formData');
        final result = await widget.apiService!.completeWorkOnMachine(
          widget.nrcJobNo!,
          widget.stepNo!,
          widget.machineId!,
          formData: formData,
          jobPlanId: widget.jobPlanId,
        );
        print('✅ Machine completion result: $result');
      } else {
        // For non-machine steps, don't call putStepDetails here - it's handled by onComplete callback in JobStep.dart
        print('✅ Non-machine step - completion handled by parent callback');
      }

      // For Dispatch, check if fully dispatched from backend response
      bool isFullyDispatched = false;
      if (widget.stepType == StepType.dispatch) {
        // TODO: Check if fully dispatched by querying the updated JobStep status
        // For now, assume not fully dispatched - backend handles setting JobStep to 'stop' when complete
        isFullyDispatched = false;
      }

      if (mounted) {
        setState(() {
          _status = 'stop';
          _isLoading = false;
        });
        
        // Close the completion dialog first
        Navigator.of(context).pop();
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.stepType == StepType.dispatch && !isFullyDispatched
                ? 'Dispatch recorded. Remaining quantity to be dispatched.'
                : 'Work completed successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }

      // Call the completion callback
      widget.onComplete(formData);
      
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showWorkflowError(e, 'complete');
      }
    }
  }

  void _handleComplete() async {
    if (_formKey.currentState!.validate()) {
      if (_status != 'stop') {
        return;
      }

      setState(() => _isLoading = true);

      try {
        // Prepare form data from all controllers
        final formData = <String, String>{};
        for (var entry in _controllers.entries) {
          formData[entry.key] = entry.value.text;
        }
        formData['Status'] = _status;
        formData['Start Time'] = _startTime?.toString() ?? '';
        formData['End Time'] = _endTime?.toString() ?? DateTime.now().toString();

        print('WorkActionForm - Form Data being sent:');
        print('Full formData: $formData');

        // Only call machine API for machine-based steps (not Paper Store, QC, Dispatch)
        if (widget.jobNumber != null && 
            widget.stepNo != null && 
            widget.apiService != null && 
            widget.machineId != null) { // ✅ Added check: only for steps with machines
          try {
            // Complete work on machine
            print('Completing work on machine ${widget.machineId} for step ${widget.stepNo}');
            final result = await widget.apiService!.completeWorkOnMachine(
              widget.nrcJobNo!,
              widget.stepNo!,
              widget.machineId!,
              formData: formData,
              jobPlanId: widget.jobPlanId,
            );
            print('Machine completion result: $result');
            
            // ✅ NEW: Check if step was auto-completed
            if (result != null && result['data'] != null) {
              final stepCompleted = result['data']['stepCompleted'] == true;
              final completionReason = result['data']['completionReason'] ?? '';
              
              if (stepCompleted) {
                print('🎉 Step auto-completed! Reason: $completionReason');
                
                // Show success dialog
                if (mounted) {
                  await showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (BuildContext dialogContext) {
                      return AlertDialog(
                        title: Row(
                          children: [
                            Icon(Icons.celebration, color: Colors.green, size: 28),
                            SizedBox(width: 12),
                            Expanded(child: Text('Step Completed!')),
                          ],
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('✅ Work data submitted successfully'),
                            SizedBox(height: 8),
                            Text('🎯 $completionReason', 
                              style: TextStyle(fontWeight: FontWeight.w600)),
                            SizedBox(height: 8),
                            Text('The entire step has been completed and is ready for the next stage.',
                              style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: Text('OK', style: TextStyle(fontSize: 16)),
                          ),
                        ],
                      );
                    },
                  );
                }
              } else {
                print('ℹ️ Work submitted. Step not yet complete: $completionReason');
                
                // Show info message
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Work submitted. $completionReason'),
                      backgroundColor: Colors.blue,
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              }
            }
          } catch (e) {
            print('Error completing work: $e');
            // Show error but continue with form data update
            if (mounted) {
              _showWorkflowError(e, 'complete');
            }
            // Continue with form data update even if completion fails
          }
        }

        // Always call onComplete regardless of status update success
        widget.onComplete(formData);

        setState(() => _isLoading = false);

        // Close the dialog after successful completion
        if (mounted) {
          print('✅ Work completed successfully - triggering refresh');
          // Pop with true to indicate refresh is needed
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        print("Error in work completion: $e");
        setState(() => _isLoading = false);

        if (mounted) {
              // Log validation warnings but don't show error popup
              print('Validation warning (operation may have succeeded): $e');
        }
      }
    }
  }

  Color _statusColor() {
    switch (_status) {
      case 'start':
      case 'in_progress':
        return Colors.orange;
      case 'major_hold':
        return Colors.deepOrange;
      case 'paused':
        return Colors.blue;
      case 'hold':
        return Colors.amber;
      case 'stop':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _statusText() {
    switch (_status) {
      case 'start':
        return 'Started';
      case 'in_progress':
        return 'In Progress';
      case 'major_hold':
        return 'MAJOR HOLD';
      case 'paused':
        return 'Paused';
      case 'hold':
        return 'On Hold';
      case 'stop':
        return 'Stopped';
      default:
        return 'Pending';
    }
  }

  // Add these fields to the state
  bool _isStartDisabled = false;
  bool _isPauseDisabled = false;
  bool _isStopDisabled = false;
  
  // Form controllers for completion form
  final TextEditingController _okQuantityController = TextEditingController();
  final TextEditingController _completeRemarkController = TextEditingController();

  // Update button enabled checks
  bool _isStartEnabled() {
    return !_isLoading && !_isStartDisabled && (_status == 'pending' || _status == 'planned' || _status == 'paused');
  }
  bool _isPauseEnabled() {
    return !_isLoading && !_isPauseDisabled && (_status == 'start' || _status == 'in_progress');
  }
  bool _isStopEnabled() {
    return !_isLoading && !_isStopDisabled && (_status == 'start' || _status == 'in_progress');
  }
  bool _isHoldEnabled() {
    return !_isLoading && (_status == 'start' || _status == 'in_progress');
  }
  bool _isResumeEnabled() {
    return !_isLoading && _status == 'hold';
  }
  bool _isMajorHoldEnabled() {
    return !_isLoading && (_status == 'start' || _status == 'in_progress');
  }

  // Check if Complete button should be enabled
  bool _isCompleteEnabled() {
    return !_isLoading && _status == 'stop';
  }

  // Build dynamic form field
  Widget _buildFormField(String fieldName, TextEditingController controller) {
    final isQuantityField = fieldName.toLowerCase().contains('quantity') || 
                           fieldName.toLowerCase().contains('qty') ||
                           fieldName.toLowerCase().contains('sheets count'); // Include "Sheets Count" for corrugation
    final isNumberField = isQuantityField || 
                         fieldName.toLowerCase().contains('wastage') ||
                         fieldName.toLowerCase().contains('boxes') ||
                         fieldName.toLowerCase().contains('sheets');
    
    // Check if field has data (is auto-populated)
    final hasData = controller.text.isNotEmpty;
    
    // Employee ID fields should always be locked when they have data
    final isEmployeeIdField = fieldName.toLowerCase().contains('emp') ||
                             fieldName.toLowerCase().contains('employee') ||
                             fieldName.toLowerCase().contains('operator');
    
    // Step-specific fields that should be locked based on specific rules
    final isStepSpecificLockedField = _isStepSpecificLockedField(fieldName);
    
    // 🎯 Smooth locking logic:
    // - Employee ID fields: Always locked (auto-filled from user)
    // - Step-specific locked fields: Locked only after they have values (smooth UX)
    // - Other fields: Always editable (even if auto-populated)
    final shouldBeLocked = isEmployeeIdField || isStepSpecificLockedField;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        enabled: !shouldBeLocked, // Disable if field has data or is employee ID field
        keyboardType: isNumberField ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: fieldName,
          labelStyle: TextStyle(
            color: shouldBeLocked ? Colors.grey[600] : AppColors.maincolor,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: shouldBeLocked ? Colors.grey[400]! : Colors.grey[300]!,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: shouldBeLocked ? Colors.grey[400]! : AppColors.maincolor, 
              width: 2,
            ),
          ),
          filled: true,
          fillColor: shouldBeLocked ? Colors.grey[200] : Colors.grey[50],
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          hintText: isEmployeeIdField
              ? 'Auto-filled from logged-in user'
              : (isStepSpecificLockedField
                  ? (hasData ? 'Locked - value set' : 'Will be locked after entry')
                  : (hasData 
                      ? 'Auto-filled from job data (editable)'
                      : (isQuantityField && _remainingQuantity != null 
                          ? '0 to $_remainingQuantity (Remaining after other machines)'
                          : (isQuantityField && widget.expectedQuantity != null 
                              ? 'Expected: ${widget.expectedQuantity} (Valid: ${_getValidQuantityRange()})'
                              : 'Enter ${fieldName.toLowerCase()}')))),
          hintStyle: TextStyle(
            color: shouldBeLocked ? Colors.grey[500] : Colors.grey[400], 
            fontSize: 12
          ),
        ),
        validator: (value) {
          // Skip validation for locked fields
          if (shouldBeLocked) {
            return null;
          }
          
          if (value == null || value.isEmpty) {
            return 'Please enter $fieldName';
          }
          
          if (isNumberField) {
            final enteredValue = int.tryParse(value);
            if (enteredValue == null) {
              return 'Please enter a valid number';
            }
            
            // Quantity validation for quantity fields (±20% tolerance)
            // Dynamically get expected quantity from widget or job data
            int? expectedQty = widget.expectedQuantity;
            
            // If no expectedQuantity passed, try to get from job data for accurate validation
            if ((expectedQty == null || expectedQty <= 0) && widget.jobData != null) {
              // Try purchase orders first
              if (widget.jobData!['purchaseOrders'] != null && widget.jobData!['purchaseOrders'] is List) {
                final List pos = widget.jobData!['purchaseOrders'];
                if (pos.isNotEmpty && pos[0]['totalPOQuantity'] != null) {
                  expectedQty = int.tryParse(pos[0]['totalPOQuantity'].toString());
                }
              }
              // Fallback to noUps
              if (expectedQty == null || expectedQty <= 0) {
                expectedQty = int.tryParse(widget.jobData!['noUps']?.toString() ?? '');
              }
            }
            
            // Cascading quantity validation - use remaining quantity (after other machines)
            if (isQuantityField && _remainingQuantity != null && _remainingQuantity! > 0) {
              // Use remaining quantity as the maximum (accounts for other machines' submission)
              final maxAllowed = _remainingQuantity!;
              final minAllowed = 0;
              
              // Debug log to help diagnose issues
              print('🔍 Multi-Machine Quantity Validation: field=$fieldName, available=$_availableQuantity, remaining=$_remainingQuantity, range=$minAllowed-$maxAllowed, entered=$enteredValue');
              
              if (enteredValue < minAllowed || enteredValue > maxAllowed) {
                return 'Quantity must be between $minAllowed and $maxAllowed (Remaining for this machine: $_remainingQuantity)';
              }
            }
            // Fallback to original validation if no available quantity
            else if (isQuantityField && expectedQty != null && expectedQty > 0) {
              // Pure ±20% tolerance without any caps
              final tolerance = (expectedQty * 0.20).round();
              
              final minAllowed = expectedQty - tolerance;
              final maxAllowed = expectedQty + tolerance;
              
              // Debug log to help diagnose issues
              print('🔍 Quantity Validation: field=$fieldName, expected=$expectedQty, tolerance=$tolerance, range=$minAllowed-$maxAllowed, entered=$enteredValue');
              
              if (enteredValue < minAllowed || enteredValue > maxAllowed) {
                return 'Quantity must be between $minAllowed and $maxAllowed (Expected: $expectedQty)';
              }
            }
            
            // Additional validation for specific fields
            if (fieldName.toLowerCase().contains('rejected') && fieldName.toLowerCase().contains('qty')) {
              // Rejected quantity should not exceed the main quantity
              // Use schema field names: quantity, quantityOK, passQuantity
              final mainQtyController = _controllers['quantity'] ?? _controllers['Quantity'] ?? _controllers['quantityOK'] ?? _controllers['passQuantity'];
              if (mainQtyController != null && mainQtyController.text.isNotEmpty) {
                final mainQty = int.tryParse(mainQtyController.text);
                if (mainQty != null && enteredValue > mainQty) {
                  return 'Rejected quantity cannot exceed main quantity ($mainQty)';
                }
              }
            }
            
            // Validation for pass quantity vs reject quantity
            if (fieldName.toLowerCase().contains('pass') && fieldName.toLowerCase().contains('qty')) {
              // Use schema field names for reject quantity
              final rejectQtyController = _controllers['rejectQuantity'] ?? _controllers['rejectedQty'] ?? _controllers['Reject Quantity'];
              if (rejectQtyController != null && rejectQtyController.text.isNotEmpty) {
                final rejectQty = int.tryParse(rejectQtyController.text);
                if (rejectQty != null && enteredValue + rejectQty > widget.expectedQuantity!) {
                  return 'Pass + Reject quantity cannot exceed expected quantity (${widget.expectedQuantity})';
                }
              }
            }
            
            // Validation for wastage fields (0 to available quantity)
            if (fieldName.toLowerCase().contains('wastage')) {
              if (enteredValue < 0) {
                return 'Wastage cannot be negative';
              }
              
              // Use remaining quantity for wastage validation (accounts for other machines)
              if (_remainingQuantity != null && _remainingQuantity! > 0) {
                if (enteredValue > _remainingQuantity!) {
                  return 'Wastage cannot exceed remaining quantity ($_remainingQuantity)';
                }
                print('🔍 Wastage Validation: remaining=$_remainingQuantity, entered=$enteredValue - OK');
              } else {
                // Fallback to main quantity validation
                final mainQtyController = _controllers['quantity'] ?? 
                                         _controllers['Quantity'] ?? 
                                         _controllers['quantityOK'] ?? 
                                         _controllers['Quantity OK'] ??
                                         _controllers['passQuantity'] ?? 
                                         _controllers['Pass Quantity'] ??
                                         _controllers['OK Quantity'] ??
                                         _controllers['Qty Sheet'] ??
                                         _controllers['Sheets Count'];
                
                if (mainQtyController != null && mainQtyController.text.isNotEmpty) {
                  final mainQty = int.tryParse(mainQtyController.text);
                  if (mainQty != null && mainQty > 0) {
                    final maxWastage = (mainQty * 0.20).round();
                    if (enteredValue > maxWastage) {
                      return 'Wastage cannot exceed 20% of quantity (max $maxWastage for qty $mainQty)';
                    }
                    print('🔍 Wastage Validation: mainQty=$mainQty, maxWastage=$maxWastage, entered=$enteredValue - OK');
                  } else {
                    return 'Please enter a valid quantity first';
                  }
                } else {
                  return 'Please enter quantity before entering wastage';
                }
              }
            }
            
            // Validation for GSM fields
            if (fieldName.toLowerCase().contains('gsm')) {
              if (enteredValue < 50 || enteredValue > 500) {
                return 'GSM should be between 50 and 500';
              }
            }
            
            // Validation for employee ID format
            if (fieldName.toLowerCase().contains('emp') && fieldName.toLowerCase().contains('id')) {
              if (enteredValue < 1000 || enteredValue > 99999) {
                return 'Employee ID must be between 1000 and 99999';
              }
            }
            
            // Validation for box count
            if (fieldName.toLowerCase().contains('no of boxes')) {
              if (enteredValue < 1) {
                return 'Number of boxes must be at least 1';
              }
            }
          }
          
          return null;
        },
      ),
    );
  }

  // Helper method to get valid quantity range (dynamically calculated)
  String _getValidQuantityRange() {
    // Try to get fresh quantity from job data first (most accurate)
    int? expectedQty = widget.expectedQuantity;
    
    // If no expectedQuantity passed, try to get from job data
    if ((expectedQty == null || expectedQty <= 0) && widget.jobData != null) {
      // Try purchase orders first
      if (widget.jobData!['purchaseOrders'] != null && widget.jobData!['purchaseOrders'] is List) {
        final List pos = widget.jobData!['purchaseOrders'];
        if (pos.isNotEmpty && pos[0]['totalPOQuantity'] != null) {
          expectedQty = int.tryParse(pos[0]['totalPOQuantity'].toString());
        }
      }
      // Fallback to noUps
      if (expectedQty == null || expectedQty <= 0) {
        expectedQty = int.tryParse(widget.jobData!['noUps']?.toString() ?? '');
      }
    }
    
    if (expectedQty == null || expectedQty <= 0) {
      return 'N/A';
    }
    
    // Pure ±20% tolerance without caps
    final tolerance = (expectedQty * 0.20).round();
    
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
                // Only show form fields if there are any (most steps have no fields in the work form)
                if (_controllers.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _controllers.entries.map((entry) {
                        return _buildFormField(entry.key, entry.value);
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
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
                
                // Show major hold warning if status is major_hold
                if (_status == 'major_hold') ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.deepOrange.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.deepOrange[700], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'MAJOR HOLD: This job is on major hold. Only admin/planner can resume.',
                            style: TextStyle(
                              color: Colors.deepOrange[700],
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
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
        // Always show action buttons (Start, Hold, Major Hold, Stop, Resume, Close)
        _buildActionButtons(),
      ],
    );
  }

  // Build action buttons (Start, Hold, Major Hold, Stop) - All in one row
  Widget _buildActionButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // All buttons in a single row
        Row(
          children: [
            // Start Button
            if (_isStartEnabled()) ...[
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 2,
                  ),
                  onPressed: _handleStart,
                  child: _isLoading && _status == 'pending'
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.play_arrow, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Start',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            
            // Hold Button
            if (_isHoldEnabled()) ...[
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _handleHold,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.pause, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Hold',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            
            // Major Hold Button
            if (_isMajorHoldEnabled()) ...[
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _handleMajorHold,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Major Hold',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            
            // Resume Button
            if (_isResumeEnabled()) ...[
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 2,
                  ),
                  onPressed: _handleResume,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_arrow, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Resume',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            
            // Stop Button
            if (_isStopEnabled()) ...[
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 2,
                  ),
                  onPressed: _handleStop,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.stop, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Stop',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        
        // Show "Complete Work" button when status is 'stop' - SAME FLOW FOR ALL STEPS
        if (_status == 'stop') ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _showCompletionFormWithContext,
              icon: Icon(Icons.check_circle, size: 18),
              label: const Text(
                'Complete Work',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
        
        const SizedBox(height: 12),
        
        // Close Button - Always functional, even during loading
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () {
              // Always allow closing the dialog, even during loading
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
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
    );
  }

  // Build completion form content
  Widget _buildCompletionFormContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // OK Quantity Field
        TextFormField(
          controller: _okQuantityController,
          decoration: InputDecoration(
            labelText: 'OK Quantity *',
            hintText: _adjustedAvailableQuantity != null 
                ? 'Enter OK quantity (0-${_adjustedAvailableQuantity})'
                : 'Enter OK quantity',
            border: const OutlineInputBorder(),
            helperText: _adjustedAvailableQuantity != null 
                ? widget.stepType == StepType.flapPasting && _availableQuantity != null && widget.jobData != null
                    ? 'Must be between 0 and ${_adjustedAvailableQuantity} (Punching OK: ${_availableQuantity} × No. of Ups: ${widget.jobData!['noUps'] is int ? widget.jobData!['noUps'] : (int.tryParse(widget.jobData!['noUps'].toString()) ?? 1)})'
                    : 'Must be between 0 and ${_adjustedAvailableQuantity}'
                : 'Enter the quantity that passed quality check',
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter OK quantity';
            }
            
            final okQuantity = int.tryParse(value);
            if (okQuantity == null) {
              return 'Please enter a valid number';
            }
            
            if (okQuantity < 0) {
              return 'OK quantity cannot be negative';
            }
            
            if (_adjustedAvailableQuantity != null && okQuantity > _adjustedAvailableQuantity!) {
              return 'OK quantity cannot exceed available quantity (${_adjustedAvailableQuantity})';
            }
            
            return null;
          },
        ),
        const SizedBox(height: 16),
        
        // Complete Remark Field
        TextFormField(
          controller: _completeRemarkController,
          decoration: InputDecoration(
            labelText: 'Complete Remark',
            hintText: 'Enter completion remarks (optional)',
            border: const OutlineInputBorder(),
            helperText: 'Optional remarks about the completion',
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        
        // Complete Work Button
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
            onPressed: _handleCompleteWithForm,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, size: 20),
                      SizedBox(width: 8),
                      Text(
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
        
        // Cancel Button
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
            child: const Text('Cancel'),
          ),
        ),
      ],
    );
  }

  // Handle complete with form data
  void _handleCompleteWithForm() async {
    // Validate form
    if (_okQuantityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter OK quantity'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final okQuantity = int.tryParse(_okQuantityController.text);
    if (okQuantity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid number for OK quantity'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (okQuantity < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OK quantity cannot be negative'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_availableQuantity != null && okQuantity > _availableQuantity!) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('OK quantity cannot exceed available quantity ($_availableQuantity)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final formData = <String, String>{
        'OK Quantity': _okQuantityController.text,
        'Complete Remark': _completeRemarkController.text,
      };

      // Complete the work with the form data
      await _completeWorkWithFormData(formData);
    } catch (e) {
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

}

class CompletionFormDialog extends StatefulWidget {
  final int? availableQuantity;
  final StepType? stepType;
  final int? totalDispatchedQty; // For Dispatch - cumulative dispatched so far
  final dynamic dispatchHistory; // For Dispatch - array of previous dispatches
  final int? jobTotalQuantity; // For Dispatch - total job quantity
  final Map<String, dynamic>? jobData; // Job data for validation (e.g., noUps for FlapPasting)

  const CompletionFormDialog({
    super.key,
    this.availableQuantity,
    this.stepType,
    this.totalDispatchedQty,
    this.dispatchHistory,
    this.jobTotalQuantity,
    this.jobData,
  });

  @override
  State<CompletionFormDialog> createState() => _CompletionFormDialogState();
}

class _CompletionFormDialogState extends State<CompletionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _okQuantityController = TextEditingController();
  final _passQuantityController = TextEditingController(); // For QC: Pass Quantity
  final _rejectQuantityController = TextEditingController(); // For QC: Reject Quantity
  final _rejectReasonController = TextEditingController(); // For QC: Reason for Rejection
  final _completeRemarkController = TextEditingController();
  bool _isLoading = false;

  // Get adjusted available quantity for Flap Pasting (multiplies by No. of Ups)
  int? get _adjustedAvailableQuantity {
    if (widget.stepType == StepType.flapPasting && widget.availableQuantity != null && widget.jobData != null) {
      final noUps = widget.jobData!['noUps'];
      print('🔍 [CompletionFormDialog] Flap Pasting - availableQuantity: ${widget.availableQuantity}, jobData: ${widget.jobData?.keys.toList()}, noUps: $noUps');
      if (noUps != null) {
        final rawNoUps = noUps is int ? noUps : int.tryParse(noUps.toString());
        final noUpsInt = (rawNoUps == null || rawNoUps <= 0) ? 1 : rawNoUps;
        final adjusted = widget.availableQuantity! * noUpsInt;
        print('🔍 [CompletionFormDialog] Calculated adjusted quantity: $adjusted (${widget.availableQuantity} × $noUpsInt)');
        return adjusted;
      } else {
        print('⚠️ [CompletionFormDialog] noUps is null in jobData');
      }
    } else {
      print('🔍 [CompletionFormDialog] Not Flap Pasting or missing data - stepType: ${widget.stepType}, availableQuantity: ${widget.availableQuantity}, jobData: ${widget.jobData != null}');
    }
    return widget.availableQuantity;
  }

  // Get display text for available quantity (shows calculation for Flap Pasting)
  String get _availableQuantityDisplayText {
    if (widget.stepType == StepType.flapPasting && widget.availableQuantity != null && widget.jobData != null) {
      final noUps = widget.jobData!['noUps'];
      if (noUps != null) {
        final rawNoUps = noUps is int ? noUps : int.tryParse(noUps.toString());
        final noUpsInt = (rawNoUps == null || rawNoUps <= 0) ? 1 : rawNoUps;
        final adjustedQty = widget.availableQuantity! * noUpsInt;
        return 'Available from previous step: ${widget.availableQuantity} (sheets) × No. of Ups: $noUpsInt = $adjustedQty (boxes)';
      }
    }
    return 'Available from previous step: ${widget.availableQuantity}';
  }

  // Get previous step display name for helper text
  String _getPreviousStepDisplayName(StepType? stepType) {
    if (stepType == null) return 'PaperStore';
    switch (stepType) {
      case StepType.printing:
      case StepType.corrugation:
        return 'PaperStore';
      case StepType.fluteLamination:
        return 'Printing';
      case StepType.punching:
        return 'Flute Lamination';
      case StepType.flapPasting:
        return 'Punching';
      case StepType.qc:
        return 'Flap Pasting';
      case StepType.dispatch:
        return 'Quality Control';
      default:
        return 'previous step';
    }
  }

  // Helper method to build dispatch progress row
  Widget _buildDispatchProgressRow(String label, int value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Text(
            value.toString(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color.fromRGBO(
                (color.red * 0.6).round(),
                (color.green * 0.6).round(),
                (color.blue * 0.6).round(),
                1.0,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _okQuantityController.dispose();
    _passQuantityController.dispose();
    _rejectQuantityController.dispose();
    _rejectReasonController.dispose();
    _completeRemarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.white,
      title: const Text('Complete Work'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Please enter the completion details:',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              
              // Partial Dispatch Tracking (for Dispatch step)
              if (widget.stepType == StepType.dispatch && widget.totalDispatchedQty != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3), width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.local_shipping, color: Colors.orange[700], size: 24),
                          const SizedBox(width: 8),
                          Text(
                            'Partial Dispatch Tracking',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[900],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (widget.jobTotalQuantity != null) ...[
                        _buildDispatchProgressRow('Total Order Quantity', widget.jobTotalQuantity!, Colors.blue),
                        const SizedBox(height: 8),
                        _buildDispatchProgressRow('Already Dispatched', widget.totalDispatchedQty!, Colors.green),
                        const SizedBox(height: 8),
                        _buildDispatchProgressRow('Remaining', widget.jobTotalQuantity! - widget.totalDispatchedQty!, Colors.orange),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: widget.totalDispatchedQty! / widget.jobTotalQuantity!,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.green[600]!),
                          minHeight: 8,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${((widget.totalDispatchedQty! / widget.jobTotalQuantity!) * 100).toStringAsFixed(1)}% Completed',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.green[700],
                          ),
                        ),
                      ] else ...[
                        _buildDispatchProgressRow('Already Dispatched', widget.totalDispatchedQty!, Colors.green),
                      ],
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 16),
            
            // PO Quantity Display (for PaperStore only)
            if (widget.stepType == StepType.paperStore) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shopping_cart, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.jobTotalQuantity != null 
                            ? 'PO Quantity: ${widget.jobTotalQuantity}' 
                            : 'PO Quantity: Loading...',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            
            // Available Quantity Display (for reference) - Not shown for Dispatch and PaperStore as they have their own tracking UI
            if (widget.availableQuantity != null && widget.stepType != StepType.dispatch && widget.stepType != StepType.paperStore) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _availableQuantityDisplayText,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            
            // QC-specific fields (Pass/Reject Quantity and Reason)
            if (widget.stepType == StepType.qc) ...[
              TextFormField(
                controller: _passQuantityController,
                decoration: InputDecoration(
                  labelText: 'Pass Quantity *',
                  hintText: widget.availableQuantity != null 
                      ? 'Enter pass quantity (0-${widget.availableQuantity})'
                      : 'Enter pass quantity',
                  border: const OutlineInputBorder(),
                  helperText: widget.availableQuantity != null 
                      ? 'Must be between 0 and ${widget.availableQuantity} (Available from ${_getPreviousStepDisplayName(widget.stepType)})'
                      : 'Enter quantity that passed quality check',
                ),
                keyboardType: TextInputType.number,
                autofocus: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter pass quantity';
                  }
                  
                  final quantity = int.tryParse(value);
                  if (quantity == null) {
                    return 'Please enter a valid number';
                  }
                  
                  if (quantity < 0) {
                    return 'Pass quantity cannot be negative';
                  }
                  
                  if (widget.availableQuantity != null && quantity > widget.availableQuantity!) {
                    return 'Pass quantity cannot exceed available quantity (${widget.availableQuantity})';
                  }
                  
                  // Check if Pass + Reject doesn't exceed available
                  if (_rejectQuantityController.text.isNotEmpty) {
                    final rejectQty = int.tryParse(_rejectQuantityController.text);
                    if (rejectQty != null && quantity + rejectQty > widget.availableQuantity!) {
                      return 'Pass + Reject quantity cannot exceed available quantity (${widget.availableQuantity})';
                    }
                  }
                  
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _rejectQuantityController,
                decoration: InputDecoration(
                  labelText: 'Reject Quantity *',
                  hintText: widget.availableQuantity != null 
                      ? 'Enter reject quantity (0-${widget.availableQuantity})'
                      : 'Enter reject quantity',
                  border: const OutlineInputBorder(),
                  helperText: 'Enter quantity that failed quality check',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter reject quantity';
                  }
                  
                  final quantity = int.tryParse(value);
                  if (quantity == null) {
                    return 'Please enter a valid number';
                  }
                  
                  if (quantity < 0) {
                    return 'Reject quantity cannot be negative';
                  }
                  
                  if (widget.availableQuantity != null && quantity > widget.availableQuantity!) {
                    return 'Reject quantity cannot exceed available quantity (${widget.availableQuantity})';
                  }
                  
                  // Check if Pass + Reject doesn't exceed available
                  if (_passQuantityController.text.isNotEmpty) {
                    final passQty = int.tryParse(_passQuantityController.text);
                    if (passQty != null && passQty + quantity > widget.availableQuantity!) {
                      return 'Pass + Reject quantity cannot exceed available quantity (${widget.availableQuantity})';
                    }
                  }
                  
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _rejectReasonController,
                decoration: InputDecoration(
                  labelText: 'Reason for Rejection *',
                  hintText: 'Enter reason for rejection',
                  border: const OutlineInputBorder(),
                  helperText: 'Required if reject quantity > 0',
                ),
                maxLines: 2,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    // If reason is provided, check if reject quantity > 0
                    final rejectQty = int.tryParse(_rejectQuantityController.text);
                    if (rejectQty == null || rejectQty == 0) {
                      return 'No reject quantity to provide reason for';
                    }
                  } else {
                    // If no reason, check if reject quantity > 0
                    final rejectQty = int.tryParse(_rejectQuantityController.text);
                    if (rejectQty != null && rejectQty > 0) {
                      return 'Reason is required when reject quantity > 0';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
            ] else ...[
              // Quantity Field (Available Quantity for PaperStore, OK Quantity for others, No of Boxes for Dispatch)
              TextFormField(
                controller: _okQuantityController,
                decoration: InputDecoration(
                  labelText: widget.stepType == StepType.paperStore 
                      ? 'Issued Quantity *' 
                      : widget.stepType == StepType.dispatch 
                          ? 'No of Boxes to Dispatch *' 
                          : widget.stepType == StepType.corrugation
                              ? 'Sheets Count *'
                              : 'OK Quantity *',
                  hintText: widget.stepType == StepType.dispatch 
                      ? (widget.jobTotalQuantity != null && widget.totalDispatchedQty != null
                          ? 'Enter quantity to dispatch (remaining: ${widget.jobTotalQuantity! - widget.totalDispatchedQty!})'
                          : 'Enter quantity to dispatch')
                      : (widget.availableQuantity != null 
                          ? widget.stepType == StepType.paperStore
                              ? 'Enter issued quantity (0-${widget.availableQuantity})'
                              : widget.stepType == StepType.corrugation
                                  ? 'Enter sheets count (0-${widget.availableQuantity})'
                                  : widget.stepType == StepType.flapPasting
                                      ? 'Enter OK quantity (0-${_adjustedAvailableQuantity})'
                                      : 'Enter OK quantity (0-${widget.availableQuantity})'
                          : widget.stepType == StepType.paperStore
                              ? 'Enter issued quantity'
                              : widget.stepType == StepType.corrugation
                                  ? 'Enter sheets count'
                                  : 'Enter OK quantity (available from ${_getPreviousStepDisplayName(widget.stepType)})'),
                  border: const OutlineInputBorder(),
                  helperText: widget.stepType == StepType.dispatch 
                      ? (widget.jobTotalQuantity != null && widget.totalDispatchedQty != null
                          ? 'Enter quantity to dispatch (remaining: ${widget.jobTotalQuantity! - widget.totalDispatchedQty!})'
                          : 'Enter quantity to dispatch')
                      : (widget.availableQuantity != null 
                          ? widget.stepType == StepType.flapPasting
                              ? 'Must be between 0 and ${_adjustedAvailableQuantity} (Available from ${_getPreviousStepDisplayName(widget.stepType)})'
                              : 'Must be between 0 and ${widget.availableQuantity} (Available from ${_getPreviousStepDisplayName(widget.stepType)})'
                          : widget.stepType == StepType.paperStore
                              ? 'Enter the issued quantity'
                              : widget.stepType == StepType.corrugation
                                  ? 'Enter sheets count'
                                  : 'Enter OK quantity (0 to ${_getPreviousStepDisplayName(widget.stepType)} available quantity)'),
                ),
                keyboardType: TextInputType.number,
                autofocus: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return widget.stepType == StepType.dispatch 
                        ? 'Please enter quantity to dispatch'
                        : widget.stepType == StepType.paperStore 
                            ? 'Please enter issued quantity'
                            : widget.stepType == StepType.corrugation
                                ? 'Please enter sheets count'
                                : 'Please enter OK quantity';
                  }
                  
                  final quantity = int.tryParse(value);
                  if (quantity == null) {
                    return 'Please enter a valid number';
                  }
                  
                  if (quantity < 0) {
                    return 'Quantity cannot be negative';
                  }
                  
                  // For Flap Pasting, validate against (Punching OK Quantity * No. of Ups)
                  if (widget.stepType == StepType.flapPasting && widget.availableQuantity != null && widget.jobData != null) {
                    final noUps = widget.jobData!['noUps'];
                    if (noUps != null) {
                      final rawNoUps = noUps is int ? noUps : int.tryParse(noUps.toString());
                      final noUpsInt = (rawNoUps == null || rawNoUps <= 0) ? 1 : rawNoUps;
                      final maxAllowed = widget.availableQuantity! * noUpsInt;
                      if (quantity > maxAllowed) {
                        return 'OK quantity cannot exceed ${maxAllowed} (Punching OK: ${widget.availableQuantity} × No. of Ups: $noUpsInt)';
                      }
                    }
                  }
                  // For Dispatch, validate against remaining quantity
                  else if (widget.stepType == StepType.dispatch && widget.jobTotalQuantity != null && widget.totalDispatchedQty != null) {
                    final remaining = widget.jobTotalQuantity! - widget.totalDispatchedQty!;
                    if (quantity > remaining) {
                      return 'Cannot dispatch more than remaining quantity ($remaining)';
                    }
                  } else if (widget.availableQuantity != null) {
                    // For Flap Pasting, use adjusted quantity; for others, use raw availableQuantity
                    final maxAllowed = widget.stepType == StepType.flapPasting 
                        ? _adjustedAvailableQuantity 
                        : widget.availableQuantity;
                    
                    if (maxAllowed != null && quantity > maxAllowed) {
                      final fieldName = widget.stepType == StepType.paperStore 
                          ? 'issued quantity' 
                          : widget.stepType == StepType.corrugation 
                              ? 'sheets count' 
                              : 'OK quantity';
                      return '$fieldName cannot exceed available quantity ($maxAllowed)';
                    }
                  }
                  
                  return null;
                },
              ),
              const SizedBox(height: 16),
            ],
            
            // Complete Remark Field
            TextFormField(
              controller: _completeRemarkController,
              decoration: InputDecoration(
                labelText: 'Complete Remark',
                hintText: 'Enter completion remarks (optional)',
                border: const OutlineInputBorder(),
                helperText: 'Optional remarks about the completion',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            
          ],
        ),
      ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleComplete,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Complete'),
        ),
      ],
    );
  }

  void _handleComplete() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final formData = <String, String>{};
      
      // Add quantity field - use "Available Quantity" for PaperStore, "OK Quantity" for others, "No of Boxes" for Dispatch
      if (widget.stepType == StepType.paperStore) {
        formData['Available Quantity'] = _okQuantityController.text;
      } else if (widget.stepType == StepType.dispatch) {
        formData['No of Boxes'] = _okQuantityController.text;
        formData['quantity'] = _okQuantityController.text; // Also add quantity field for backend
      } else if (widget.stepType == StepType.qc) {
        // QC-specific fields
        formData['Pass Quantity'] = _passQuantityController.text;
        formData['Reject Quantity'] = _rejectQuantityController.text;
        formData['Reason for Rejection'] = _rejectReasonController.text;
        // Also add for backwards compatibility
        formData['passQuantity'] = _passQuantityController.text;
        formData['rejectQuantity'] = _rejectQuantityController.text;
        formData['rejectedQty'] = _rejectQuantityController.text;
        formData['reasonForRejection'] = _rejectReasonController.text;
      } else {
        formData['OK Quantity'] = _okQuantityController.text;
      }
      
      formData['Complete Remark'] = _completeRemarkController.text;

      // Calculate wastage if available quantity is present (not for Dispatch and not for QC)
      if (widget.availableQuantity != null && widget.stepType != StepType.dispatch && widget.stepType != StepType.qc) {
        final quantity = int.tryParse(_okQuantityController.text);
        if (quantity != null) {
          final wastage = widget.availableQuantity! - quantity;
          formData['Wastage'] = wastage.toString();
        }
      }

      Navigator.pop(context, formData);
    } catch (e) {
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}