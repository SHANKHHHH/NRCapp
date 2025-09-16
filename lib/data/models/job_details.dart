class JobDetails {
  String? nrcJobNo;
  String? styleItemSKU;
  String? customerName;
  String? fluteType;
  String? jobStatus;
  String? latestRate;
  String? preRate;
  String? length;
  String? width;
  String? height;
  String? boxDimensions;
  String? diePunchCode;
  String? boardCategory;
  String? noOfColor;
  String? processColors;
  String? specialColor1;
  String? specialColor2;
  String? specialColor3;
  String? specialColor4;
  String? overPrintFinishing;
  String? topFaceGSM;
  String? flutingGSM;
  String? bottomLinerGSM;
  String? decalBoardX;
  String? lengthBoardY;
  String? boardSize;
  String? noUps;
  String? srNo;
  DateTime? artworkReceivedDate;
  DateTime? artworkApprovedDate;
  DateTime? shadeCardApprovalDate;

  JobDetails({
    this.nrcJobNo,
    this.styleItemSKU,
    this.customerName,
    this.fluteType,
    this.jobStatus,
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
    this.srNo,
    this.artworkReceivedDate,
    this.artworkApprovedDate,
    this.shadeCardApprovalDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'nrcJobNo': nrcJobNo,
      'styleItemSKU': styleItemSKU,
      'customerName': customerName,
      'fluteType': fluteType,
      'status': jobStatus?.toLowerCase(),
      'latestRate': latestRate != null ? double.tryParse(latestRate.toString()) : null,
      'preRate': preRate != null ? double.tryParse(preRate.toString()) : null,
      'length': length != null ? double.tryParse(length.toString()) : null,
      'width': width != null ? double.tryParse(width.toString()) : null,
      'height': height != null ? double.tryParse(height.toString()) : null,
      'boxDimensions': boxDimensions,
      'diePunchCode': diePunchCode != null ? double.tryParse(diePunchCode.toString()) : null,
      'boardCategory': boardCategory,
      'noOfColor': noOfColor,
      'processColors': processColors,
      'specialColor1': specialColor1,
      'specialColor2': specialColor2,
      'specialColor3': specialColor3,
      'specialColor4': specialColor4,
      'overPrintFinishing': overPrintFinishing,
      'topFaceGSM': topFaceGSM,
      'flutingGSM': flutingGSM,
      'bottomLinerGSM': bottomLinerGSM,
      'decalBoardX': decalBoardX,
      'lengthBoardY': lengthBoardY,
      'boardSize': boardSize,
      'noUps': noUps,
      'artworkReceivedDate': artworkReceivedDate?.toIso8601String(),
      'artworkApprovedDate': artworkApprovedDate?.toIso8601String(),
      'shadeCardApprovalDate': shadeCardApprovalDate?.toIso8601String(),
      'srNo': srNo != null ? double.tryParse(srNo.toString()) : null,
    };
  }
} 