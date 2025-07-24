import '../../../data/datasources/job_api.dart';
import '../../../data/models/job_step_models.dart';

class JobApiService {
  final JobApi _jobApi;

  JobApiService(this._jobApi);

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

  Future<Map<String, dynamic>?> fetchJobDetails(String jobNumber) async {
    try {
      return await _jobApi.getJobByNrcJobNo(jobNumber);
    } catch (e) {
      print('Error fetching job details: $e');
      return null;
    }
  }

  Future<void> startPaperStoreWork(String jobNumber, Map<String, dynamic> jobDetails) async {
    final body = {
      "jobStepId": 1,
      'jobNrcJobNo': jobNumber,
      'status': 'in_progress',
      'sheetSize': jobDetails['boardSize'] ?? '',
      'required': int.tryParse(jobDetails['noUps']?.toString() ?? '0') ?? 0,
      'gsm': jobDetails['fluteType'] ?? '',
      'issuedDate': DateTime.now().toUtc().toIso8601String(),
    };

    await _jobApi.postPaperStore(body);
  }

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

  Future<void> completePaperStoreWork(String jobNumber, Map<String, dynamic> jobDetails, Map<String, String> formData) async {
    final body = {
      "jobStepId": 1,
      'jobNrcJobNo': jobNumber,
      'status': 'accept',
      'sheetSize': jobDetails['boardSize'] ?? '',
      'required': int.tryParse(jobDetails['noUps']?.toString() ?? '0') ?? 0,
      'available': int.tryParse(formData['available'] ?? '0') ?? 0,
      'issuedDate': DateTime.now().toUtc().toIso8601String(),
      'mill': formData['mill'] ?? '',
      'extraMargin': formData['extraMargin'] ?? '',
      'gsm': jobDetails['fluteType'] ?? '',
      'quality': formData['quality'] ?? '',
    };

    final paperStore = await _jobApi.getPaperStoreStepByJob(jobNumber);
    if (paperStore != null) {
      await _jobApi.putPaperStore(jobNumber, body);
    }

    // Update planning step status
    await updateStepStatus(jobNumber, 1, "stop");
  }

  Future<void> postStepDetails(StepType stepType, String jobNumber, Map<String, String> formData, int stepNo) async {
    switch (stepType) {
      case StepType.printing:
        await _postPrintingDetails(jobNumber, formData, stepNo);
        break;
      case StepType.corrugation:
        await _postCorrugationDetails(jobNumber, formData, stepNo);
        break;
      case StepType.fluteLamination:
        await _postFluteLaminationDetails(jobNumber, formData, stepNo);
        break;
      case StepType.punching:
        await _postPunchingDetails(jobNumber, formData, stepNo);
        break;
      case StepType.flapPasting:
        await _postFlapPastingDetails(jobNumber, formData, stepNo);
        break;
      case StepType.qc:
        await _postQCDetails(jobNumber, formData, stepNo);
        break;
      case StepType.dispatch:
        await _postDispatchDetails(jobNumber, formData, stepNo);
        break;
      default:
        break;
    }
  }

  Future<void> _postPrintingDetails(String jobNumber, Map<String, String> formData, int stepNo) async {
    final body = {
      "jobNrcJobNo": jobNumber,
      "jobStepId": stepNo,
      "status": "accept",
      "postPrintingFinishingOkQty": int.tryParse(formData['Quantity OK'] ?? '0') ?? 0,
      "date": formData['Date'] ?? DateTime.now().toIso8601String(),
      "operatorName": formData['Operator Name'] ?? '',
      "colorsUsed": formData['Colors Used'] ?? '',
      "wastage": int.tryParse(formData['Wastage'] ?? '0') ?? 0,
      "machine": formData['Machine'] ?? '',
      "remarks": formData['Remarks'] ?? '',
    };
    await _jobApi.postPrintingDetails(body);
  }

  Future<void> _postCorrugationDetails(String jobNumber, Map<String, String> formData, int stepNo) async {
    final body = {
      "jobNrcJobNo": jobNumber,
      "jobStepId": stepNo,
      "status": "accept",
      "date": formData['Date'] ?? DateTime.now().toIso8601String(),
      "operatorName": formData['Operator Name'] ?? '',
      "machineNo": formData['Machine No'] ?? '',
      "sheetsCount": int.tryParse(formData['Sheets Count'] ?? '0') ?? 0,
      "size": formData['Size'] ?? '',
      "gsm": formData['GSM'] ?? '',
      "fluteType": formData['Flute Type'] ?? '',
      "remarks": formData['Remarks'] ?? '',
    };
    await _jobApi.postCorrugationDetails(body);
  }

  Future<void> _postFluteLaminationDetails(String jobNumber, Map<String, String> formData, int stepNo) async {
    final body = {
      "jobNrcJobNo": jobNumber,
      "jobStepId": stepNo,
      "status": "accept",
      "date": formData['Date'] ?? DateTime.now().toIso8601String(),
      "operatorName": formData['Operator Name'] ?? '',
      "filmType": formData['Film Type'] ?? '',
      "okQuantity": int.tryParse(formData['OK Quantity'] ?? '0') ?? 0,
      "adhesive": formData['Adhesive'] ?? '',
      "wastage": int.tryParse(formData['Wastage'] ?? '0') ?? 0,
      "remarks": formData['Remarks'] ?? '',
    };
    await _jobApi.postFluteLaminationDetails(body);
  }

  Future<void> _postPunchingDetails(String jobNumber, Map<String, String> formData, int stepNo) async {
    final body = {
      "jobNrcJobNo": jobNumber,
      "jobStepId": stepNo,
      "status": "accept",
      "date": formData['Date'] ?? DateTime.now().toIso8601String(),
      "operatorName": formData['Operator Name'] ?? '',
      "machine": formData['Machine'] ?? '',
      "okQuantity": int.tryParse(formData['OK Quantity'] ?? '0') ?? 0,
      "dieUsed": formData['Die Used'] ?? '',
      "wastage": int.tryParse(formData['Wastage'] ?? '0') ?? 0,
      "remarks": formData['Remarks'] ?? '',
    };
    await _jobApi.postPunchingDetails(body);
  }

  Future<void> _postFlapPastingDetails(String jobNumber, Map<String, String> formData, int stepNo) async {
    final body = {
      "jobNrcJobNo": jobNumber,
      "jobStepId": stepNo,
      "status": "accept",
      "date": formData['Date'] ?? DateTime.now().toIso8601String(),
      "operatorName": formData['Operator Name'] ?? '',
      "machineNo": formData['Machine No'] ?? '',
      "adhesive": formData['Adhesive'] ?? '',
      "quantity": int.tryParse(formData['Quantity'] ?? '0') ?? 0,
      "wastage": int.tryParse(formData['Wastage'] ?? '0') ?? 0,
      "remarks": formData['Remarks'] ?? '',
    };
    await _jobApi.postFlapPastingDetails(body);
  }

  Future<void> _postQCDetails(String jobNumber, Map<String, String> formData, int stepNo) async {
    final body = {
      "jobNrcJobNo": jobNumber,
      "jobStepId": stepNo,
      "status": "accept",
      "date": formData['Date'] ?? DateTime.now().toIso8601String(),
      "checkedBy": formData['Checked By'] ?? '',
      "passQuantity": int.tryParse(formData['Pass Quantity'] ?? '0') ?? 0,
      "rejectQuantity": int.tryParse(formData['Reject Quantity'] ?? '0') ?? 0,
      "reasonForRejection": formData['Reason for Rejection'] ?? '',
      "remarks": formData['Remarks'] ?? '',
    };
    await _jobApi.postQCDetails(body);
  }

  Future<void> _postDispatchDetails(String jobNumber, Map<String, String> formData, int stepNo) async {
    final body = {
      "jobNrcJobNo": jobNumber,
      "jobStepId": stepNo,
      "status": "accept",
      "date": formData['Date'] ?? DateTime.now().toIso8601String(),
      "operatorName": formData['Operator Name'] ?? '',
      "noOfBoxes": int.tryParse(formData['No of Boxes'] ?? '0') ?? 0,
      "dispatchNo": formData['Dispatch No'] ?? '',
      "dispatchDate": formData['Dispatch Date'] ?? '',
      "balanceQty": int.tryParse(formData['Balance Qty'] ?? '0') ?? 0,
      "remarks": formData['Remarks'] ?? '',
    };
    await _jobApi.postDispatchDetails(body);
  }
}