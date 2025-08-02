class PurchaseOrder {
  final DateTime poDate;
  final String? poNumber;
  final DateTime deliveryDate;
  final DateTime dispatchDate;
  final DateTime nrcDeliveryDate;
  final int totalPOQuantity;
  final String unit;
  final int pendingValidity;
  final int noOfSheets;

  PurchaseOrder({
    required this.poDate,
    required this.poNumber,
    required this.deliveryDate,
    required this.dispatchDate,
    required this.nrcDeliveryDate,
    required this.totalPOQuantity,
    required this.unit,
    required this.pendingValidity,
    required this.noOfSheets,
  });

  factory PurchaseOrder.fromJson(Map<String, dynamic> json) {
    return PurchaseOrder(
      poDate: json['poDate'] != null ? DateTime.parse(json['poDate'].toString()) : DateTime.now(),
      poNumber: json['poNumber']?.toString(),
      deliveryDate: json['deliveryDate'] != null ? DateTime.parse(json['deliveryDate'].toString()) : DateTime.now(),
      dispatchDate: json['dispatchDate'] != null ? DateTime.parse(json['dispatchDate'].toString()) : DateTime.now(),
      nrcDeliveryDate: json['nrcDeliveryDate'] != null ? DateTime.parse(json['nrcDeliveryDate'].toString()) : DateTime.now(),
      totalPOQuantity: json['totalPOQuantity'] is int ? json['totalPOQuantity'] : int.tryParse(json['totalPOQuantity']?.toString() ?? '0') ?? 0,
      unit: json['unit']?.toString() ?? '',
      pendingValidity: json['pendingValidity'] is int ? json['pendingValidity'] : int.tryParse(json['pendingValidity']?.toString() ?? '0') ?? 0,
      noOfSheets: json['noOfSheets'] is int ? json['noOfSheets'] : int.tryParse(json['noOfSheets']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'poDate': poDate.toIso8601String(),
      'poNumber': poNumber,
      'deliveryDate': deliveryDate.toIso8601String(),
      'dispatchDate': dispatchDate.toIso8601String(),
      'nrcDeliveryDate': nrcDeliveryDate.toIso8601String(),
      'totalPOQuantity': totalPOQuantity,
      'unit': unit,
      'pendingValidity': pendingValidity,
      'noOfSheets': noOfSheets,
    };
  }
}
