import 'package:flutter/material.dart';
import 'package:nrc/data/models/purchase_order.dart';

enum JobStatus { active, inactive, hold, workingStarted, completed }
enum JobDemand { high, medium, low }

class Job {
  final String jobNumber;
  final String customer;
  final String plant;
  final String jobDate;
  final String deliveryDate;
  final String createdDate;
  final String createdBy;
  final String style;
  final String dieCode;
  final String boardSize;
  final String fluteType;
  final String jobMonth;
  final String noOfUps;
  final String noOfSheets;
  final int totalQuantity;
  final String unit;
  final int dispatchQuantity;
  final int pendingQuantity;
  final String shadeCardApprovalDate;
  final String nrcDeliveryDate;
  final String dispatchDate;
  final String pendingValidity;
  final JobStatus status;
  final JobDemand? jobDemand;
  final bool isApprovalPending;
  
  // New fields for artwork workflow
  final String? artworkReceivedDate;
  final String? artworkApprovalDate;
  final String? shadeCardDate;
  final bool hasPoAdded;
  final PurchaseOrder? purchaseOrder;

  Job({
    required this.jobNumber,
    required this.customer,
    required this.plant,
    required this.jobDate,
    required this.deliveryDate,
    required this.createdDate,
    required this.createdBy,
    required this.style,
    required this.dieCode,
    required this.boardSize,
    required this.fluteType,
    required this.jobMonth,
    required this.noOfUps,
    required this.noOfSheets,
    required this.totalQuantity,
    required this.unit,
    required this.dispatchQuantity,
    required this.pendingQuantity,
    required this.shadeCardApprovalDate,
    required this.nrcDeliveryDate,
    required this.dispatchDate,
    required this.pendingValidity,
    required this.status,
    this.jobDemand,
    this.isApprovalPending = false,
    this.artworkReceivedDate,
    this.artworkApprovalDate,
    this.shadeCardDate,
    this.hasPoAdded = false,
    this.purchaseOrder,
  });

  // Check if all artwork workflow steps are completed
  bool get isArtworkWorkflowComplete {
    return artworkReceivedDate != null &&
           artworkReceivedDate!.isNotEmpty &&
           artworkApprovalDate != null &&
           artworkApprovalDate!.isNotEmpty &&
           shadeCardDate != null &&
           shadeCardDate!.isNotEmpty;
  }

  // Check if any artwork field is missing
  bool get hasIncompleteArtworkData {
    return (artworkReceivedDate?.isEmpty ?? true) ||
           (artworkApprovalDate?.isEmpty ?? true) ||
           (shadeCardDate?.isEmpty ?? true);
  }

  Job copyWith({
    String? jobNumber,
    String? customer,
    String? plant,
    String? jobDate,
    String? deliveryDate,
    String? createdDate,
    String? createdBy,
    String? style,
    String? dieCode,
    String? boardSize,
    String? fluteType,
    String? jobMonth,
    String? noOfUps,
    String? noOfSheets,
    int? totalQuantity,
    String? unit,
    int? dispatchQuantity,
    int? pendingQuantity,
    String? shadeCardApprovalDate,
    String? nrcDeliveryDate,
    String? dispatchDate,
    String? pendingValidity,
    JobStatus? status,
    JobDemand? jobDemand,
    bool? isApprovalPending,
    String? artworkReceivedDate,
    String? artworkApprovalDate,
    String? shadeCardDate,
    bool? hasPoAdded,
    PurchaseOrder? purchaseOrder,
  }) {
    return Job(
      jobNumber: jobNumber ?? this.jobNumber,
      customer: customer ?? this.customer,
      plant: plant ?? this.plant,
      jobDate: jobDate ?? this.jobDate,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      createdDate: createdDate ?? this.createdDate,
      createdBy: createdBy ?? this.createdBy,
      style: style ?? this.style,
      dieCode: dieCode ?? this.dieCode,
      boardSize: boardSize ?? this.boardSize,
      fluteType: fluteType ?? this.fluteType,
      jobMonth: jobMonth ?? this.jobMonth,
      noOfUps: noOfUps ?? this.noOfUps,
      noOfSheets: noOfSheets ?? this.noOfSheets,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      unit: unit ?? this.unit,
      dispatchQuantity: dispatchQuantity ?? this.dispatchQuantity,
      pendingQuantity: pendingQuantity ?? this.pendingQuantity,
      shadeCardApprovalDate: shadeCardApprovalDate ?? this.shadeCardApprovalDate,
      nrcDeliveryDate: nrcDeliveryDate ?? this.nrcDeliveryDate,
      dispatchDate: dispatchDate ?? this.dispatchDate,
      pendingValidity: pendingValidity ?? this.pendingValidity,
      status: status ?? this.status,
      jobDemand: jobDemand ?? this.jobDemand,
      isApprovalPending: isApprovalPending ?? this.isApprovalPending,
      artworkReceivedDate: artworkReceivedDate ?? this.artworkReceivedDate,
      artworkApprovalDate: artworkApprovalDate ?? this.artworkApprovalDate,
      shadeCardDate: shadeCardDate ?? this.shadeCardDate,
      hasPoAdded: hasPoAdded ?? this.hasPoAdded,
      purchaseOrder: purchaseOrder ?? this.purchaseOrder,
    );
  }
}