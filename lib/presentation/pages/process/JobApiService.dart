import 'dart:async';
import 'package:nrc/data/models/Job.dart';

import '../../../data/datasources/job_api.dart';
import '../../../data/models/job_step_models.dart';
import '../../../utils/field_editability.dart';

class JobApiService {
  final JobApi _jobApi;

  JobApiService(this._jobApi);

  // Lightweight in-memory caching with TTL and request coalescing to reduce GET load
  static const Duration _defaultTtl = Duration(seconds: 45);
  // Static caches to persist across page rebuilds/reopens
  static final Map<String, _CacheEntry<dynamic>> _cache = {};
  static final Map<String, Future<dynamic>> _inflight = {};

  // Build cache keys
  String _keyPlanningStep(String job, int stepNo) => 'planningStep:$job:$stepNo';
  String _keyPlanningSteps(String job) => 'planningSteps:$job';
  String _keyPaperStore(String job) => 'paperStore:$job';
  String _keyJobDetails(String job) => 'jobDetails:$job';
  String _keyStepType(String job, StepType type) => 'stepType:${type.toString()}:$job';

  // Generic cached getter for Maps
  Future<Map<String, dynamic>?> _getOrFetchMap(
    String key,
    Future<Map<String, dynamic>?> Function() fetcher, {
    Duration ttl = _defaultTtl,
  }) async {
    final existing = _cache[key];
    if (existing != null && existing.isFresh(ttl)) {
      return existing.value as Map<String, dynamic>?;
    }
    if (_inflight.containsKey(key)) {
      return await _inflight[key] as Map<String, dynamic>?;
    }
    final future = fetcher().then((value) {
      _cache[key] = _CacheEntry<dynamic>(value);
      _inflight.remove(key);
      return value;
    });
    _inflight[key] = future;
    return await future;
  }

  // Generic cached getter for Lists (used for Job details)
  Future<List<Job>?> _getOrFetchJobList(
    String key,
    Future<List<Job>?> Function() fetcher, {
    Duration ttl = _defaultTtl,
  }) async {
    final existing = _cache[key];
    if (existing != null && existing.isFresh(ttl)) {
      return existing.value as List<Job>?;
    }
    if (_inflight.containsKey(key)) {
      return await _inflight[key] as List<Job>?;
    }
    final future = fetcher().then((value) {
      _cache[key] = _CacheEntry<dynamic>(value);
      _inflight.remove(key);
      return value;
    });
    _inflight[key] = future;
    return await future;
  }

  void _invalidateKeys(Iterable<String> keys) {
    for (final k in keys) {
      _cache.remove(k);
    }
  }

  void invalidateJobCaches(String jobNumber, {int? stepNo, StepType? stepType}) {
    final keys = <String>{
      _keyPlanningSteps(jobNumber),
      _keyPaperStore(jobNumber),
      _keyJobDetails(jobNumber),
    };
    if (stepNo != null) keys.add(_keyPlanningStep(jobNumber, stepNo));
    if (stepType != null) keys.add(_keyStepType(jobNumber, stepType));
    _invalidateKeys(keys);
    
    print('🔄 Cache invalidated for job: $jobNumber, stepNo: $stepNo, stepType: $stepType');
  }

  /// Clear all caches for a specific job (more aggressive cache clearing)
  void clearAllJobCaches(String jobNumber) {
    final keys = <String>{
      _keyPlanningSteps(jobNumber),
      _keyPaperStore(jobNumber),
      _keyJobDetails(jobNumber),
    };
    
    // Clear all step-specific caches for this job
    for (int i = 1; i <= 9; i++) {
      keys.add(_keyPlanningStep(jobNumber, i));
    }
    
    _invalidateKeys(keys);
    print('🧹 Cleared all caches for job: $jobNumber');
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

  /// Get step details from job planning
  Future<Map<String, dynamic>?> getJobPlanningStepDetails(String jobNumber, int stepNo) async {
    final key = _keyPlanningStep(jobNumber, stepNo);
    try {
      return await _getOrFetchMap(key, () => _jobApi.getJobPlanningStepDetails(jobNumber, stepNo));
    } catch (e) {
      print('Error getting job planning step details: $e');
      return null;
    }
  }

  /// Sync Paper Store step with backend
  Future<void> syncPaperStoreStep(String jobNumber, Function(StepStatus) onStatusUpdate) async {
    try {
      final paperStore = await _jobApi.getPaperStoreStepByJob(jobNumber);
      if (paperStore != null) {
        final status = paperStore['status'];
        if (status == 'in_progress') {
          onStatusUpdate(StepStatus.started);
        } else if (status == 'accept') {
          onStatusUpdate(StepStatus.completed);
        } else {
          onStatusUpdate(StepStatus.pending);
        }
      }
    } catch (e) {
      print('Error syncing Paper Store step: $e');
    }
  }

  /// Get Paper Store step by job number
  Future<Map<String, dynamic>?> getPaperStoreStepByJob(String jobNumber) async {
    final key = _keyPaperStore(jobNumber);
    try {
      return await _getOrFetchMap(key, () => _jobApi.getPaperStoreStepByJob(jobNumber));
    } catch (e) {
      print('Error getting paper store step: $e');
      return null;
    }
  }

  /// Get Paper Store step by job number with editability information
  Future<List<StepDataWithEditability>> getPaperStoreStepByJobWithEditability(String jobNumber) async {
    try {
      final response = await _jobApi.getPaperStoreStepByJobWithEditability(jobNumber);
      return StepDataWithEditability.fromBackendResponseList(response);
    } catch (e) {
      print('Error getting paper store step with editability: $e');
      return [];
    }
  }

  /// Get step details by job number with editability information
  Future<List<StepDataWithEditability>> getStepDetailsWithEditability(String jobNumber, StepType stepType) async {
    try {
      List<Map<String, dynamic>> response;
      switch (stepType) {
        case StepType.paperStore:
          response = await _jobApi.getPaperStoreStepByJobWithEditability(jobNumber);
          break;
        case StepType.printing:
          response = await _jobApi.getPrintingDetailsByJobWithEditability(jobNumber);
          break;
        case StepType.corrugation:
          response = await _jobApi.getCorrugationByJobWithEditability(jobNumber);
          break;
        case StepType.fluteLamination:
          response = await _jobApi.getFluteLaminationByJobWithEditability(jobNumber);
          break;
        case StepType.punching:
          response = await _jobApi.getPunchingByJobWithEditability(jobNumber);
          break;
        case StepType.flapPasting:
          response = await _jobApi.getSideFlapPastingByJobWithEditability(jobNumber);
          break;
        case StepType.qc:
          response = await _jobApi.getQualityDeptByJobWithEditability(jobNumber);
          break;
        case StepType.dispatch:
          response = await _jobApi.getDispatchProcessByJobWithEditability(jobNumber);
          break;
        default:
          return [];
      }
      return StepDataWithEditability.fromBackendResponseList(response);
    } catch (e) {
      print('Error getting step details with editability for $stepType: $e');
      return [];
    }
  }

  /// Fetch job details
  Future<List<Job>?> fetchJobDetails(String jobNumber) async {
    final key = _keyJobDetails(jobNumber);
    try {
      return await _getOrFetchJobList(key, () => _jobApi.getJobsByNo(jobNumber));
    } catch (e) {
      print('Error fetching job details: $e');
      return null;
    }
  }

  /// Fetch job details with comprehensive PO details
  Future<Map<String, dynamic>?> fetchJobWithPODetails(String jobNumber) async {
    try {
      return await _jobApi.getJobWithPODetails(jobNumber);
    } catch (e) {
      print('Error fetching job with PO details: $e');
      return null;
    }
  }

  /// Start Paper Store work
  /// Start Paper Store work
  Future<void> startPaperStoreWork(String jobNumber, Map<String, dynamic> jobDetails) async {
    // Get the job planning step details to retrieve the ID
    final stepDetails = await getJobPlanningStepDetails(jobNumber, 1); // stepNo 1 for Paper Store

    if (stepDetails == null) {
      throw Exception('Failed to get job planning step details for Paper Store');
    }

    final jobStepId = stepDetails['id'];
    print("stepDetails");
    print(stepDetails);
    if (jobStepId == null) {
      throw Exception('Job step ID not found in planning details');
    }

    final body = {
      'status': 'in_progress',
      'sheetSize': jobDetails['boardSize'] ?? '',
      'quantity': int.tryParse(jobDetails['noUps']?.toString() ?? '0') ?? 0,
      'gsm': jobDetails['fluteType'] ?? '',
      'issuedDate': _formatDateWithMilliseconds(),
    };

    // Use PUT to update existing Paper Store record instead of POST to create new one
    await _jobApi.putPaperStore(jobNumber, body);
  }
  /// Update job planning step status and dates
  Future<void> updateJobPlanningStepComplete(String jobNumber, int stepNo, String status, {String? user, Map<String, dynamic>? additionalFields}) async {
    try {
      // Get step details to determine step type
      final stepDetails = await getJobPlanningStepDetails(jobNumber, stepNo);
      final stepName = stepDetails?['stepName']?.toString().toLowerCase() ?? '';
      
      // Prepare additional fields for validation based on step type
      Map<String, dynamic> fieldsToSend = {
        'user': user ?? 'NRC015',
      };
      
      // If additionalFields are provided, use them instead of defaults
      if (additionalFields != null) {
        fieldsToSend.addAll(additionalFields);
      } else {
        // Add step-specific required fields as defaults
        if (stepName.contains('qualitydept') || stepName.contains('quality')) {
          // QualityDept requires passQuantity and checkedBy
          fieldsToSend['passQuantity'] = 1000; // Default pass quantity
          fieldsToSend['checkedBy'] = user ?? 'System';
        } else if (stepName.contains('dispatchprocess') || stepName.contains('dispatch')) {
          // DispatchProcess requires noOfBoxes and dispatchNo
          fieldsToSend['noOfBoxes'] = 100; // Default number of boxes
          fieldsToSend['dispatchNo'] = 'DISP-${DateTime.now().millisecondsSinceEpoch}';
        } else {
          // Other steps require quantity, oprName, size
          fieldsToSend['quantity'] = 1000; // Default quantity
          fieldsToSend['oprName'] = user ?? 'System'; // Use user as operator name
          fieldsToSend['size'] = 'A4'; // Default size for PaperStore
        }
      }
      
      // If user is provided, update with user information
      if (user != null && user.isNotEmpty) {
        await _jobApi.updateJobPlanningStepFields(jobNumber, stepNo, {
          'status': status,
          'user': user,
          ...fieldsToSend,
        });
      } else {
        await _jobApi.updateJobPlanningStepComplete(jobNumber, stepNo, status, additionalFields: fieldsToSend);
      }

      if (status == 'start') {
        final postBody = {
          'jobStepId': stepDetails!['id'],
          'jobNrcJobNo': jobNumber,
          'status': 'in_progress',
        };

        // Prefer routing by stepName from planning to support dynamic step numbers
        final rawName = (stepDetails['stepName'] ?? '').toString();
        final normalized = rawName.replaceAll(' ', '').toLowerCase();

        // Skip PaperStore here (handled by startPaperStoreWork)
        if (normalized == 'paperstore') {
          print('[JobApiService.updateJobPlanningStepComplete] Paper Store start handled separately');
        } else if (normalized == 'printingdetails') {
          print('[JobApiService.updateJobPlanningStepComplete] Posting in_progress to Printing');
          await _jobApi.postPrintingDetails(postBody);
        } else if (normalized == 'corrugation') {
          print('[JobApiService.updateJobPlanningStepComplete] Posting in_progress to Corrugation');
          await _jobApi.postCorrugationDetails(postBody);
        } else if (normalized == 'flutelaminateboardconversion') {
          print('[JobApiService.updateJobPlanningStepComplete] Posting in_progress to Flute Lamination');
          await _jobApi.postFluteLaminationDetails(postBody);
        } else if (normalized == 'punching') {
          print('[JobApiService.updateJobPlanningStepComplete] Posting in_progress to Punching');
          await _jobApi.postPunchingDetails(postBody);
        } else if (normalized == 'sideflappasting') {
          print('[JobApiService.updateJobPlanningStepComplete] Posting in_progress to Flap Pasting');
          await _jobApi.postFlapPastingDetails(postBody);
        } else if (normalized == 'qualitydept') {
          print('[JobApiService.updateJobPlanningStepComplete] Posting in_progress to QC');
          await _jobApi.postQCDetails(postBody);
        } else if (normalized == 'dispatchprocess') {
          print('[JobApiService.updateJobPlanningStepComplete] Posting in_progress to Dispatch');
          await _jobApi.postDispatchDetails(postBody);
        } else {
          print('[JobApiService.updateJobPlanningStepComplete] Unknown planning stepName "$rawName"; skipping in_progress POST');
        }
      }
      // Invalidate caches after a mutation affecting this job/step
      invalidateJobCaches(jobNumber, stepNo: stepNo);
    } catch (e) {
      print('Error updating job planning step: $e');
      rethrow;
    }
  }

  /// Update step status (legacy method for backward compatibility)
  Future<void> updateStepStatus(String jobNumber, int stepNo, String status) async {
    if (stepNo == 1) {
      // Paper Store specific handling
      final stepDetails = await _jobApi.getJobPlanningStepDetails(jobNumber, stepNo);
      if (stepDetails != null) {
        final planningId = stepDetails['jobPlanningId'];
        final stepNoFromDetails = stepDetails['stepNo'];
        await _jobApi.updateJobPlanningStepStatus(jobNumber, planningId, stepNoFromDetails, status);
      }
    } else {
      await _jobApi.updateJobPlanningStepComplete(jobNumber, stepNo, status);
    }
  }

  /// Generic method to update any fields for a job planning step
  Future<void> updateJobPlanningStepFields(String jobNumber, int stepNo, Map<String, dynamic> body) async {
    await _jobApi.updateJobPlanningStepFields(jobNumber, stepNo, body);
    invalidateJobCaches(jobNumber, stepNo: stepNo);
  }

  /// Complete Paper Store work
  Future<void> completePaperStoreWork(String jobNumber, Map<String, dynamic> jobDetails, Map<String, String> formData) async {

    final stepDetails = await getJobPlanningStepDetails(jobNumber, 1); // stepNo 1 for Paper Store

    if (stepDetails == null) {
      throw Exception('Failed to get job planning step details for Paper Store');
    }

    final jobStepId = stepDetails['id'];
    print("stepDetails");
    print(stepDetails);
    if (jobStepId == null) {
      throw Exception('Job step ID not found in planning details');
    }

    final body = {
      "jobStepId": jobStepId,
      'jobNrcJobNo': jobNumber,
      'status': 'accept',
      'sheetSize': jobDetails['boardSize'] ?? '',
      'quantity': int.tryParse(jobDetails['noUps']?.toString() ?? '0') ?? 0,
      'available': int.tryParse(formData['available'] ?? '0') ?? 0,
      'issuedDate': _formatDateWithMilliseconds(),
      'mill': formData['mill'] ?? '',
      'extraMargin': formData['extraMargin'] ?? '',
      'gsm': jobDetails['fluteType'] ?? '',
      'quality': formData['quality'] ?? '',
    };

    final paperStore = await _jobApi.getPaperStoreStepByJob(jobNumber);
    if (paperStore != null) {
      await _jobApi.putPaperStore(jobNumber, body);
    } else {
      await _jobApi.postPaperStore(body);
    }
    invalidateJobCaches(jobNumber, stepNo: 1);
  }

  /// Post step details for different step types
  Future<void> putStepDetails(StepType stepType, String jobNumber, Map<String, String> formData, int stepNo) async {
    // Instead of calling separate step-specific APIs, send form data directly to job planning step completion
    await _putJobPlanningStepFormData(jobNumber, stepNo, formData);
  }

  /// Send form data directly to job planning step completion endpoint
  Future<void> _putJobPlanningStepFormData(String jobNumber, int stepNo, Map<String, String> formData) async {
    try {
      print('[_putJobPlanningStepFormData] Sending form data to job planning step completion');
      print('Job Number: $jobNumber, Step No: $stepNo');
      print('Form Data: $formData');
      
      // Get step details to determine step type
      final stepDetails = await getJobPlanningStepDetails(jobNumber, stepNo);
      final stepName = stepDetails?['stepName']?.toString() ?? '';
      
      // Map frontend form data to backend expected field names
      Map<String, dynamic> requestBody = {
        'status': 'stop',
        'user': 'NRC015', // Default user
      };
      
        // Map form data based on step type
        if (stepName.toLowerCase().contains('paperstore')) {
          requestBody['quantity'] = formData['Required Qty'] ?? formData['quantity'];
          requestBody['available'] = formData['Available Qty'] ?? formData['available'];
          requestBody['sheetSize'] = formData['Sheet Size'] ?? formData['sheetSize'] ?? 'A4';
          requestBody['mill'] = formData['mill'] ?? formData['Mill'] ?? '';
          requestBody['gsm'] = formData['GSM'] ?? formData['gsm'] ?? '';
          requestBody['quality'] = formData['quality'] ?? formData['Quality'] ?? '';
          requestBody['extraMargin'] = formData['extraMargin'] ?? formData['Extra Margin'] ?? '';
          requestBody['issuedDate'] = formData['Issue Date'] ?? formData['issuedDate'];
          // QC fields are only updated by Flying Squad, not by regular operators
        } else if (stepName.toLowerCase().contains('printing')) {
        requestBody['quantity'] = formData['Quantity OK'] ?? formData['quantity'];
        requestBody['wastage'] = formData['Wastage'] ?? formData['wastage'];
        requestBody['noOfColours'] = formData['Colors Used'] ?? formData['noOfColours'];
        requestBody['inksUsed'] = formData['Inks Used'] ?? formData['inksUsed'];
        requestBody['coatingType'] = formData['Coating Type'] ?? formData['coatingType'];
        requestBody['separateSheets'] = formData['Separate Sheets'] ?? formData['separateSheets'];
        requestBody['extraSheets'] = formData['Extra Sheets'] ?? formData['extraSheets'];
        requestBody['remarks'] = formData['Remarks'] ?? formData['remarks'];
        // Machine, operator, date, shift, and QC fields are auto-populated, not user input
      } else if (stepName.toLowerCase().contains('corrugation')) {
        requestBody['quantity'] = formData['Sheets Count'] ?? formData['quantity'];
        requestBody['size'] = formData['Size'] ?? formData['size'];
        requestBody['gsm1'] = formData['GSM1'] ?? formData['gsm1'];
        requestBody['gsm2'] = formData['GSM2'] ?? formData['gsm2'];
        requestBody['flute'] = formData['Flute Type'] ?? formData['flute'];
        requestBody['remarks'] = formData['Remarks'] ?? formData['remarks'];
        // Machine, operator, date, shift, and QC fields are auto-populated, not user input
      } else if (stepName.toLowerCase().contains('flute')) {
        requestBody['quantity'] = formData['OK Quantity'] ?? formData['quantity'];
        requestBody['film'] = formData['Film Type'] ?? formData['film'];
        requestBody['adhesive'] = formData['Adhesive'] ?? formData['adhesive'];
        requestBody['wastage'] = formData['Wastage'] ?? formData['wastage'];
        // Machine, operator, date, shift, and QC fields are auto-populated, not user input
      } else if (stepName.toLowerCase().contains('punching') || stepName.toLowerCase().contains('die cutting')) {
        requestBody['quantity'] = formData['OK Quantity'] ?? formData['quantity'];
        requestBody['die'] = formData['Die Used'] ?? formData['die'];
        requestBody['wastage'] = formData['Wastage'] ?? formData['wastage'];
        requestBody['remarks'] = formData['Remarks'] ?? formData['remarks'];
        // Machine, operator, date, shift, and QC fields are auto-populated, not user input
      } else if (stepName.toLowerCase().contains('flap')) {
        requestBody['quantity'] = formData['Quantity'] ?? formData['quantity'];
        requestBody['adhesive'] = formData['Adhesive'] ?? formData['adhesive'];
        requestBody['wastage'] = formData['Wastage'] ?? formData['wastage'];
        requestBody['remarks'] = formData['Remarks'] ?? formData['remarks'];
        // Machine, operator, date, shift, and QC fields are auto-populated, not user input
      } else if (stepName.toLowerCase().contains('quality')) {
        requestBody['passQuantity'] = formData['Pass Quantity'] ?? formData['passQuantity'];
        requestBody['rejectedQty'] = formData['Reject Quantity'] ?? formData['rejectedQty'];
        requestBody['reasonForRejection'] = formData['Reason for Rejection'] ?? formData['reasonForRejection'];
        requestBody['remarks'] = formData['Remarks'] ?? formData['remarks'];
        // Machine, operator, date, shift, and QC fields are auto-populated, not user input
      } else if (stepName.toLowerCase().contains('dispatch')) {
        requestBody['noOfBoxes'] = formData['No of Boxes'] ?? formData['noOfBoxes'];
        requestBody['dispatchNo'] = formData['Dispatch No'] ?? formData['dispatchNo'] ?? 'DISP-${DateTime.now().millisecondsSinceEpoch}';
        requestBody['dispatchDate'] = formData['Dispatch Date'] ?? formData['dispatchDate'];
        requestBody['balanceQty'] = formData['Balance Qty'] ?? formData['balanceQty'];
        requestBody['remarks'] = formData['Remarks'] ?? formData['remarks'];
        // Machine, operator, date, shift, and QC fields are auto-populated, not user input
      } else {
        // Default mapping for unknown steps
        requestBody['quantity'] = formData['quantity'];
        requestBody['remarks'] = formData['remarks'];
        // Machine, operator, date, shift, and QC fields are auto-populated, not user input
      }
      
      print('[_putJobPlanningStepFormData] Mapped request body: $requestBody');
      
      // Send directly to job planning step endpoint
      await _jobApi.updateJobPlanningStepFields(jobNumber, stepNo, requestBody);
      
      print('[_putJobPlanningStepFormData] Successfully sent form data to backend');
    } catch (e) {
      print('[_putJobPlanningStepFormData] Error sending form data: $e');
      rethrow;
    }
  }

  Future<void> _putPrintingDetails(String jobNumber, Map<String, String> formData, int stepNo) async {

    final stepDetails = await getJobPlanningStepDetails(jobNumber, stepNo);

    if (stepDetails == null) {
      throw Exception('Failed to get job planning step details for Paper Store');
    }

    final jobStepId = stepDetails['id'];

    print(jobNumber);
    print(stepNo);
    print('JobApiService - Printing formData received:');
    print('Qty Sheet: ${formData['Qty Sheet']}');
    print('Full formData: $formData');
    
    final body = {
      "jobNrcJobNo": jobNumber,
      "jobStepId": jobStepId,
      "status": "accept",
      "quantity": int.tryParse(formData['Qty Sheet'] ?? '0') ?? 0,
      "date": _formatDateWithMilliseconds(),
      "oprName": formData['Operator Name'] ?? '',
      "wastage": int.tryParse(formData['Wastage'] ?? '0') ?? 0,
      "machine": formData['Machine'] ?? '',
    };
    print("Printing Details");
    print(body);
    await _jobApi.putPrintingDetails(body,jobNumber);
    invalidateJobCaches(jobNumber, stepNo: stepNo, stepType: StepType.printing);
  }

  Future<void> _putCorrugationDetails(String jobNumber, Map<String, String> formData, int stepNo) async {
    print("Comes to Corrugation");
    print('[_putCorrugationDetails] DEBUG: jobNumber parameter = "$jobNumber"');
    print('[_putCorrugationDetails] DEBUG: stepNo parameter = $stepNo');
    final stepDetails = await getJobPlanningStepDetails(jobNumber, stepNo);

    print("Steps Details will come here");
    if (stepDetails == null) {
      throw Exception('Failed to get job planning step details for Corrugation Store');
    }

    final jobStepId = stepDetails['id'];
    print("Corrugation job step number is $jobStepId");
    print('JobApiService - Corrugation formData received:');
    print('Qty Sheet: ${formData['Qty Sheet']}');
    print('Full formData: $formData');

    final body = {
    "jobStepId": jobStepId,
    "jobNrcJobNo": jobNumber,
    "status": "accept",
    "date": _formatDateWithMilliseconds(),
    "shift": formData['Shift'] ?? '',
    "oprName": formData['Operator Name'] ?? '',
    "machineNo": formData['Machine No'] ?? '',
    "quantity": int.tryParse(formData['Qty Sheet'] ?? '0') ?? 0,
    "size": formData['Size'] ?? '',
    "gsm1": formData['GSM 1'] ?? '',
    "gsm2": formData['GSM 2'] ?? '',
    "flute": formData['Flute Type'] ?? '',
    "remarks": formData['Remarks'] ?? '',
    "qcCheckSignBy": formData['QC Check Sign By'] ?? '',
    };


    print("Corrugation Details Body:");
    print(body);

    print('[_putCorrugationDetails] DEBUG: About to call _jobApi.putCorrugationDetails with jobNumber = "$jobNumber"');
    await _jobApi.putCorrugationDetails(body,jobNumber);
    invalidateJobCaches(jobNumber, stepNo: stepNo, stepType: StepType.corrugation);
  }


  Future<void> _putFluteLaminationDetails(String jobNumber, Map<String, String> formData, int stepNo) async {
    print("Comes to FluteLamination");
    final stepDetails = await getJobPlanningStepDetails(jobNumber, stepNo);

    print("Steps Details will come here");
    if (stepDetails == null) {
      throw Exception('Failed to get job planning step details for Corrugation Store');
    }

    final jobStepId = stepDetails['id'];
    print("Corrugation job step number is $jobStepId");
    print('JobApiService - FluteLamination formData received:');
    print('Qty Sheet: ${formData['Qty Sheet']}');
    print('Full formData: $formData');
    
    final body = {
      "jobNrcJobNo": jobNumber,
      "jobStepId": jobStepId,
      "status": "accept",
      "date": _formatDateWithMilliseconds(),
      "shift": formData['Shift'] ?? '',                  // New
      "operatorName": formData['Operator Name'] ?? '',
      "film": formData['Film Type'] ?? '',               // Changed key from 'filmType' to 'film'
      "quantity": int.tryParse(formData['Qty Sheet'] ?? '0') ?? 0, // Use Qty Sheet from form
      "qcCheckSignBy": formData['QC Sign By'] ?? '',     // New
      "adhesive": formData['Adhesive'] ?? '',
      "wastage": int.tryParse(formData['Wastage'] ?? '0') ?? 0,
    };

    await _jobApi.putFluteLaminationDetails(body,jobNumber);
    invalidateJobCaches(jobNumber, stepNo: stepNo, stepType: StepType.fluteLamination);
  }

  Future<void> _putPunchingDetails(String jobNumber, Map<String, String> formData, int stepNo) async {
    print("Comes to Punching");
    final stepDetails = await getJobPlanningStepDetails(jobNumber, stepNo);

    print("Steps Details will come here");
    if (stepDetails == null) {
      throw Exception('Failed to get job planning step details for Corrugation Store');
    }

    final jobStepId = stepDetails['id'];
    print("Punching job step number is $jobStepId");
    print('JobApiService - Punching formData received:');
    print('Qty Sheet: ${formData['Qty Sheet']}');
    print('Full formData: $formData');
    
    final body = {
      "jobNrcJobNo": jobNumber,
      "jobStepId": jobStepId,
      "status": "accept",
      "date": _formatDateWithMilliseconds(),
      "operatorName": formData['Operator Name'] ?? '',
      "machine": formData['Machine'] ?? '',
      "quantity": int.tryParse(formData['Qty Sheet'] ?? '0') ?? 0,
      "die": formData['Die Used'] ?? '',
      "wastage": int.tryParse(formData['Wastage'] ?? '0') ?? 0,
      "remarks": formData['Remarks'] ?? '',
    };
    await _jobApi.putPunchingDetails(body,jobNumber);
    invalidateJobCaches(jobNumber, stepNo: stepNo, stepType: StepType.punching);
  }

  Future<void> _putQCDetails(String jobNumber, Map<String, String> formData, int stepNo) async {
    print("Comes to Quality Control");
    final stepDetails = await getJobPlanningStepDetails(jobNumber, stepNo);

    print("Steps Details will come here");
    if (stepDetails == null) {
      throw Exception('Failed to get job planning step details for Corrugation Store');
    }

    final jobStepId = stepDetails['id'];
    print("Quality Control job step number is $jobStepId");
    print('JobApiService - QC formData received:');
    print('Qty Sheet: ${formData['Qty Sheet']}');
    print('Full formData: $formData');
    
    final body = {
      "jobNrcJobNo": jobNumber,
      "jobStepId": jobStepId,
      "status": "accept",
      "date": _formatDateWithMilliseconds(),
      "checkedBy": formData['Checked By'] ?? formData['Emp Id'] ?? 'System',
      "passQuantity": int.tryParse(formData['Qty Sheet'] ?? '0') ?? 0,
      "quantity": int.tryParse(formData['Qty Sheet'] ?? '0') ?? 0, // Keep for backward compatibility
      "rejectedQty": int.tryParse(formData['Reject Quantity'] ?? '0') ?? 0,
      "reasonForRejection": formData['Reason for Rejection'].toString() ?? '',
      "remarks": formData['Remarks'] ?? '',
    };
    print(body);
    await _jobApi.putQCDetails(body,jobNumber);
    invalidateJobCaches(jobNumber, stepNo: stepNo, stepType: StepType.qc);
  }

  Future<void> _putFlapPastingDetails(String jobNumber, Map<String, String> formData, int stepNo) async {
    print("Comes to FlapPasting");
    final stepDetails = await getJobPlanningStepDetails(jobNumber, stepNo);

    print("Steps Details will come here");
    if (stepDetails == null) {
      throw Exception('Failed to get job planning step details for Corrugation Store');
    }

    final jobStepId = stepDetails['id'];
    print("FlapPasting job step number is $jobStepId");
    final body = {
      "jobNrcJobNo": jobNumber,
      "jobStepId": jobStepId,
      "status": "accept",
      "date": _formatDateWithMilliseconds(),
      "shift": '',
      "operatorName": formData['Operator Name'] ?? '',
      "machineNo": formData['Machine No'] ?? '',
      "adhesive": formData['Adhesive'] ?? '',
      "quantity": int.tryParse(formData['Quantity'] ?? '0') ?? 0,
      "wastage": int.tryParse(formData['Wastage'] ?? '0') ?? 0,
      "remarks": formData['Remarks'] ?? '',
    };
    await _jobApi.putFlapPastingDetails(body,jobNumber);
    invalidateJobCaches(jobNumber, stepNo: stepNo, stepType: StepType.flapPasting);
  }

  Future<void> _putDispatchDetails(String jobNumber, Map<String, String> formData, int stepNo) async {
    print("Comes to Dispatch");
    final stepDetails = await getJobPlanningStepDetails(jobNumber, stepNo);

    print("Steps Details will come here");
    if (stepDetails == null) {
      throw Exception('Failed to get job planning step details for Dispatch');
    }

    final jobStepId = stepDetails['id'];
    print("Dispatch job step number is $jobStepId");
    print('JobApiService - Dispatch formData received:');
    print('Qty Sheet: ${formData['Qty Sheet']}');
    print('Full formData: $formData');
    
    final body = {
      "jobNrcJobNo": jobNumber,
      "jobStepId": jobStepId,
      "status": "accept",
      "date": _formatDateWithMilliseconds(),
      "operatorName": formData['Operator Name'] ?? formData['Emp Id'] ?? 'System',
      "quantity": int.tryParse(formData['Qty Sheet'] ?? '0') ?? 0,
      "noOfBoxes": int.tryParse(formData['No of Boxes'] ?? '100') ?? 100, // Required field for validation
      "dispatchNo": formData['Dispatch No'] ?? 'DISP-${DateTime.now().millisecondsSinceEpoch}',
      "dispatchDate": _formatDateWithMilliseconds(),
      "balanceQty": int.tryParse(formData['Balance Qty'] ?? '0') ?? 0,
      "remarks": formData['Remarks'] ?? '',
    };
    print('Dispatch body: $body');
    await _jobApi.putDispatchDetails(body,jobNumber);
    invalidateJobCaches(jobNumber, stepNo: stepNo, stepType: StepType.dispatch);
  }

  /// Helper to get step status by type
  Future<String?> getStepStatusByType(StepType stepType, String jobNumber) async {
    String? _extractStatus(Map<String, dynamic>? details) {
      if (details == null) return null;
      final data = details['data'];
      if (data is List && data.isNotEmpty) {
        final first = data[0];
        if (first is Map && first['status'] != null) {
          return first['status']?.toString();
        }
      }
      if (details['status'] != null) {
        return details['status']?.toString();
      }
      return null;
    }

    switch (stepType) {
      case StepType.printing:
        return _extractStatus(await _jobApi.getPrintingDetails(jobNumber));
      case StepType.corrugation:
        return _extractStatus(await _jobApi.getCorrugationDetails(jobNumber));
      case StepType.fluteLamination:
        return _extractStatus(await _jobApi.getFluteLaminationDetails(jobNumber));
      case StepType.punching:
        return _extractStatus(await _jobApi.getPunchingDetails(jobNumber));
      case StepType.dieCutting:
        return _extractStatus(await _jobApi.getPunchingDetails(jobNumber)); // uses same API as punching
      case StepType.flapPasting:
        return _extractStatus(await _jobApi.getFlapPastingDetails(jobNumber));
      case StepType.qc:
        return _extractStatus(await _jobApi.getQCDetails(jobNumber));
      case StepType.dispatch:
        return _extractStatus(await _jobApi.getDispatchDetails(jobNumber));
      default:
        return null;
    }
  }

  Future<Map<String, dynamic>?> getPrintingDetails(String jobNumber) async {
    final key = _keyStepType(jobNumber, StepType.printing);
    return await _getOrFetchMap(key, () => _jobApi.getPrintingDetails(jobNumber));
  }

  Future<Map<String, dynamic>?> getCorrugationDetails(String jobNumber) async {
    final key = _keyStepType(jobNumber, StepType.corrugation);
    return await _getOrFetchMap(key, () => _jobApi.getCorrugationDetails(jobNumber));
  }

  Future<Map<String, dynamic>?> getFluteLaminationDetails(String jobNumber) async {
    final key = _keyStepType(jobNumber, StepType.fluteLamination);
    return await _getOrFetchMap(key, () => _jobApi.getFluteLaminationDetails(jobNumber));
  }

  Future<Map<String, dynamic>?> getPunchingDetails(String jobNumber) async {
    final key = _keyStepType(jobNumber, StepType.punching);
    return await _getOrFetchMap(key, () => _jobApi.getPunchingDetails(jobNumber));
  }

  Future<Map<String, dynamic>?> getDieCuttingDetails(String jobNumber) async {
    final key = _keyStepType(jobNumber, StepType.dieCutting);
    return await _getOrFetchMap(key, () => _jobApi.getPunchingDetails(jobNumber)); // uses same API as punching
  }

  Future<Map<String, dynamic>?> getFlapPastingDetails(String jobNumber) async {
    final key = _keyStepType(jobNumber, StepType.flapPasting);
    return await _getOrFetchMap(key, () => _jobApi.getFlapPastingDetails(jobNumber));
  }

  Future<Map<String, dynamic>?> getQCDetails(String jobNumber) async {
    final key = _keyStepType(jobNumber, StepType.qc);
    return await _getOrFetchMap(key, () => _jobApi.getQCDetails(jobNumber));
  }

  Future<Map<String, dynamic>?> getDispatchDetails(String jobNumber) async {
    final key = _keyStepType(jobNumber, StepType.dispatch);
    return await _getOrFetchMap(key, () => _jobApi.getDispatchDetails(jobNumber));
  }

  /// Get all job plannings
  Future<List<Map<String, dynamic>>> getAllJobPlannings() async {
    try {
      return await _jobApi.getAllJobPlannings();
    } catch (e) {
      print('Error getting all job plannings: $e');
      return [];
    }
  }

  /// Get job planning steps by job number
  Future<Map<String, dynamic>?> getJobPlanningStepsByNrcJobNo(String jobNumber) async {
    final key = _keyPlanningSteps(jobNumber);
    try {
      return await _getOrFetchMap(key, () => _jobApi.getJobPlanningStepsByNrcJobNo(jobNumber));
    } catch (e) {
      print('Error getting job planning steps: $e');
      return null;
    }
  }

  /// Get job planning steps bypassing cache (used for manual refresh / instant updates)
  Future<Map<String, dynamic>?> getJobPlanningStepsByNrcJobNoFresh(String jobNumber) async {
    final key = _keyPlanningSteps(jobNumber);
    try {
      final data = await _jobApi.getJobPlanningStepsByNrcJobNo(jobNumber);
      _cache[key] = _CacheEntry<dynamic>(data);
      return data;
    } catch (e) {
      print('Error getting job planning steps (fresh): $e');
      return null;
    }
  }

  /// Hold PaperStore step with remarks
  Future<Map<String, dynamic>?> holdPaperStoreStep(String jobNumber, String remarks) async {
    try {
      final result = await _jobApi.holdPaperStoreStep(jobNumber, remarks);
      // Clear cache to ensure fresh data on next fetch
      _clearCacheForJob(jobNumber);
      return result;
    } catch (e) {
      print('Error holding PaperStore step: $e');
      return null;
    }
  }

  /// Resume PaperStore step with remarks
  Future<Map<String, dynamic>?> resumePaperStoreStep(String jobNumber, String remarks) async {
    try {
      final result = await _jobApi.resumePaperStoreStep(jobNumber, remarks);
      // Clear cache to ensure fresh data on next fetch
      _clearCacheForJob(jobNumber);
      return result;
    } catch (e) {
      print('Error resuming PaperStore step: $e');
      return null;
    }
  }

  /// Clear all caches for a specific job
  void _clearCacheForJob(String jobNumber) {
    final keysToRemove = _cache.keys.where((key) => key.contains(jobNumber)).toList();
    for (final key in keysToRemove) {
      _cache.remove(key);
    }
  }

  /// Hold any step with remarks
  Future<Map<String, dynamic>?> holdStep(String stepType, String jobNumber, String remarks) async {
    try {
      final result = await _jobApi.holdStep(stepType, jobNumber, remarks);
      // Clear cache to ensure fresh data on next fetch
      _clearCacheForJob(jobNumber);
      return result;
    } catch (e) {
      print('Error holding $stepType step: $e');
      return null;
    }
  }

  /// Resume any step with remarks
  Future<Map<String, dynamic>?> resumeStep(String stepType, String jobNumber, String remarks) async {
    try {
      final result = await _jobApi.resumeStep(stepType, jobNumber, remarks);
      // Clear cache to ensure fresh data on next fetch
      _clearCacheForJob(jobNumber);
      return result;
    } catch (e) {
      print('Error resuming $stepType step: $e');
      return null;
    }
  }

  /// Update status for any step type (generic status update)
  Future<Map<String, dynamic>?> updateStepStatusGeneric(String stepType, String jobNumber, String status, {String? remarks}) async {
    try {
      final result = await _jobApi.updateStepStatusGeneric(stepType, jobNumber, status, remarks: remarks);
      // Clear cache to ensure fresh data on next fetch
      _clearCacheForJob(jobNumber);
      return result;
    } catch (e) {
      print('Error updating $stepType step status to $status: $e');
      return null;
    }
  }

  // ===== MACHINE-SPECIFIC WORK METHODS =====

  /// Get available machines for a job step
  Future<Map<String, dynamic>?> getAvailableMachines(String nrcJobNo, int stepNo) async {
    try {
      final result = await _jobApi.getAvailableMachines(nrcJobNo, stepNo);
      return result;
    } catch (e) {
      print('Error getting available machines for step $stepNo: $e');
      return null;
    }
  }

  /// Start work on a specific machine
  Future<Map<String, dynamic>?> startWorkOnMachine(String nrcJobNo, int stepNo, String machineId, {Map<String, dynamic>? formData}) async {
    try {
      final result = await _jobApi.startWorkOnMachine(nrcJobNo, stepNo, machineId, formData: formData);
      // Clear cache to ensure fresh data on next fetch
      _clearCacheForJob(nrcJobNo);
      return result;
    } catch (e) {
      print('Error starting work on machine $machineId: $e');
      return null;
    }
  }

  /// Start urgent job work (auto-assigns user's machine)
  Future<Map<String, dynamic>?> startUrgentJobWork(String nrcJobNo, int stepNo, {Map<String, dynamic>? formData}) async {
    try {
      final result = await _jobApi.startUrgentJobWork(nrcJobNo, stepNo, formData: formData);
      // Clear cache to ensure fresh data on next fetch
      _clearCacheForJob(nrcJobNo);
      return result;
    } catch (e) {
      print('Error starting urgent job work for step $stepNo: $e');
      return null;
    }
  }

  /// Complete work on a specific machine
  Future<Map<String, dynamic>?> completeWorkOnMachine(String nrcJobNo, int stepNo, String machineId, {Map<String, dynamic>? formData}) async {
    try {
      final result = await _jobApi.completeWorkOnMachine(nrcJobNo, stepNo, machineId, formData: formData);
      // Clear cache to ensure fresh data on next fetch
      _clearCacheForJob(nrcJobNo);
      return result;
    } catch (e) {
      print('Error completing work on machine $machineId: $e');
      return null;
    }
  }

  /// Hold work on a specific machine
  Future<Map<String, dynamic>?> holdWorkOnMachine(String nrcJobNo, int stepNo, String machineId, {Map<String, dynamic>? formData, String? holdReason}) async {
    try {
      final result = await _jobApi.holdWorkOnMachine(nrcJobNo, stepNo, machineId, formData: formData, holdReason: holdReason);
      // Clear cache to ensure fresh data on next fetch
      _clearCacheForJob(nrcJobNo);
      return result;
    } catch (e) {
      print('Error holding work on machine $machineId: $e');
      return null;
    }
  }

  /// Resume work on a specific machine
  Future<Map<String, dynamic>?> resumeWorkOnMachine(String nrcJobNo, int stepNo, String machineId, {Map<String, dynamic>? formData}) async {
    try {
      final result = await _jobApi.resumeWorkOnMachine(nrcJobNo, stepNo, machineId, formData: formData);
      // Clear cache to ensure fresh data on next fetch
      _clearCacheForJob(nrcJobNo);
      return result;
    } catch (e) {
      print('Error resuming work on machine $machineId: $e');
      return null;
    }
  }

  /// Stop work on a specific machine
  Future<Map<String, dynamic>?> stopWorkOnMachine(String nrcJobNo, int stepNo, String machineId, {Map<String, dynamic>? formData}) async {
    try {
      final result = await _jobApi.stopWorkOnMachine(nrcJobNo, stepNo, machineId, formData: formData);
      // Clear cache to ensure fresh data on next fetch
      _clearCacheForJob(nrcJobNo);
      return result;
    } catch (e) {
      print('Error stopping work on machine $machineId: $e');
      return null;
    }
  }

  /// Get machine work status for a job step
  Future<Map<String, dynamic>?> getMachineWorkStatus(String nrcJobNo, int stepNo) async {
    try {
      final result = await _jobApi.getMachineWorkStatus(nrcJobNo, stepNo);
      return result;
    } catch (e) {
      print('Error getting machine work status for step $stepNo: $e');
      return null;
    }
  }

  /// Get all machines as raw data
  Future<List<Map<String, dynamic>>> getMachinesRaw() async {
    try {
      return await _jobApi.getMachinesRaw();
    } catch (e) {
      print('Error getting machines raw: $e');
      return [];
    }
  }

  /// Get user machines
  Future<List<Map<String, dynamic>>> getUserMachines() async {
    try {
      return await _jobApi.getUserMachines();
    } catch (e) {
      print('Error getting user machines: $e');
      return [];
    }
  }

  /// Get machine status
  Future<String?> getMachineStatus(String machineId) async {
    try {
      return await _jobApi.getMachineStatus(machineId);
    } catch (e) {
      print('Error getting machine status for $machineId: $e');
      return null;
    }
  }

  /// Start work without machine for non-machine steps
  Future<Map<String, dynamic>> startWorkWithoutMachine(String endpoint) async {
    try {
      return await _jobApi.startWorkWithoutMachine(endpoint);
    } catch (e) {
      print('Error starting work without machine: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Hold work for non-machine steps
  Future<Map<String, dynamic>> holdWork(String endpoint, Map<String, dynamic> data) async {
    try {
      return await _jobApi.holdWork(endpoint, data);
    } catch (e) {
      print('Error holding work: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Resume work for non-machine steps
  Future<Map<String, dynamic>> resumeWork(String endpoint) async {
    try {
      return await _jobApi.resumeWork(endpoint);
    } catch (e) {
      print('Error resuming work: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

}

class _CacheEntry<T> {
  final T value;
  final DateTime timestamp;
  _CacheEntry(this.value) : timestamp = DateTime.now();

  bool isFresh(Duration ttl) => DateTime.now().difference(timestamp) <= ttl;
}