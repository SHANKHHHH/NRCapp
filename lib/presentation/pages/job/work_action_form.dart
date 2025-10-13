import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nrc/data/datasources/job_api.dart';
import '../../../constants/colors.dart';
import '../process/JobApiService.dart';
import '../process/StepDataManager.dart';
import '../../../data/models/job_step_models.dart';

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
  final void Function(String)? onResume;
  final String? jobNumber; // Add jobNumber parameter
  final int? stepNo; // Add stepNo parameter
  final JobApiService? apiService; // Add apiService parameter
  final int? expectedQuantity; // Add expectedQuantity parameter for validation
  final StepType? stepType; // Add stepType parameter for dynamic fields
  final Map<String, dynamic>? jobData; // Add jobData parameter for auto-population
  final String? machineId; // Add machineId parameter for machine-specific work
  final String? nrcJobNo; // Add nrcJobNo parameter

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
    this.onResume,
    this.hasData = false,
    this.jobNumber, // Add jobNumber
    this.stepNo, // Add stepNo
    this.apiService, // Add apiService
    this.expectedQuantity, // Add expectedQuantity
    this.stepType, // Add stepType
    this.jobData, // Add jobData
    this.machineId, // Add machineId
    this.nrcJobNo, // Add nrcJobNo
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
  bool _isLoadingAvailableQty = false;

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
  Future<void> _loadAvailableQuantity() async {
    if (widget.apiService == null || widget.jobNumber == null || widget.stepType == null) {
      return;
    }

    setState(() {
      _isLoadingAvailableQty = true;
    });

    try {
      final availableQty = await widget.apiService!.getPreviousStepAvailableQuantity(
        widget.jobNumber!, 
        widget.stepType!
      );
      
      if (mounted) {
        setState(() {
          _availableQuantity = availableQty;
          _isLoadingAvailableQty = false;
        });
        print('🔍 Loaded available quantity: $_availableQuantity for step: ${widget.stepType!.name}');
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
    _initializeControllers();
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
        }
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      // For machine-specific work, get machine status instead of step status
      if (widget.machineId != null && widget.nrcJobNo != null) {
        // Get available machines to find the current machine status
        final machinesData = await widget.apiService!.getAvailableMachines(widget.nrcJobNo!, widget.stepNo!);
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
            
            setState(() {
              if (machineStatus == 'stop' || endDate != null) {
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
              } else {
                // Machine is available - show start button
                _isStartDisabled = false;
                _isPauseDisabled = true;
                _isStopDisabled = true;
                print('Machine is available, showing start button');
              }
            });
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
      
      setState(() => _isLoading = true);
      
      try {
        final formData = _collectFormData();
        final result = await widget.apiService!.startWorkOnMachine(
          widget.nrcJobNo!,
          widget.stepNo!,
          widget.machineId!,
          formData: formData,
        );
        
        if (result != null) {
          print('Work started on machine: ${widget.machineId}');
          _startTime = DateTime.now();
          
          setState(() {
            _status = 'start';
            _isLoading = false;
          });
          
          widget.onStart?.call();
          print('✅ Work started on machine - data will auto-refresh');
        } else {
          print('Failed to start work on machine');
          setState(() => _isLoading = false);
        }
      } catch (e) {
        print('Error starting work on machine: $e');
        setState(() => _isLoading = false);
        
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

    // Show remarks dialog
    final remarks = await _showRemarksDialog('Hold Work');
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

  void _handleResume() async {
    if (_status != 'hold') {
      return;
    }

    // Show remarks dialog
    final remarks = await _showRemarksDialog('Resume Work');
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

  Future<String?> _showRemarksDialog(String title) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter remarks (optional)',
            border: OutlineInputBorder(),
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

  /// Show user-friendly workflow error messages
  void _showWorkflowError(dynamic error, String action) {
    String errorMessage = 'Failed to $action work';
    
    // Parse error to get user-friendly message
    final errorStr = error.toString();
    
    if (errorStr.contains('DioException') || errorStr.contains('400')) {
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
        errorMessage = 'Cannot $action this step. Please check if previous steps are completed.';
      }
    } else if (errorStr.contains('403') || errorStr.contains('Access denied') || errorStr.contains('do not have access')) {
      errorMessage = 'You do not have access to this machine';
    } else if (errorStr.contains('404')) {
      errorMessage = 'Job step not found';
    } else if (errorStr.contains('401')) {
      errorMessage = 'Please login again';
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

    // If this is machine-specific work, use machine API
    if (widget.machineId != null && widget.nrcJobNo != null && widget.stepNo != null && widget.apiService != null) {
      setState(() => _isLoading = true);
      
      try {
        final formData = _collectFormData();
        final result = await widget.apiService!.stopWorkOnMachine(
          widget.nrcJobNo!,
          widget.stepNo!,
          widget.machineId!,
          formData: formData,
        );
        
        if (result != null) {
          print('Work stopped on machine: ${widget.machineId}');
          // Check if all machines are completed
          if (result['allMachinesCompleted'] == true) {
            print('All machines completed for this step');
          }
          
          setState(() {
            _status = 'stop';
            _endTime = DateTime.now();
            _isLoading = false;
          });
          
          widget.onStop?.call();
          print('✅ Work stopped successfully - data will auto-refresh');
        } else {
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
      // Update JobStep endDate
      await widget.apiService!.updateJobPlanningStepFields(
        widget.jobNumber!,
        widget.stepNo!,
        {'endDate': _formatDateWithMilliseconds()},
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
      });

      widget.onStop?.call();

      if (mounted) {
        print('✅ Work stopped successfully - data will auto-refresh');
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
            );
            print('Machine completion result: $result');
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

  // Update button enabled checks
  bool _isStartEnabled() {
    return !_isLoading && !_isStartDisabled && (_status == 'pending' || _status == 'paused');
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
                      : (isQuantityField && _availableQuantity != null 
                          ? '0 to $_availableQuantity (Available from previous step)'
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
            
            // Cascading quantity validation - use available quantity from previous step
            if (isQuantityField && _availableQuantity != null && _availableQuantity! > 0) {
              // Use available quantity from previous step as the maximum
              final maxAllowed = _availableQuantity!;
              final minAllowed = 0;
              
              // Debug log to help diagnose issues
              print('🔍 Cascading Quantity Validation: field=$fieldName, available=$_availableQuantity, range=$minAllowed-$maxAllowed, entered=$enteredValue');
              
              if (enteredValue < minAllowed || enteredValue > maxAllowed) {
                return 'Quantity must be between $minAllowed and $maxAllowed (Available: $_availableQuantity)';
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
              
              // Use available quantity from previous step for wastage validation
              if (_availableQuantity != null && _availableQuantity! > 0) {
                if (enteredValue > _availableQuantity!) {
                  return 'Wastage cannot exceed available quantity ($_availableQuantity)';
                }
                print('🔍 Wastage Validation: available=$_availableQuantity, entered=$enteredValue - OK');
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
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _controllers.entries.map((entry) {
                      return _buildFormField(entry.key, entry.value);
                    }).toList(),
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
                            : Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(Icons.check_circle, size: 24),
                                  Text(
                                    'Start',
                                    style: TextStyle(color: Colors.transparent),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isHoldEnabled() ? Colors.orange : Colors.grey,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _isHoldEnabled() ? _handleHold : null,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(Icons.pause_circle, size: 24),
                            Text(
                              'Hold',
                              style: TextStyle(color: Colors.transparent),
                            ),
                          ],
                        ),
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
                        child: _isLoading && (_status == 'start' || _status == 'in_progress')
                            ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                            : Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(Icons.cancel, size: 24),
                                  Text(
                                    'Stop',
                                    style: TextStyle(color: Colors.transparent),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isResumeEnabled() ? Colors.green : Colors.grey,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _isResumeEnabled() ? _handleResume : null,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(Icons.play_circle, size: 24),
                            Text(
                              'Resume',
                                    style: TextStyle(color: Colors.transparent),
                                  ),
                                ],
                              ),
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
                child: _isLoading && _status == 'stop'
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