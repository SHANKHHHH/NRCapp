import 'package:nrc/data/models/Job.dart';

import '../../../data/datasources/job_api.dart';
import '../../../data/models/job_step_models.dart';

class JobApiService {
  final JobApi _jobApi;

  JobApiService(this._jobApi);

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

  /// Get step details from job planning
  Future<Map<String, dynamic>?> getJobPlanningStepDetails(String jobNumber, int stepNo) async {
    try {
      return await _jobApi.getJobPlanningStepDetails(jobNumber, stepNo);
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
    try {
      return await _jobApi.getPaperStoreStepByJob(jobNumber);
    } catch (e) {
      print('Error getting paper store step: $e');
      return null;
    }
  }

  /// Fetch job details
  Future<List<Job>?> fetchJobDetails(String jobNumber) async {
    try {
      return await _jobApi.getJobsByNo(jobNumber);
    } catch (e) {
      print('Error fetching job details: $e');
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
      "jobStepId": jobStepId, // Use the ID from job planning step details
      'jobNrcJobNo': jobNumber,
      'status': 'in_progress',
      'sheetSize': jobDetails['boardSize'] ?? '',
      'required': int.tryParse(jobDetails['noUps']?.toString() ?? '0') ?? 0,
      'gsm': jobDetails['fluteType'] ?? '',
      'issuedDate': _formatDateWithMilliseconds(),
    };

    await _jobApi.postPaperStore(body);
  }
  /// Update job planning step status and dates
  Future<void> updateJobPlanningStepComplete(String jobNumber, int stepNo, String status, {String? user}) async {
    try {
      // If user is provided, update with user information
      if (user != null && user.isNotEmpty) {
        await _jobApi.updateJobPlanningStepFields(jobNumber, stepNo, {
          'status': status,
          'user': user,
        });
      } else {
        await _jobApi.updateJobPlanningStepComplete(jobNumber, stepNo, status);
      }

      final stepDetails = await getJobPlanningStepDetails(jobNumber, stepNo);
      if (status == 'start') {
        final postBody = {
          'jobStepId': stepDetails!['id'],
          'jobNrcJobNo': jobNumber,
          'status': 'in_progress',
        };
        switch (stepNo) {
          case 2:
            print('[JobApiService.updateJobPlanningStepComplete] Posting in_progress to Printing');
            await _jobApi.postPrintingDetails(postBody);
            break;
          case 3:
            print('[JobApiService.updateJobPlanningStepComplete] Posting in_progress to Corrugation');
            await _jobApi.postCorrugationDetails(postBody);
            break;
          case 4:
            print('[JobApiService.updateJobPlanningStepComplete] Posting in_progress to Flute Lamination');
            await _jobApi.postFluteLaminationDetails(postBody);
            break;
          case 5:
            print('[JobApiService.updateJobPlanningStepComplete] Posting in_progress to Punching');
            await _jobApi.postPunchingDetails(postBody);
            break;
          case 6:
            print('[JobApiService.updateJobPlanningStepComplete] Posting in_progress to Flap Pasting');
            await _jobApi.postFlapPastingDetails(postBody);
            break;
          case 7:
            print('[JobApiService.updateJobPlanningStepComplete] Posting in_progress to QC');
            await _jobApi.postQCDetails(postBody);
            break;
          case 8:
            print('[JobApiService.updateJobPlanningStepComplete] Posting in_progress to Dispatch');
            await _jobApi.postDispatchDetails(postBody);
            break;
          default:
          // Do nothing for unknown step
            break;
        }
      }
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
      'required': int.tryParse(jobDetails['noUps']?.toString() ?? '0') ?? 0,
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
  }

  /// Post step details for different step types
  Future<void> putStepDetails(StepType stepType, String jobNumber, Map<String, String> formData, int stepNo) async {
    switch (stepType) {
      case StepType.printing:
        await _putPrintingDetails(jobNumber, formData, stepNo); // uses PUT
        break;
      case StepType.corrugation:
        await _putCorrugationDetails(jobNumber, formData, stepNo); // uses PUT
        break;
      case StepType.fluteLamination:
        await _putFluteLaminationDetails(jobNumber, formData, stepNo); // uses PUT
        break;
      case StepType.punching:
        await _putPunchingDetails(jobNumber, formData, stepNo); // uses PUT
        break;
      case StepType.flapPasting:
        await _putFlapPastingDetails(jobNumber, formData, stepNo); // uses PUT
        break;
      case StepType.qc:
        await _putQCDetails(jobNumber, formData, stepNo); // uses PUT
        break;
      case StepType.dispatch:
        await _putDispatchDetails(jobNumber, formData, stepNo); // uses PUT
        break;
      default:
        break;
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
      "postPrintingFinishingOkQty": int.tryParse(formData['Qty Sheet'] ?? '0') ?? 0,
      "date": _formatDateWithMilliseconds(),
      "oprName": formData['Operator Name'] ?? '',
      "wastage": int.tryParse(formData['Wastage'] ?? '0') ?? 0,
      "machine": formData['Machine'] ?? '',
    };
    print("Printing Details");
    print(body);
    await _jobApi.putPrintingDetails(body,jobNumber);
  }

  Future<void> _putCorrugationDetails(String jobNumber, Map<String, String> formData, int stepNo) async {
    print("Comes to Corrugation");
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
    "noOfSheets": int.tryParse(formData['Qty Sheet'] ?? '0') ?? 0,
    "size": formData['Size'] ?? '',
    "gsm1": formData['GSM 1'] ?? '',
    "gsm2": formData['GSM 2'] ?? '',
    "flute": formData['Flute Type'] ?? '',
    "remarks": formData['Remarks'] ?? '',
    "qcCheckSignBy": formData['QC Check Sign By'] ?? '',
    };


    print("Corrugation Details Body:");
    print(body);

    await _jobApi.putCorrugationDetails(body,jobNumber);
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
      "okQty": int.tryParse(formData['Qty Sheet'] ?? '0') ?? 0, // Use Qty Sheet from form
      "qcCheckSignBy": formData['QC Sign By'] ?? '',     // New
      "adhesive": formData['Adhesive'] ?? '',
      "wastage": int.tryParse(formData['Wastage'] ?? '0') ?? 0,
    };

    await _jobApi.putFluteLaminationDetails(body,jobNumber);
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
      "okQty": int.tryParse(formData['Qty Sheet'] ?? '0') ?? 0,
      "die": formData['Die Used'] ?? '',
      "wastage": int.tryParse(formData['Wastage'] ?? '0') ?? 0,
      "remarks": formData['Remarks'] ?? '',
    };
    await _jobApi.putPunchingDetails(body,jobNumber);
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
      "checkedBy": formData['Checked By'] ?? '',
      "passQty": int.tryParse(formData['Qty Sheet'] ?? '0') ?? 0,
      "rejectedQty": int.tryParse(formData['Reject Quantity'] ?? '0') ?? 0,
      "reasonForRejection": formData['Reason for Rejection'] ?? '',
      "remarks": formData['Remarks'] ?? '',
      "user": formData['Emp Id'] ?? '',
    };
    print(body);
    await _jobApi.putQCDetails(body,jobNumber);
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
      "user": formData['Emp Id'] ?? '',
    };
    await _jobApi.putFlapPastingDetails(body,jobNumber);
  }

  Future<void> _putDispatchDetails(String jobNumber, Map<String, String> formData, int stepNo) async {
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
      "operatorName": formData['Operator Name'] ?? '',
      "noOfBoxes": int.tryParse(formData['No of Boxes'] ?? '0') ?? 0,
      "dispatchNo": formData['Dispatch No'] ?? '',
      "dispatchDate": _formatDateWithMilliseconds(),
      "balanceQty": int.tryParse(formData['Balance Qty'] ?? '0') ?? 0,
      "remarks": formData['Remarks'] ?? '',
      "user": formData['Emp Id'] ?? '',
    };
    await _jobApi.putDispatchDetails(body,jobNumber);
  }

  /// Helper to get step status by type
  Future<String?> getStepStatusByType(StepType stepType, String jobNumber) async {
    switch (stepType) {
      case StepType.printing:
        final details = await _jobApi.getPrintingDetails(jobNumber);
        print("this is the status for particular post");
        print(details?['data'][0]['status']);
        return details?['data'][0]['status'];
      case StepType.corrugation:
        final details = await _jobApi.getCorrugationDetails(jobNumber);
        return details?['data'][0]['status'];
      case StepType.fluteLamination:
        final details = await _jobApi.getFluteLaminationDetails(jobNumber);
        return details?['data'][0]['status'];
      case StepType.punching:
        final details = await _jobApi.getPunchingDetails(jobNumber);
        return details?['data'][0]['status'];
      case StepType.flapPasting:
        final details = await _jobApi.getFlapPastingDetails(jobNumber);
        return details?['data'][0]['status'];
      case StepType.qc:
        final details = await _jobApi.getQCDetails(jobNumber);
        return details?['data'][0]['status'];
      case StepType.dispatch:
        final details = await _jobApi.getDispatchDetails(jobNumber);
        return details?['data'][0]['status'];
      default:
        return null;
    }
  }

  Future<Map<String, dynamic>?> getPrintingDetails(String jobNumber) async {
    return await _jobApi.getPrintingDetails(jobNumber);
  }

  Future<Map<String, dynamic>?> getCorrugationDetails(String jobNumber) async {
    return await _jobApi.getCorrugationDetails(jobNumber);
  }

  Future<Map<String, dynamic>?> getFluteLaminationDetails(String jobNumber) async {
    return await _jobApi.getFluteLaminationDetails(jobNumber);
  }

  Future<Map<String, dynamic>?> getPunchingDetails(String jobNumber) async {
    return await _jobApi.getPunchingDetails(jobNumber);
  }

  Future<Map<String, dynamic>?> getFlapPastingDetails(String jobNumber) async {
    return await _jobApi.getFlapPastingDetails(jobNumber);
  }

  Future<Map<String, dynamic>?> getQCDetails(String jobNumber) async {
    return await _jobApi.getQCDetails(jobNumber);
  }

  Future<Map<String, dynamic>?> getDispatchDetails(String jobNumber) async {
    return await _jobApi.getDispatchDetails(jobNumber);
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
    try {
      return await _jobApi.getJobPlanningStepsByNrcJobNo(jobNumber);
    } catch (e) {
      print('Error getting job planning steps: $e');
      return null;
    }
  }
}