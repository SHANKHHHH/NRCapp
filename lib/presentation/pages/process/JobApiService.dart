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
  String _keyPlanningStep(String job, int stepNo, [int? jobPlanId]) =>
      'planningStep:$job:$stepNo:${jobPlanId ?? 'latest'}';
  String _keyPlanningSteps(String job, [int? jobPlanId]) =>
      'planningSteps:$job:${jobPlanId ?? 'latest'}';
  String _keyPaperStore(String job, [int? jobPlanId]) =>
      'paperStore:$job:${jobPlanId ?? 'all'}';
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

  void invalidateJobCaches(String jobNumber, {int? stepNo, StepType? stepType, int? jobPlanId}) {
    final keys = <String>{
      _keyPlanningSteps(jobNumber),
      _keyJobDetails(jobNumber),
    };
    if (jobPlanId != null) {
      keys.add(_keyPlanningSteps(jobNumber, jobPlanId));
    }
    if (stepNo != null) {
      keys.add(_keyPlanningStep(jobNumber, stepNo));
      if (jobPlanId != null) {
        keys.add(_keyPlanningStep(jobNumber, stepNo, jobPlanId));
      }
    }
    if (stepType != null) keys.add(_keyStepType(jobNumber, stepType));
    _invalidateKeys(keys);
    _invalidatePaperStoreKeys(jobNumber, jobPlanId: jobPlanId);
    
    print('🔄 Cache invalidated for job: $jobNumber, stepNo: $stepNo, stepType: $stepType, jobPlanId: $jobPlanId');
  }

  /// Clear all caches for a specific job (more aggressive cache clearing)
  void clearAllJobCaches(String jobNumber, {int? jobPlanId}) {
    final keys = <String>{
      _keyPlanningSteps(jobNumber),
      _keyJobDetails(jobNumber),
    };
    if (jobPlanId != null) {
      keys.add(_keyPlanningSteps(jobNumber, jobPlanId));
    }
    // Clear all step-specific caches for this job
    for (int i = 1; i <= 9; i++) {
      keys.add(_keyPlanningStep(jobNumber, i));
      if (jobPlanId != null) {
        keys.add(_keyPlanningStep(jobNumber, i, jobPlanId));
      }
    }
    
    _invalidateKeys(keys);
    _invalidatePaperStoreKeys(jobNumber, jobPlanId: jobPlanId);
    print('🧹 Cleared all caches for job: $jobNumber${jobPlanId != null ? ' (plan $jobPlanId)' : ''}');
  }

  void _invalidatePaperStoreKeys(String jobNumber, {int? jobPlanId}) {
    final keysToRemove = _cache.keys
        .where((key) {
          if (!key.startsWith('paperStore:$jobNumber:')) return false;
          if (jobPlanId == null) return true;
          return key == _keyPaperStore(jobNumber, jobPlanId) ||
              key == _keyPaperStore(jobNumber);
        })
        .toList();
    if (keysToRemove.isNotEmpty) {
      _invalidateKeys(keysToRemove);
    }
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
  Future<Map<String, dynamic>?> getJobPlanningStepDetails(
    String jobNumber,
    int stepNo, {
    int? jobPlanId,
    int? jobStepId,
  }) async {
    final key = _keyPlanningStep(jobNumber, stepNo, jobPlanId);
    try {
      return await _getOrFetchMap(
        key,
        () => _jobApi.getJobPlanningStepDetails(
          jobNumber,
          stepNo,
          jobPlanId: jobPlanId,
          jobStepId: jobStepId,
        ),
      );
    } catch (e) {
      print('Error getting job planning step details: $e');
      return null;
    }
  }

  /// Sync Paper Store step with backend
  Future<void> syncPaperStoreStep(
    String jobNumber,
    Function(StepStatus) onStatusUpdate, {
    int? jobPlanId,
  }) async {
    try {
      final paperStore = await _jobApi.getPaperStoreStepByJob(
        jobNumber,
        jobPlanId: jobPlanId,
      );
      if (paperStore != null) {
        final status = paperStore['status'];
        if (status == 'in_progress') {
          onStatusUpdate(StepStatus.started);
        } else if (status == 'accept') {
          onStatusUpdate(StepStatus.paused);
        } else {
          onStatusUpdate(StepStatus.pending);
        }
      }
    } catch (e) {
      print('Error syncing Paper Store step: $e');
    }
  }

  /// Get Paper Store step by job number
  Future<Map<String, dynamic>?> getPaperStoreStepByJob(String jobNumber, {int? jobPlanId}) async {
    final key = _keyPaperStore(jobNumber, jobPlanId);
    try {
      return await _getOrFetchMap(
        key,
        () => _jobApi.getPaperStoreStepByJob(jobNumber, jobPlanId: jobPlanId),
      );
    } catch (e) {
      print('Error getting paper store step: $e');
      return null;
    }
  }

  /// Get Paper Store step by job number with editability information
  Future<List<StepDataWithEditability>> getPaperStoreStepByJobWithEditability(String jobNumber, {int? jobPlanId}) async {
    try {
      final response = await _jobApi.getPaperStoreStepByJobWithEditability(
        jobNumber,
        jobPlanId: jobPlanId,
      );
      final filtered = jobPlanId != null ? response.where((item) {
            final data = item['data'];
            if (data is Map<String, dynamic>) {
              final planningId = data['jobPlanningId'] ??
                  data['jobPlanId'] ??
                  item['jobPlanningId'] ??
                  item['jobPlanId'];
              if (planningId != null && planningId.toString() == jobPlanId.toString()) {
                return true;
              }
              final jobStep = data['jobStep'];
              if (jobStep is Map<String, dynamic>) {
                final nestedPlanningId = jobStep['jobPlanningId'] ?? jobStep['jobPlanId'];
                if (nestedPlanningId != null && nestedPlanningId.toString() == jobPlanId.toString()) {
                  return true;
                }
              }
            }
            return false;
          }).toList() : response;
      return StepDataWithEditability.fromBackendResponseList(filtered);
    } catch (e) {
      print('Error getting paper store step with editability: $e');
      return [];
    }
  }

  int _stepNumberForType(StepType stepType) {
    switch (stepType) {
      case StepType.paperStore:
        return 1;
      case StepType.printing:
        return 2;
      case StepType.corrugation:
        return 3;
      case StepType.fluteLamination:
        return 4;
      case StepType.punching:
        return 5;
      case StepType.flapPasting:
        return 6;
      case StepType.dieCutting:
        return 6;
      case StepType.qc:
        return 7;
      case StepType.dispatch:
        return 8;
      default:
        return 1;
    }
  }

  /// Get step details by job number with editability information
  Future<List<StepDataWithEditability>> getStepDetailsWithEditability(
    String jobNumber,
    StepType stepType, {
    int? jobPlanId,
    int? jobStepId,
  }) async {
    try {
      List<Map<String, dynamic>> response;
      switch (stepType) {
        case StepType.paperStore:
          response = await _jobApi.getPaperStoreStepByJobWithEditability(
            jobNumber,
            jobPlanId: jobPlanId,
          );
          break;
        case StepType.printing:
          response = await _jobApi.getPrintingDetailsByJobWithEditability(
            jobNumber,
            jobPlanId: jobPlanId,
          );
          break;
        case StepType.corrugation:
          response = await _jobApi.getCorrugationByJobWithEditability(
            jobNumber,
            jobPlanId: jobPlanId,
          );
          break;
        case StepType.fluteLamination:
          response = await _jobApi.getFluteLaminationByJobWithEditability(
            jobNumber,
            jobPlanId: jobPlanId,
          );
          break;
        case StepType.punching:
          response = await _jobApi.getPunchingByJobWithEditability(
            jobNumber,
            jobPlanId: jobPlanId,
          );
          break;
        case StepType.flapPasting:
          response = await _jobApi.getSideFlapPastingByJobWithEditability(
            jobNumber,
            jobPlanId: jobPlanId,
          );
          break;
        case StepType.qc:
          response = await _jobApi.getQualityDeptByJobWithEditability(
            jobNumber,
            jobPlanId: jobPlanId,
          );
          break;
        case StepType.dispatch:
          response = await _jobApi.getDispatchProcessByJobWithEditability(
            jobNumber,
            jobPlanId: jobPlanId,
          );
          break;
        default:
          return [];
      }
      if (jobStepId != null) {
        response = response.where((item) {
          final data = item['data'];
          if (data is Map<String, dynamic>) {
            final candidateId = data['jobStepId'] ??
                data['jobStepID'] ??
                (data['jobStep'] is Map<String, dynamic> ? data['jobStep']['id'] : null) ??
                item['jobStepId'];
            return candidateId != null && candidateId.toString() == jobStepId.toString();
          }
          return false;
        }).toList();
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
  Future<void> startPaperStoreWork(
    String jobNumber,
    Map<String, dynamic> jobDetails, {
    int? jobPlanId,
    int? jobStepId,
  }) async {
    // Get the job planning step details to retrieve the ID
    final stepDetails = await getJobPlanningStepDetails(
      jobNumber,
      1,
      jobPlanId: jobPlanId,
      jobStepId: jobStepId,
    ); // stepNo 1 for Paper Store

    if (stepDetails == null) {
      throw Exception('Failed to get job planning step details for Paper Store');
    }

    final resolvedJobStepId = jobStepId ?? stepDetails['id'];
    print("stepDetails");
    print(stepDetails);
    if (resolvedJobStepId == null) {
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
    await _jobApi.putPaperStore(jobNumber, {
      ...body,
      'jobStepId': resolvedJobStepId,
    });
  }
  /// Update job planning step status and dates
  Future<void> updateJobPlanningStepComplete(
    String jobNumber,
    int stepNo,
    String status, {
    String? user,
    Map<String, dynamic>? additionalFields,
    int? jobPlanId,
    int? jobStepId,
  }) async {
    try {
      // Get step details to determine step type
      final stepDetails = await getJobPlanningStepDetails(
        jobNumber,
        stepNo,
        jobPlanId: jobPlanId,
        jobStepId: jobStepId,
      );
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
        await _jobApi.updateJobPlanningStepFields(
          jobNumber,
          stepNo,
          {
          'status': status,
          'user': user,
          ...fieldsToSend,
            if (jobPlanId != null) 'jobPlanId': jobPlanId,
            if (jobStepId != null) 'jobStepId': jobStepId,
          },
          jobPlanId: jobPlanId,
          jobStepId: jobStepId,
        );
      } else {
        await _jobApi.updateJobPlanningStepComplete(
          jobNumber,
          stepNo,
          status,
          additionalFields: {
            ...fieldsToSend,
            if (jobPlanId != null) 'jobPlanId': jobPlanId,
            if (jobStepId != null) 'jobStepId': jobStepId,
          },
          jobPlanId: jobPlanId,
          jobStepId: jobStepId,
        );
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
      invalidateJobCaches(jobNumber, stepNo: stepNo, jobPlanId: jobPlanId);
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
  Future<void> updateJobPlanningStepFields(
    String jobNumber,
    int stepNo,
    Map<String, dynamic> body, {
    int? jobPlanId,
    int? jobStepId,
  }) async {
    await _jobApi.updateJobPlanningStepFields(
      jobNumber,
      stepNo,
      body,
      jobPlanId: jobPlanId,
      jobStepId: jobStepId,
    );
    invalidateJobCaches(jobNumber, stepNo: stepNo, jobPlanId: jobPlanId);
  }

  /// Complete Paper Store work with completion remarks
  Future<void> completePaperStoreWork(String jobNumber, Map<String, dynamic> jobDetails, Map<String, String> formData, {String? completeRemark}) async {

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

    final jobPlanIdRaw = stepDetails['jobPlanningId'] ?? stepDetails['jobPlanId'];
    final int? jobPlanId = jobPlanIdRaw is int ? jobPlanIdRaw : int.tryParse(jobPlanIdRaw?.toString() ?? '');

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
      if (completeRemark != null) 'completeRemark': completeRemark,
    };

    final paperStore = await _jobApi.getPaperStoreStepByJob(
      jobNumber,
      jobPlanId: jobPlanId,
    );
    if (paperStore != null) {
      await _jobApi.putPaperStore(jobNumber, body);
    } else {
      await _jobApi.postPaperStore(body);
    }
    invalidateJobCaches(jobNumber, stepNo: 1, jobPlanId: jobPlanId);
  }

  /// Post step details for different step types with completion remarks
  Future<void> putStepDetails(
    StepType stepType,
    String jobNumber,
    Map<String, String> formData,
    int stepNo, {
    String? completeRemark,
    int? jobPlanId,
    int? jobStepId,
  }) async {
    // Instead of calling separate step-specific APIs, send form data directly to job planning step completion
    await _putJobPlanningStepFormData(
      jobNumber,
      stepNo,
      formData,
      completeRemark: completeRemark,
      jobPlanId: jobPlanId,
      jobStepId: jobStepId,
    );
  }

  /// Send form data directly to job planning step completion endpoint with completion remarks
  Future<void> _putJobPlanningStepFormData(
    String jobNumber,
    int stepNo,
    Map<String, String> formData, {
    String? completeRemark,
    int? jobPlanId,
    int? jobStepId,
  }) async {
    try {
      print('[_putJobPlanningStepFormData] Sending form data to job planning step completion');
      print('Job Number: $jobNumber, Step No: $stepNo');
      print('Form Data: $formData');
      
      // Get step details to determine step type
      final stepDetails = await getJobPlanningStepDetails(
        jobNumber,
        stepNo,
        jobPlanId: jobPlanId,
        jobStepId: jobStepId,
      );

      if (stepDetails == null) {
        throw Exception('Failed to load step details for job $jobNumber, step $stepNo');
      }

      final resolvedJobStepId = jobStepId ?? (stepDetails['id'] is int ? stepDetails['id'] as int : int.tryParse(stepDetails['id']?.toString() ?? ''));
      final jobPlanIdRaw = jobPlanId ?? stepDetails['jobPlanningId'] ?? stepDetails['jobPlanId'];
      final resolvedJobPlanId = jobPlanIdRaw is int ? jobPlanIdRaw : int.tryParse(jobPlanIdRaw?.toString() ?? '');

      final stepName = stepDetails?['stepName']?.toString() ?? '';
      
      // Check if this is a machine-based step
      final isMachineStep = stepName.toLowerCase().contains('printing') ||
                           stepName.toLowerCase().contains('corrugation') ||
                           stepName.toLowerCase().contains('flute') ||
                           stepName.toLowerCase().contains('punching') ||
                           stepName.toLowerCase().contains('die cutting') ||
                           stepName.toLowerCase().contains('flap') ||
                           stepName.toLowerCase().contains('pasting');
      
      // Map frontend form data to backend expected field names
      // ✅ DO NOT send 'status' for machine-based steps - backend controls it!
      Map<String, dynamic> requestBody = {
        'user': 'NRC015', // Default user
        if (completeRemark != null) 'completeRemark': completeRemark,
        if (resolvedJobPlanId != null) 'jobPlanId': resolvedJobPlanId,
        if (resolvedJobStepId != null) 'jobStepId': resolvedJobStepId,
      };
      
      // Only include status for non-machine steps
      if (!isMachineStep) {
        requestBody['status'] = 'stop';
        print('[_putJobPlanningStepFormData] Non-machine step - including status: stop');
      } else {
        print('[_putJobPlanningStepFormData] Machine-based step - NOT including status (backend controls it)');
      }
      
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
        // Add individual rejection reason quantities
        requestBody['rejectionReasonAQty'] = formData['Rejection Reason A Qty'] ?? formData['rejectionReasonAQty'] ?? '0';
        requestBody['rejectionReasonBQty'] = formData['Rejection Reason B Qty'] ?? formData['rejectionReasonBQty'] ?? '0';
        requestBody['rejectionReasonCQty'] = formData['Rejection Reason C Qty'] ?? formData['rejectionReasonCQty'] ?? '0';
        requestBody['rejectionReasonDQty'] = formData['Rejection Reason D Qty'] ?? formData['rejectionReasonDQty'] ?? '0';
        requestBody['rejectionReasonEQty'] = formData['Rejection Reason E Qty'] ?? formData['rejectionReasonEQty'] ?? '0';
        requestBody['rejectionReasonFQty'] = formData['Rejection Reason F Qty'] ?? formData['rejectionReasonFQty'] ?? '0';
        requestBody['rejectionReasonOthersQty'] = formData['Rejection Reason Others Qty'] ?? formData['rejectionReasonOthersQty'] ?? '0';
        // Machine, operator, date, shift, and QC fields are auto-populated, not user input
      } else if (stepName.toLowerCase().contains('dispatch')) {
        requestBody['noOfBoxes'] = formData['No of Boxes'] ?? formData['noOfBoxes'];
        requestBody['dispatchNo'] = formData['Dispatch No'] ?? formData['dispatchNo'] ?? 'DISP-${DateTime.now().millisecondsSinceEpoch}';
        requestBody['dispatchDate'] = formData['Dispatch Date'] ?? formData['dispatchDate'];
        requestBody['balanceQty'] = formData['Balance Qty'] ?? formData['balanceQty'];
        requestBody['remarks'] = formData['Remarks'] ?? formData['remarks'];
        // Add finished goods quantity (mandatory, can be 0)
        requestBody['finishedGoodsQty'] = formData['finishedGoodsQty'] ?? formData['Finished Goods Qty'] ?? '0';
        // Machine, operator, date, shift, and QC fields are auto-populated, not user input
      } else {
        // Default mapping for unknown steps
        requestBody['quantity'] = formData['quantity'];
        requestBody['remarks'] = formData['remarks'];
        // Machine, operator, date, shift, and QC fields are auto-populated, not user input
      }
      
      print('[_putJobPlanningStepFormData] Mapped request body: $requestBody');
      
      // Send directly to job planning step endpoint
      await _jobApi.updateJobPlanningStepFields(
        jobNumber,
        stepNo,
        requestBody,
        jobPlanId: resolvedJobPlanId,
        jobStepId: resolvedJobStepId,
      );
      invalidateJobCaches(jobNumber, stepNo: stepNo, jobPlanId: resolvedJobPlanId);
      
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
    print('Quantity OK: ${formData['Quantity OK']}'); // ✅ Fixed: Use correct field name
    print('Full formData: $formData');
    
    final body = {
      "jobNrcJobNo": jobNumber,
      "jobStepId": jobStepId,
      "status": "accept",
      "quantity": int.tryParse(formData['Quantity OK'] ?? '0') ?? 0, // ✅ Fixed: Use 'Quantity OK' instead of 'Qty Sheet'
      "date": _formatDateWithMilliseconds(),
      "oprName": formData['Operator Name'] ?? '',
      "wastage": int.tryParse(formData['Wastage'] ?? '0') ?? 0,
      "machine": formData['Machine'] ?? '',
      "noOfColours": int.tryParse(formData['Colors Used'] ?? '0') ?? 0, // ✅ Added: Colors Used field
      "inksUsed": formData['Inks Used'] ?? '', // ✅ Added: Inks Used field
      "coatingType": formData['Coating Type'] ?? '', // ✅ Added: Coating Type field
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
    print('Sheets Count: ${formData['Sheets Count']}'); // ✅ Fixed: Use correct field name
    print('Full formData: $formData');

    final body = {
    "jobStepId": jobStepId,
    "jobNrcJobNo": jobNumber,
    "status": "accept",
    "date": _formatDateWithMilliseconds(),
    "shift": formData['Shift'] ?? '',
    "oprName": formData['Operator Name'] ?? '',
    "machineNo": formData['Machine No'] ?? '',
    "quantity": int.tryParse(formData['Sheets Count'] ?? '0') ?? 0, // ✅ Fixed: Use 'Sheets Count' instead of 'Qty Sheet'
    "size": formData['Size'] ?? '',
    "gsm1": formData['GSM1 (Top Face)'] ?? formData['GSM 1'] ?? '', // ✅ Fixed: Include full field name
    "gsm2": formData['GSM2 (Bottom Face)'] ?? formData['GSM 2'] ?? '', // ✅ Fixed: Include full field name
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
      throw Exception('Failed to get job planning step details for Flute Lamination');
    }

    final jobStepId = stepDetails['id'];
    print("Flute Lamination job step number is $jobStepId");
    print('JobApiService - FluteLamination formData received:');
    print('OK Quantity: ${formData['OK Quantity']}'); // ✅ Fixed: Use correct field name
    print('Full formData: $formData');
    
    final body = {
      "jobNrcJobNo": jobNumber,
      "jobStepId": jobStepId,
      "status": "accept",
      "date": _formatDateWithMilliseconds(),
      "shift": formData['Shift'] ?? '',
      "operatorName": formData['Operator Name'] ?? '',
      "film": formData['Film Type'] ?? '',
      "quantity": int.tryParse(formData['OK Quantity'] ?? '0') ?? 0, // ✅ Fixed: Use 'OK Quantity' instead of 'Qty Sheet'
      "qcCheckSignBy": formData['QC Sign By'] ?? '',
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
      throw Exception('Failed to get job planning step details for Punching');
    }

    final jobStepId = stepDetails['id'];
    print("Punching job step number is $jobStepId");
    print('JobApiService - Punching formData received:');
    print('OK Quantity: ${formData['OK Quantity']}'); // ✅ Fixed: Use correct field name
    print('Full formData: $formData');
    
    final body = {
      "jobNrcJobNo": jobNumber,
      "jobStepId": jobStepId,
      "status": "accept",
      "date": _formatDateWithMilliseconds(),
      "operatorName": formData['Operator Name'] ?? '',
      "machine": formData['Machine'] ?? '',
      "quantity": int.tryParse(formData['OK Quantity'] ?? '0') ?? 0, // ✅ Fixed: Use 'OK Quantity' instead of 'Qty Sheet'
      "die": formData['Die Used (diePunchCode)'] ?? formData['Die Used'] ?? '', // ✅ Fixed: Include full field name
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
      throw Exception('Failed to get job planning step details for Quality Control');
    }

    final jobStepId = stepDetails['id'];
    print("Quality Control job step number is $jobStepId");
    print('JobApiService - QC formData received:');
    print('Pass Quantity: ${formData['Pass Quantity']}'); // ✅ Fixed: Use correct field name
    print('Full formData: $formData');
    
    final body = {
      "jobNrcJobNo": jobNumber,
      "jobStepId": jobStepId,
      "status": "accept",
      "date": _formatDateWithMilliseconds(),
      "checkedBy": formData['Checked By'] ?? formData['Emp Id'] ?? 'System',
      "passQuantity": int.tryParse(formData['Pass Quantity'] ?? '0') ?? 0, // ✅ Fixed: Use 'Pass Quantity'
      "quantity": int.tryParse(formData['Pass Quantity'] ?? '0') ?? 0, // ✅ Fixed: Use 'Pass Quantity'
      "rejectedQty": int.tryParse(formData['Reject Quantity'] ?? '0') ?? 0,
      "reasonForRejection": formData['Reason for Rejection'].toString() ?? '',
      "remarks": formData['Remarks'] ?? formData['Complete Remark'] ?? formData['remarks'] ?? '',
      // Add individual rejection reason quantities
      "rejectionReasonAQty": formData['Rejection Reason A Qty'] ?? formData['rejectionReasonAQty'] ?? '0',
      "rejectionReasonBQty": formData['Rejection Reason B Qty'] ?? formData['rejectionReasonBQty'] ?? '0',
      "rejectionReasonCQty": formData['Rejection Reason C Qty'] ?? formData['rejectionReasonCQty'] ?? '0',
      "rejectionReasonDQty": formData['Rejection Reason D Qty'] ?? formData['rejectionReasonDQty'] ?? '0',
      "rejectionReasonEQty": formData['Rejection Reason E Qty'] ?? formData['rejectionReasonEQty'] ?? '0',
      "rejectionReasonFQty": formData['Rejection Reason F Qty'] ?? formData['rejectionReasonFQty'] ?? '0',
      "rejectionReasonOthersQty": formData['Rejection Reason Others Qty'] ?? formData['rejectionReasonOthersQty'] ?? '0',
    };
    print('🔍 [JobApiService] QC body with rejection reasons:');
    print('  rejectionReasonAQty: ${body["rejectionReasonAQty"]}');
    print('  rejectionReasonBQty: ${body["rejectionReasonBQty"]}');
    print('  rejectionReasonCQty: ${body["rejectionReasonCQty"]}');
    print('  rejectionReasonDQty: ${body["rejectionReasonDQty"]}');
    print('  rejectionReasonEQty: ${body["rejectionReasonEQty"]}');
    print('  rejectionReasonFQty: ${body["rejectionReasonFQty"]}');
    print('  rejectionReasonOthersQty: ${body["rejectionReasonOthersQty"]}');
    print('Full body: $body');
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
    print('No of Boxes: ${formData['No of Boxes']}'); // ✅ Fixed: Use correct field name
    print('Full formData: $formData');
    
    final body = {
      "jobNrcJobNo": jobNumber,
      "jobStepId": jobStepId,
      "status": "accept",
      "date": _formatDateWithMilliseconds(),
      "operatorName": formData['Operator Name'] ?? formData['Emp Id'] ?? 'System',
      "quantity": int.tryParse(formData['No of Boxes'] ?? '0') ?? 0, // ✅ Fixed: Use 'No of Boxes' for quantity
      "noOfBoxes": int.tryParse(formData['No of Boxes'] ?? '0') ?? 0, // ✅ Fixed: Use correct field name
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
  Future<Map<String, dynamic>?> getJobPlanningStepsByNrcJobNo(String jobNumber, {int? jobPlanId}) async {
    final key = _keyPlanningSteps(jobNumber, jobPlanId);
    try {
      return await _getOrFetchMap(
        key,
        () => _jobApi.getJobPlanningStepsByNrcJobNo(jobNumber, jobPlanId: jobPlanId),
      );
    } catch (e) {
      print('Error getting job planning steps: $e');
      return null;
    }
  }

  /// Get job planning steps bypassing cache (used for manual refresh / instant updates)
  Future<Map<String, dynamic>?> getJobPlanningStepsByNrcJobNoFresh(String jobNumber, {int? jobPlanId}) async {
    final key = _keyPlanningSteps(jobNumber, jobPlanId);
    try {
      final data = await _jobApi.getJobPlanningStepsByNrcJobNo(jobNumber, jobPlanId: jobPlanId);
      _cache[key] = _CacheEntry<dynamic>(data);
      return data;
    } catch (e) {
      print('Error getting job planning steps (fresh): $e');
      return null;
    }
  }

  /// Hold PaperStore step with hold remarks
  Future<Map<String, dynamic>?> holdPaperStoreStep(String jobNumber, String holdRemark) async {
    try {
      final result = await _jobApi.holdPaperStoreStep(jobNumber, holdRemark);
      // Clear cache to ensure fresh data on next fetch
      _clearCacheForJob(jobNumber);
      return result;
    } catch (e) {
      print('Error holding PaperStore step: $e');
      return null;
    }
  }

  /// Resume PaperStore step with resume remarks
  Future<Map<String, dynamic>?> resumePaperStoreStep(String jobNumber, String resumeRemark) async {
    try {
      final result = await _jobApi.resumePaperStoreStep(jobNumber, resumeRemark);
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

  /// Hold any step with hold remarks
  Future<Map<String, dynamic>?> holdStep(String stepType, String jobNumber, String holdRemark) async {
    try {
      final result = await _jobApi.holdStep(stepType, jobNumber, holdRemark);
      // Clear cache to ensure fresh data on next fetch
      _clearCacheForJob(jobNumber);
      return result;
    } catch (e) {
      print('Error holding $stepType step: $e');
      return null;
    }
  }

  /// Major hold work on machine
  /// Major hold entire job (simple - no machine/step required)
  Future<Map<String, dynamic>?> majorHoldJob(
    String jobNumber, {
    String? majorHoldReason,
  }) async {
    try {
      final result = await _jobApi.majorHoldJob(
        jobNumber,
        majorHoldReason: majorHoldReason,
      );
      // Clear cache to ensure fresh data on next fetch
      _clearCacheForJob(jobNumber);
      return result;
    } catch (e) {
      print('Error major holding job: $e');
      return null;
    }
  }

  /// Major hold specific job plan (simple - no machine/step required)
  Future<Map<String, dynamic>?> majorHoldJobPlan(
    int jobPlanId, {
    String? majorHoldReason,
  }) async {
    try {
      final result = await _jobApi.majorHoldJobPlan(
        jobPlanId,
        majorHoldReason: majorHoldReason,
      );
      return result;
    } catch (e) {
      print('Error major holding job plan: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> majorHoldWorkOnMachine(
    String jobNumber,
    int stepNo,
    String machineId, {
    Map<String, dynamic>? formData,
    String? majorHoldReason,
    int? jobPlanId,
    int? jobStepId,
  }) async {
    try {
      final result = await _jobApi.majorHoldWorkOnMachine(
        jobNumber,
        stepNo,
        machineId,
        formData: formData,
        majorHoldReason: majorHoldReason,
        jobPlanId: jobPlanId,
        jobStepId: jobStepId,
      );
      // Clear cache to ensure fresh data on next fetch
      _clearCacheForJob(jobNumber);
      return result;
    } catch (e) {
      print('Error major holding work on machine: $e');
      return null;
    }
  }

  /// Resume major hold for a specific job plan
  Future<Map<String, dynamic>?> resumeMajorHoldJobPlan(
    int jobPlanId, {
    String? resumeRemark,
  }) async {
    try {
      final result = await _jobApi.resumeMajorHoldJobPlan(
        jobPlanId,
        resumeRemark: resumeRemark,
      );
      return result;
    } catch (e) {
      print('Error resuming major hold for job plan: $e');
      return null;
    }
  }

  /// Resume any step with resume remarks
  Future<Map<String, dynamic>?> resumeStep(String stepType, String jobNumber, String resumeRemark) async {
    try {
      final result = await _jobApi.resumeStep(stepType, jobNumber, resumeRemark);
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
  Future<Map<String, dynamic>?> getAvailableMachines(String nrcJobNo, int stepNo, {int? jobPlanId, int? jobStepId}) async {
    try {
      final result = await _jobApi.getAvailableMachines(nrcJobNo, stepNo, jobPlanId: jobPlanId, jobStepId: jobStepId);
      return result;
    } catch (e) {
      print('Error getting available machines for step $stepNo: $e');
      return null;
    }
  }

  /// Start work on a specific machine
  Future<Map<String, dynamic>?> startWorkOnMachine(
    String nrcJobNo,
    int stepNo,
    String machineId, {
    Map<String, dynamic>? formData,
    int? jobPlanId,
    int? jobStepId,
  }) async {
    try {
      final result = await _jobApi.startWorkOnMachine(
        nrcJobNo,
        stepNo,
        machineId,
        formData: formData,
        jobPlanId: jobPlanId,
        jobStepId: jobStepId,
      );
      // Clear cache to ensure fresh data on next fetch
      _clearCacheForJob(nrcJobNo);
      return result;
    } catch (e) {
      print('Error starting work on machine $machineId: $e');
      // Re-throw the exception so the UI can handle it properly
      rethrow;
    }
  }

  /// Start urgent job work (auto-assigns user's machine)
  Future<Map<String, dynamic>?> startUrgentJobWork(String nrcJobNo, int stepNo, {Map<String, dynamic>? formData, int? jobPlanId, int? jobStepId}) async {
    try {
      final result = await _jobApi.startUrgentJobWork(nrcJobNo, stepNo, formData: formData, jobPlanId: jobPlanId, jobStepId: jobStepId);
      // Clear cache to ensure fresh data on next fetch
      _clearCacheForJob(nrcJobNo);
      return result;
    } catch (e) {
      print('Error starting urgent job work for step $stepNo: $e');
      // Re-throw the exception so the UI can handle it properly
      rethrow;
    }
  }

  /// Complete work on a specific machine
  Future<Map<String, dynamic>?> completeWorkOnMachine(
    String nrcJobNo,
    int stepNo,
    String machineId, {
    Map<String, dynamic>? formData,
    int? jobPlanId,
    int? jobStepId,
  }) async {
    try {
      final result = await _jobApi.completeWorkOnMachine(
        nrcJobNo,
        stepNo,
        machineId,
        formData: formData,
        jobPlanId: jobPlanId,
        jobStepId: jobStepId,
      );
      // Clear cache to ensure fresh data on next fetch
      _clearCacheForJob(nrcJobNo);
      return result;
    } catch (e) {
      print('Error completing work on machine $machineId: $e');
      // Re-throw the exception so the UI can handle it properly
      rethrow;
    }
  }

  /// Hold work on a specific machine
  Future<Map<String, dynamic>?> holdWorkOnMachine(
    String nrcJobNo,
    int stepNo,
    String machineId, {
    Map<String, dynamic>? formData,
    String? holdReason,
    int? jobPlanId,
    int? jobStepId,
  }) async {
    try {
      final result = await _jobApi.holdWorkOnMachine(
        nrcJobNo,
        stepNo,
        machineId,
        formData: formData,
        holdReason: holdReason,
        jobPlanId: jobPlanId,
        jobStepId: jobStepId,
      );
      // Clear cache to ensure fresh data on next fetch
      _clearCacheForJob(nrcJobNo);
      return result;
    } catch (e) {
      print('Error holding work on machine $machineId: $e');
      // Re-throw the exception so the UI can handle it properly
      rethrow;
    }
  }

  /// Resume work on a specific machine
  Future<Map<String, dynamic>?> resumeWorkOnMachine(
    String nrcJobNo,
    int stepNo,
    String machineId, {
    Map<String, dynamic>? formData,
    int? jobPlanId,
    int? jobStepId,
  }) async {
    try {
      final result = await _jobApi.resumeWorkOnMachine(
        nrcJobNo,
        stepNo,
        machineId,
        formData: formData,
        jobPlanId: jobPlanId,
        jobStepId: jobStepId,
      );
      // Clear cache to ensure fresh data on next fetch
      _clearCacheForJob(nrcJobNo);
      return result;
    } catch (e) {
      print('Error resuming work on machine $machineId: $e');
      // Re-throw the exception so the UI can handle it properly
      rethrow;
    }
  }

  /// Stop work on a specific machine
  /// Stop work on a specific machine - ONLY changes status, does NOT save formData
  Future<Map<String, dynamic>?> stopWorkOnMachine(
    String nrcJobNo,
    int stepNo,
    String machineId, {
    int? jobPlanId,
    int? jobStepId,
  }) async {
    try {
      // ✅ UPDATED: Stop does NOT send formData anymore
      final result = await _jobApi.stopWorkOnMachine(
        nrcJobNo,
        stepNo,
        machineId,
        jobPlanId: jobPlanId,
        jobStepId: jobStepId,
      );
      // Clear cache to ensure fresh data on next fetch
      _clearCacheForJob(nrcJobNo);
      return result;
    } catch (e) {
      print('Error stopping work on machine $machineId: $e');
      // Re-throw the exception so the UI can handle it properly
      rethrow;
    }
  }

  /// Get machine work status for a job step
  Future<Map<String, dynamic>?> getMachineWorkStatus(
    String nrcJobNo,
    int stepNo, {
    int? jobPlanId,
    int? jobStepId,
  }) async {
    try {
      final result = await _jobApi.getMachineWorkStatus(
        nrcJobNo,
        stepNo,
        jobPlanId: jobPlanId,
        jobStepId: jobStepId,
      );
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

  /// Get available quantity from Paper Store for cascading validation
  Future<int?> getPaperStoreAvailableQuantity(String jobNumber, {int? jobPlanId}) async {
    try {
      final paperStoreData = await _jobApi.getPaperStoreStepByJob(
        jobNumber,
        jobPlanId: jobPlanId,
      );
      print('🔍 DEBUG: paperStoreData = $paperStoreData');
      
      if (paperStoreData != null && paperStoreData['data'] != null) {
        // The API returns: { "data": { "available": 11000, ... }, "editableFields": { ... } }
        final innerData = paperStoreData['data'];
        print('🔍 DEBUG: innerData = $innerData');
        
        // Try 'available' field first
        var available = innerData['available'];
        print('🔍 DEBUG: available = $available');
        
        // If 'available' is null, try 'quantity' field as fallback
        if (available == null) {
          available = innerData['quantity'];
          print('🔍 DEBUG: available (from quantity) = $available');
        }
        
        if (available != null) {
          final availableQty = int.tryParse(available.toString());
          print('✅ Paper Store Available Quantity: $availableQty');
          return availableQty;
        }
      }
      print('⚠️ No Paper Store available quantity found for job: $jobNumber');
      return null;
    } catch (e) {
      print('❌ Error fetching Paper Store available quantity: $e');
      return null;
    }
  }

  /// Get available finished goods quantity for a job
  Future<int?> getAvailableFinishedGoodsQty(String jobNumber) async {
    try {
      return await _jobApi.getAvailableFinishedGoodsQty(jobNumber);
    } catch (e) {
      print('Error getting available finished goods quantity: $e');
      return 0;
    }
  }

  /// Get available quantity from previous step for cascading validation
  /// Supports multiple machines by summing OK quantities across all machine records
  Future<int?> getPreviousStepAvailableQuantity(String jobNumber, StepType currentStep, {int? jobPlanId}) async {
    try {
      StepType? previousStepType;
      
      // Determine which step to get available quantity from
      switch (currentStep) {
        case StepType.printing:
        case StepType.corrugation:
          // Both Printing and Corrugation get available quantity from Paper Store
          return await getPaperStoreAvailableQuantity(jobNumber, jobPlanId: jobPlanId);
          
        case StepType.fluteLamination:
          // Flute Lamination gets OK quantity from Printing
          previousStepType = StepType.printing;
          break;
          
        case StepType.punching:
          // Punching gets OK quantity from Flute Lamination
          previousStepType = StepType.fluteLamination;
          break;
          
        case StepType.flapPasting:
          // Flap Pasting gets OK quantity from Punching
          previousStepType = StepType.punching;
          break;
          
        case StepType.qc:
          // QC gets OK quantity from Flap Pasting
          previousStepType = StepType.flapPasting;
          break;
          
        case StepType.dispatch:
          // Dispatch gets OK quantity from QC
          previousStepType = StepType.qc;
          break;
          
        default:
          // For other steps, try to get from Paper Store as fallback
          return await getPaperStoreAvailableQuantity(jobNumber, jobPlanId: jobPlanId);
      }
      
      if (previousStepType != null) {
        int? previousJobStepId;
        if (jobPlanId != null) {
          final previousStepNo = _stepNumberForType(previousStepType);
          final previousStepMeta = await getJobPlanningStepDetails(
            jobNumber,
            previousStepNo,
            jobPlanId: jobPlanId,
          );
          final rawId = previousStepMeta?['id'];
          if (rawId is int) {
            previousJobStepId = rawId;
          } else if (rawId is String) {
            previousJobStepId = int.tryParse(rawId);
          }
        }

        // Get step details for the previous step (may include multiple machine records)
        final stepDetails = await getStepDetailsWithEditability(
          jobNumber,
          previousStepType,
          jobPlanId: jobPlanId,
          jobStepId: previousJobStepId,
        );
        
        if (stepDetails.isNotEmpty) {
          print('🔍 [Qty] Step details (first item) for ${previousStepType.name}: ${stepDetails.first.data}');
          int totalOkQuantity = 0;
          int recordsProcessed = 0;
          
          print('🔍 Processing ${stepDetails.length} records for ${previousStepType.name}');
          
          // Sum OK quantities across all machines for this step
          for (var stepDetail in stepDetails) {
            final stepData = stepDetail.data;
            print('🔍 [Qty] Processing step data: $stepData');
            print('🔍 [Qty] Step data keys: ${stepData.keys.toList()}');
            
            // Try different field names for OK quantity
            final okQuantityCandidates = [
              stepData['quantityOK'],
              stepData['quantity'],
              stepData['Qty Sheet'],
              stepData['qtySheet'],
              stepData['OK Qty'],
              stepData['okQuantity'],
              stepData['Ok Quantity'],
              stepData['OK Quantity'],
              stepData['Quantity OK'],
              stepData['okQty'],
              stepData['passQuantity'], // For QC step
            ];

            bool foundQuantity = false;
            for (final candidate in okQuantityCandidates) {
              if (candidate != null) {
                print('🔍 [Qty] Trying candidate: $candidate (type: ${candidate.runtimeType})');
                // Handle both int and string types
                int? qty;
                if (candidate is int) {
                  qty = candidate;
                } else if (candidate is num) {
                  qty = candidate.toInt();
                } else {
                  qty = int.tryParse(candidate.toString());
                }
                
                if (qty != null && qty >= 0) { // Changed from > 0 to >= 0 to allow 0
                  totalOkQuantity += qty;
                  recordsProcessed++;
                  foundQuantity = true;
                  print('  ✅ Machine record ${recordsProcessed}: OK Qty = $qty (Total so far: $totalOkQuantity)');
                  break;
                }
              }
            }
            
            // If no quantity found, log for debugging
            if (!foundQuantity) {
              print('⚠️ [Qty] No quantity found in step data. Available keys: ${stepData.keys.toList()}');
              print('⚠️ [Qty] quantity field value: ${stepData['quantity']}');
              print('⚠️ [Qty] quantityOK field value: ${stepData['quantityOK']}');
            }
          }
          
          if (recordsProcessed > 0) {
            print('✅ Previous step (${previousStepType.name}) Total OK Quantity from $recordsProcessed machines: $totalOkQuantity');
            return totalOkQuantity;
          } else {
            print('⚠️ No valid OK quantities found in ${stepDetails.length} records for ${previousStepType.name}');
          }
        } else if (previousJobStepId != null) {
          print('⚠️ No step details list for previous step; attempting fallback using jobStepId $previousJobStepId');
          final previousStepNo = _stepNumberForType(previousStepType);
          final previousStepMeta = await getJobPlanningStepDetails(
            jobNumber,
            previousStepNo,
            jobPlanId: jobPlanId,
          );
          if (previousStepMeta != null) {
            final printingDetails = previousStepMeta['printingDetails'];
            final candidateFields = <dynamic>[
              previousStepMeta['quantityOK'],
              previousStepMeta['quantity'],
              previousStepMeta['Qty Sheet'],
              previousStepMeta['okQuantity'],
              previousStepMeta['OK Quantity'],
              previousStepMeta['Quantity OK'],
            ];

            if (printingDetails is Map<String, dynamic>) {
              candidateFields.addAll([
                printingDetails['quantityOK'],
                printingDetails['quantity'],
                printingDetails['okQuantity'],
                printingDetails['Qty Sheet'],
                printingDetails['OK Quantity'],
                printingDetails['Quantity OK'],
                printingDetails['OK Qty'],
              ]);
            } else if (printingDetails is List) {
              for (final entry in printingDetails) {
                if (entry is Map<String, dynamic>) {
                  candidateFields.addAll([
                    entry['quantityOK'],
                    entry['quantity'],
                    entry['okQuantity'],
                    entry['Qty Sheet'],
                    entry['OK Quantity'],
                    entry['Quantity OK'],
                    entry['OK Qty'],
                  ]);
                }
              }
            }

            for (final field in candidateFields) {
              if (field != null) {
                final qty = int.tryParse(field.toString());
                if (qty != null && qty > 0) {
                  print('✅ Fallback quantity from previous step metadata for jobStepId $previousJobStepId: $qty');
                  return qty;
                }
              }
            }
          }
        }
      }
      
      print('⚠️ No previous step quantity found for step: ${currentStep.name}');
      return null;
    } catch (e) {
      print('❌ Error fetching previous step available quantity: $e');
      return null;
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

  /// Get all users for name lookup
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      return await _jobApi.getAllUsers();
    } catch (e) {
      print('Error fetching all users: $e');
      return [];
    }
  }

  /// Get individual user by ID for name lookup
  Future<Map<String, dynamic>?> getUserById(String userId) async {
    try {
      return await _jobApi.getUserById(userId);
    } catch (e) {
      print('Error fetching user $userId: $e');
      return null;
    }
  }

}

class _CacheEntry<T> {
  final T value;
  final DateTime timestamp;
  _CacheEntry(this.value) : timestamp = DateTime.now();

  bool isFresh(Duration ttl) => DateTime.now().difference(timestamp) <= ttl;
}