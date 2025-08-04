import 'package:flutter/material.dart';
import 'package:nrc/data/models/purchase_order.dart';

enum JobStatus { active, inactive, hold, workingStarted, completed }
enum JobDemand { high, medium, low }

class Job {
  final int id;
  final String nrcJobNo;
  final String styleItemSKU;
  final String customerName;
  final String fluteType;
  final String status;
  final double? latestRate;
  final double? preRate;
  final int? length;
  final int? width;
  final int? height;
  final String? boxDimensions;
  final int? diePunchCode;
  final String? boardCategory;
  final String? noOfColor;
  final String? processColors;
  final String? specialColor1;
  final String? specialColor2;
  final String? specialColor3;
  final String? specialColor4;
  final String? overPrintFinishing;
  final String? topFaceGSM;
  final String? flutingGSM;
  final String? bottomLinerGSM;
  final String? decalBoardX;
  final String? lengthBoardY;
  final String? boardSize;
  final String? noUps;
  final String? artworkReceivedDate;
  final String? artworkApprovalDate;
  final String? shadeCardApprovalDate;
  final String? srNo;
  final String? jobDemand;
  final String? imageURL;
  final String? createdAt;
  final String? updatedAt;
  final int? userId;
  final int? machineId;
  final bool? isMachineDetailsFilled;
  final PurchaseOrder? purchaseOrder;
  final List<PurchaseOrder>? purchaseOrders;
  final bool? hasPurchaseOrders;


  Job({
    required this.id,
    required this.nrcJobNo,
    required this.styleItemSKU,
    required this.customerName,
    required this.fluteType,
    required this.status,
    this.latestRate,
    this.preRate,
    this.length,
    this.width,
    this.height,
    this.boxDimensions,
    this.diePunchCode,
    this.boardCategory,
    this.noOfColor,
    this.processColors,
    this.specialColor1,
    this.specialColor2,
    this.specialColor3,
    this.specialColor4,
    this.overPrintFinishing,
    this.topFaceGSM,
    this.flutingGSM,
    this.bottomLinerGSM,
    this.decalBoardX,
    this.lengthBoardY,
    this.boardSize,
    this.noUps,
    this.artworkReceivedDate,
    this.artworkApprovalDate,
    this.shadeCardApprovalDate,
    this.srNo,
    this.jobDemand,
    this.imageURL,
    this.createdAt,
    this.updatedAt,
    this.userId,
    this.machineId,
    this.isMachineDetailsFilled,
    this.purchaseOrder,
    this.purchaseOrders,
    this.hasPurchaseOrders,
  });

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: json['id'],
      nrcJobNo: json['nrcJobNo'] ?? '',
      styleItemSKU: json['styleItemSKU'] ?? '',
      customerName: json['customerName'] ?? '',
      fluteType: json['fluteType'] ?? '',
      status: json['status'] ?? '',
      latestRate: (json['latestRate'] != null) ? (json['latestRate'] as num?)?.toDouble() : null,
      preRate: (json['preRate'] != null) ? (json['preRate'] as num?)?.toDouble() : null,
      length: json['length'] is int ? json['length'] : (json['length'] is double ? (json['length'] as double).toInt() : null),
      width: json['width'] is int ? json['width'] : (json['width'] is double ? (json['width'] as double).toInt() : null),
      height: json['height'] is int ? json['height'] : (json['height'] is double ? (json['height'] as double).toInt() : null),
      boxDimensions: json['boxDimensions']?.toString(),
      diePunchCode: json['diePunchCode'] is int ? json['diePunchCode'] : (json['diePunchCode'] is double ? (json['diePunchCode'] as double).toInt() : null),
      boardCategory: json['boardCategory']?.toString(),
      noOfColor: json['noOfColor']?.toString(),
      processColors: json['processColors']?.toString(),
      specialColor1: json['specialColor1']?.toString(),
      specialColor2: json['specialColor2']?.toString(),
      specialColor3: json['specialColor3']?.toString(),
      specialColor4: json['specialColor4']?.toString(),
      overPrintFinishing: json['overPrintFinishing']?.toString(),
      topFaceGSM: json['topFaceGSM']?.toString(),
      flutingGSM: json['flutingGSM']?.toString(),
      bottomLinerGSM: json['bottomLinerGSM']?.toString(),
      decalBoardX: json['decalBoardX']?.toString(),
      lengthBoardY: json['lengthBoardY']?.toString(),
      boardSize: json['boardSize']?.toString(),
      noUps: json['noUps']?.toString(),
      artworkReceivedDate: json['artworkReceivedDate']?.toString(),
      artworkApprovalDate: json['artworkApprovalDate']?.toString(),
      shadeCardApprovalDate: json['shadeCardApprovalDate']?.toString(),
      srNo: json['srNo']?.toString(),
      jobDemand: json['jobDemand']?.toString(),
      imageURL: json['imageURL']?.toString(),
      createdAt: json['createdAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
      userId: json['userId'] is int ? json['userId'] : (json['userId'] is double ? (json['userId'] as double).toInt() : null),
      machineId: json['machineId'] is int ? json['machineId'] : (json['machineId'] is double ? (json['machineId'] as double).toInt() : null),
      isMachineDetailsFilled: json['isMachineDetailsFilled'] as bool?,
      purchaseOrder: json['purchaseOrder'] != null ? PurchaseOrder.fromJson(json['purchaseOrder']) : null,
      purchaseOrders: json['purchaseOrders'] != null
          ? List<PurchaseOrder>.from((json['purchaseOrders'] as List).map((po) => PurchaseOrder.fromJson(po)))
          : [],
      hasPurchaseOrders: json['hasPurchaseOrders'],
    );
  }

  // Check if all artwork workflow steps are completed
  bool get isArtworkWorkflowComplete {
    return artworkReceivedDate != null &&
        artworkReceivedDate!.isNotEmpty &&
        artworkApprovalDate != null &&
        artworkApprovalDate!.isNotEmpty &&
        shadeCardApprovalDate != null &&
        shadeCardApprovalDate!.isNotEmpty;
  }

  // Check if any artwork field is missing
  bool get hasIncompleteArtworkData {
    return (artworkReceivedDate?.isEmpty ?? true) ||
        (artworkApprovalDate?.isEmpty ?? true) ||
        (shadeCardApprovalDate?.isEmpty ?? true);
  }

  bool get hasPoAdded => purchaseOrder != null;

  Job copyWith({
    int? id,
    String? nrcJobNo,
    String? styleItemSKU,
    String? customerName,
    String? fluteType,
    String? status,
    double? latestRate,
    double? preRate,
    int? length,
    int? width,
    int? height,
    String? boxDimensions,
    int? diePunchCode,
    String? boardCategory,
    String? noOfColor,
    String? processColors,
    String? specialColor1,
    String? specialColor2,
    String? specialColor3,
    String? specialColor4,
    String? overPrintFinishing,
    String? topFaceGSM,
    String? flutingGSM,
    String? bottomLinerGSM,
    String? decalBoardX,
    String? lengthBoardY,
    String? boardSize,
    String? noUps,
    String? artworkReceivedDate,
    String? artworkApprovalDate,
    String? shadeCardApprovalDate,
    String? srNo,
    String? jobDemand,
    String? imageURL,
    String? createdAt,
    String? updatedAt,
    int? userId,
    int? machineId,
    bool? isMachineDetailsFilled,
    PurchaseOrder? purchaseOrder,
    List<PurchaseOrder>? purchaseOrders,
    bool? hasPurchaseOrders,
  }) {
    return Job(
      id: id ?? this.id,
      nrcJobNo: nrcJobNo ?? this.nrcJobNo,
      styleItemSKU: styleItemSKU ?? this.styleItemSKU,
      customerName: customerName ?? this.customerName,
      fluteType: fluteType ?? this.fluteType,
      status: status ?? this.status,
      latestRate: latestRate ?? this.latestRate,
      preRate: preRate ?? this.preRate,
      length: length ?? this.length,
      width: width ?? this.width,
      height: height ?? this.height,
      boxDimensions: boxDimensions ?? this.boxDimensions,
      diePunchCode: diePunchCode ?? this.diePunchCode,
      boardCategory: boardCategory ?? this.boardCategory,
      noOfColor: noOfColor ?? this.noOfColor,
      processColors: processColors ?? this.processColors,
      specialColor1: specialColor1 ?? this.specialColor1,
      specialColor2: specialColor2 ?? this.specialColor2,
      specialColor3: specialColor3 ?? this.specialColor3,
      specialColor4: specialColor4 ?? this.specialColor4,
      overPrintFinishing: overPrintFinishing ?? this.overPrintFinishing,
      topFaceGSM: topFaceGSM ?? this.topFaceGSM,
      flutingGSM: flutingGSM ?? this.flutingGSM,
      bottomLinerGSM: bottomLinerGSM ?? this.bottomLinerGSM,
      decalBoardX: decalBoardX ?? this.decalBoardX,
      lengthBoardY: lengthBoardY ?? this.lengthBoardY,
      boardSize: boardSize ?? this.boardSize,
      noUps: noUps ?? this.noUps,
      artworkReceivedDate: artworkReceivedDate ?? this.artworkReceivedDate,
      artworkApprovalDate: artworkApprovalDate ?? this.artworkApprovalDate,
      shadeCardApprovalDate: shadeCardApprovalDate ?? this.shadeCardApprovalDate,
      srNo: srNo ?? this.srNo,
      jobDemand: jobDemand ?? this.jobDemand,
      imageURL: imageURL ?? this.imageURL,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
      machineId: machineId ?? this.machineId,
      isMachineDetailsFilled: isMachineDetailsFilled ?? this.isMachineDetailsFilled,
      purchaseOrder: purchaseOrder ?? this.purchaseOrder,
      purchaseOrders: purchaseOrders ?? this.purchaseOrders,
      hasPurchaseOrders: hasPurchaseOrders ?? this.hasPurchaseOrders,
    );
  }
}