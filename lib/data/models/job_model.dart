import 'package:nrc/data/models/purchase_order.dart';

class JobModel {
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
  final String? artworkApprovedDate;
  final String? shadeCardApprovalDate;
  final String? srNo;
  final String? jobDemand;
  final String? imageURL;
  final String? createdAt;
  final String? updatedAt;
  final int? userId;
  final int? machineId;
  final List<PurchaseOrder>? purchaseOrders;


  JobModel({
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
    this.artworkApprovedDate,
    this.shadeCardApprovalDate,
    this.srNo,
    this.jobDemand,
    this.imageURL,
    this.createdAt,
    this.updatedAt,
    this.userId,
    this.machineId,
    this.purchaseOrders
  });

  factory JobModel.fromJson(Map<String, dynamic> json) {
    return JobModel(
      id: json['id'],
      nrcJobNo: json['nrcJobNo'] ?? '',
      styleItemSKU: json['styleItemSKU'] ?? '',
      customerName: json['customerName'] ?? '',
      fluteType: json['fluteType'] ?? '',
      status: json['status'] ?? '',
      latestRate: (json['latestRate'] != null) ? (json['latestRate'] as num?)?.toDouble() : null,
      preRate: (json['preRate'] != null) ? (json['preRate'] as num?)?.toDouble() : null,
      length: json['length'] is int
          ? json['length']
          : (json['length'] is double ? (json['length'] as double).toInt() : null),
      width: json['width'] is int
          ? json['width']
          : (json['width'] is double ? (json['width'] as double).toInt() : null),
      height: json['height'] is int
          ? json['height']
          : (json['height'] is double ? (json['height'] as double).toInt() : null),
      boxDimensions: json['boxDimensions']?.toString(),
      diePunchCode: json['diePunchCode'] is int
          ? json['diePunchCode']
          : (json['diePunchCode'] is double ? (json['diePunchCode'] as double).toInt() : null),
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
      artworkApprovedDate: json['artworkApprovedDate']?.toString(),
      shadeCardApprovalDate: json['shadeCardApprovalDate']?.toString(),
      srNo: json['srNo']?.toString(),
      jobDemand: json['jobDemand']?.toString(),
      imageURL: json['imageURL']?.toString(),
      createdAt: json['createdAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
      userId: json['userId'] is int
          ? json['userId']
          : (json['userId'] is double ? (json['userId'] as double).toInt() : null),
      machineId: json['machineId'] is int
          ? json['machineId']
          : (json['machineId'] is double ? (json['machineId'] as double).toInt() : null),
      purchaseOrders: json['purchaseOrders'] != null
          ? (json['purchaseOrders'] as List)
          .map((po) => PurchaseOrder.fromJson(po))
          .toList()
          : null,
    );
  }
}
