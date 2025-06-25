import 'package:flutter/material.dart';

import 'job_details.dart';

enum ApprovalStatus { pending, accepted, rejected }

class PurchaseOrder {
  String id;
  String srNo;
  String poNumber;
  String poDate;
  String customer;
  String plant;
  String style;
  String dieCode;
  String boardSize;
  String fluteType;
  String noOfUps;
  String noOfSheets;
  String totalPOQuantity;
  String unit;
  String deliveryDate;
  String nrcDeliveryDate;
  String dispatchDate;
  String dispatchQuantity;
  String pendingQuantity;
  String pendingValidity;
  String jockeyMonth;
  String shadeCardApprovalDate;
  ApprovalStatus status;
  String rejectionReason;
  bool hasJobDetails = false;
  JobDetails? _jobDetails;

  JobDetails? get jobDetails => _jobDetails;
  set jobDetails(JobDetails? details) {
    _jobDetails = details;
    hasJobDetails = details != null;
  }

  PurchaseOrder({
    required this.id,
    required this.srNo,
    required this.poNumber,
    required this.poDate,
    required this.customer,
    required this.plant,
    required this.style,
    required this.dieCode,
    required this.boardSize,
    required this.fluteType,
    required this.noOfUps,
    required this.noOfSheets,
    required this.totalPOQuantity,
    required this.unit,
    required this.deliveryDate,
    required this.nrcDeliveryDate,
    required this.dispatchDate,
    required this.dispatchQuantity,
    required this.pendingQuantity,
    required this.pendingValidity,
    required this.jockeyMonth,
    required this.shadeCardApprovalDate,
    this.status = ApprovalStatus.pending,
    this.rejectionReason = '',
    this.hasJobDetails = false,
  });
} 